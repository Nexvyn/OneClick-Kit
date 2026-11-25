@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "SELF=%~f0"
set "HERE=%~dp0"
set "CACHE=%USERPROFILE%\Desktop\F-project\shared-cache"
:parseargs
if "%~1"=="" goto :argsdone
set "ARG=%~1"
if /i "%ARG%"=="/auto" set "AUTO=1"
if /i "%ARG%"=="/dryrun" set "DRYRUN=1"
if not "%ARG:~0,1%"=="/" set "CACHE=%~1"
shift
goto :parseargs
:argsdone
if "%CACHE:~-1%"=="\" set "CACHE=%CACHE:~0,-1%"
title Shared Cache Setup
if not defined AUTO cls
echo =========================================
echo           Shared Cache Setup
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

rem One shared folder holds the pnpm store, npm cache and build caches for all projects.
rem Safe to run again: it only creates missing folders and sets values.

echo [1/5] Location...
call :RefreshPath
echo   Cache folder:
echo   "%CACHE%"
echo   Keep it on the same drive as your projects - hard links do not work across drives.

echo.
echo [2/5] Folders...
call :MakeDir pnpm-store
call :MakeDir cargo-targets
call :MakeDir sccache
call :MakeDir gradle
call :MakeDir npm-cache
call :MakeDir puppeteer
call :MakeDir playwright
call :MakeDir bun-cache
call :MakeDir yarn-cache
call :MakeDir pip-cache
call :MakeDir uv-cache

echo.
echo [3/5] Tools...
set "SCCACHE_OK="
where sccache >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" echo   sccache is installed.
if "%RC%"=="0" set "SCCACHE_OK=1"
if "%RC%"=="0" goto :sccache_done
if defined DRYRUN echo   [dry run] would install sccache with winget
if defined DRYRUN goto :sccache_done
winget install --id Mozilla.sccache -e --silent --accept-source-agreements --accept-package-agreements
call :RefreshPath
where sccache >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" echo   sccache installed.
if "%RC%"=="0" set "SCCACHE_OK=1"
if not "%RC%"=="0" echo   WARNING: sccache could not be installed. RUSTC_WRAPPER will not be set.
if not "%RC%"=="0" set "RESULT=1"
:sccache_done

set "PNPM_OK="
where pnpm >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" echo   pnpm is installed.
if "%RC%"=="0" set "PNPM_OK=1"
if "%RC%"=="0" goto :pnpm_install_done
if defined DRYRUN echo   [dry run] would install pnpm
if defined DRYRUN goto :pnpm_install_done
where npm >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" call npm install -g pnpm
if not "%RC%"=="0" winget install --id pnpm.pnpm -e --silent --accept-source-agreements --accept-package-agreements
call :RefreshPath
where pnpm >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" echo   pnpm installed.
if "%RC%"=="0" set "PNPM_OK=1"
if not "%RC%"=="0" echo   WARNING: pnpm could not be installed.
if not "%RC%"=="0" set "RESULT=1"
:pnpm_install_done

echo.
echo [4/5] pnpm and npm settings...
if defined PNPM_OK goto :pnpm_settings
echo   pnpm not found, pnpm settings skipped
set "RESULT=1"
goto :pnpm_settings_done
:pnpm_settings
if defined DRYRUN echo   [dry run] would run pnpm config set store-dir "%CACHE%\pnpm-store" --global
if defined DRYRUN echo   [dry run] would run pnpm config set package-import-method auto --global
if defined DRYRUN goto :pnpm_settings_done
call pnpm config set store-dir "%CACHE%\pnpm-store" --global
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: could not set the pnpm store folder.
if not "%RC%"=="0" set "RESULT=1"
call pnpm config set package-import-method auto --global
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: could not set the pnpm import method.
if not "%RC%"=="0" set "RESULT=1"
:pnpm_settings_done

where npm >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   npm not found, npm settings skipped
if not "%RC%"=="0" goto :npm_settings_done
if defined DRYRUN echo   [dry run] would run npm config set cache "%CACHE%\npm-cache" --location=user
if defined DRYRUN goto :npm_settings_done
call npm config set cache "%CACHE%\npm-cache" --location=user
set "RC=%errorlevel%"
if "%RC%"=="0" goto :npm_settings_done
call npm config set cache "%CACHE%\npm-cache"
set "RC=%errorlevel%"
if "%RC%"=="0" echo   Saved in your user npm settings instead of the global ones.
if not "%RC%"=="0" echo   WARNING: could not set the npm cache folder.
if not "%RC%"=="0" set "RESULT=1"
:npm_settings_done

echo.
echo [5/5] Environment variables for your user...
call :SetVar ONECLICK_CACHE_ROOT "%CACHE%"
rem Remove only the legacy target value created by OneClick Kit, not custom settings.
if defined DRYRUN echo   [dry run] would check legacy CARGO_TARGET_DIR
if not defined DRYRUN powershell -NoProfile -Command "$v=[Environment]::GetEnvironmentVariable('CARGO_TARGET_DIR','User'); if ($v -eq (Join-Path $env:CACHE 'cargo-target') -or $v -eq (Join-Path $env:USERPROFILE 'Desktop\F-project\shared-cache\cargo-target')) { [Environment]::SetEnvironmentVariable('CARGO_TARGET_DIR',$null,'User') }"
call :SetVar SCCACHE_ALLOW_INCREMENTAL 1
call :SetVar SCCACHE_DIR "%CACHE%\sccache"
call :SetVar SCCACHE_CACHE_SIZE 5G
call :SetVar GRADLE_USER_HOME "%CACHE%\gradle"
call :SetVar PUPPETEER_CACHE_DIR "%CACHE%\puppeteer"
call :SetVar PLAYWRIGHT_BROWSERS_PATH "%CACHE%\playwright"
call :SetVar BUN_INSTALL_CACHE_DIR "%CACHE%\bun-cache"
call :SetVar YARN_GLOBAL_FOLDER "%CACHE%\yarn-cache"
call :SetVar YARN_ENABLE_GLOBAL_CACHE true
call :SetVar PIP_CACHE_DIR "%CACHE%\pip-cache"
call :SetVar UV_CACHE_DIR "%CACHE%\uv-cache"
if defined SCCACHE_OK call :SetVar RUSTC_WRAPPER sccache
if not defined SCCACHE_OK echo   RUSTC_WRAPPER not set - Rust builds fail when it points to a missing sccache.

echo.
echo Shared cache setup finished. Open a new terminal, then use the project tool in docs/shared-cache.md.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%

:MakeDir
if exist "%CACHE%\%~1\" echo   %~1 exists
if exist "%CACHE%\%~1\" exit /b 0
if defined DRYRUN echo   [dry run] would create %~1
if defined DRYRUN exit /b 0
mkdir "%CACHE%\%~1"
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: could not create %~1
if not "%RC%"=="0" set "RESULT=1"
exit /b 0

:SetVar
if defined DRYRUN echo   [dry run] would set %~1
if defined DRYRUN exit /b 0
setx "%~1" "%~2" >nul
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: could not set %~1
if not "%RC%"=="0" set "RESULT=1"
exit /b 0

:RefreshPath
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P"
exit /b 0
