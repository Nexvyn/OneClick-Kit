@echo off
setlocal
rem Windows settings for developers: long paths, file extensions, hidden files, git long paths.
rem /auto    no questions (used by first_install.bat)
rem /dryrun  print what would run, change nothing
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "IS_ADMIN="
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Windows Developer Settings
if not defined AUTO cls
echo =========================================
echo        Windows Developer Settings
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

rem Administrator rights are needed only to apply the machine-wide settings.
if defined DRYRUN goto :admin_done
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
:admin_done

echo [1/3] Long paths for Windows...
if defined DRYRUN echo [dry run] would run: reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
if defined DRYRUN goto :step2
if not defined IS_ADMIN goto :longpaths_noadmin
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul
if errorlevel 1 echo   WARNING: could not turn on long paths.
if errorlevel 1 set "RESULT=1"
if not errorlevel 1 echo   Long paths are on.
goto :step2
:longpaths_noadmin
echo   Skipped: run this from an administrator terminal to turn on long paths.
set "RESULT=1"

:step2
echo.
echo [2/3] File Explorer view for your user...
if defined DRYRUN echo [dry run] would run: reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
if defined DRYRUN echo [dry run] would run: reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
if defined DRYRUN goto :step3
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul
if errorlevel 1 echo   WARNING: could not show file extensions.
if errorlevel 1 set "RESULT=1"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul
if errorlevel 1 echo   WARNING: could not show hidden files.
if errorlevel 1 set "RESULT=1"
if not errorlevel 1 echo   File extensions and hidden files are shown after sign-out or an Explorer restart.

:step3
echo.
echo [3/3] Git long paths...
where git >nul 2>&1
if errorlevel 1 goto :git_missing
if defined DRYRUN echo [dry run] would run: git config --system core.longpaths true
if defined DRYRUN goto :finish
if not defined IS_ADMIN goto :git_noadmin
git config --system core.longpaths true
if errorlevel 1 echo   WARNING: could not set core.longpaths.
if errorlevel 1 set "RESULT=1"
if not errorlevel 1 echo   Git long paths are on.
goto :finish
:git_noadmin
echo   Skipped: run this from an administrator terminal to set core.longpaths.
set "RESULT=1"
goto :finish
:git_missing
echo   Git is not installed, core.longpaths skipped.
goto :finish

:finish
echo.
if defined DRYRUN goto :done
echo Developer settings finished. Sign out or restart Explorer to see the file extension and hidden-file changes.
:done
exit /b %RESULT%
