#!/bin/zsh
# install.sh - copy the plugin into Lightroom Classic's Modules folder and
# fix the plugin-path preference (replaces any older registration of this
# plugin, e.g. the prototype under see-through-lr).
#
# Renderer priority:
#   1. Native cardgen binary (no Python needed):
#      - $SEE_THROUGH_CAMERA_CARDGEN override, or
#      - bundled with this download (bin/, fonts/, body_profiles/ next to
#        this script - Release ZIP layout), or
#      - built from a see-through-camera checkout (cli/native/build.sh).
#   2. Python CLI fallback: needs python3 + Pillow + a see-through-camera
#      checkout (auto-detected; see env overrides below).
#
# Environment overrides:
#   SEE_THROUGH_CAMERA_CARDGEN  path to a prebuilt cardgen binary
#   SEE_THROUGH_CAMERA_PYTHON   python interpreter (fallback renderer)
#   SEE_THROUGH_CAMERA_CLI      path to cli/watermark.py (fallback renderer)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# repo layout: src/ next to scripts/ ; Release ZIP: plugin next to install.sh
if [ -d "$SCRIPT_DIR/../src/SeeThroughCamera.lrplugin" ]; then
  SRC_DIR="$(cd "$SCRIPT_DIR/../src" && pwd)"
  REPO_DIR="$(cd "$SRC_DIR/.." && pwd)"
else
  SRC_DIR="$SCRIPT_DIR"
  REPO_DIR="$SCRIPT_DIR"
fi
PLUGIN_NAME="SeeThroughCamera.lrplugin"
MODULES="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
DEST="$MODULES/$PLUGIN_NAME"
DOMAIN="com.adobe.LightroomClassicCC7"
KEY="AgSdkPluginLoader_installedPluginPaths"

# Lightroom may never have run yet - create the Modules folder ourselves.
mkdir -p "$MODULES"

# --- locate a see-through-camera checkout (profiles/fonts/binary source) --
STC="${SEE_THROUGH_CAMERA_STC:-}"
if [ -z "$STC" ]; then
  for cand in "$REPO_DIR/../see-through-camera" \
              "$REPO_DIR/see-through-camera" \
              "$SCRIPT_DIR/see-through-camera"; do
    if [ -d "$cand/body_profiles" ]; then STC="$cand"; break; fi
  done
fi

# --- renderer 1: native cardgen ------------------------------------------
BIN_SRC="${SEE_THROUGH_CAMERA_CARDGEN:-}"
FONTS_SRC=""
PROFILES_SRC=""
if [ -z "$BIN_SRC" ]; then
  # Release ZIP layout: bin/ + fonts/ + body_profiles/ next to this script
  if [ -x "$SCRIPT_DIR/bin/cardgen" ]; then
    BIN_SRC="$SCRIPT_DIR/bin/cardgen"
    [ -d "$SCRIPT_DIR/fonts" ] && FONTS_SRC="$SCRIPT_DIR/fonts"
    [ -d "$SCRIPT_DIR/body_profiles" ] && PROFILES_SRC="$SCRIPT_DIR/body_profiles"
  fi
fi
if [ -z "$BIN_SRC" ] && [ -n "$STC" ]; then
  # already built in the checkout?
  if [ -x "$STC/cli/native-build/cardgen" ]; then
    BIN_SRC="$STC/cli/native-build/cardgen"
  elif command -v cc >/dev/null 2>&1; then
    echo "building native renderer from source..."
    (cd "$STC/cli/native" && sh build.sh) || true
    [ -x "$STC/cli/native-build/cardgen" ] && BIN_SRC="$STC/cli/native-build/cardgen"
  fi
  [ -n "$BIN_SRC" ] && FONTS_SRC="$STC/cli/native/fonts"
  [ -n "$BIN_SRC" ] && PROFILES_SRC="$STC/body_profiles"
fi

NATIVE_OK=0
if [ -n "$BIN_SRC" ] && [ -x "$BIN_SRC" ] && [ -d "$PROFILES_SRC" ] && [ -d "$FONTS_SRC" ]; then
  NATIVE_OK=1
else
  echo "note: native renderer not available - falling back to the Python CLI."
fi

