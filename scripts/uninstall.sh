#!/bin/zsh
# uninstall.sh — remove the plugin from Lightroom Classic's Modules folder
# and unregister it from the plugin-path preference.
set -e

PLUGIN_NAME="SeeThroughCamera.lrplugin"
MODULES="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
DEST="$MODULES/$PLUGIN_NAME"
DOMAIN="com.adobe.LightroomClassicCC7"
KEY="AgSdkPluginLoader_installedPluginPaths"

rm -rf "$DEST" && echo "removed: $DEST" || true

python3 - "$DEST" "$DOMAIN" "$KEY" <<'PYEOF'
import re, subprocess, sys

dest, domain, key = sys.argv[1], sys.argv[2], sys.argv[3]
raw = subprocess.run(['defaults', 'read', domain, key],
                     capture_output=True, text=True).stdout
paths = re.findall(r'\["(.*?)"\]\s*=\s*true', raw)
paths = [p for p in paths if p != dest]
if paths:
    body = ',\n'.join(f'\t["{p}"] = true' for p in paths)
    subprocess.run(['defaults', 'write', domain, key, '-string', f't = {{\n{body},\n}}'],
                   check=True)
else:
    subprocess.run(['defaults', 'delete', domain, key], capture_output=True)
print('remaining paths:', paths or '(none)')
PYEOF

echo "done. Restart Lightroom Classic."
