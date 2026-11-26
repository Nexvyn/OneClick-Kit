param([switch]$DryRun)

# Automatic light cleanup, run by the "OneClick Kit Auto Clean" scheduled task.
# -DryRun prints what would happen and changes nothing (no log, no state file).

$ErrorActionPreference = 'Continue'

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$kitDir = Join-Path $env:LOCALAPPDATA 'OneClickKit'
$logDir = Join-Path $kitDir 'logs'
$stateFile = Join-Path $kitDir 'auto-clean-state.json'
$logPath = Join-Path $logDir ('auto-clean-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$now = Get-Date
$results = New-Object System.Collections.ArrayList

if (-not $DryRun) {
    try { New-Item -ItemType Directory -Force -Path $logDir | Out-Null } catch { }
}

function Write-Step {
    param([string]$Text)
    Write-Host $Text
    if (-not $DryRun) {
        try { Add-Content -LiteralPath $logPath -Value $Text -Encoding UTF8 } catch { }
    }
}

function Add-Result {
    param([string]$Text)
    [void]$results.Add($Text)
}

function Remove-Paths {
    param([string[]]$Paths, [string]$Label)
    $list = @($Paths)
    $total = $list.Count

    if ($DryRun) {
        $shown = 0
        foreach ($p in $list) {
            if ($shown -ge 20) { break }
            Write-Step ('[dry run] would delete ' + $p)
            $shown++
        }
        if ($total -gt 20) {
            Write-Step ('[dry run] ... and ' + ($total - 20) + ' more (' + $Label + ')')
        }
        Write-Step ('[dry run] ' + $Label + ': ' + $total + ' item(s) would be deleted')
        return
    }

    $deleted = 0
    $skipped = 0
    foreach ($p in $list) {
        try {
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
            $deleted++
        } catch {
            $skipped++
        }
    }
    $msg = $Label + ': deleted ' + $deleted + ', skipped ' + $skipped + ' (in use or errors)'
    Write-Step $msg
    Add-Result $msg
}

function Invoke-Tool {
    param([string]$Exe, [string[]]$ArgList, [string]$Label)
    $shown = $Exe + ' ' + ($ArgList -join ' ')
    if ($DryRun) {
        Write-Step ('[dry run] would run ' + $shown)
        return
    }
    Write-Step ('Running: ' + $shown)
    $output = & $Exe @ArgList 2>&1
    $code = $LASTEXITCODE
    foreach ($line in @($output)) {
        Write-Step ('  ' + ('' + $line))
    }
    $msg = $Label + ': exit code ' + $code
    Write-Step $msg
    Add-Result $msg
}

# Step 1: top-level temp files and folders older than 2 days.
try {
    $cutoff = $now.AddDays(-2)
    $roots = @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'))
    foreach ($root in $roots) {
        try {
            if (-not (Test-Path -LiteralPath $root)) {
                Write-Step ('Temp: ' + $root + ' not found, skipped')
                continue
            }
            $old = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Name -ine 'claude' } |
                ForEach-Object { $_.FullName })
            Remove-Paths -Paths $old -Label ('Temp ' + $root)
        } catch {
            Write-Step ('Temp step failed for ' + $root + ': ' + $_.Exception.Message)
        }
    }
} catch {
    Write-Step ('Temp step failed: ' + $_.Exception.Message)
}

# Step 2: Recycle Bin items deleted more than 14 days ago.
# Reads the $I metadata files in <fixed drive>\$Recycle.Bin\<current user SID>.
# Each $I file holds the deletion time; the matching data item is the $R file or folder.
try {
    $cutoff14 = $now.AddDays(-14)
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $fixedDrives = @([System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed -and $_.IsReady } |
        ForEach-Object { $_.RootDirectory.FullName })
    $binItems = New-Object System.Collections.ArrayList
    $binDeleted = 0
    $binSkipped = 0
    foreach ($drive in $fixedDrives) {
        try {
            $sidFolder = Join-Path (Join-Path $drive '$Recycle.Bin') $sid
            if (-not (Test-Path -LiteralPath $sidFolder)) { continue }
            $infoFiles = @(Get-ChildItem -LiteralPath $sidFolder -Force -Filter '$I*' -File -ErrorAction Stop)
        } catch {
            Write-Step ('Recycle Bin: cannot list ' + $drive + ' (' + $_.Exception.Message + ')')
            continue
        }
        foreach ($info in $infoFiles) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($info.FullName)
                if ($bytes.Length -lt 24) {
                    Write-Step ('Recycle Bin: skipped ' + $info.Name + ' (file too short)')
                    $binSkipped++
                    continue
                }
                $version = [BitConverter]::ToInt64($bytes, 0)
                $deletedOn = [DateTime]::FromFileTimeUtc([BitConverter]::ToInt64($bytes, 16)).ToLocalTime()
                if ($deletedOn -ge $cutoff14) { continue }

                # The data item is named '$R' + the suffix of the '$I' file name.
                $rPath = Join-Path $sidFolder ('$R' + $info.Name.Substring(2))
                $rExists = Test-Path -LiteralPath $rPath

                if ($DryRun) {
                    if ($rExists) {
                        [void]$binItems.Add('[dry run] would delete from Recycle Bin: ' + $rPath + ' (deleted ' + $deletedOn.ToString('yyyy-MM-dd') + ')')
                    }
                    continue
                }

                # The $I file is removed only when the data item is gone, so a failed
                # data item removal is never left without its metadata record.
                $rRemoved = $true
                if ($rExists) {
                    try {
                        Remove-Item -LiteralPath $rPath -Recurse -Force -ErrorAction Stop
                    } catch {
                        $rRemoved = $false
                    }
                }
                if ($rRemoved) {
                    Remove-Item -LiteralPath $info.FullName -Force -ErrorAction Stop
                    $binDeleted++
                } else {
                    $binSkipped++
                }
            } catch {
                Write-Step ('Recycle Bin: skipped ' + $info.Name + ' (' + $_.Exception.Message + ')')
                $binSkipped++
            }
        }
    }

    if ($DryRun) {
        $shown = 0
        foreach ($line in $binItems) {
            if ($shown -ge 20) { break }
            Write-Step $line
            $shown++
        }
        if ($binItems.Count -gt 20) {
            Write-Step ('[dry run] ... and ' + ($binItems.Count - 20) + ' more (Recycle Bin (older than 14 days))')
        }
        Write-Step ('[dry run] Recycle Bin (older than 14 days): ' + $binItems.Count + ' item(s) would be deleted')
    } else {
        $msg = 'Recycle Bin (older than 14 days): deleted ' + $binDeleted + ', skipped ' + $binSkipped + ' (in use or errors)'
        Write-Step $msg
        Add-Result $msg
    }
} catch {
    Write-Step ('Recycle Bin step failed: ' + $_.Exception.Message)
}

