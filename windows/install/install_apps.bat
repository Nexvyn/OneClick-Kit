@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "HERE=%~dp0"
set "SELF=%~f0"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Install My Apps
if not defined AUTO cls
echo =========================================
echo               Install My Apps
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

if defined DRYRUN goto :admin_ok
fltmc >nul 2>&1
if not errorlevel 1 goto :admin_ok
echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
exit /b
:admin_ok

echo.
echo [1/3] Checking apps.json...
if exist "%HERE%apps.json" goto :json_ok
echo   apps.json not found. Run save_my_apps.bat on your old PC first.
set "RESULT=1"
goto :done
:json_ok
echo   apps.json found.

echo.
echo [2/3] Checking winget...
set "RC=1"
where winget >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   winget not found. Install App Installer from the Microsoft Store.
if not "%RC%"=="0" set "RESULT=1"
if not "%RC%"=="0" goto :done

echo.
echo [3/3] Installing apps from apps.json...
if defined DRYRUN goto :dry_list
winget import -i "%HERE%apps.json" --accept-source-agreements --accept-package-agreements --ignore-unavailable
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   Some apps could not be installed. See the messages above.
if not "%RC%"=="0" set "RESULT=1"
goto :done

:dry_list
powershell -NoProfile -ExecutionPolicy Bypass -Command "$j = Get-Content -Raw -LiteralPath '%HERE%apps.json' | ConvertFrom-Json; $ids = $j.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_.PackageIdentifier }; Write-Host ('  [dry run] would install ' + $ids.Count + ' apps:'); $ids | ForEach-Object { Write-Host ('    ' + $_) }"
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   Could not read apps.json.
if not "%RC%"=="0" set "RESULT=1"

:done
echo.
echo Install my apps finished.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%
