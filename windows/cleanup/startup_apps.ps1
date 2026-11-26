# Startup app manager for OneClick Kit (Windows).
# Disables startup entries the same way Task Manager does (StartupApproved values),
# so the user can re-enable them in Task Manager > Startup apps.
# Never deletes anything. Protected items (security, drivers, input, OneClick) are never touched.
#
# Usage:
#   startup_apps.ps1 -DryRun            show what would change, change nothing
#   startup_apps.ps1 -Review            list items, ask which to keep, disable the rest
#   startup_apps.ps1 -Auto              disable every enabled item not protected and not kept
#   startup_apps.ps1 -Undo              restore the newest startup backup
# -DryRun can be combined with -Review or -Undo to preview them.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Auto,
    [switch]$Review,
    [switch]$Undo
)

$AppDir    = Join-Path $env:LOCALAPPDATA 'OneClickKit'
$LogDir    = Join-Path $AppDir 'logs'
$KeepFile  = Join-Path $AppDir 'startup-keep.json'
$Utf8      = New-Object System.Text.UTF8Encoding($false)
$SkipProps = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

$script:LogFile = $null
$script:Failed  = 0

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$ElevatedNow = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Protected tokens. Wide flag = word-boundary match (short tokens); otherwise substring match.
$ProtectedTokens = @(
    @{ T = 'SecurityHealth';  W = $false },
    @{ T = 'Windows Defender'; W = $false },
    @{ T = 'MsMpEng';         W = $false },
    @{ T = 'antivirus';       W = $false },
    @{ T = 'Defender';        W = $false },
    @{ T = 'Sense';           W = $false },
    @{ T = 'Realtek';         W = $false },
    @{ T = 'RtkAudUService';  W = $false },
    @{ T = 'NVIDIA';          W = $false },
    @{ T = 'NvBackend';       W = $false },
    @{ T = 'AMD';             W = $true },
    @{ T = 'Radeon';          W = $false },
    @{ T = 'Intel';           W = $false },
    @{ T = 'igfx';            W = $false },
    @{ T = 'Synaptics';       W = $false },
    @{ T = 'ELAN';            W = $false },
    @{ T = 'HP';              W = $true },
    @{ T = 'HPSEU';           W = $false },
    @{ T = 'HPPC';            W = $false },
    @{ T = 'myHP';            W = $false },
    @{ T = 'System.sav';      W = $false },
    @{ T = 'AD2F1837';        W = $false },
    @{ T = 'OMEN';            W = $false },
    @{ T = 'Dolby';           W = $false },
    @{ T = 'Logitech';        W = $false },
    @{ T = 'Razer';           W = $false },
    @{ T = 'ctfmon';          W = $false },
    @{ T = 'osk';             W = $true },
    @{ T = 'Narrator';        W = $false },
    @{ T = 'OneClick';        W = $false }
)

function Out-Line([string]$Text) {
    Write-Host $Text
    if ($script:LogFile) {
        try { Add-Content -LiteralPath $script:LogFile -Value $Text -Encoding UTF8 } catch { }
    }
}

