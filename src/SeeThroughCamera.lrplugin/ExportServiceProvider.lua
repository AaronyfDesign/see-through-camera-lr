-- ExportServiceProvider.lua — custom export destination "机型预览卡片".
--
-- Shows up in the Export dialog's "Export To" dropdown. LR renders each
-- selected photo at full resolution (File Settings etc. apply), and for
-- every rendition this provider runs the see-through-camera CLI to turn
-- the rendered JPEG into a body-preview card.
--
-- NOTE: rendition:renderImage() only exists in this export-provider
-- context — the same call from a plain menu-item LrExportSession returns
-- nil (verified: that path must use session:doExportOnCurrentTask()).
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrShell = import 'LrShell'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrDate = import 'LrDate'

local CONFIG = require 'Config'

local OUTDIR = LrPathUtils.child(_PLUGIN.path, 'output')

local function dbg(msg)
  local f = io.open(LrPathUtils.child(OUTDIR, 'debug.txt'), 'a')
  if f then
    f:write(os.date('%H:%M:%S') .. ' [export] ' .. tostring(msg) .. '\n')
    f:close()
  end
end

return {
  exportPresetFields = {
    { key = 'bgMode', default = 'soft' },
  },

  sectionsForTopOfDialog = function(f, propertyTable)
    return {
      {
        title = '机型预览卡片',
        f:row {
          spacing = f:control_spacing(),
          f:static_text {
            title = '背景模式',
            alignment = 'right',
            width = 80,
          },
          f:popup_menu {
            value = LrView.bind { table = propertyTable, key = 'bgMode' },
            items = {
              { value = 'soft',   title = '柔和虚化' },
              { value = 'radial', title = '径向模糊' },
              { value = 'solid',  title = '纯色填充' },
            },
            width = 120,
          },
        },
      },
    }
  end,

  processRenderedPhotos = function(functionContext, exportContext)
    LrFileUtils.createAllDirectories(OUTDIR)
    local propertyTable = exportContext.propertyTable
    local bgMode = propertyTable.bgMode or 'soft'
    dbg('=== export started, bgMode=' .. bgMode)

    local lastCard = nil
    local failures = {}

    for _, rendition in exportContext:renditions { stopOnError = true } do
      local okR, pathOrMessage = rendition:renderImage()
      dbg('render ok=' .. tostring(okR) .. ' src=' .. tostring(pathOrMessage))
      if not okR then
        rendition:skipThisRendition()
        failures[#failures + 1] = tostring(pathOrMessage)
      else
        -- rendered temp file carries EXIF -> CLI resolves the body itself
        local photo = rendition.photo
        local okN, photoName = pcall(function()
          return photo:getFormattedMetadata('fileName') end)
        local stem = 'photo'
        if okN and photoName then
          stem = photoName:match('^(.*)%.') or photoName
        end
        local outPath = LrPathUtils.child(OUTDIR, string.format(
          'card_%s_%s.jpg', LrDate.currentTime(),
          (stem:gsub('[^%w%-_]', '_'))))
        local cmd = table.concat({
          '"', CONFIG.python, '" "', CONFIG.cli, '" "', pathOrMessage, '"',
          ' --body auto --bg ', bgMode,
          ' -o "', outPath, '"',
          ' >> "', OUTDIR, '/cli.log" 2>&1',
        })
        dbg('exec: ' .. cmd)
        local status = LrTasks.execute(cmd)
        dbg('execute status=' .. tostring(status))
        if status == 0 then
          lastCard = outPath
        else
          failures[#failures + 1] = stem .. '（CLI 渲染失败，见 output/cli.log）'
        end
      end
    end

    if #failures > 0 then
      LrDialogs.message('See-Through Camera',
        table.concat(failures, '\n'))
    end
    if lastCard then
      LrShell.revealInShell(lastCard)
    end
    dbg('=== export finished, cards=' .. tostring(lastCard ~= nil))
  end,
}
