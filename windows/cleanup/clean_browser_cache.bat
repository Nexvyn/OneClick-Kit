@echo off
setlocal
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
title Browser Cache Cleanup
if not defined AUTO cls
echo ========================================
echo           Browser Cache Cleanup
echo ========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

rem Only caches are deleted. History, cookies, passwords, bookmarks, sessions,
rem Local Storage, IndexedDB, Service Worker data and extensions are never touched.

echo.
echo [1/3] Closing browsers...
set "R_CHROME="
set "R_MSEDGE="
set "R_BRAVE="
set "R_FIREFOX="
tasklist /FI "IMAGENAME eq chrome.exe" 2>nul | find /i "chrome.exe" >nul
if not errorlevel 1 set "R_CHROME=1"
tasklist /FI "IMAGENAME eq msedge.exe" 2>nul | find /i "msedge.exe" >nul
if not errorlevel 1 set "R_MSEDGE=1"
tasklist /FI "IMAGENAME eq brave.exe" 2>nul | find /i "brave.exe" >nul
if not errorlevel 1 set "R_BRAVE=1"
tasklist /FI "IMAGENAME eq firefox.exe" 2>nul | find /i "firefox.exe" >nul
if not errorlevel 1 set "R_FIREFOX=1"
set "ANY="
if defined R_CHROME set "ANY=1"
if defined R_MSEDGE set "ANY=1"
if defined R_BRAVE set "ANY=1"
if defined R_FIREFOX set "ANY=1"
if not defined ANY goto :browsers_none
if defined DRYRUN goto :browsers_dry
if not defined AUTO echo Chrome, Edge, Brave and Firefox will be closed. Save your work first. Close this window now to cancel.
if not defined AUTO timeout /t 10
echo   Closing running browsers...
if defined R_CHROME taskkill /IM chrome.exe >nul 2>&1
if defined R_MSEDGE taskkill /IM msedge.exe >nul 2>&1
if defined R_BRAVE taskkill /IM brave.exe >nul 2>&1
if defined R_FIREFOX taskkill /IM firefox.exe >nul 2>&1
timeout /t 3 /nobreak >nul
if defined R_CHROME taskkill /IM chrome.exe /F >nul 2>&1
if defined R_MSEDGE taskkill /IM msedge.exe /F >nul 2>&1
if defined R_BRAVE taskkill /IM brave.exe /F >nul 2>&1
if defined R_FIREFOX taskkill /IM firefox.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul
goto :browsers_done
:browsers_dry
if defined R_CHROME echo   [dry run] would close chrome.exe
if defined R_MSEDGE echo   [dry run] would close msedge.exe
if defined R_BRAVE echo   [dry run] would close brave.exe
if defined R_FIREFOX echo   [dry run] would close firefox.exe
goto :browsers_done
:browsers_none
echo   No browsers are running.
:browsers_done

echo.
echo [2/3] Chromium browsers...
call :CleanChromium "Chrome" "%LOCALAPPDATA%\Google\Chrome\User Data"
call :CleanChromium "Edge" "%LOCALAPPDATA%\Microsoft\Edge\User Data"
call :CleanChromium "Brave" "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"

echo.
echo [3/3] Firefox...
if not exist "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\" echo   Firefox not found, skipped
if not exist "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\" goto :firefox_done
for /d %%P in ("%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*") do for %%C in ("cache2" "startupCache" "thumbnails") do call :EmptyFolder "%%~P\%%~C"
:firefox_done

echo.
echo Browser cache cleanup finished. History, cookies, passwords and logins were not touched.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%

:CleanChromium
rem Arguments: browser name and its User Data folder.
if not exist "%~2\" echo   %~1 not found, skipped
if not exist "%~2\" exit /b
echo   Cleaning %~1 cache...
for /d %%P in ("%~2\Default" "%~2\Profile *" "%~2\Guest Profile") do for %%C in ("Cache" "Code Cache" "GPUCache" "DawnCache" "DawnGraphiteCache" "DawnWebGPUCache") do call :EmptyFolder "%%~P\%%~C"
for %%C in ("ShaderCache" "GrShaderCache" "GraphiteDawnCache") do call :EmptyFolder "%~2\%%~C"
exit /b

:EmptyFolder
rem Deletes the CONTENTS of folder %1 and keeps the folder itself.
if "%~1"=="" exit /b
if not exist "%~1\" exit /b
if "%~pnx1"=="\" exit /b
if not defined DRYRUN goto :EmptyFolder_run
echo   [dry run] would empty "%~1"
exit /b
:EmptyFolder_run
del /f /s /q "%~1\*" >nul 2>&1
for /d %%D in ("%~1\*") do rd /s /q "%%~D" >nul 2>&1
exit /b
