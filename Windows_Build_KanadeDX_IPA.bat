@echo off
setlocal
cd /d "%~dp0"

echo ===============================================
echo  KanadeDX Windows ^> Remote Mac ^> IPA  [v17 Auto Discovery IPv4 Byte Fix + Remote Root Fix]
echo ===============================================
echo.

where powershell.exe >nul 2>&1 || (
  echo ERROR: PowerShell not found.
  exit /b 2
)
where ssh.exe >nul 2>&1 || (
  echo ERROR: OpenSSH ssh.exe not found. Install Windows OpenSSH Client.
  exit /b 2
)
where scp.exe >nul 2>&1 || (
  echo ERROR: OpenSSH scp.exe not found. Install Windows OpenSSH Client.
  exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\build_remote_mac.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo SUCCESS: verified IPA returned to Builds\KanadeDX.ipa
) else (
  echo FAILED: remote build exited with code %RC%.
)
pause
exit /b %RC%
