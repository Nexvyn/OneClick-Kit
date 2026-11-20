@echo off
setlocal
cd /d "%~dp0"

set "RC=1"

rem Find the .NET Framework C# compiler (64-bit first, then 32-bit).
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo ERROR: csc.exe not found. This Windows has no .NET Framework 4 C# compiler.
  goto :end
)

rem Check that every input file exists.
set "MISSING="
for %%F in (cleanup\clean_browser_cache.bat cleanup\clean_windows_junk.bat cleanup\clean_dev_caches.bat update\update_system.bat src\OneClickKit.cs src\app.manifest) do (
  if not exist "%%~F" (
    echo ERROR: missing file %%~F
    set "MISSING=1"
  )
)
if defined MISSING goto :end

echo Compiling OneClickKit.exe ...
"%CSC%" /nologo /target:exe /platform:anycpu /optimize+ /out:OneClickKit.exe /win32manifest:src\app.manifest /resource:cleanup\clean_browser_cache.bat,clean_browser_cache.bat /resource:cleanup\clean_windows_junk.bat,clean_windows_junk.bat /resource:cleanup\clean_dev_caches.bat,clean_dev_caches.bat /resource:update\update_system.bat,update_system.bat src\OneClickKit.cs
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo Build failed.
) else (
  echo Built OneClickKit.exe
)

:end
if /i not "%~1"=="/nopause" pause
exit /b %RC%
