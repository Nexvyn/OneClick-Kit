@echo off
setlocal EnableExtensions
set "MODE=%~1"
set "APPLY="
set "SELF=%~f0"
set "HERE=%~dp0"
if /i "%MODE%"=="menu" goto :menu
if defined MODE goto :parse_args
rem No arguments: open the menu when a real console is attached, otherwise preview everything.
call :console_check
if "%ISTTY%"=="1" goto :menu
set "MODE=all"
goto :parse_args

:parse_args
if /i "%MODE%"=="--help" if not "%~2"=="" goto :usage
if /i "%MODE%"=="--dry-run" if not "%~2"=="" goto :usage
if /i "%MODE%"=="--help" set "MODE=all"
if /i "%MODE%"=="--dry-run" set "MODE=all"
if not "%~3"=="" goto :usage
if /i "%~2"=="--apply" set "APPLY=1"
if not "%~2"=="" if /i not "%~2"=="--apply" if /i not "%~2"=="--dry-run" goto :usage
if /i "%MODE%"=="all" goto :valid
if /i "%MODE%"=="install" goto :valid
if /i "%MODE%"=="debloat" goto :valid
if /i "%MODE%"=="update" goto :valid
if /i "%MODE%"=="cache" goto :valid
if /i "%MODE%"=="clean" goto :valid
if /i "%MODE%"=="autoclean" goto :valid
if /i "%MODE%"=="self-update" goto :valid
if /i "%MODE%"=="startup" goto :valid
goto :usage

:valid
echo OneClick Kit
echo Operation: %MODE%
echo Available: all, install, debloat, update, clean, cache, autoclean, self-update, startup.
if /i "%MODE%"=="all" goto :preview_all
if /i "%MODE%"=="install" goto :preview_install
if /i "%MODE%"=="debloat" goto :preview_debloat
if /i "%MODE%"=="update" goto :preview_update
if /i "%MODE%"=="cache" goto :preview_cache
if /i "%MODE%"=="autoclean" goto :preview_autoclean
if /i "%MODE%"=="self-update" goto :preview_selfupdate
if /i "%MODE%"=="startup" goto :preview_startup
goto :preview_clean

:preview_all
call :install_preview
if errorlevel 1 exit /b 1
call :debloat_preview
if errorlevel 1 exit /b 1
call :update_text
call :cache_text
call :clean_preview
if errorlevel 1 exit /b 1
goto :after_preview

:preview_install
call :install_preview
if errorlevel 1 exit /b 1
goto :after_preview

:preview_debloat
call :debloat_preview
if errorlevel 1 exit /b 1
goto :after_preview

:preview_update
call :update_text
goto :after_preview

:preview_cache
call :cache_text
goto :after_preview

:preview_clean
call :clean_preview
if errorlevel 1 exit /b 1
goto :after_preview

:preview_autoclean
call :autoclean_state
echo Auto-clean: %AC_STATE%
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%schedule\auto_clean.ps1" -DryRun
if errorlevel 1 exit /b 1
goto :after_preview

:preview_selfupdate
call :selfupdate_check
if "%SU_GIT%"=="1" goto :preview_selfupdate_git
echo Download the latest from https://github.com/Nexvyn/OneClick-Kit
goto :after_preview
:preview_selfupdate_git
echo Would run: git -C "%REPO%" pull --ff-only
goto :after_preview

:preview_startup
echo Startup apps: turn off new startup programs; protected and kept items are skipped.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%cleanup\startup_apps.ps1" -DryRun
if errorlevel 1 exit /b 1
goto :after_preview

:after_preview
if defined APPLY call :prune_logs
if defined APPLY if /i "%MODE%"=="autoclean" goto :autoclean_apply
if defined APPLY if /i "%MODE%"=="self-update" goto :selfupdate_apply
if defined APPLY goto :apply
echo Preview only. Rerun with an operation followed by --apply to apply.
echo Nothing was changed.
exit /b 0

