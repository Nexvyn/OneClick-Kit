@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "SELF=%~f0"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Windows Junk Cleanup
if not defined AUTO cls
echo =========================================
echo            Windows Junk Cleanup
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

rem REMOVED ON PURPOSE: Prefetch cleanup. Windows uses the Prefetch folder to start apps
rem and boot faster. Deleting it makes the PC slower until Windows rebuilds it.
rem REMOVED ON PURPOSE: the rd and mkdir of system folders such as C:\Windows\Temp.
rem Re-creating a folder wipes its special permissions, so only the CONTENTS are deleted.

if defined DRYRUN goto :admin_ok
fltmc >nul 2>&1
if not errorlevel 1 goto :admin_ok
echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
exit /b
:admin_ok

echo.
echo [1/6] Measuring free space and stopping Windows Update services...
set "FREE_BEFORE="
for /f "usebackq" %%A in (`powershell -NoProfile -Command "[math]::Floor((Get-PSDrive -Name '%SystemDrive:~0,1%').Free / 1MB)"`) do set "FREE_BEFORE=%%A"
if defined DRYRUN echo   [dry run] would stop service wuauserv
if not defined DRYRUN net stop wuauserv >nul 2>&1
if defined DRYRUN echo   [dry run] would stop service bits
if not defined DRYRUN net stop bits >nul 2>&1

echo.
echo [2/6] Temp files and caches...
echo   Your temp files...
call :EmptyFolder "%TEMP%"
echo   Windows temp files...
call :EmptyFolder "%SystemRoot%\Temp"
echo   Old Windows Update downloads...
call :EmptyFolder "%SystemRoot%\SoftwareDistribution\Download"
echo   Crash reports...
call :EmptyFolder "%ProgramData%\Microsoft\Windows\WER\ReportArchive"
call :EmptyFolder "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
echo   App crash dumps...
call :EmptyFolder "%LOCALAPPDATA%\CrashDumps"
if defined DRYRUN echo   [dry run] would start service bits
if not defined DRYRUN net start bits >nul 2>&1
if defined DRYRUN echo   [dry run] would start service wuauserv
if not defined DRYRUN net start wuauserv >nul 2>&1

echo.
echo [3/6] Delivery Optimization cache...
if defined DRYRUN echo   [dry run] would clear the Delivery Optimization cache
if not defined DRYRUN powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue }"

echo.
echo [4/6] Old Windows log files, older than 7 days...
if defined DRYRUN echo   [dry run] would delete log files older than 7 days in %SystemRoot%\Logs
if not defined DRYRUN forfiles /p "%SystemRoot%\Logs" /s /m * /d -7 /c "cmd /c if @isdir==FALSE del /f /q @path" >nul 2>&1

echo.
echo [5/6] Recycle Bin...
if defined DRYRUN echo   [dry run] would empty the Recycle Bin
if not defined DRYRUN powershell -NoProfile -ExecutionPolicy Bypass -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"

echo.
echo [6/6] Measuring free space after cleanup...
set "FREE_AFTER="
for /f "usebackq" %%A in (`powershell -NoProfile -Command "[math]::Floor((Get-PSDrive -Name '%SystemDrive:~0,1%').Free / 1MB)"`) do set "FREE_AFTER=%%A"
set "FREED="
if "%FREE_BEFORE%"=="" goto :freed_unknown
if "%FREE_AFTER%"=="" goto :freed_unknown
set /a FREED=FREE_AFTER-FREE_BEFORE
if %FREED% LSS 0 set "FREED=0"
goto :freed_show
:freed_unknown
echo   Free space could not be measured.
goto :freed_done
:freed_show
echo   Freed about %FREED% MB on %SystemDrive%
:freed_done

echo.
echo Windows junk cleanup finished.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%

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
