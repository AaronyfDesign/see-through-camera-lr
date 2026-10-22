-- SeeThroughCard.lua — shared implementation for all menu entries.
--
-- Chain: selected photo -> full-resolution JPEG export (keeps EXIF, so the
-- CLI reads model/exposure itself and resolves the body profile via
-- `--body auto`) -> external CLI renders the card -> reveal in Finder.
--
-- Verified SDK behaviours baked in here (see prototype at
-- /Users/zhangyf/work/personal/see-through-lr):
--   * metadata getters yield internally: never call them inside pcall
--   * the whole flow must run inside an async task
--   * LrLogger is unreliable on this machine: we log to output/debug.txt
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrExportSession = import 'LrExportSession'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrShell = import 'LrShell'
local LrTasks = import 'LrTasks'
local LrDate = import 'LrDate'

local CONFIG = require 'Config'

local OUTDIR = LrPathUtils.child(_PLUGIN.path, 'output')

local function dbg(msg)
  local f = io.open(LrPathUtils.child(OUTDIR, 'debug.txt'), 'a')
  if f then
    f:write(os.date('%H:%M:%S') .. ' ' .. tostring(msg) .. '\n')
    f:close()
  end
end

local function makeCard(bgMode)
  LrTasks.startAsyncTask(function()
    LrFileUtils.createAllDirectories(OUTDIR)
    dbg('=== menu fired, mode=' .. bgMode)

    local cat = LrApplication.activeCatalog()
    local sel = cat:getTargetPhotos()
    dbg('selection=' .. #sel)
    if #sel == 0 then
      LrDialogs.message('See-Through Camera', '请先在图库中选中一张照片')
      return
    end
    local photo = sel[1]

    -- yields internally; must not be wrapped in pcall
    local model = photo:getFormattedMetadata('cameraModel')
    dbg('model=' .. tostring(model))

    local progress = LrProgressScope {
      title = 'See-Through Card',
      caption = '导出全分辨率 JPEG…',
    }

    -- 1. full-resolution JPEG export (real EXIF -> CLI needs no --meta)
    -- NOTE (verified against LR 15.4.1's bundled AgExportSettings.lua):
    --   * destination is resolved from INTERNAL keys (no LR_ prefix):
    --     export_destinationType = 'specificFolder' | 'tempFolder' |
    --     'chooseLater'; the UI-preset LR_export_* keys are ignored here
    --   * LrExportRendition exposes destinationPath as a property; there is
    --     no renderImage()/getRenditions() on this SDK level
    local session = LrExportSession {
      photosToExport = { photo },
      exportSettings = {
        LR_format = 'JPEG',
        LR_export_quality = 0.92,
        LR_size_doConstrain = false,
        LR_collisionHandling = 'overwrite',
        export_destinationType = 'specificFolder',
        export_destinationPathPrefix = OUTDIR,
        export_destinationPathSuffix = '',
      },
    }
    local okE, errE = LrTasks.pcall(function()
      session:doExportOnCurrentTask() end)
    dbg('export ok=' .. tostring(okE) .. ' err=' .. tostring(errE))
    local srcPath
    for _, rendition in session:renditions { stopOnError = true } do
      local p = rendition.destinationPath
      if type(p) == 'function' then
        local okP, pp = LrTasks.pcall(function()
          return rendition:destinationPath() end)
        p = okP and pp or nil
      end
      dbg('rendition dest=' .. tostring(p))
      if p then srcPath = p end
    end
    if not srcPath then
      progress:done()
      LrDialogs.message('See-Through Camera',
        '导出 JPEG 失败: ' .. tostring(errE or srcPath))
      return
    end
    local okS, ssize = LrTasks.pcall(function()
      return LrFileUtils.fileAttributes(srcPath).fileSize end)
    dbg('src=' .. tostring(srcPath) .. ' size=' .. tostring(ssize))
    if not (srcPath and okS and ssize and ssize > 0) then
      progress:done()
      LrDialogs.message('See-Through Camera',
        '导出文件未落盘: ' .. tostring(srcPath))
      return
    end

    -- 2. external renderer
    progress:setCaption('渲染回屏卡片…')
    local outPath = LrPathUtils.child(OUTDIR,
      'card_' .. LrDate.currentTime() .. '.jpg')
    local cmd = table.concat({
      '"', CONFIG.python, '" "', CONFIG.cli, '" "', srcPath, '"',
      ' --body auto --bg ', bgMode,
      ' -o "', outPath, '"',
      ' >> "', OUTDIR, '/cli.log" 2>&1',
    })
    dbg('exec: ' .. cmd)
    local status = LrTasks.execute(cmd)
    dbg('execute status=' .. tostring(status))
    progress:done()
    if status == 0 then
      dbg('card written: ' .. outPath)
      -- NOTE: LrDialogs has no showInFinder (verified against LR 15.4.1's
      -- bundled LrDialogs.lua) — LrShell.revealInShell is the real API.
      LrShell.revealInShell(outPath)
    else
      LrDialogs.message('See-Through Camera',
        '渲染失败，详见 output/cli.log 与 output/debug.txt')
    end
  end, 'stc-' .. bgMode)
end

return makeCard
