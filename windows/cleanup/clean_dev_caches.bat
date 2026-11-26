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
title Developer Cache Cleanup
if not defined AUTO cls
echo =========================================
echo          Developer Cache Cleanup
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

rem Only package download caches are tidied: npm, pnpm and uv are pruned, yarn, bun and pip are cleared.
rem Your project files, source code and node_modules folders are never touched.
rem The npm cache, pnpm store and uv cache may be shared, so they are only pruned, never wiped.

echo [1/7] Measuring free space before cleanup...
set "FREE_BEFORE="
for /f "usebackq" %%A in (`powershell -NoProfile -Command "[math]::Floor((Get-PSDrive -Name '%SystemDrive:~0,1%').Free / 1MB)"`) do set "FREE_BEFORE=%%A"

echo.
echo [2/7] npm cache - verify, removes only broken or unused entries...
set "RC=1"
where npm >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   npm not found, skipped
if not "%RC%"=="0" goto :npm_done
if defined DRYRUN echo   [dry run] would run npm cache verify
if defined DRYRUN goto :npm_done
call npm cache verify
:npm_done

echo.
echo [3/7] pnpm store...
set "RC=1"
where pnpm >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   pnpm not found, skipped
if not "%RC%"=="0" goto :pnpm_done
if defined DRYRUN echo   [dry run] would run pnpm store prune
if defined DRYRUN goto :pnpm_done
call pnpm store prune
:pnpm_done

echo.
echo [4/7] yarn cache...
set "RC=1"
where yarn >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   yarn not found, skipped
if not "%RC%"=="0" goto :yarn_done
if defined DRYRUN echo   [dry run] would run yarn cache clean
if defined DRYRUN goto :yarn_done
call yarn cache clean
:yarn_done

echo.
echo [5/7] bun and pip caches...
set "RC=1"
where bun >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   bun not found, skipped
if not "%RC%"=="0" goto :bun_done
if defined DRYRUN echo   [dry run] would run bun pm cache rm
if defined DRYRUN goto :bun_done
call bun pm cache rm
:bun_done
set "RC=1"
where pip >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   pip not found, skipped
if not "%RC%"=="0" goto :pip_done
if defined DRYRUN echo   [dry run] would run pip cache purge
if defined DRYRUN goto :pip_done
call pip cache purge
:pip_done

echo.
echo [6/7] uv cache - prune, removes only unused entries...
set "RC=1"
where uv >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   uv not found, skipped
if not "%RC%"=="0" goto :uv_done
if defined DRYRUN echo   [dry run] would run uv cache prune
if defined DRYRUN goto :uv_done
call uv cache prune
:uv_done

echo.
echo [7/7] Measuring free space after cleanup...
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
echo Developer cache cleanup finished. Projects re-download packages the next time they install.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%
