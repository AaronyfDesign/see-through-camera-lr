@echo off
rem install.cmd - double-click installer for the See-Through Camera
rem Lightroom plugin (Windows). You can also drag a .lrplugin folder
rem onto this file to install that copy instead.
rem
rem Requires: Python 3 with Pillow  (python -m pip install Pillow)
rem NOTE: keep this file ASCII-only (no em-dashes) - cmd.exe on zh-CN
rem Windows uses the GBK codepage and mis-parses UTF-8 punctuation.
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
echo.
pause