:apply
rem Require a real interactive console; redirected input must not approve.
call :console_check
if not "%ISTTY%"=="1" goto :refuse_redirected
choice /c YN /m "Run it?"
if errorlevel 2 goto :cancelled
if /i "%MODE%"=="startup" goto :startup_apply
if /i "%MODE%"=="update" goto :require_admin
if /i "%MODE%"=="all" goto :require_admin
if /i "%MODE%"=="debloat" goto :require_admin
if /i "%MODE%"=="clean" goto :require_admin
goto :node_check

:require_admin
fltmc >nul 2>&1
if errorlevel 1 goto :need_elevated
if /i "%MODE%"=="update" goto :update
goto :node_check

:node_check
if /i "%MODE%"=="debloat" goto :dispatch
where node >nul 2>&1
if not errorlevel 1 goto :dispatch
if /i "%MODE%"=="clean" goto :dispatch
if /i "%MODE%"=="cache" goto :need_node
call :ensure_winget
if errorlevel 1 exit /b 1
winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
where node >nul 2>&1
if errorlevel 1 goto :need_node
goto :dispatch

:dispatch
if /i "%MODE%"=="cache" goto :cache_apply
if /i "%MODE%"=="clean" goto :clean
if /i "%MODE%"=="debloat" goto :debloat_only
call :ensure_winget
if errorlevel 1 exit /b 1
call "%HERE%install\first_install.bat" --apply --all
if errorlevel 1 exit /b 1
if /i "%MODE%"=="install" exit /b 0
call :debloat_apply
goto :update

:debloat_only
call :debloat_apply
exit /b %DEBLOAT_RC%

:cache_apply
call "%HERE%install\setup_shared_cache.bat"
exit /b

:update
call "%HERE%update\update_system.bat" /auto
if errorlevel 1 exit /b 1
if /i "%MODE%"=="update" exit /b 0
goto :clean

:clean
where node >nul 2>&1
if errorlevel 1 goto :clean_no_node
node "%HERE%..\tools\devcache.mjs" clean-idle --apply
set "CLEAN_RC=%errorlevel%"
goto :clean_caches

:clean_no_node
echo Node.js is missing, so idle project cleanup is skipped. Download cache and temp cleanup still run.
set "CLEAN_RC=0"

:clean_caches
call "%HERE%cleanup\clean_dev_caches.bat" /auto
set "CACHE_RC=%errorlevel%"
call "%HERE%cleanup\clean_windows_junk.bat" /auto
set "JUNK_RC=%errorlevel%"
call :startup_clean
set "START_RC=%errorlevel%"
if not "%CLEAN_RC%"=="0" exit /b %CLEAN_RC%
if not "%CACHE_RC%"=="0" exit /b %CACHE_RC%
if not "%JUNK_RC%"=="0" exit /b %JUNK_RC%
exit /b %START_RC%

:startup_clean
rem Interactive console: ask which startup items to keep. Otherwise switch off every new item.
call :console_check
if "%ISTTY%"=="1" goto :startup_clean_review
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%cleanup\startup_apps.ps1" -Auto
exit /b %errorlevel%
:startup_clean_review
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%cleanup\startup_apps.ps1" -Review
exit /b %errorlevel%

:startup_apply
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%cleanup\startup_apps.ps1" -Review
exit /b %errorlevel%

:debloat_apply
rem Interactive: Ask questions are shown. A failure here does not stop the other steps.
call "%HERE%debloat\debloat.bat" /nopause
set "DEBLOAT_RC=%errorlevel%"
exit /b 0

:autoclean_apply
call :autoclean_state
call :autoclean_run
exit /b %errorlevel%

:selfupdate_apply
call :selfupdate_run
exit /b %errorlevel%

