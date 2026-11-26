@echo off
setlocal
set "HERE=%~dp0"
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
if defined APPLY goto :browsers_apply
node "%HERE%..\..\tools\browsers.mjs"
set "BROWSER_STATUS=%errorlevel%"
goto :dev_tools
:browsers_apply
node "%HERE%..\..\tools\browsers.mjs" --apply
set "BROWSER_STATUS=%errorlevel%"
:dev_tools
node "%HERE%..\..\tools\install-development.mjs" %ARGS%
set "INSTALL_STATUS=%errorlevel%"
if errorlevel 2 exit /b %INSTALL_STATUS%
if not defined APPLY goto :plan_tail
call "%HERE%setup_shared_cache.bat" /auto
if errorlevel 1 exit /b %errorlevel%
call "%HERE%dev_settings.bat" /auto
call "%HERE%setup_git.bat"
if not "%BROWSER_STATUS%"=="0" echo Some browsers did not install. See the list above.
if not "%BROWSER_STATUS%"=="0" exit /b 1
exit /b %INSTALL_STATUS%
:plan_tail
echo Also sets Windows developer settings and Git and SSH setup. Preview of those steps below.
call "%HERE%dev_settings.bat" /auto /dryrun
call "%HERE%setup_git.bat" /dryrun
exit /b %INSTALL_STATUS%
