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

--- Build the shell command that renders `srcPath` into `outPath`.
--- Returns command string, renderer name (for logs).
local function renderCommand(srcPath, outPath, bgMode)
  local log = quote(LrPathUtils.child(OUTDIR, 'cli.log')) .. ' 2>&1'

  local binary = CONFIG.binary
  if binary and binary ~= '' and LrFileUtils.exists(binary) then
    local cmd = table.concat({
      quote(binary), quote(srcPath),
      '--body auto', '--bg ' .. bgMode,
      '--profiles', quote(CONFIG.profiles),
      '--fonts', quote(CONFIG.fonts),
      '-o', quote(outPath),
      '>>', log,
    }, ' ')
    return cmd, 'cardgen'
  end

  local cmd = table.concat({
    quote(CONFIG.python), quote(CONFIG.cli), quote(srcPath),
    '--body auto', '--bg ' .. bgMode,
    '-o', quote(outPath),
    '>>', log,
  }, ' ')
  return cmd, 'python-cli'
end

return {
  OUTDIR = OUTDIR,
  renderCommand = renderCommand,
}