:menu
fltmc >nul 2>&1
if not errorlevel 1 goto :menu_show
if /i "%~2"=="elevated" goto :menu_no_admin
echo Administrator rights are needed for updates. Windows will ask once.
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'menu elevated' -Verb RunAs"
if errorlevel 1 goto :menu_declined
exit /b 0

:menu_declined
echo Administrator permission was declined. Nothing was changed.
pause
exit /b 1

:menu_no_admin
echo Administrator rights were not granted. Nothing was changed.
pause
exit /b 1

:menu_show
call :autoclean_state
echo.
echo What do you want to do?
echo   1. Install    - choose browsers, then developer tools and shared cache
echo   2. Debloat    - remove preinstalled junk apps, ads and tracking
echo   3. Update     - system, drivers and apps
echo   4. Clean - temp files, Recycle Bin, startup apps, idle project build folders, download caches
echo   5. Everything - install, debloat, update and clean
echo   6. Auto-clean - turn cleaning every 2 days on or off ^(now: %AC_STATE%^)
echo   U. Update OneClick Kit ^(download the latest version^)
echo   Q. Quit
choice /c 123456UQ /n /m "Choose 1, 2, 3, 4, 5, 6, U or Q: "
if errorlevel 8 exit /b 0
if errorlevel 7 goto :menu_selfupdate
if errorlevel 6 goto :menu_autoclean
if errorlevel 5 goto :menu_all
if errorlevel 4 goto :menu_clean
if errorlevel 3 goto :menu_update
if errorlevel 2 goto :menu_debloat
goto :menu_install

:menu_install
set "MODE=install"
goto :menu_run

:menu_debloat
set "MODE=debloat"
goto :menu_run

:menu_update
set "MODE=update"
goto :menu_run

:menu_clean
set "MODE=clean"
goto :menu_run

:menu_all
set "MODE=all"

:menu_run
call "%SELF%" %MODE% --apply
set "RUN_RC=%errorlevel%"
echo.
echo Finished with exit code %RUN_RC%.
echo Done. Press any key to close.
pause >nul
exit /b %RUN_RC%

:menu_autoclean
call :autoclean_state
if "%AC_STATE%"=="On" goto :menu_autoclean_off
choice /c YN /m "Turn it on? "
if errorlevel 2 goto :menu_autoclean_no
goto :menu_autoclean_go
:menu_autoclean_off
choice /c YN /m "Turn it off? "
if errorlevel 2 goto :menu_autoclean_no
:menu_autoclean_go
call :prune_logs
call :autoclean_run
set "AC_RC=%errorlevel%"
goto :menu_end
:menu_autoclean_no
echo Nothing was changed.
set "AC_RC=0"
:menu_end
echo.
echo Done. Press any key to close.
pause >nul
exit /b %AC_RC%

:menu_selfupdate
call :prune_logs
call :selfupdate_run
set "SU_RC=%errorlevel%"
echo.
echo Done. Press any key to close.
pause >nul
exit /b %SU_RC%

:ensure_winget
where winget >nul 2>&1
if not errorlevel 1 exit /b 0
echo winget not found. Registering App Installer for this account.
powershell -NoProfile -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
set "PATH=%LOCALAPPDATA%\Microsoft\WindowsApps;%PATH%"
where winget >nul 2>&1
if not errorlevel 1 exit /b 0
echo winget is missing. Open Microsoft Store, update App Installer, then run this again.
exit /b 1

:console_check
set "ISTTY=0"
powershell -NoProfile -Command "if ([Console]::IsInputRedirected) { exit 1 }; exit 0" >nul 2>&1
if errorlevel 1 exit /b 0
set "ISTTY=1"
exit /b 0

:update_text
echo Update: Windows, managed applications, drivers and Defender.
exit /b 0

:cache_text
echo Cache: shared downloads and isolated project targets.
exit /b 0

