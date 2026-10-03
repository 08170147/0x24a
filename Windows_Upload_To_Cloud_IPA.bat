@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

echo ================================================
echo KanadeDX - Windows -> Cloud macOS -> IPA
echo ================================================

git --version >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git is not installed or not in PATH.
  echo Install Git for Windows first.
  pause
  exit /b 1
)

if not exist ".git" (
  echo Initializing Git repository...
  git init
  git branch -M main
)

git add .
git diff --cached --quiet
if not errorlevel 1 (
  echo No changes to commit.
) else (
  git commit -m "Prepare KanadeDX cloud iOS build"
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo.
  set /p REPO_URL=Enter your GitHub repository URL (for example https://github.com/USER/KanadeDX-iOS.git): 
  if "!REPO_URL!"=="" (
    echo ERROR: Repository URL is required.
    pause
    exit /b 1
  )
  git remote add origin "!REPO_URL!"
)

echo.
echo Pushing project to GitHub...
git push -u origin main
if errorlevel 1 (
  echo.
  echo Push failed. If GitHub asks for authentication, use GitHub Desktop or a GitHub PAT/credential manager.
  pause
  exit /b 1
)

echo.
echo ================================================
echo Upload complete.
echo ================================================
echo.
echo Next:
echo 1. Open your GitHub repository.
echo 2. Open Actions.
echo 3. Select "KanadeDX Cloud iOS IPA".
echo 4. Click Run workflow.
echo 5. Choose app-store-connect, ad-hoc, or development.
echo 6. Download the KanadeDX-IPA artifact after the job succeeds.
echo.
where gh >nul 2>&1
if not errorlevel 1 (
  gh auth status >nul 2>&1
  if not errorlevel 1 (
    set /p RUN_NOW=GitHub CLI is available. Start the cloud build now? [Y/n]: 
    if /I "!RUN_NOW!"=="" set "RUN_NOW=Y"
    if /I "!RUN_NOW!"=="Y" (
      gh workflow run build-ios-ipa.yml -f export_method=app-store-connect
      if errorlevel 1 echo WARNING: Could not dispatch workflow automatically.
      if not errorlevel 1 echo Cloud build dispatched.
    )
  )
)

pause
