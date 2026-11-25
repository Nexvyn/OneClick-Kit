@echo off
setlocal
if not "%~2"=="" goto :usage
if "%~1"=="" goto :preview
if /i "%~1"=="--dry-run" goto :preview
if /i "%~1"=="--apply" goto :apply
:usage
echo Usage: update-only.bat [--dry-run^|--apply]
exit /b 2
:preview
call "%~dp0update\update_system.bat" /dryrun
exit /b %errorlevel%
:apply
call "%~dp0update\update_system.bat"
exit /b %errorlevel%