# --- renderer 2 (fallback): Python CLI ------------------------------------
CLI="${SEE_THROUGH_CAMERA_CLI:-}"
PY="${SEE_THROUGH_CAMERA_PYTHON:-}"
if [ "$NATIVE_OK" = 0 ]; then
  if [ -z "$CLI" ] && [ -n "$STC" ]; then CLI="$STC/cli/watermark.py"; fi
  if [ -z "$CLI" ] || [ ! -f "$CLI" ]; then
    echo "error: no renderer available." >&2
    echo "  Either provide the native renderer (Release ZIP ships it, or" >&2
    echo "  clone see-through-camera next to this repo so it can build):" >&2
    echo "    SEE_THROUGH_CAMERA_CARDGEN=/path/to/cardgen $0" >&2
    echo "  or the Python fallback:" >&2
    echo "    SEE_THROUGH_CAMERA_CLI=/path/to/see-through-camera/cli/watermark.py $0" >&2
    exit 1
  fi
  CLI="$(cd "$(dirname "$CLI")" && pwd)/$(basename "$CLI")"
  if [ -z "$PY" ]; then
    PY="$(command -v python3 || true)"
  fi
  if [ -z "$PY" ] || [ ! -x "$PY" ]; then
    echo "error: python3 not found on PATH." >&2
    echo "  Install Python 3 (with Pillow) or set:" >&2
    echo "    SEE_THROUGH_CAMERA_PYTHON=/path/to/python $0" >&2
    exit 1
  fi
  if ! "$PY" -c 'import PIL' 2>/dev/null; then
    echo "warning: $PY cannot import PIL (Pillow). The CLI needs it:" >&2
    echo "  '$PY' -m pip install Pillow" >&2
  fi
fi

# --- copy (replace) the plugin --------------------------------------------
rm -rf "$DEST"
cp -R "$SRC_DIR/$PLUGIN_NAME" "$DEST"
echo "installed: $DEST"

if [ "$NATIVE_OK" = 1 ]; then
  mkdir -p "$DEST/bin"
  cp "$BIN_SRC" "$DEST/bin/cardgen"
  cp -R "$FONTS_SRC" "$DEST/fonts"
  cp -R "$PROFILES_SRC" "$DEST/body_profiles"
  # Release ZIPs carry a quarantine xattr that would stop LR from
  # executing the binary; clear it (best-effort, harmless if absent).
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
  echo "renderer:  native cardgen ($BIN_SRC)"
fi

# --- generate the machine-specific Config.lua ------------------------------
BIN_LUA="" ; PROFILES_LUA="" ; FONTS_LUA=""
PY_LUA="''" ; CLI_LUA="''"
if [ "$NATIVE_OK" = 1 ]; then
  BIN_LUA="'$DEST/bin/cardgen'"
  PROFILES_LUA="'$DEST/body_profiles'"
  FONTS_LUA="'$DEST/fonts'"
fi
if [ "$NATIVE_OK" = 0 ]; then
  PY_LUA="'$PY'"
  CLI_LUA="'$CLI'"
fi
cat > "$DEST/Config.lua" <<CFGEOF
-- Config.lua - generated by install.sh on $(date '+%Y-%m-%d %H:%M').
-- Do not edit by hand; re-run install.sh instead.
return {
  binary = $BIN_LUA,
  profiles = $PROFILES_LUA,
  fonts = $FONTS_LUA,
  python = $PY_LUA,
  cli = $CLI_LUA,
}
CFGEOF

# --- register in the plugin-path preference (replace stale paths) ----------
python3 - "$DEST" "$DOMAIN" "$KEY" <<'PYEOF'
import re, subprocess, sys

dest, domain, key = sys.argv[1], sys.argv[2], sys.argv[3]
raw = subprocess.run(['defaults', 'read', domain, key],
                     capture_output=True, text=True).stdout
# value is Lua-table shaped:  t = { ["/path" ] = true, ... }
paths = re.findall(r'\["(.*?)"\]\s*=\s*true', raw)
paths = [p for p in paths
         if not p.endswith('/' + dest.split('/')[-1])]
if dest not in paths:
    paths.append(dest)
body = ',\n'.join(f'\t["{p}"] = true' for p in paths)
subprocess.run(['defaults', 'write', domain, key, '-string', f't = {{\n{body},\n}}'],
               check=True)
print('registered:', dest)
print('all paths:', paths)
PYEOF

echo
echo "done. (Re)start Lightroom Classic to load the plugin."
