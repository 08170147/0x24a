@echo off
setlocal
cd /d "%~dp0.."
if exist "Tools\remote-mac.config.json" (
  del /q "Tools\remote-mac.config.json"
  echo Remote Mac saved settings removed.
) else (
  echo No saved Remote Mac settings found.
)
echo Next run will ask for the settings again.
pause
