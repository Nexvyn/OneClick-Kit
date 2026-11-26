# OneClick Kit - Windows debloat engine. Windows PowerShell 5.1.
# Reads profiles/debloat.json. Dry run changes nothing and writes no files.
param(
  [switch]$DryRun,
  [switch]$Auto,
  [switch]$Undo,
  [string]$ProfilePath = (Join-Path $PSScriptRoot '..\..\profiles\debloat.json')
)

$ErrorActionPreference = 'Continue'
$script:Removed = 0
$script:SettingsChanged = 0
$script:Skipped = 0
$script:Failed = 0
$script:LogFile = $null
$script:DataDir = Join-Path $env:LOCALAPPDATA 'OneClickKit'
$script:Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Log([string]$Message) {
  Write-Host $Message
  if ($script:LogFile) {
    Add-Content -LiteralPath $script:LogFile -Value $Message -Encoding UTF8
  }
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($id)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Interactive {
  if ($Auto) { return $false }
  if ([Console]::IsInputRedirected) { return $false }
  return [Environment]::UserInteractive
}

function Test-Protected([string]$Name) {
  foreach ($pattern in $script:Cfg.never) {
    if ($Name -like $pattern) { return $true }
  }
  return $false
}

function Get-PsRegPath([string]$Hive, [string]$Path) {
  return ($Hive + ':\' + $Path)
}

# Returns the current state of one registry value: Exists, Kind, Value.
function Get-ValueState([string]$Hive, [string]$Path, [string]$Name) {
  $state = [pscustomobject]@{ Exists = $false; Kind = $null; Value = $null }
  $psPath = Get-PsRegPath $Hive $Path
  try {
    $key = Get-Item -LiteralPath $psPath -ErrorAction Stop
    $names = @($key.GetValueNames())
    if ($names -contains $Name) {
      $state.Exists = $true
      $state.Kind = [string]$key.GetValueKind($Name)
      $state.Value = $key.GetValue($Name)
    }
  } catch {
    # Key missing: the value does not exist.
  }
  return $state
}

function Get-AppxLists {
  try {
    $script:InstalledApps = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
  } catch {
    Write-Log '  Could not read the all-users app list. Using the current user only.'
    $script:InstalledApps = @(Get-AppxPackage -ErrorAction SilentlyContinue)
  }
  try {
    $script:ProvisionedApps = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop)
  } catch {
    Write-Log '  Could not read the provisioned app list. Skipping it.'
    $script:ProvisionedApps = @()
  }
}

# Finds installed and provisioned packages matching any of the patterns.
function Get-Targets([string[]]$Patterns) {
  $found = @{}
  foreach ($pattern in $Patterns) {
    foreach ($app in $script:InstalledApps) {
      if ($app.Name -like $pattern) {
        if (-not $found.ContainsKey($app.Name)) {
          $found[$app.Name] = [pscustomobject]@{ Name = $app.Name; Full = $null; Prov = $null }
        }
        $found[$app.Name].Full = $app.PackageFullName
      }
    }
    foreach ($prov in $script:ProvisionedApps) {
      if ($prov.DisplayName -like $pattern) {
        if (-not $found.ContainsKey($prov.DisplayName)) {
          $found[$prov.DisplayName] = [pscustomobject]@{ Name = $prov.DisplayName; Full = $null; Prov = $null }
        }
        $found[$prov.DisplayName].Prov = $prov.PackageName
      }
    }
  }
  return @($found.Values | Sort-Object Name)
}

# Startup (Run key) values whose names match the patterns.
function Get-RunMatches([string]$Hive, [string]$Path, [string[]]$Patterns) {
  $matches = @()
  $state = $null
  try {
    $key = Get-Item -LiteralPath (Get-PsRegPath $Hive $Path) -ErrorAction Stop
  } catch {
    return $matches
  }
  foreach ($name in @($key.GetValueNames())) {
    foreach ($pattern in $Patterns) {
      if ($name -like $pattern) {
        $matches += [pscustomobject]@{
          Hive = $Hive; Path = $Path; Name = $name
          Kind = [string]$key.GetValueKind($name); Value = $key.GetValue($name)
        }
        break
      }
    }
  }
  return $matches
}

function Get-WingetFound($Group) {
  if (-not $Group.PSObject.Properties['detectPaths']) { return $false }
  foreach ($raw in $Group.detectPaths) {
    $path = [Environment]::ExpandEnvironmentVariables($raw)
    if (Test-Path -LiteralPath $path) { return $true }
  }
  return $false
}

# Everything one group would change on this PC (only what is found).
function Get-GroupFindings($Group) {
  $packages = @()
  if ($Group.PSObject.Properties['packages']) { $packages = @($Group.packages) }
  $targets = @()
  if ($packages.Count -gt 0) { $targets = @(Get-Targets $packages | Where-Object { -not (Test-Protected $_.Name) }) }
  $winget = ''
  if ($Group.PSObject.Properties['winget'] -and (Get-WingetFound $Group)) { $winget = [string]$Group.winget }
  $runs = @()
  if ($Group.PSObject.Properties['startupPatterns']) {
    $runs = @(Get-RunMatches 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\Run' @($Group.startupPatterns))
  }
  $settings = @()
  if ($Group.PSObject.Properties['settings']) {
    foreach ($s in $Group.settings) {
      $st = Get-ValueState $s.hive $s.path $s.value
      if (-not ($st.Exists -and ([string]$st.Value -eq [string]$s.data))) { $settings += $s }
    }
  }
  return [pscustomobject]@{ Targets = $targets; Winget = $winget; Runs = $runs; Settings = $settings }
}

function Get-FoundNames($Findings) {
  $names = @()
  foreach ($t in $Findings.Targets) { $names += $t.Name }
  if ($Findings.Winget) { $names += ('winget ' + $Findings.Winget) }
  foreach ($r in $Findings.Runs) { $names += ('startup ' + $r.Name) }
  foreach ($s in $Findings.Settings) { $names += $s.name }
  return ($names -join ', ')
}

function Test-FindingsAny($Findings) {
  return (($Findings.Targets.Count + $Findings.Runs.Count + $Findings.Settings.Count) -gt 0) -or ([bool]$Findings.Winget)
}

# Removes one installed or provisioned package. Returns $true on success.
function Remove-Target($Target) {
  $ok = $true
  if ($Target.Full) {
    try {
      Remove-AppxPackage -Package $Target.Full -AllUsers -ErrorAction Stop
    } catch {
      try {
        Remove-AppxPackage -Package $Target.Full -ErrorAction Stop
      } catch {
        $ok = $false
        Write-Log ('  FAILED to remove ' + $Target.Name + ': ' + $_.Exception.Message)
      }
    }
  }
  if ($Target.Prov) {
    try {
      Remove-AppxProvisionedPackage -Online -PackageName $Target.Prov -ErrorAction Stop | Out-Null
    } catch {
      $ok = $false
      Write-Log ('  FAILED to remove provisioned ' + $Target.Name + ': ' + $_.Exception.Message)
    }
  }
  return $ok
}

function Invoke-Winget($Group) {
  if ($DryRun) {
    Write-Log ('[dry run] would remove ' + $Group.id + ' (winget ' + $Group.winget + ')')
    return
  }
  & winget uninstall --id $Group.winget --exact --silent --accept-source-agreements | Out-Host
  if ($LASTEXITCODE -eq 0) {
    Write-Log ('  removed ' + $Group.id + ' with winget')
    $script:Removed++
  } elseif ($Group.id -eq 'edge') {
    Write-Log '  Windows does not allow removing Edge in your region. Skipped.'
    $script:Skipped++
  } else {
    Write-Log ('  FAILED winget uninstall of ' + $Group.winget + ' (exit ' + $LASTEXITCODE + ')')
    $script:Failed++
  }
}

function Set-Setting($Setting) {
  $psPath = Get-PsRegPath $Setting.hive $Setting.path
  if ($DryRun) {
    Write-Log ('[dry run] would set ' + $Setting.name + ' (' + $Setting.hive + '\' + $Setting.path + ' ' + $Setting.value + ' = ' + $Setting.data + ')')
    return
  }
  try {
    if (-not (Test-Path -LiteralPath $psPath)) {
      New-Item -Path $psPath -Force | Out-Null
    }
    New-ItemProperty -Path $psPath -Name $Setting.value -PropertyType $Setting.type -Value $Setting.data -Force | Out-Null
    Write-Log ('  set ' + $Setting.name)
    $script:SettingsChanged++
  } catch {
    if ($Setting.PSObject.Properties['optional'] -and $Setting.optional) {
      Write-Log ('  skipped ' + $Setting.name + ' (not supported on this Windows build)')
      $script:Skipped++
    } else {
      Write-Log ('  FAILED ' + $Setting.name + ': ' + $_.Exception.Message)
      $script:Failed++
    }
  }
}

function Remove-RunValue($Run) {
  $psPath = Get-PsRegPath $Run.Hive $Run.Path
  if ($DryRun) {
    Write-Log ('[dry run] would remove startup value ' + $Run.Name + ' (' + $Run.Hive + ' Run)')
    return
  }
  try {
    Remove-ItemProperty -LiteralPath $psPath -Name $Run.Name -ErrorAction Stop
    Write-Log ('  removed startup value ' + $Run.Name)
    $script:SettingsChanged++
  } catch {
    Write-Log ('  FAILED startup value ' + $Run.Name + ': ' + $_.Exception.Message)
    $script:Failed++
  }
}

function Invoke-Undo {
  $file = Get-ChildItem -LiteralPath $script:DataDir -Filter 'debloat-backup-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $file) {
    Write-Log 'No debloat backup found. Nothing to undo.'
    return 1
  }
  Write-Log ('Restoring from ' + $file.FullName)
  $entries = @(Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)
  $failed = 0
  foreach ($e in $entries) {
    $psPath = Get-PsRegPath $e.hive $e.path
    $label = $e.name
    if ($DryRun) {
      if ($e.existed) { Write-Log ('[dry run] would restore ' + $label + ' to its old value') }
      else { Write-Log ('[dry run] would remove value ' + $label) }
      continue
    }
    try {
      if ($e.existed) {
        New-ItemProperty -Path $psPath -Name $e.value -PropertyType $e.kind -Value $e.data -Force | Out-Null
      } else {
        Remove-ItemProperty -LiteralPath $psPath -Name $e.value -ErrorAction Stop
      }
      Write-Log ('  restored ' + $label)
    } catch {
      Write-Log ('  FAILED to restore ' + $label + ': ' + $_.Exception.Message)
      $failed++
    }
  }
  if (-not $DryRun) {
    Write-Log 'Removed apps come back from the Microsoft Store (search the app name).'
  }
  if ($failed -gt 0) { return 1 }
  return 0
}

# ---------------------------------------------------------------- main

if (-not (Test-Path -LiteralPath $ProfilePath)) {
  Write-Host ('Profile not found: ' + $ProfilePath)
  exit 1
}
$script:Cfg = (Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json).windows

if (-not $DryRun -and -not (Test-IsAdmin)) {
  Write-Host 'Administrator rights are needed to debloat. Nothing was changed.'
  exit 1
}

if ($Undo) {
  $undoRc = Invoke-Undo
  exit $undoRc
}

if ($DryRun) {
  Write-Host 'DRY RUN - nothing will be changed, no restore point, no files written.'
} else {
  if (-not (Test-Path -LiteralPath $script:DataDir)) { New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null }
  $script:LogFile = Join-Path $script:DataDir ('debloat-' + $script:Stamp + '.log')
  Write-Log ('OneClick Kit debloat started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
  try {
    Checkpoint-Computer -Description 'OneClick Kit debloat' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Log 'Restore point created.'
  } catch {
    Write-Log ('WARNING: no restore point (' + $_.Exception.Message + '). System Protection may be off. Continuing.')
  }
}

Get-AppxLists

# Selected apps and promo items.
$removeTargets = New-Object System.Collections.ArrayList
$settingsToApply = New-Object System.Collections.ArrayList
$runToRemove = New-Object System.Collections.ArrayList
$wingetGroups = New-Object System.Collections.ArrayList

Write-Log ''
Write-Log '== Apps =='
foreach ($app in $script:Cfg.apps) {
  if ($app.mark -ne 'yes') { continue }
  foreach ($t in (Get-Targets @($app.packages))) {
    if (Test-Protected $t.Name) { Write-Log ('  protected: ' + $t.Name); $script:Skipped++; continue }
    $removeTargets.Add($t) | Out-Null
    $pkg = $t.Full; if (-not $pkg) { $pkg = $t.Prov }
    if ($DryRun) { Write-Log ('[dry run] would remove ' + $t.Name + ' (' + $pkg + ')') }
  }
}

Write-Log ''
Write-Log '== Promo apps =='
foreach ($promo in $script:Cfg.promo) {
  if ($promo.mark -ne 'yes') { continue }
  foreach ($t in (Get-Targets @($promo.patterns))) {
    if (Test-Protected $t.Name) { Write-Log ('  protected: ' + $t.Name); $script:Skipped++; continue }
    $removeTargets.Add($t) | Out-Null
    $pkg = $t.Full; if (-not $pkg) { $pkg = $t.Prov }
    if ($DryRun) { Write-Log ('[dry run] would remove ' + $t.Name + ' (' + $pkg + ')') }
  }
}

Write-Log ''
Write-Log '== Settings =='
foreach ($s in $script:Cfg.settings) {
  if ($s.mark -ne 'yes') { continue }
  $st = Get-ValueState $s.hive $s.path $s.value
  if ($st.Exists -and ([string]$st.Value -eq [string]$s.data)) { continue }
  $settingsToApply.Add($s) | Out-Null
  if ($DryRun) { Write-Log ('[dry run] would set ' + $s.name + ' (' + $s.hive + '\' + $s.path + ' ' + $s.value + ' = ' + $s.data + ')') }
}

Write-Log ''
Write-Log '== Startup =='
foreach ($item in $script:Cfg.startup) {
  if ($item.mark -ne 'yes') { continue }
  foreach ($r in (Get-RunMatches $item.hive $item.path @($item.patterns))) {
    if (Test-Protected $r.Name) { Write-Log ('  protected: ' + $r.Name); $script:Skipped++; continue }
    $runToRemove.Add($r) | Out-Null
    if ($DryRun) { Write-Log ('[dry run] would remove startup value ' + $r.Name + ' (' + $r.Hive + ' Run)') }
  }
}

# Ask groups: asked interactively, skipped with -Auto or without a console.
$askGroups = @()
foreach ($g in $script:Cfg.askGroups) { $askGroups += $g }
$oemPatterns = @()
foreach ($o in $script:Cfg.oemPromo) { $oemPatterns += $o.patterns }
$askGroups += [pscustomobject]@{
  id = 'oem-promo'
  question = 'Remove these PC maker welcome and promo apps? (Listed below when found)'
  removeWhen = 'yes'
  packages = $oemPatterns
}

Write-Log ''
Write-Log '== Ask =='
$interactive = Test-Interactive
$chosenGroups = @()
foreach ($g in $askGroups) {
  $findings = Get-GroupFindings $g
  if (-not (Test-FindingsAny $findings)) { continue }
  Write-Log ('[ask] ' + $g.question)
  Write-Log ('      found: ' + (Get-FoundNames $findings))
  if ($DryRun) { continue }
  if (-not $interactive) {
    Write-Log '      kept (no interactive answer with -Auto or redirected input)'
    continue
  }
  $answer = Read-Host ($g.question + ' [y/N]')
  $yes = ($answer -match '^(y|yes)$')
  $remove = $yes
  if ($g.removeWhen -eq 'no') { $remove = -not $yes }
  if ($remove) { $chosenGroups += $g } else { Write-Log '      kept' }
}

# Real run: a choice from Ask groups is added to the plan.
if ($DryRun) {
  Write-Log ''
  Write-Log 'Dry run complete. Nothing was changed.'
  exit 0
}

foreach ($g in $chosenGroups) {
  $findings = Get-GroupFindings $g
  foreach ($t in $findings.Targets) { $removeTargets.Add($t) | Out-Null }
  if ($findings.Winget) { $wingetGroups.Add($g) | Out-Null }
  foreach ($r in $findings.Runs) { $runToRemove.Add($r) | Out-Null }
  foreach ($s in $findings.Settings) { $settingsToApply.Add($s) | Out-Null }
}
# Ask-group settings that are not chosen are not in $settingsToApply.

# Backup every value that will change, before any change.
$backupRows = New-Object System.Collections.ArrayList
foreach ($s in $settingsToApply) {
  $st = Get-ValueState $s.hive $s.path $s.value
  $kind = [string]$s.type
  if ($st.Exists) { $kind = [string]$st.Kind }
  $backupRows.Add([pscustomobject]@{
    name = $s.name; hive = $s.hive; path = $s.path; value = $s.value
    existed = [bool]$st.Exists; kind = $kind; data = $st.Value
  }) | Out-Null
}
foreach ($r in $runToRemove) {
  $backupRows.Add([pscustomobject]@{
    name = ('startup ' + $r.Name); hive = $r.Hive; path = $r.Path; value = $r.Name
    existed = $true; kind = [string]$r.Kind; data = $r.Value
  }) | Out-Null
}
$backupFile = Join-Path $script:DataDir ('debloat-backup-' + $script:Stamp + '.json')
$backupJson = ConvertTo-Json -InputObject @($backupRows.ToArray()) -Depth 5
Set-Content -LiteralPath $backupFile -Value $backupJson -Encoding UTF8
Write-Log ('Backup written: ' + $backupFile + ' (' + $backupRows.Count + ' values)')

Write-Log ''
Write-Log '== Removing apps =='
foreach ($t in $removeTargets) {
  $ok = Remove-Target $t
  if ($ok) { Write-Log ('  removed ' + $t.Name); $script:Removed++ } else { $script:Failed++ }
}
foreach ($g in $wingetGroups) { Invoke-Winget $g }

Write-Log ''
Write-Log '== Startup values =='
foreach ($r in $runToRemove) { Remove-RunValue $r }

Write-Log ''
Write-Log '== Settings =='
foreach ($s in $settingsToApply) { Set-Setting $s }

Write-Log ''
Write-Log ('Summary: removed ' + $script:Removed + ', settings changed ' + $script:SettingsChanged + ', skipped ' + $script:Skipped + ', failed ' + $script:Failed)
Write-Log ('Log: ' + $script:LogFile)
Write-Log ('Undo: windows\debloat\debloat.bat /undo (backup ' + $backupFile + ')')
if ($script:Failed -gt 0) { exit 1 }
exit 0
