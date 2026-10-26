# install.ps1 - Windows installer for the See-Through Camera Lightroom
# plugin. The .lrplugin itself is cross-platform; this script copies it
# into Lightroom Classic's per-user Modules folder and generates a
# machine-specific Config.lua.
#
# Renderer priority:
#   1. Native cardgen binary (no Python needed): bundled bin\cardgen.exe
#      + fonts\ + body_profiles\ next to this script (Release ZIP layout),
#      or $env:SEE_THROUGH_CAMERA_CARDGEN.
#   2. Python CLI fallback: needs Python 3 + Pillow + a
#      see-through-camera checkout.
#
# Usage:
#   install.ps1                  install from the repo (src/) or from a
#                                bundled SeeThroughCamera.lrplugin next
#                                to this script (Release ZIP layout)
#   install.ps1 C:\path\SeeThroughCamera.lrplugin
#                                install the given plugin folder (this
#                                is what dragging it onto install.cmd
#                                does)
#
# Fallback env overrides:
#   SEE_THROUGH_CAMERA_CARDGEN  path to a prebuilt cardgen.exe
#   SEE_THROUGH_CAMERA_PYTHON   python interpreter (fallback renderer)
#   SEE_THROUGH_CAMERA_CLI      path to cli\watermark.py (fallback renderer)
param([string]$PluginPath = '')
$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent $PSScriptRoot          # see-through-camera-lr
$modules = Join-Path $env:APPDATA 'Adobe\Lightroom\Modules'
$dest    = Join-Path $modules 'SeeThroughCamera.lrplugin'

# --- locate the plugin source --------------------------------------------
# priority: explicit path (drag-drop) > bundled copy (Release ZIP) > repo src
if ($PluginPath) {
    if (-not (Test-Path $PluginPath)) {
        Write-Error "plugin folder not found: $PluginPath"
    }
    $src = $PluginPath
} elseif (Test-Path (Join-Path $PSScriptRoot 'SeeThroughCamera.lrplugin')) {
    $src = Join-Path $PSScriptRoot 'SeeThroughCamera.lrplugin'
} else {
    $src = Join-Path $repoDir 'src\SeeThroughCamera.lrplugin'
}
# Lightroom Classic may not have run yet on a fresh machine, so the
# Modules folder does not exist - create it (LR scans this folder for
# plugins on every start).
New-Item -ItemType Directory -Path $modules -Force | Out-Null

# --- locate the native renderer ------------------------------------------
# priority: env > bundled bin\cardgen.exe (Release ZIP layout)
$bin = $env:SEE_THROUGH_CAMERA_CARDGEN
$fontsDir = $null
$profilesDir = $null
if (-not $bin) {
    $candBin = Join-Path $PSScriptRoot 'bin\cardgen.exe'
    if (Test-Path $candBin) {
        $bin = $candBin
        $f = Join-Path $PSScriptRoot 'fonts'
        $p = Join-Path $PSScriptRoot 'body_profiles'
        if ((Test-Path $f) -and (Test-Path $p)) {
            $fontsDir = $f
            $profilesDir = $p
        } else {
            $bin = $null
        }
    }
} elseif (-not (Test-Path $bin)) {
    Write-Error "cardgen binary not found: $bin"
}
$nativeOk = [bool]$bin -and (Test-Path $bin) -and $fontsDir -and $profilesDir

# --- locate the CLI (Python fallback) -------------------------------------
# priority: env > bundled cli\watermark.py (Release ZIP) > sibling/repo checkout
$cli = $env:SEE_THROUGH_CAMERA_CLI
if (-not $nativeOk) {
    if (-not $cli) {
        foreach ($cand in @(
            (Join-Path $PSScriptRoot 'cli\watermark.py'),
            (Join-Path (Split-Path -Parent $repoDir) 'see-through-camera\cli\watermark.py'),
            (Join-Path $repoDir 'see-through-camera\cli\watermark.py'))) {
            if (Test-Path $cand) { $cli = $cand; break }
        }
    }
    if (-not $cli -or -not (Test-Path $cli)) {
        Write-Error (@"
no renderer available.
  The native renderer needs bin\cardgen.exe + fonts\ + body_profiles\
  next to install.ps1 (the Release ZIP ships them). The Python
  fallback needs a see-through-camera checkout:
    `$env:SEE_THROUGH_CAMERA_CLI = 'C:\path\to\see-through-camera\cli\watermark.py'
  then re-run install.ps1
"@)
    }
} else {
    Write-Host "renderer:  native cardgen ($bin)"
}

if (-not $nativeOk) {
    # --- locate python (fallback renderer only) ---------------------------
    $py = $env:SEE_THROUGH_CAMERA_PYTHON
    if (-not $py) {
        foreach ($name in @('python3', 'python', 'py')) {
            $cmd = Get-Command $name -ErrorAction SilentlyContinue
            if ($cmd) { $py = $cmd.Source; break }
        }
    }
    if (-not $py -or -not (Test-Path $py)) {
        Write-Error "python not found on PATH. Install Python 3 (with Pillow) or set `$env:SEE_THROUGH_CAMERA_PYTHON."
    }
    & $py -c 'import PIL' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$py cannot import PIL (Pillow). The CLI needs it:"
        Write-Warning "  '$py' -m pip install Pillow"
    }
}

# --- copy (replace) the plugin -------------------------------------------
if (Test-Path $dest) { [System.IO.Directory]::Delete($dest, $true) }
Copy-Item -Recurse $src $dest
Write-Host "installed: $dest"

if ($nativeOk) {
    New-Item -ItemType Directory -Path (Join-Path $dest 'bin') -Force | Out-Null
    Copy-Item $bin (Join-Path $dest 'bin\cardgen.exe')
    Copy-Item -Recurse $fontsDir (Join-Path $dest 'fonts')
    Copy-Item -Recurse $profilesDir (Join-Path $dest 'body_profiles')
}

# --- generate the machine-specific Config.lua ----------------------------
# Lua/Python both accept forward-slash paths on Windows, which avoids
# escaping backslashes inside Lua string literals. Single quotes in paths
# are escaped Lua-style ('' inside a quoted string).
function ConvertTo-LuaPath([string]$p) {
    if ($p) { return ($p -replace '\\', '/') -replace "'", "''" }
    return ''
}
$binLua      = if ($nativeOk) { ConvertTo-LuaPath ($dest + '\bin\cardgen.exe') } else { '' }
$profilesLua = if ($nativeOk) { ConvertTo-LuaPath ($dest + '\body_profiles') } else { '' }
$fontsLua    = if ($nativeOk) { ConvertTo-LuaPath ($dest + '\fonts') } else { '' }
$pyLua       = if (-not $nativeOk) { ConvertTo-LuaPath $py } else { '' }
$cliLua      = if (-not $nativeOk) { ConvertTo-LuaPath $cli } else { '' }
@"
-- Config.lua - generated by install.ps1. Do not edit by hand; re-run
-- install.ps1 (or set SEE_THROUGH_CAMERA_* environment variables).
return {
  binary = '$binLua',
  profiles = '$profilesLua',
  fonts = '$fontsLua',
  python = '$pyLua',
  cli = '$cliLua',
}
"@ | Set-Content -Encoding ASCII (Join-Path $dest 'Config.lua')
if ($nativeOk) {
    Write-Host "config:    binary=$binLua"
} else {
    Write-Host "config:    python=$py"
    Write-Host "config:    cli=$cli"
}

Write-Host ''
Write-Host 'done. (Re)start Lightroom Classic to load the plugin.'
