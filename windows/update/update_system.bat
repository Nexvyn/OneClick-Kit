@echo off
setlocal
set "AUTO="
set "DRYRUN="
set "RESULT=0"
set "SKIP_WU="
set "SELF=%~f0"
:parseargs
if "%~1"=="" goto :argsdone
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
shift
goto :parseargs
:argsdone
title Windows, Driver and App Updates
if not defined AUTO cls
echo =========================================
echo      Windows, Driver and App Updates
echo =========================================
if defined DRYRUN echo DRY RUN - nothing will be changed.
echo.

if defined DRYRUN goto :admin_ok
fltmc >nul 2>&1
if not errorlevel 1 goto :admin_ok
echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
exit /b
:admin_ok

rem Restore point before any update is installed. Never aborts the run.
if defined DRYRUN goto :restore_dry
goto :restore_run
:restore_dry
echo [dry run] would create a restore point
goto :restore_done
:restore_run
echo Creating a restore point...
powershell -NoProfile -Command "try { Checkpoint-Computer -Description 'OneClick Kit before updates' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 echo WARNING: could not create a restore point. System Protection may be off, or a restore point was made in the last 24 hours. Continuing.
:restore_done

echo.
echo [1/5] Checking the PSWindowsUpdate module...
if defined DRYRUN goto :psmod_dry
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) { try { Write-Host 'Installing PSWindowsUpdate...'; Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null; Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force -AllowClobber -ErrorAction Stop } catch { Write-Warning $_; exit 1 } } else { Write-Host 'PSWindowsUpdate is installed.' }"
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: could not install PSWindowsUpdate. Windows updates will be skipped.
if not "%RC%"=="0" set "RESULT=1"
if not "%RC%"=="0" set "SKIP_WU=1"
goto :psmod_done
:psmod_dry
powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Module -ListAvailable -Name PSWindowsUpdate) { Write-Host '  PSWindowsUpdate is installed.' } else { Write-Host '  [dry run] would install PSWindowsUpdate' }"
:psmod_done

echo.
echo [2/5] Microsoft Defender definitions...
if defined DRYRUN echo   [dry run] would update Microsoft Defender definitions
if not defined DRYRUN powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Update-MpSignature -ErrorAction Stop; Write-Host '  Defender definitions are up to date.' } catch { Write-Host '  Defender update skipped - another antivirus may be in use.' }"

echo.
echo [3/5] Windows, driver and Microsoft product updates...
if defined SKIP_WU echo   Skipped - PSWindowsUpdate is not available.
if defined SKIP_WU goto :wu_done
if defined DRYRUN echo   [dry run] would install Windows, driver and Microsoft product updates
if defined DRYRUN goto :wu_done
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Import-Module PSWindowsUpdate -ErrorAction Stop; Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Stop } catch { Write-Warning $_; exit 1 }"
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   WARNING: Windows, driver or product updates did not finish. See the messages above.
if not "%RC%"=="0" set "RESULT=1"
:wu_done

echo.
echo [4/5] Microsoft Store app updates...
if defined DRYRUN echo   [dry run] would ask the Microsoft Store to check for app updates
if not defined DRYRUN powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01' -ErrorAction Stop | Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop | Out-Null; Write-Host '  Microsoft Store was asked to update apps.' } catch { Write-Host '  Microsoft Store update check skipped.' }"

echo.
echo [5/5] Apps via winget...
where winget >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" echo   winget not found. Install App Installer from the Microsoft Store.
if not "%RC%"=="0" set "RESULT=1"
if not "%RC%"=="0" goto :winget_done
if defined DRYRUN echo   [dry run] would update the apps listed below. Read-only list follows.
if defined DRYRUN winget upgrade --accept-source-agreements
if defined DRYRUN goto :winget_done
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
set "RC=%errorlevel%"
if "%RC%"=="-1978335189" set "RC=0"
if "%RC%"=="-1978335212" set "RC=0"
if not "%RC%"=="0" echo   Some apps could not be updated.
if not "%RC%"=="0" set "RESULT=1"
:winget_done

echo.
set "REBOOT="
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if not errorlevel 1 set "REBOOT=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if not errorlevel 1 set "REBOOT=1"
if not defined REBOOT echo No restart needed.
if not defined REBOOT goto :restart_done
echo A restart is needed to finish installing updates.
if defined AUTO goto :restart_done
if defined DRYRUN goto :restart_done
choice /c YN /m "Restart now"
if errorlevel 2 goto :norestart
shutdown /r /t 15 /c "Restarting to finish updates"
echo Restarting in 15 seconds. Run shutdown /a to cancel.
goto :restart_done
:norestart
echo Restart skipped. Restart later to finish updates.
:restart_done

echo.
echo Updates finished.
if "%RESULT%"=="1" echo Some steps had problems - see the warnings above.
if not defined AUTO echo Press any key to close...
if not defined AUTO pause >nul
exit /b %RESULT%
