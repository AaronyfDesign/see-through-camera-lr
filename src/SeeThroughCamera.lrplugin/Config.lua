-- Config.lua — TEMPLATE. You normally never edit this file: the install
-- scripts regenerate it (in the installed copy) with paths detected on
-- your machine. Edit it manually only if you installed the plugin by hand.
--
-- Preferred renderer: native cardgen binary (no Python needed).
--   binary:   cardgen executable (bin/cardgen or bin/cardgen.exe)
--   profiles: body_profiles/ directory (body PNGs + profile.json)
--   fonts:    fonts/ directory (InterVariable + JetBrains Mono TTFs)
-- Fallback renderer: Python CLI (needs Python 3 + Pillow).
--   python: interpreter that runs the CLI
--   cli:    cli/watermark.py of a see-through-camera checkout
-- If `binary` is empty or missing, the plugin uses the Python fallback.
return {
  binary = '',
  profiles = '',
  fonts = '',
  python = '/path/to/python3',
  cli = '/path/to/see-through-camera/cli/watermark.py',
}
