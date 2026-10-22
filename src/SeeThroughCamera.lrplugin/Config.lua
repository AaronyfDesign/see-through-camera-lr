-- Config.lua — TEMPLATE. You normally never edit this file: install.sh
-- regenerates it (in the installed copy) with paths detected on your
-- machine. Edit it manually only if you installed the plugin by hand.
--
-- python: interpreter that runs the CLI; needs Pillow (PIL).
-- cli:    cli/watermark.py of a see-through-camera checkout — body
--         profiles are resolved from that repo's body_profiles/ dir.
return {
  python = '/path/to/python3',
  cli = '/path/to/see-through-camera/cli/watermark.py',
}
