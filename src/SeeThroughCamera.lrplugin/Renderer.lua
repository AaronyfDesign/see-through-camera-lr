-- Renderer.lua — shared external-renderer invocation.
--
-- Prefers the native cardgen binary (no Python needed); falls back to the
-- Python CLI when Config.binary is empty or the file is missing. Both
-- paths resolve the body profile from the input JPEG's own EXIF
-- (`--body auto`), so callers only supply input/output/background.
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local CONFIG = require 'Config'

local OUTDIR = LrPathUtils.child(_PLUGIN.path, 'output')

local function quote(s)
  return '"' .. s .. '"'
end

-- Strip the macOS Gatekeeper quarantine flag from the bundled cardgen
-- binary. Release zips downloaded via a browser carry the quarantine
-- extended attribute; unsigned ad-hoc binaries are then killed on sight by
-- Gatekeeper (observed on macOS 26: SIGKILL, LrTasks.execute returns != 0
-- and the export reports "CLI render failed"). Removing the attribute needs
-- no user interaction, so the plugin self-heals on first export.
local function dequarantine(binary)
  if not (LrPathUtils and binary and binary ~= ''
          and not binary:find('\\', 1, true)) then
    return -- non-mac path or no binary: nothing to do
  end
  os.execute('/usr/bin/xattr -dr com.apple.quarantine '
             .. quote(binary) .. ' 2>/dev/null')
end

local function forExecution(cmd)
  -- On Windows, cmd /c removes the first and last quotes of a quoted command.
  return OUTDIR:find('\\', 1, true) and quote(cmd) or cmd
end

--- Build the shell command that renders `srcPath` into `outPath`.
--- Returns command string, renderer name (for logs).
local function renderCommand(srcPath, outPath, bgMode, bodyScale)
  local log = quote(LrPathUtils.child(OUTDIR, 'cli.log')) .. ' 2>&1'

  local binary = CONFIG.binary
  if binary and binary ~= '' and LrFileUtils.exists(binary) then
    dequarantine(binary)
    local scale = tonumber(bodyScale) or 1.0
    local cmd = table.concat({
      quote(binary), quote(srcPath),
      '--body auto', '--bg ' .. bgMode,
      '--profiles', quote(CONFIG.profiles),
      '--fonts', quote(CONFIG.fonts),
      '-o', quote(outPath),
      '>>', log,
    }, ' ')
    if scale > 1.001 then
      cmd = cmd .. ' --body-scale ' .. string.format('%.2f', scale)
    end
    return forExecution(cmd), 'cardgen'
  end

  local cmd = table.concat({
    quote(CONFIG.python), quote(CONFIG.cli), quote(srcPath),
    '--body auto', '--bg ' .. bgMode,
    '-o', quote(outPath),
    '>>', log,
  }, ' ')
  return forExecution(cmd), 'python-cli'
end

return {
  OUTDIR = OUTDIR,
  renderCommand = renderCommand,
}
