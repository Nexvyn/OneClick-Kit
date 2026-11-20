@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "HERE=%~dp0"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Save My App List
if not defined AUTO cls
echo =========================================
echo             Save My App List
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

echo [1/2] Checking winget...
set "RC=1"
where winget >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   winget not found. Install App Installer from the Microsoft Store.
if not "%RC%"=="0" set "RESULT=1"
if not "%RC%"=="0" goto :done

echo.
echo [2/2] Saving the list of installed apps...
if defined DRYRUN echo   [dry run] would save the app list to %HERE%apps.json
if defined DRYRUN goto :done
rem winget export may print lines about apps it cannot match. That is normal;
rem only a nonzero exit code is a failure.
winget export -o "%HERE%apps.json" --accept-source-agreements
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   Export failed. apps.json was not saved.
if not "%RC%"=="0" set "RESULT=1"
if not "%RC%"=="0" goto :done
echo   Saved. Commit apps.json to keep it with the repo.

:done
echo.
echo Save my app list finished.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%