# Step 2b: startup apps. Turns off new startup programs (never deletes; keep list and protected items are respected).
try {
    $startupScript = Join-Path $repo 'windows\cleanup\startup_apps.ps1'
    if ($DryRun) { $startupArg = '-DryRun' } else { $startupArg = '-Auto' }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $startupScript $startupArg | ForEach-Object { Write-Step ('  ' + ('' + $_)) }
    $msg = 'Startup apps: exit code ' + $LASTEXITCODE
    Write-Step $msg
    Add-Result $msg
} catch {
    Write-Step ('Startup apps step failed: ' + $_.Exception.Message)
}

# Step 3: idle dev cache cleanup, if node is installed.
try {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $node) {
        Write-Step 'Idle cache cleanup: node not found, skipped'
    } else {
        $devcache = Join-Path $repo 'tools\devcache.mjs'
        Invoke-Tool -Exe 'node' -ArgList @($devcache, 'clean-idle', '--unattended') -Label 'devcache clean-idle'
    }
} catch {
    Write-Step ('Idle cache step failed: ' + $_.Exception.Message)
}

# Step 4: pnpm store prune and npm cache verify, if installed.
try {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Invoke-Tool -Exe 'cmd.exe' -ArgList @('/c', 'pnpm', 'store', 'prune') -Label 'pnpm store prune'
    } else {
        Write-Step 'pnpm not found, store prune skipped'
    }
} catch {
    Write-Step ('pnpm step failed: ' + $_.Exception.Message)
}
try {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Invoke-Tool -Exe 'cmd.exe' -ArgList @('/c', 'npm', 'cache', 'verify') -Label 'npm cache verify'
    } else {
        Write-Step 'npm not found, cache verify skipped'
    }
} catch {
    Write-Step ('npm step failed: ' + $_.Exception.Message)
}

# Step 5: weekly full dev cache clean, at most every 7 days.
try {
    $last = $null
    if (Test-Path -LiteralPath $stateFile) {
        try {
            $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            if ($null -ne $state.lastWeekly) { $last = [datetime]$state.lastWeekly }
        } catch {
            $last = $null
        }
    }
    $due = $true
    if ($null -ne $last) {
        if (($now - $last).TotalDays -lt 7) { $due = $false }
    }

    if (-not $due) {
        $msg = 'Weekly clean: last run ' + $last.ToString('yyyy-MM-dd HH:mm') + ', not due yet'
        Write-Step $msg
        Add-Result $msg
    } else {
        $bat = Join-Path $repo 'windows\cleanup\clean_dev_caches.bat'
        Invoke-Tool -Exe 'cmd.exe' -ArgList @('/c', $bat, '/auto') -Label 'weekly clean_dev_caches'
        if ($DryRun) {
            Write-Step '[dry run] would write state file (lastWeekly = now)'
        } else {
            New-Item -ItemType Directory -Force -Path $kitDir | Out-Null
            $json = @{ lastWeekly = (Get-Date).ToString('o') } | ConvertTo-Json
            [System.IO.File]::WriteAllText($stateFile, $json)
        }
    }
} catch {
    Write-Step ('Weekly step failed: ' + $_.Exception.Message)
}

# Step 6: old logs (30 days). debloat-backup-*.json files are never deleted.
try {
    $cutoff30 = $now.AddDays(-30)
    $logFiles = @()
    if (Test-Path -LiteralPath $logDir) {
        $logFiles += @(Get-ChildItem -LiteralPath $logDir -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff30 })
    }
    $debloatLogs = @(Get-ChildItem -LiteralPath $kitDir -File -Filter 'debloat-*.log' -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'debloat-backup-*' -and $_.LastWriteTime -lt $cutoff30 })
    $logFiles += $debloatLogs
    $paths = @($logFiles | ForEach-Object { $_.FullName })
    Remove-Paths -Paths $paths -Label 'Old logs (older than 30 days)'
} catch {
    Write-Step ('Log step failed: ' + $_.Exception.Message)
}

if (-not $DryRun) {
    Write-Step ''
    Write-Step '=== Auto clean summary ==='
    foreach ($r in $results) { Write-Step $r }
    Write-Step ('Log: ' + $logPath)
}

exit 0
