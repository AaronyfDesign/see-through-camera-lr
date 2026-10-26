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
local RENDER = require 'Renderer'

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
    dbg('about to iterate renditions')

    local idx = 0
    for _, rendition in exportContext:renditions { stopOnError = true } do
      idx = idx + 1
      -- LR 15.4.1 has no rendition:renderImage() in export-provider
      -- context: renditions arrive already rendered; destinationPath
      -- (property) is the finished file (verified by strings on the
      -- bundled LrExportRendition.lua bytecode).
      local pathOrMessage = rendition.destinationPath
      dbg('rendition #' .. idx .. ' path=' .. tostring(pathOrMessage))

      -- Runtime introspection: dump every member reachable through the
      -- object and its metatable chain, so we learn the real API.
      local function dumpObj(obj, label)
        local names, seen, cur, depth = {}, {}, obj, 0
        while cur and depth < 4 do
          local okT, t = pcall(function() return cur end)
          if okT and type(t) == 'table' then
            for k, v in pairs(t) do
              if not seen[tostring(k)] then
                seen[tostring(k)] = true
                names[#names + 1] = tostring(k) .. '(' .. type(v) .. ')'
              end
            end
          end
          local okM, mt = pcall(getmetatable, cur)
          cur = (okM and mt and mt.__index) or nil
          depth = depth + 1
        end
        dbg(label .. ' members: ' .. table.concat(names, ', '))
      end
      dumpObj(rendition, 'rendition#' .. tostring(idx))

      -- destinationPath can be set before rendering finishes. Copy the
      -- completed JPEG before metadata calls yield to other Lightroom tasks.
      local inputPath = nil
      local rendered, renderPath = rendition:waitForRender()
      if rendered then
        local snapshotPath = LrPathUtils.child(OUTDIR, string.format(
          'rendition_%s_%d.jpg', LrDate.currentTime(), idx))
        if LrFileUtils.copy(renderPath or pathOrMessage, snapshotPath) then
          inputPath = snapshotPath
        end
      end
      dbg('chosen input=' .. tostring(inputPath))

      if not inputPath then
        failures[#failures + 1] = '渲染数据不可用（'
          .. tostring(idx) .. '）'
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
        local cmd, which = RENDER.renderCommand(inputPath, outPath, bgMode)
        dbg('exec [' .. which .. ']: ' .. cmd)
        local status = LrTasks.execute(cmd)
        dbg('execute status=' .. tostring(status))
        LrFileUtils.delete(inputPath)
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
