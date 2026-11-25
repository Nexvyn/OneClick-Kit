@echo off
setlocal
set "MODE=%~1"
if not defined MODE set "MODE=all"
if /i "%MODE%"=="--help" if not "%~2"=="" goto :usage
if /i "%MODE%"=="--dry-run" if not "%~2"=="" goto :usage
if /i "%MODE%"=="--help" set "MODE=all"
if /i "%MODE%"=="--dry-run" set "MODE=all"
if not "%~3"=="" goto :usage
set "APPLY="
if /i "%~2"=="--apply" set "APPLY=1"
if not "%~2"=="" if /i not "%~2"=="--apply" if /i not "%~2"=="--dry-run" goto :usage
if /i "%MODE%"=="all" goto :valid
if /i "%MODE%"=="install" goto :valid
if /i "%MODE%"=="update" goto :valid
if /i "%MODE%"=="cache" goto :valid
if /i "%MODE%"=="clean" goto :valid
goto :usage
:valid
echo OneClick Kit
echo Operation: %MODE%
echo Available: all, install, update, clean, cache.
if /i "%MODE%"=="all" (
  call :install_preview
  if errorlevel 1 exit /b 1
)
if /i "%MODE%"=="install" (
  call :install_preview
  if errorlevel 1 exit /b 1
)
if /i "%MODE%"=="all" echo Update: Windows, managed applications, drivers and Defender.
if /i "%MODE%"=="update" echo Update: Windows, managed applications, drivers and Defender.
if /i "%MODE%"=="all" echo Cache: shared downloads and isolated project targets.
if /i "%MODE%"=="cache" echo Cache: shared downloads and isolated project targets.
if /i "%MODE%"=="all" (
  call :clean_preview
  if errorlevel 1 exit /b 1
)
if /i "%MODE%"=="clean" (
  call :clean_preview
  if errorlevel 1 exit /b 1
)
if not defined APPLY (
  echo Preview only. Rerun with an operation followed by --apply to apply.
  echo Nothing was changed.
  exit /b 0
)
rem Require a real interactive console; redirected input must not approve.
powershell -NoProfile -Command "if ([Console]::IsInputRedirected) { exit 1 }; if ((Read-Host 'Type APPLY to continue') -ceq 'APPLY') { exit 0 }; exit 1"
if errorlevel 1 exit /b 1
if /i "%MODE%"=="update" goto :require_admin
if /i "%MODE%"=="all" goto :require_admin
goto :node_check
:require_admin
fltmc >nul 2>&1
if errorlevel 1 (
  echo Run this command from an elevated terminal to apply system updates. No changes were made.
  exit /b 1
)
if /i "%MODE%"=="update" goto :update
:node_check
where node >nul 2>&1
if not errorlevel 1 goto :dispatch
if /i "%MODE%"=="clean" goto :need_node
if /i "%MODE%"=="cache" goto :need_node
where winget >nul 2>&1
if errorlevel 1 goto :need_node
winget install --id OpenJS.NodeJS.LTS --exact --source winget
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
where node >nul 2>&1
if errorlevel 1 goto :need_node
:dispatch
if /i "%MODE%"=="cache" (
  call "%~dp0install\setup_shared_cache.bat"
  exit /b
)
if /i "%MODE%"=="clean" goto :clean
call "%~dp0install\first_install.bat" --apply --all
if errorlevel 1 exit /b 1
if /i "%MODE%"=="install" exit /b 0
:update
call "%~dp0update\update_system.bat" /auto
if errorlevel 1 exit /b 1
if /i "%MODE%"=="update" exit /b 0
:clean
node "%~dp0..\tools\devcache.mjs" clean-idle --apply
exit /b %errorlevel%
:install_preview
echo Install: approved development profile only.
where node >nul 2>&1
if errorlevel 1 (
  echo Node.js is required first: https://nodejs.org/en/download
  exit /b 0
)
node "%~dp0..\tools\install-development.mjs" --all
exit /b
:clean_preview
echo Clean: only reviewed idle project dependencies and build outputs.
where node >nul 2>&1
if errorlevel 1 exit /b 0
node "%~dp0..\tools\devcache.mjs" clean-idle
exit /b
:need_node
echo Install Node.js from https://nodejs.org/en/download and open a new terminal.
exit /b 1
:usage
echo Usage: oneclick.bat [all^|install^|update^|clean^|cache] [--apply^|--dry-run]
exit /b 2
