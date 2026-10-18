@echo off
rem Runs the FigBridge setup wizard (Setup.ps1) without changing the system's script policy.
title FigBridge setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
echo.
pause
