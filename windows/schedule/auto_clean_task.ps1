param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Status,
    [switch]$DryRun
)

# Registers, removes or reports the "OneClick Kit Auto Clean" scheduled task.
# Runs auto_clean.ps1 every 2 days at 12:00, only when idle and on AC power.

$taskName = 'OneClick Kit Auto Clean'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptPath = Join-Path $repo 'windows\schedule\auto_clean.ps1'
$logsDir = Join-Path $env:LOCALAPPDATA 'OneClickKit\logs'
$user = $env:USERDOMAIN + '\' + $env:USERNAME
$taskArgs = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $scriptPath + '"'

function Show-Usage {
    Write-Host 'Usage: auto_clean_task.ps1 -Enable | -Disable | -Status [-DryRun]'
    Write-Host '  -Enable   register the scheduled task "OneClick Kit Auto Clean"'
    Write-Host '  -Disable  remove the scheduled task'
    Write-Host '  -Status   print Auto-clean: On/Off (and the next run time when On)'
    Write-Host '  -DryRun   with -Enable or -Disable, print what would happen and change nothing'
}

function Get-AutoCleanTask {
    try {
        return Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    } catch {
        return $null
    }
}

if (-not ($Enable -or $Disable -or $Status)) {
    Show-Usage
    exit 0
}

if ($Enable -and $Disable) {
    Write-Host 'Use only one of -Enable or -Disable.'
    Show-Usage
    exit 1
}

if ($Status) {
    $task = Get-AutoCleanTask
    if ($null -eq $task) {
        Write-Host 'Auto-clean: Off'
        exit 0
    }
    Write-Host 'Auto-clean: On'
    $nextText = 'unknown'
    try {
        $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        if ($null -ne $info.NextRunTime) { $nextText = $info.NextRunTime.ToString('yyyy-MM-dd HH:mm') }
    } catch { }
    Write-Host ('Next run: ' + $nextText)
    exit 0
}

if ($Enable) {
    if ($DryRun) {
        Write-Host '[dry run] would register the scheduled task:'
        Write-Host ('  task name : ' + $taskName)
        Write-Host ('  action    : powershell.exe ' + $taskArgs)
        Write-Host '  trigger   : daily, every 2 days, at 12:00'
        Write-Host '  settings  : run only if idle (10 min idle, wait up to 4 h), start when available,'
        Write-Host '              time limit 1 h, no battery start (AC power only)'
        Write-Host ('  principal : ' + $user + ' (highest privileges)')
        Write-Host 'Nothing was registered.'
        exit 0
    }

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Host ('Enable failed: script not found: ' + $scriptPath)
        exit 1
    }

    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
        $trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 2 -At (Get-Date -Hour 12 -Minute 0 -Second 0)
        $settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle -IdleDuration (New-TimeSpan -Minutes 10) -IdleWaitTimeout (New-TimeSpan -Hours 4) -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
        Write-Host ('Enabled: ' + $taskName)
        Write-Host ('Logs: ' + $logsDir)
        Write-Host 'Moving the OneClickUpdater repo folder breaks this task. After moving it, run -Disable, then -Enable again.'
        exit 0
    } catch {
        Write-Host ('Enable failed: ' + $_.Exception.Message)
        exit 1
    }
}

if ($Disable) {
    $task = Get-AutoCleanTask
    if ($null -eq $task) {
        Write-Host ($taskName + ' is not registered, nothing to disable.')
        exit 0
    }
    if ($DryRun) {
        Write-Host ('[dry run] would unregister the scheduled task: ' + $taskName)
        Write-Host 'Nothing was unregistered.'
        exit 0
    }
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host ('Disabled: ' + $taskName + ' removed.')
        exit 0
    } catch {
        Write-Host ('Disable failed: ' + $_.Exception.Message)
        exit 1
    }
}
