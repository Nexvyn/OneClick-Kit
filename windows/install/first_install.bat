@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "HERE=%~dp0"
set "SELF=%~f0"
set "ARGS=%*"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title First Install
if not defined AUTO cls
echo =========================================
echo              First Install
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

set "CHILD_ARGS=/auto"
if not defined DRYRUN goto :args_ready
set "CHILD_ARGS=/auto /dryrun"
:args_ready

if defined DRYRUN goto :admin_ok
fltmc >nul 2>&1
if not errorlevel 1 goto :admin_ok
echo Requesting admin rights...
if "%ARGS%"=="" powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
if not "%ARGS%"=="" powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -ArgumentList '%ARGS%' -Verb RunAs"
exit /b
:admin_ok

echo.
echo [1/2] Apps...
if exist "%HERE%apps.json" goto :apps_run
echo   apps.json not found - app install skipped. Run save_my_apps.bat on your old PC to create it.
set "RC_APPS=skipped"
goto :apps_done
:apps_run
call "%HERE%install_apps.bat" %CHILD_ARGS%
set "RC_APPS=%errorlevel%"
:apps_done

echo.
echo [2/2] Shared cache...
call "%HERE%setup_shared_cache.bat" %CHILD_ARGS%
set "RC_CACHE=%errorlevel%"

echo.
echo =========================================
echo   Summary
echo =========================================
if "%RC_APPS%"=="0" echo   Apps: OK
if "%RC_APPS%"=="skipped" echo   Apps: skipped - no apps.json
if not "%RC_APPS%"=="0" if not "%RC_APPS%"=="skipped" echo   Apps: finished with warnings
if not "%RC_APPS%"=="0" if not "%RC_APPS%"=="skipped" set "RESULT=1"
if "%RC_CACHE%"=="0" echo   Shared cache: OK
if not "%RC_CACHE%"=="0" echo   Shared cache: finished with warnings
if not "%RC_CACHE%"=="0" set "RESULT=1"

echo.
echo First install finished. Restart the PC so every app and setting is picked up.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%
