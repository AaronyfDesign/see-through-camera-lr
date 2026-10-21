#!/bin/zsh
# install.sh — copy the plugin into Lightroom Classic's Modules folder and
# fix the plugin-path preference (replaces any older registration of this
# plugin, e.g. the prototype under see-through-lr).
set -e

SRC_DIR="$(cd "$(dirname "$0")/../src" && pwd)"
PLUGIN_NAME="SeeThroughCamera.lrplugin"
MODULES="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
DEST="$MODULES/$PLUGIN_NAME"
DOMAIN="com.adobe.LightroomClassicCC7"
KEY="AgSdkPluginLoader_installedPluginPaths"

[ -d "$MODULES" ] || { echo "error: Lightroom Modules folder not found: $MODULES" >&2; exit 1; }

# 1. copy (replace) the plugin
rm -rf "$DEST"
cp -R "$SRC_DIR/$PLUGIN_NAME" "$DEST"
echo "installed: $DEST"

# 2. register in the plugin-path preference (replace stale paths)
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