:install_preview
echo Install: approved development profile only.
echo Also set up: Windows developer settings ^(long paths, file extensions^)
echo Also set up: Git and GitHub SSH setup
where node >nul 2>&1
if errorlevel 1 goto :install_preview_no_node
node "%HERE%..\tools\browsers.mjs"
if errorlevel 1 exit /b 1
node "%HERE%..\tools\install-development.mjs" --all
exit /b
:install_preview_no_node
echo Node.js is required first: https://nodejs.org/en/download
exit /b 0

:debloat_preview
echo Debloat: preinstalled junk apps, ads, promo items, tracking and background settings.
call "%HERE%debloat\debloat.bat" /auto /dryrun
if errorlevel 1 exit /b 1
exit /b 0

:clean_preview
echo Clean: temp files, Recycle Bin, startup apps, idle project dependencies and Cargo targets, plus download cache pruning.
where node >nul 2>&1
if errorlevel 1 goto :clean_preview_cache
node "%HERE%..\tools\devcache.mjs" clean-idle
if errorlevel 1 exit /b 1
:clean_preview_cache
call "%HERE%cleanup\clean_dev_caches.bat" /auto /dryrun
if errorlevel 1 exit /b 1
call "%HERE%cleanup\clean_windows_junk.bat" /auto /dryrun
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%cleanup\startup_apps.ps1" -DryRun
if errorlevel 1 exit /b 1
exit /b 0

:autoclean_state
rem Live state from the status line: "Auto-clean: On" or "Auto-clean: Off".
set "AC_LINE="
set "AC_STATE=Off"
for /f "delims=" %%L in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%schedule\auto_clean_task.ps1" -Status 2^>nul') do if not defined AC_LINE set "AC_LINE=%%L"
if "%AC_LINE%"=="Auto-clean: On" set "AC_STATE=On"
exit /b 0

:autoclean_run
if "%AC_STATE%"=="On" goto :autoclean_run_off
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%schedule\auto_clean_task.ps1" -Enable
exit /b %errorlevel%
:autoclean_run_off
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%schedule\auto_clean_task.ps1" -Disable
exit /b %errorlevel%

:selfupdate_run
call :selfupdate_check
if "%SU_GIT%"=="1" goto :selfupdate_pull
echo Download the latest from https://github.com/Nexvyn/OneClick-Kit
exit /b 0
:selfupdate_pull
git -C "%REPO%" pull --ff-only
exit /b %errorlevel%

:selfupdate_check
for %%R in ("%HERE%..") do set "REPO=%%~fR"
set "SU_GIT=0"
if not exist "%REPO%\.git" exit /b 0
where git >nul 2>&1
if errorlevel 1 exit /b 0
set "SU_GIT=1"
exit /b 0

:prune_logs
rem Deletes kit logs older than 30 days. Backups (debloat-backup-*.json) are never touched.
powershell -NoProfile -Command "$cut=(Get-Date).AddDays(-30); $d=Join-Path $env:LOCALAPPDATA 'OneClickKit'; $f=@(); $f+=Get-ChildItem -LiteralPath (Join-Path $d 'logs') -File -ErrorAction SilentlyContinue; $f+=Get-ChildItem -LiteralPath $d -File -Filter 'debloat-*.log' -ErrorAction SilentlyContinue; $f | Where-Object { $_.LastWriteTime -lt $cut -and $_.Name -notlike 'debloat-backup-*' } | Remove-Item -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 0

:cancelled
echo Cancelled. Nothing was changed.
exit /b 0

:refuse_redirected
echo Applying needs an interactive console. Nothing was changed.
exit /b 1

:need_elevated
echo Run this command from an elevated terminal to apply system changes. No changes were made.
exit /b 1

:need_node
echo Install Node.js from https://nodejs.org/en/download and open a new terminal.
exit /b 1

:usage
echo Usage: oneclick.bat [menu^|all^|install^|debloat^|update^|clean^|cache^|autoclean^|self-update^|startup] [--apply^|--dry-run]
exit /b 2
