@echo off
setlocal
rem Curated profile only. The old exported-app restore is explicitly run via install_apps.bat.
where node >nul 2>&1
if errorlevel 1 (
  echo Install Node.js from https://nodejs.org/en/download, then rerun this script.
  exit /b 1
)
set "APPLY="
set "ARGS="
:args
if "%~1"=="" goto :run
if /i "%~1"=="/dryrun" (
  set "ARGS=%ARGS% --dry-run"
  goto :next
)
if /i "%~1"=="/auto" goto :next
if /i "%~1"=="--apply" set "APPLY=1"
set "ARGS=%ARGS% %~1"
:next
shift
goto :args
:run
node "%~dp0..\..\tools\install-development.mjs" %ARGS%
if errorlevel 1 exit /b 1
if not defined APPLY exit /b 0
call "%~dp0setup_shared_cache.bat" /auto
exit /b %errorlevel%
