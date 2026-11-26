@echo off
setlocal
rem Git identity, default branch and GitHub SSH key.
rem /auto    print the status only, ask nothing (used by first_install.bat)
rem /dryrun  print what would run, change nothing, ask nothing
set "AUTO="
set "DRYRUN="
set "RESULT=0"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Git and SSH Setup
if not defined AUTO cls
echo =========================================
echo            Git and SSH Setup
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

where git >nul 2>&1
if errorlevel 1 goto :no_git

set "GIT_NAME="
set "GIT_EMAIL="
set "GIT_BRANCH="
for /f "delims=" %%V in ('git config --global user.name 2^>nul') do set "GIT_NAME=%%V"
for /f "delims=" %%V in ('git config --global user.email 2^>nul') do set "GIT_EMAIL=%%V"
for /f "delims=" %%V in ('git config --global init.defaultBranch 2^>nul') do set "GIT_BRANCH=%%V"

set "PUB=%USERPROFILE%\.ssh\id_ed25519.pub"
set "HAVE_KEY="
if exist "%PUB%" set "HAVE_KEY=1"
set "HAVE_GH="
where gh >nul 2>&1
if not errorlevel 1 set "HAVE_GH=1"

set "S_NAME=%GIT_NAME%"
if not defined GIT_NAME set "S_NAME=not set"
set "S_EMAIL=%GIT_EMAIL%"
if not defined GIT_EMAIL set "S_EMAIL=not set"
set "S_BRANCH=%GIT_BRANCH%"
if not defined GIT_BRANCH set "S_BRANCH=not set"
set "S_KEY=missing"
if defined HAVE_KEY set "S_KEY=present"
set "S_GH=not installed"
if defined HAVE_GH set "S_GH=installed"

echo Current status:
echo   Git:            found
echo   User name:      %S_NAME%
echo   User email:     %S_EMAIL%
echo   Default branch: %S_BRANCH%
echo   SSH key:        %S_KEY%
echo   GitHub CLI gh:  %S_GH%
echo.

if defined AUTO goto :finish
if defined DRYRUN goto :plan
goto :apply

:plan
if defined GIT_NAME goto :plan_email
echo [dry run] would ask for your Git user name
echo [dry run] would run: git config --global user.name "your name"
:plan_email
if defined GIT_EMAIL goto :plan_branch
echo [dry run] would ask for your Git email
echo [dry run] would run: git config --global user.email "your email"
:plan_branch
if defined GIT_BRANCH goto :plan_ssh
echo [dry run] would run: git config --global init.defaultBranch main
:plan_ssh
if defined HAVE_KEY goto :plan_gh
echo [dry run] would ask: Create an SSH key for GitHub? Y/N
echo [dry run] would run: ssh-keygen -t ed25519 -C "your email" -f "%USERPROFILE%\.ssh\id_ed25519"
:plan_gh
if not defined HAVE_GH goto :finish
echo [dry run] would run, if gh is signed in and you say Y: gh ssh-key add "%PUB%" --title "%COMPUTERNAME% OneClick Kit"
goto :finish

:apply
if defined GIT_NAME goto :apply_email
set "NEW_NAME="
set /p "NEW_NAME=Your name for Git commits: "
if not defined NEW_NAME goto :apply_email
git config --global user.name "%NEW_NAME%"
if errorlevel 1 echo   WARNING: could not set user.name.
if errorlevel 1 set "RESULT=1"
:apply_email
if defined GIT_EMAIL goto :apply_branch
set "NEW_EMAIL="
set /p "NEW_EMAIL=Your email for Git commits: "
if not defined NEW_EMAIL goto :apply_branch
git config --global user.email "%NEW_EMAIL%"
if errorlevel 1 echo   WARNING: could not set user.email.
if errorlevel 1 set "RESULT=1"
set "GIT_EMAIL=%NEW_EMAIL%"
:apply_branch
if defined GIT_BRANCH goto :apply_ssh
git config --global init.defaultBranch main
if errorlevel 1 echo   WARNING: could not set init.defaultBranch.
if errorlevel 1 set "RESULT=1"
:apply_ssh
if defined HAVE_KEY goto :apply_key_ready
set "MAKE_KEY="
set /p "MAKE_KEY=Create an SSH key for GitHub? Y/N: "
if /i not "%MAKE_KEY%"=="Y" goto :apply_key_skip
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
ssh-keygen -t ed25519 -C "%GIT_EMAIL%" -f "%USERPROFILE%\.ssh\id_ed25519"
if errorlevel 1 echo   WARNING: ssh-keygen did not create the key.
if errorlevel 1 set "RESULT=1"
if errorlevel 1 goto :finish
set "HAVE_KEY=1"
echo.
echo Your public key:
type "%PUB%"
echo.
echo Add it at https://github.com/settings/keys
goto :apply_key_ready
:apply_key_skip
echo No SSH key created.
goto :finish
:apply_key_ready
if not defined HAVE_KEY goto :finish
if not defined HAVE_GH goto :finish
gh auth status >nul 2>&1
if errorlevel 1 goto :finish
set "UPLOAD="
set /p "UPLOAD=Upload it to GitHub now with gh? Y/N: "
if /i not "%UPLOAD%"=="Y" goto :finish
gh ssh-key add "%PUB%" --title "%COMPUTERNAME% OneClick Kit"
if errorlevel 1 echo   WARNING: gh could not add the key.
if errorlevel 1 set "RESULT=1"
goto :finish

:no_git
echo Git is not installed. Install Git for Windows from https://git-scm.com/download/win, then rerun this script.
exit /b 0

:finish
echo.
echo Git and SSH setup finished.
exit /b %RESULT%
