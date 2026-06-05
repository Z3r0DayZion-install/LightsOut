# Nightfall.Core - settings, power actions, LuxGrid events
$script:NightfallVersion = '3.2.0'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:EventDir = Join-Path $env:LOCALAPPDATA 'LuxGrid\events\inbox'
$script:DryRun = $false
$script:Channel = 'Dev'

function Get-NightfallVersion { $script:NightfallVersion }

function Set-NightfallChannel {
    param([ValidateSet('Dev', 'Release')][string]$Name)
    $script:Channel = $Name
}

function Set-NightfallDryRun {
    param([bool]$Enabled)
    $script:DryRun = $Enabled
}

function Test-NightfallDryRun { [bool]$script:DryRun }

function Get-NightfallDefaultSettings {
    @{
        DefaultSeconds = 1700
        Action         = 'Shutdown'
        ConfirmAtEnd   = $true
        AutoStart      = $true
        TopMost        = $true
        WarnAt5Min     = $true
        DryRun         = $false
        EmitLuxGridEvents = $false
        RunAtLogin       = $false
    }
}

function Get-NightfallInstallDir {
    Join-Path ${env:ProgramFiles} 'Nightfall'
}

function Get-NightfallStartupShortcutPath {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'Nightfall.lnk'
}

function Test-NightfallRunAtLogin {
    Test-Path (Get-NightfallStartupShortcutPath)
}

function Set-NightfallRunAtLogin {
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled,
        [string]$ExePath = $null
    )
    $lnk = Get-NightfallStartupShortcutPath
    if (-not $Enabled) {
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
        return
    }
    if (-not $ExePath) {
        $ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }
    if (-not (Test-Path $ExePath)) { throw "Exe not found: $ExePath" }
    $wsh = New-Object -ComObject WScript.Shell
    $s = $wsh.CreateShortcut($lnk)
    $s.TargetPath = $ExePath
    $s.WorkingDirectory = Split-Path $ExePath -Parent
    $s.Description = 'Nightfall bedtime countdown'
    $icon = Join-Path (Split-Path $ExePath -Parent) 'Nightfall.ico'
    if (Test-Path $icon) { $s.IconLocation = "$icon,0" }
    $s.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
}

function Get-NightfallSettings {
    $s = Get-NightfallDefaultSettings
    if (-not (Test-Path $script:SettingsDir)) {
        New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
    }
    if (Test-Path $script:SettingsPath) {
        try {
            $j = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
            foreach ($k in $s.Keys) {
                if ($null -eq $j.$k) { continue }
                $v = $j.$k
                if ($s[$k] -is [bool]) { $s[$k] = [bool]$v }
                else { $s[$k] = $v }
            }
            if ($j.RestartInstead -eq $true -and -not $j.Action) { $s.Action = 'Restart' }
        } catch { }
    }
    if ($script:Channel -eq 'Release') { $s.DryRun = $false }
    if (Test-NightfallDryRun) { $s.DryRun = $true }
    return $s
}

function Save-NightfallSettings {
    param([hashtable]$Settings)
    if (-not (Test-Path $script:SettingsDir)) {
        New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
    }
    $Settings | ConvertTo-Json | Set-Content $script:SettingsPath -Encoding UTF8
}

function Invoke-NightfallPowerAction {
    param(
        [ValidateSet('Shutdown', 'Restart', 'Sleep')][string]$Action,
        [string]$Context = 'Timer finished'
    )
    if (Test-NightfallDryRun) {
        [System.Windows.Forms.MessageBox]::Show(
            "$Context`n`nDry run - no power action.`nWould have run: $Action",
            'Nightfall',
            'OK',
            'Information') | Out-Null
        return $false
    }
    switch ($Action) {
        'Sleep'   { & rundll32.exe powrprof.dll,SetSuspendState 0, 1, 0; break }
        'Restart' { Restart-Computer -Force; break }
        default   { Stop-Computer -Force }
    }
    return $true
}

function Publish-NightfallEvent {
    param(
        [ValidateSet('timer.start', 'timer.tick', 'timer.warning', 'timer.cancel', 'timer.cancelled', 'timer.complete', 'timer.completed', 'lights.out')]
        [string]$EventName,
        [hashtable]$Payload = @{},
        [switch]$Enabled
    )
    if (-not $Enabled) { return }
    if (-not (Test-Path $script:EventDir)) {
        New-Item -ItemType Directory -Path $script:EventDir -Force | Out-Null
    }
    $body = @{
        id         = [guid]::NewGuid().ToString()
        timestamp  = (Get-Date).ToUniversalTime().ToString('o')
        sourceApp  = 'Nightfall'
        eventName  = $EventName
        channel    = 'sleep'
        payload    = $Payload
        processed  = $false
    }
    $file = Join-Path $script:EventDir ("nightfall_{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $body | ConvertTo-Json -Depth 5 | Set-Content $file -Encoding UTF8
}

Export-ModuleMember -Function @(
    'Get-NightfallVersion'
    'Set-NightfallChannel'
    'Set-NightfallDryRun'
    'Test-NightfallDryRun'
    'Get-NightfallDefaultSettings'
    'Get-NightfallSettings'
    'Save-NightfallSettings'
    'Invoke-NightfallPowerAction'
    'Publish-NightfallEvent'
    'Get-NightfallInstallDir'
    'Test-NightfallRunAtLogin'
    'Set-NightfallRunAtLogin'
)
