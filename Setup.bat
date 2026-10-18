@echo off
rem Runs the FigmaToRoblox setup wizard (Setup.ps1) without changing the system's script policy.
title FigmaToRoblox setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
echo.
pause