function Test-Protected([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    foreach ($t in $ProtectedTokens) {
        if ($t.W) {
            $pattern = '\b' + [regex]::Escape($t.T) + '\b'
            if ([regex]::IsMatch($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        } else {
            if ($Text.IndexOf($t.T, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
    }
    return $false
}

function Get-ApprovedValue([string]$KeyPath, [string]$ValueName) {
    $result = @{ Existed = $false; Value = $null }
    $obj = Get-ItemProperty -LiteralPath $KeyPath -ErrorAction SilentlyContinue
    if ($obj) {
        foreach ($p in $obj.PSObject.Properties) {
            if ($p.Name -eq $ValueName) {
                $result.Existed = $true
                $result.Value = $p.Value
            }
        }
    }
    return $result
}

function New-Record {
    param($Kind, $Name, $Where, $Hive, $Admin, $ApprovedKey, $ValueName, $Command, $Existed, $Bytes, $State)
    $enabled = $false
    if ($Kind -eq 'store') {
        $enabled = ($Existed -and ($State -eq 2))
    } else {
        if (-not $Existed) {
            $enabled = $true
        } elseif ($null -ne $Bytes -and $Bytes.Length -gt 0) {
            $enabled = (([int]$Bytes[0] -band 1) -eq 0)
        } else {
            $enabled = $true
        }
    }
    $prot = (Test-Protected $Name) -or (Test-Protected $Command)
    return [pscustomobject]@{
        Kind       = $Kind
        Name       = [string]$Name
        Where      = $Where
        Hive       = $Hive
        Admin      = [bool]$Admin
        ApprovedKey = $ApprovedKey
        ValueName  = $ValueName
        Command    = [string]$Command
        Existed    = [bool]$Existed
        Bytes      = $Bytes
        State      = $State
        Enabled    = [bool]$enabled
        Protected  = [bool]$prot
    }
}

function Get-StartupItems {
    $items = New-Object System.Collections.ArrayList

    # Registry Run values. Run32 is the StartupApproved name for WOW6432Node entries.
    $runSources = @(
        @{ Hive = 'HKCU'; Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
           Where = 'Run, HKCU'; Admin = $false },
        @{ Hive = 'HKLM'; Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';
           Approved = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
           Where = 'Run, HKLM'; Admin = $true },
        @{ Hive = 'HKLM'; Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run';
           Approved = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32';
           Where = 'Run, HKLM 32-bit'; Admin = $true }
    )
    foreach ($src in $runSources) {
        try {
            $obj = Get-ItemProperty -LiteralPath $src.Key -ErrorAction SilentlyContinue
            if (-not $obj) { continue }
            foreach ($p in $obj.PSObject.Properties) {
                if ($SkipProps -contains $p.Name) { continue }
                try {
                    $ap = Get-ApprovedValue $src.Approved $p.Name
                    $rec = New-Record 'run' $p.Name $src.Where $src.Hive $src.Admin $src.Approved $p.Name ([string]$p.Value) $ap.Existed $ap.Value $null
                    [void]$items.Add($rec)
                } catch {
                    Out-Line "warning: could not read run value $($p.Name): $($_.Exception.Message)"
                }
            }
        } catch {
            Out-Line "warning: could not read $($src.Key): $($_.Exception.Message)"
        }
    }

    # Startup folders: user and all users.
    $folders = @(
        @{ Dir = [Environment]::GetFolderPath('Startup'); Hive = 'HKCU';
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder';
           Where = 'Startup folder, user'; Admin = $false },
        @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Hive = 'HKLM';
           Approved = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder';
           Where = 'Startup folder, all users'; Admin = $true }
    )
    foreach ($f in $folders) {
        if ([string]::IsNullOrEmpty($f.Dir)) { continue }
        try {
            $files = @(Get-ChildItem -LiteralPath $f.Dir -File -Force -ErrorAction SilentlyContinue)
            foreach ($file in $files) {
                if ($file.Name -eq 'desktop.ini') { continue }
                try {
                    $ap = Get-ApprovedValue $f.Approved $file.Name
                    $rec = New-Record 'folder' $file.Name $f.Where $f.Hive $f.Admin $f.Approved $file.Name $file.FullName $ap.Existed $ap.Value $null
                    [void]$items.Add($rec)
                } catch {
                    Out-Line "warning: could not read startup file $($file.Name): $($_.Exception.Message)"
                }
            }
        } catch {
            Out-Line "warning: could not read startup folder $($f.Dir): $($_.Exception.Message)"
        }
    }

    # Store app startup tasks (HKCU only).
    $storeRoot = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    try {
        $pkgs = @(Get-ChildItem -LiteralPath $storeRoot -ErrorAction SilentlyContinue)
        foreach ($pkg in $pkgs) {
            $pkgName = $pkg.PSChildName
            $tasks = @(Get-ChildItem -LiteralPath "$storeRoot\$pkgName" -ErrorAction SilentlyContinue)
            foreach ($task in $tasks) {
                try {
                    $taskPath = "$storeRoot\$pkgName\$($task.PSChildName)"
                    $st = Get-ApprovedValue $taskPath 'State'
                    if (-not $st.Existed) { continue }
                    $rec = New-Record 'store' ($pkgName + '/' + $task.PSChildName) 'Store app task' 'HKCU' $false $taskPath 'State' $pkgName $true $null ([int]$st.Value)
                    [void]$items.Add($rec)
                } catch {
                    Out-Line "warning: could not read store task under ${pkgName}: $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Out-Line "warning: could not read store startup tasks: $($_.Exception.Message)"
    }

    return @($items)
}

function Read-KeepList {
    if (-not (Test-Path -LiteralPath $KeepFile)) { return @() }
    $raw = Get-Content -LiteralPath $KeepFile -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $data = $raw | ConvertFrom-Json
    return @($data | ForEach-Object { [string]$_ })
}

function Write-KeepList([string[]]$Names) {
    if (-not (Test-Path -LiteralPath $AppDir)) { New-Item -ItemType Directory -Path $AppDir -Force | Out-Null }
    $quoted = @()
    foreach ($n in $Names) { $quoted += ('"' + $n.Replace('\', '\\').Replace('"', '\"') + '"') }
    if ($quoted.Count -eq 0) {
        $json = '[]'
    } else {
        $json = "[`r`n  " + ($quoted -join ",`r`n  ") + "`r`n]"
    }
    [System.IO.File]::WriteAllText($KeepFile, $json + "`r`n", $Utf8)
}

function Write-Backup($All, [string]$Path) {
    $entries = @()
    foreach ($it in $All) {
        $bytesOut = $null
        $stateOut = $null
        if ($it.Existed) {
            if ($it.Kind -eq 'store') { $stateOut = [int]$it.State } else { $bytesOut = [int[]]$it.Bytes }
        }
        $entries += @{
            item    = $it.Name
            where   = $it.Where
            kind    = $it.Kind
            hive    = $it.Hive
            path    = $it.ApprovedKey
            name    = $it.ValueName
            existed = [bool]$it.Existed
            bytes   = $bytesOut
            state   = $stateOut
        }
    }
    $doc = @{ version = 1; created = (Get-Date).ToString('s'); entries = @($entries) }
    $json = $doc | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($Path, $json, $Utf8)
}

function Set-Disabled($It) {
    if ($It.Kind -eq 'store') {
        Set-ItemProperty -LiteralPath $It.ApprovedKey -Name 'State' -Value 1 -Type DWord -ErrorAction Stop
        return
    }
    $b = New-Object byte[] 12
    $b[0] = 3
    if (-not (Test-Path -LiteralPath $It.ApprovedKey)) {
        New-Item -Path $It.ApprovedKey -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $It.ApprovedKey -Name $It.ValueName -Value $b -Type Binary -ErrorAction Stop
}

function Restore-Entry($E) {
    $key = [string]$E.path
    $vn  = [string]$E.name
    if ($E.kind -eq 'store') {
        if ($null -eq $E.state) { return }
        Set-ItemProperty -LiteralPath $key -Name $vn -Value ([int]$E.state) -Type DWord -ErrorAction Stop
        return
    }
    $b = New-Object byte[] 12
    if ($null -eq $E.bytes) {
        # Entry did not exist before: Windows treats that as enabled, so write the enabled marker.
        $b[0] = 2
    } else {
        $src = @($E.bytes)
        for ($i = 0; $i -lt 12 -and $i -lt $src.Count; $i++) { $b[$i] = [byte]$src[$i] }
    }
    if (-not (Test-Path -LiteralPath $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $key -Name $vn -Value $b -Type Binary -ErrorAction Stop
}

function Show-Usage {
    Write-Host 'Usage: startup_apps.ps1 [-DryRun] [-Review | -Auto | -Undo]'
    Write-Host '  -Review   list enabled startup items, ask which to keep, disable the rest'
    Write-Host '  -Auto     disable every enabled startup item that is not protected and not kept'
    Write-Host '  -Undo     restore StartupApproved and Store state from the newest backup'
    Write-Host '  -DryRun   print what would change; changes nothing (no backup, keep list or log)'
    Write-Host 'Protected items (security, drivers, input, OneClick) are never changed.'
}

function Invoke-Undo([string]$Stamp) {
    $latest = Get-ChildItem -LiteralPath $AppDir -Filter 'startup-backup-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -Last 1
    if (-not $latest) {
        Write-Host "No startup backup found in $AppDir. Nothing to restore."
        return 0
    }
    Write-Host "Restoring from: $($latest.FullName)"
    if (-not $DryRun) {
        if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        $script:LogFile = Join-Path $LogDir "startup-apps-$Stamp.log"
        Out-Line "undo from $($latest.FullName)"
    }
    $data = Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $entries = @($data.entries)
    foreach ($e in $entries) {
        $label = "$($e.item) ($($e.where))"
        try {
            if ($e.hive -eq 'HKLM' -and -not $ElevatedNow) {
                Out-Line "skipped (needs admin): $label"
                continue
            }
            if ($DryRun) {
                Out-Line "[dry run] would restore $label"
                continue
            }
            Restore-Entry $e
            Out-Line "restored: $label"
        } catch {
            $script:Failed++
            Out-Line "failed: $label - $($_.Exception.Message)"
        }
    }
    if ($script:Failed -gt 0) { return 1 }
    return 0
}

# ---- main ----

if (-not ($DryRun -or $Auto -or $Review -or $Undo)) {
    Show-Usage
    exit 0
}

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if ($Undo) {
    $undoCode = Invoke-Undo $Stamp
    exit $undoCode
}

$keep = @()
try {
    $keep = @(Read-KeepList)
} catch {
    Write-Host "error: keep list is unreadable ($KeepFile): $($_.Exception.Message)"
    Write-Host 'No changes made.'
    exit 1
}

$items = @(Get-StartupItems)
$saveKeep = $false

# Review: show the numbered list, then ask unless this is a dry run or input is redirected.
if ($Review -and -not $Auto) {
    $cands = @($items | Where-Object { $_.Enabled -and -not $_.Protected })
    Write-Host ''
    Write-Host 'Enabled startup items (not protected):'
    for ($i = 0; $i -lt $cands.Count; $i++) {
        $mark = ''
        if ($keep -contains $cands[$i].Name) { $mark = ' (kept)' }
        Write-Host ("  {0}. {1} ({2}){3}" -f ($i + 1), $cands[$i].Name, $cands[$i].Where, $mark)
    }
    Write-Host ''
    if (-not $DryRun -and -not [Console]::IsInputRedirected) {
        Write-Host -NoNewline 'Type the numbers to KEEP starting with Windows, separated by spaces, or press Enter to keep none of them: '
        $answer = [Console]::ReadLine()
        if ($null -eq $answer) { $answer = '' }
        $chosen = @()
        foreach ($tok in @($answer -split '[\s,]+' | Where-Object { $_ -ne '' })) {
            $n = 0
            if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $cands.Count) {
                $nm = $cands[$n - 1].Name
                if ($chosen -notcontains $nm) { $chosen += $nm }
            } else {
                Write-Host "ignored: $tok"
            }
        }
        $keep = @($chosen)
        $saveKeep = $true
    }
}

# Classify every item and collect the ones to disable.
$toDo = @()
foreach ($it in $items) {
    if ($it.Protected) {
        Out-Line "protected: $($it.Name)"
        continue
    }
    if (-not $it.Enabled) {
        Out-Line "already off: $($it.Name) ($($it.Where))"
        continue
    }
    if ($keep -contains $it.Name) {
        Out-Line "kept: $($it.Name)"
        continue
    }
    $toDo += $it
    if ($DryRun) { Out-Line "[dry run] would disable $($it.Name) ($($it.Where))" }
}

if ($DryRun) {
    Write-Host ("summary: {0} would be disabled, {1} items total" -f $toDo.Count, $items.Count)
    exit 0
}

# Real run: back up, save keep list (Review only), log, then disable.
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$script:LogFile = Join-Path $LogDir "startup-apps-$Stamp.log"
Out-Line "startup-apps run at $Stamp (elevated: $ElevatedNow)"

if ($toDo.Count -gt 0 -or $saveKeep) {
    $backupPath = Join-Path $AppDir "startup-backup-$Stamp.json"
    try {
        Write-Backup $items $backupPath
        Out-Line "backup: $backupPath"
    } catch {
        Out-Line "error: backup failed, no changes made: $($_.Exception.Message)"
        exit 1
    }
}

if ($saveKeep) {
    try {
        Write-KeepList $keep
        Out-Line "keep list saved: $($keep.Count) item(s)"
    } catch {
        $script:Failed++
        Out-Line "failed: keep list save - $($_.Exception.Message)"
    }
}

foreach ($it in $toDo) {
    $label = "$($it.Name) ($($it.Where))"
    try {
        if ($it.Hive -eq 'HKLM' -and -not $ElevatedNow) {
            Out-Line "skipped (needs admin): $label"
            continue
        }
        Set-Disabled $it
        Out-Line "disabled: $label"
    } catch {
        $script:Failed++
        Out-Line "failed: $label - $($_.Exception.Message)"
    }
}

Out-Line ("summary: {0} disabled candidate(s), {1} failed" -f $toDo.Count, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
