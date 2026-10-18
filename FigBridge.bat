@echo off
rem FigBridge one-click start: installs the Studio plugin and runs the local server.
title FigBridge
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Get it from https://nodejs.org and run this again.
  pause
  exit /b 1
)

echo Installing the Roblox Studio plugin...
node roblox-plugin\build.js --install
if errorlevel 1 (
  echo Could not build the plugin.
  pause
  exit /b 1
)

if not exist server\config.json (
  echo.
  echo Note: server\config.json is missing, so images will NOT upload to Roblox.
  echo See README.md, section "Image upload".
)

echo.
echo Starting the FigBridge server. Keep this window open while you work.
echo Restart Roblox Studio if it was open, so it loads the new plugin.
echo.
node server\server.js
pause
