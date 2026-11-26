@echo off
rem Debloat wrapper. Flags: /auto (skip Ask questions), /dryrun (preview only),
rem /undo (restore the newest backup), /nopause (no final pause, used by oneclick).
setlocal
rem Capture the folder before the argument loop: SHIFT also moves %0.
set "HERE=%~dp0"
set "PSAUTO="
set "PSDRY="
set "PSUNDO="
set "NOPAUSE="
:parseargs
if "%~1"=="" goto :run
if /i "%~1"=="/auto" set "PSAUTO=-Auto"
if /i "%~1"=="/dryrun" set "PSDRY=-DryRun"
if /i "%~1"=="/undo" set "PSUNDO=-Undo"
if /i "%~1"=="/nopause" set "NOPAUSE=1"
shift
goto :parseargs
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%debloat_windows.ps1" %PSAUTO% %PSDRY% %PSUNDO%
set "RC=%errorlevel%"
if defined PSAUTO goto :done
if defined NOPAUSE goto :done
echo.
pause
:done
exit /b %RC%
