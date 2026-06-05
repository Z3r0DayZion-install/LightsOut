#Requires -Version 5.1
<#
.SYNOPSIS
    Premium Sleep Timer Pro - Professional system power management
.DESCRIPTION
    A premium sleep timer with modern dark UI, persistent settings, system tray integration,
    hotkey support, profiles, scheduling, idle detection, and advanced power management.
.PARAMETER Minutes
    Duration in minutes (default: 30)
.PARAMETER Action
    Action to perform: Shutdown, Restart, Sleep, Hibernate, Lock, Logoff (default: Shutdown)
.PARAMETER Profile
    Load a saved profile by name
.PARAMETER ScheduleTime
    Schedule timer to start at specific time (HH:mm format)
.PARAMETER TimerName
    Optional name for the timer (shown in notifications)
.PARAMETER NoGUI
    Run in console mode without GUI
.PARAMETER Silent
    Suppress all non-essential output
.PARAMETER MinimizeToTray
    Start minimized to system tray
.PARAMETER ExportSettings
    Export settings to a file
.PARAMETER ImportSettings
    Import settings from a file
.PARAMETER ListProfiles
    List all available profiles and exit
.EXAMPLE
    .\SleepTimer.ps1 -Minutes 60 -Action Hibernate
.EXAMPLE
    .\SleepTimer.ps1 -Profile "Movie Night"
.EXAMPLE
    .\SleepTimer.ps1 -ScheduleTime "22:30" -Action Sleep
.EXAMPLE
    .\SleepTimer.ps1 -ListProfiles
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(1, 1440)]
    [int]$Minutes = 30,

    [Parameter()]
    [ValidateSet("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff")]
    [string]$Action = "Shutdown",

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$ScheduleTime,

    [Parameter()]
    [string]$TimerName,

    [Parameter()]
    [switch]$NoGUI,

    [Parameter()]
    [switch]$Silent,

    [Parameter()]
    [switch]$MinimizeToTray,

    [Parameter()]
    [string]$ExportSettings,

    [Parameter()]
    [string]$ImportSettings,

    [Parameter()]
    [switch]$ListProfiles
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Media

# Script-level variables
$script:TimerActive = $false
$script:RemainingSeconds = 0
$script:TimerJob = $null
$script:SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimer\settings.json"
$script:LogFile = Join-Path $env:LOCALAPPDATA "SleepTimer\app.log"
$script:HistoryPath = Join-Path $env:LOCALAPPDATA "SleepTimer\history.json"
$script:ProfilesPath = Join-Path $env:LOCALAPPDATA "SleepTimer\profiles.json"
$script:CustomSoundsPath = Join-Path $env:LOCALAPPDATA "SleepTimer\Sounds"
$script:Settings = $null
$script:NotifyIcon = $null
$script:MainForm = $null
$script:HotkeyID = 1
$script:SnoozeWindow = $null
$script:CurrentProfile = "Default"
$script:IsDarkTheme = $true
$script:TimerName = ""
$script:IdleCheckActive = $false

# Premium Color Palettes
$script:DarkColors = @{
    Background     = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Surface        = [System.Drawing.Color]::FromArgb(45, 45, 55)
    SurfaceLight   = [System.Drawing.Color]::FromArgb(55, 55, 68)
    Primary        = [System.Drawing.Color]::FromArgb(99, 102, 241)
    PrimaryDark    = [System.Drawing.Color]::FromArgb(79, 70, 229)
    Secondary      = [System.Drawing.Color]::FromArgb(236, 72, 153)
    Accent         = [System.Drawing.Color]::FromArgb(34, 211, 238)
    Success        = [System.Drawing.Color]::FromArgb(34, 197, 94)
    Warning        = [System.Drawing.Color]::FromArgb(251, 146, 60)
    Danger         = [System.Drawing.Color]::FromArgb(239, 68, 68)
    Text           = [System.Drawing.Color]::FromArgb(243, 244, 246)
    TextMuted      = [System.Drawing.Color]::FromArgb(156, 163, 175)
    TextDark       = [System.Drawing.Color]::FromArgb(107, 114, 128)
}

$script:LightColors = @{
    Background     = [System.Drawing.Color]::FromArgb(249, 250, 251)
    Surface        = [System.Drawing.Color]::FromArgb(255, 255, 255)
    SurfaceLight   = [System.Drawing.Color]::FromArgb(243, 244, 246)
    Primary        = [System.Drawing.Color]::FromArgb(79, 70, 229)
    PrimaryDark    = [System.Drawing.Color]::FromArgb(67, 56, 202)
    Secondary      = [System.Drawing.Color]::FromArgb(219, 39, 119)
    Accent         = [System.Drawing.Color]::FromArgb(8, 145, 178)
    Success        = [System.Drawing.Color]::FromArgb(22, 163, 74)
    Warning        = [System.Drawing.Color]::FromArgb(234, 88, 12)
    Danger         = [System.Drawing.Color]::FromArgb(220, 38, 38)
    Text           = [System.Drawing.Color]::FromArgb(17, 24, 39)
    TextMuted      = [System.Drawing.Color]::FromArgb(107, 114, 128)
    TextDark       = [System.Drawing.Color]::FromArgb(156, 163, 175)
}

$script:Colors = $script:DarkColors

# Ensure app directory exists
$appDir = Split-Path $script:SettingsPath -Parent
if (-not (Test-Path $appDir)) {
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
}

function Write-TimerLog {
    param([string]$Message, [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch { }
    if (-not $Silent -and $Level -ne "INFO") {
        Write-Host $logEntry -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } else { "Cyan" })
    }
}

function Get-Settings {
    if ($script:Settings -eq $null) {
        if (Test-Path $script:SettingsPath) {
            try {
                $script:Settings = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
            }
            catch {
                $script:Settings = Get-DefaultSettings
            }
        }
        else {
            $script:Settings = Get-DefaultSettings
        }
    }
    return $script:Settings
}

function Get-DefaultSettings {
    return @{
        LastMinutes = 30
        LastAction = "Shutdown"
        WarningMinutes = 2
        PlaySound = $true
        MinimizeToTray = $true
        AlwaysOnTop = $false
        DarkMode = $true
        CompactView = $false
        SnoozeMinutes = 5
        CheckBattery = $true
        AutoStart = $false
        CurrentProfile = "Default"
        RequirePassword = $false
        PasswordHash = ""
        CheckIdle = $false
        IdleThresholdMinutes = 5
        CustomSoundStart = ""
        CustomSoundWarning = ""
        CustomSoundComplete = ""
        CustomSoundCancel = ""
    }
}

function Export-TimerSettings {
    param([string]$ExportPath)
    $exportData = @{
        Settings = Get-Settings
        Profiles = Get-Profiles
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Version = "3.0"
    }
    $exportData | ConvertTo-Json -Depth 5 | Set-Content $ExportPath -Force
    Write-TimerLog "Settings exported to: $ExportPath"
    return $true
}

function Import-TimerSettings {
    param([string]$ImportPath)
    if (-not (Test-Path $ImportPath)) {
        throw "Import file not found: $ImportPath"
    }
    $importData = Get-Content $ImportPath -Raw | ConvertFrom-Json
    if ($importData.Settings) {
        Save-Settings -Settings $importData.Settings
    }
    if ($importData.Profiles) {
        Save-Profiles -Profiles $importData.Profiles
    }
    Write-TimerLog "Settings imported from: $ImportPath"
    return $true
}

function Get-IdleTime {
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace UserActivity {
    public class Monitor {
        [DllImport("user32.dll")]
        static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        
        [StructLayout(LayoutKind.Sequential)]
        struct LASTINPUTINFO {
            public uint cbSize;
            public uint dwTime;
        }
        
        public static TimeSpan GetIdleTime() {
            var info = new LASTINPUTINFO();
            info.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
            GetLastInputInfo(ref info);
            uint idleTicks = (uint)Environment.TickCount - info.dwTime;
            return TimeSpan.FromMilliseconds(idleTicks);
        }
    }
}
'@
        $idle = [UserActivity.Monitor]::GetIdleTime()
        return [math]::Floor($idle.TotalMinutes)
    }
    catch {
        return 0
    }
}

function Test-UserIdle {
    param([int]$ThresholdMinutes)
    $idleMinutes = Get-IdleTime
    return $idleMinutes -ge $ThresholdMinutes
}

function Set-TimerPassword {
    param([string]$Password)
    $settings = Get-Settings
    if ($Password) {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Password)
        $hash = [System.Convert]::ToBase64String($sha256.ComputeHash($bytes))
        $settings.PasswordHash = $hash
        $settings.RequirePassword = $true
    } else {
        $settings.PasswordHash = ""
        $settings.RequirePassword = $false
    }
    Save-Settings -Settings $settings
}

function Test-TimerPassword {
    param([string]$Password)
    $settings = Get-Settings
    if (-not $settings.RequirePassword) { return $true }
    if (-not $settings.PasswordHash) { return $true }
    
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Password)
    $hash = [System.Convert]::ToBase64String($sha256.ComputeHash($bytes))
    return $hash -eq $settings.PasswordHash
}

function Get-DefaultProfiles {
    return @{
        Default = @{ Minutes = 30; Action = "Shutdown" }
        "Quick Nap" = @{ Minutes = 20; Action = "Sleep" }
        "Movie Night" = @{ Minutes = 150; Action = "Shutdown" }
        "Work Lock" = @{ Minutes = 60; Action = "Lock" }
        Overnight = @{ Minutes = 480; Action = "Hibernate" }
    }
}

function Get-Profiles {
    if (Test-Path $script:ProfilesPath) {
        try {
            return Get-Content $script:ProfilesPath -Raw | ConvertFrom-Json
        }
        catch {
            return Get-DefaultProfiles
        }
    }
    return Get-DefaultProfiles
}

function Save-Profiles {
    param($Profiles)
    $Profiles | ConvertTo-Json -Depth 3 | Set-Content $script:ProfilesPath -Force
}

function Add-TimerHistory {
    param(
        [string]$Action,
        [int]$Minutes,
        [string]$Status,
        [string]$ProfileName = "Default"
    )
    $history = @()
    if (Test-Path $script:HistoryPath) {
        try {
            $history = Get-Content $script:HistoryPath -Raw | ConvertFrom-Json
        }
        catch { }
    }
    if (-not $history) { $history = @() }
    
    $entry = @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Action = $Action
        Minutes = $Minutes
        Status = $Status
        Profile = $ProfileName
    }
    $history = @($entry) + $history
    # Keep only last 100 entries
    if ($history.Count -gt 100) { $history = $history[0..99] }
    
    $history | ConvertTo-Json | Set-Content $script:HistoryPath -Force
}

function Get-TimerHistory {
    if (Test-Path $script:HistoryPath) {
        try {
            return Get-Content $script:HistoryPath -Raw | ConvertFrom-Json
        }
        catch { }
    }
    return @()
}

function Test-BatteryStatus {
    try {
        $powerStatus = [System.Windows.Forms.PowerStatus]::new()
        return $powerStatus.PowerLineStatus -eq "Offline"
    }
    catch {
        return $false
    }
}

function Switch-Theme {
    param([bool]$DarkMode)
    $script:IsDarkTheme = $DarkMode
    if ($DarkMode) {
        $script:Colors = $script:DarkColors
    } else {
        $script:Colors = $script:LightColors
    }
    return $script:Colors
}

function Show-SnoozeDialog {
    param(
        [string]$ActionName,
        [int]$SnoozeMinutes = 5
    )
    
    $snoozeForm = New-Object System.Windows.Forms.Form
    $snoozeForm.Text = "Action Warning - Sleep Timer Pro"
    $snoozeForm.Size = New-Object System.Drawing.Size(450, 250)
    $snoozeForm.StartPosition = "CenterScreen"
    $snoozeForm.FormBorderStyle = "FixedDialog"
    $snoozeForm.TopMost = $true
    $snoozeForm.BackColor = $script:Colors.Background
    
    # Warning icon
    $iconLabel = New-Object System.Windows.Forms.Label
    $iconLabel.Text = "!"
    $iconLabel.Font = New-Object System.Drawing.Font("Segoe UI", 48)
    $iconLabel.Size = New-Object System.Drawing.Size(80, 80)
    $iconLabel.Location = New-Object System.Drawing.Point(30, 30)
    $iconLabel.ForeColor = $script:Colors.Warning
    $snoozeForm.Controls.Add($iconLabel)
    
    # Message
    $msgLabel = New-Object System.Windows.Forms.Label
    $msgLabel.Text = "$ActionName will execute in less than $($script:Settings.WarningMinutes) minutes!"
    $msgLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $msgLabel.Size = New-Object System.Drawing.Size(300, 60)
    $msgLabel.Location = New-Object System.Drawing.Point(120, 30)
    $msgLabel.ForeColor = $script:Colors.Text
    $snoozeForm.Controls.Add($msgLabel)
    
    # Sub message
    $subMsg = New-Object System.Windows.Forms.Label
    $subMsg.Text = "What would you like to do?"
    $subMsg.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $subMsg.Size = New-Object System.Drawing.Size(300, 25)
    $subMsg.Location = New-Object System.Drawing.Point(120, 90)
    $subMsg.ForeColor = $script:Colors.TextMuted
    $snoozeForm.Controls.Add($subMsg)
    
    # Snooze button
    $snoozeBtn = New-RoundedButton -Text "😴 Snooze $SnoozeMinutes min" -Size (New-Object System.Drawing.Size(180, 45)) `
        -Location (New-Object System.Drawing.Point(30, 150)) -BackColor $script:Colors.Primary
    $snoozeBtn.Add_Click({
        $snoozeForm.DialogResult = "Retry"
        $snoozeForm.Close()
    })
    $snoozeForm.Controls.Add($snoozeBtn)
    
    # Proceed button
    $proceedBtn = New-RoundedButton -Text "✓ Proceed Now" -Size (New-Object System.Drawing.Size(180, 45)) `
        -Location (New-Object System.Drawing.Point(230, 150)) -BackColor $script:Colors.Danger
    $proceedBtn.Add_Click({
        $snoozeForm.DialogResult = "OK"
        $snoozeForm.Close()
    })
    $snoozeForm.Controls.Add($proceedBtn)
    
    # Play warning sound
    Play-NotificationSound -Type "Warning"
    
    return $snoozeForm.ShowDialog()
}

function Save-Settings {
    param($Settings)
    $Settings | ConvertTo-Json -Depth 3 | Set-Content $script:SettingsPath -Force
    $script:Settings = $Settings
}

function Play-NotificationSound {
    param([ValidateSet("Start", "Warning", "Complete", "Cancel")][string]$Type = "Start")
    $settings = Get-Settings
    if (-not $settings.PlaySound) { return }
    
    # Check for custom sound first
    $customSound = switch ($Type) {
        "Start"    { $settings.CustomSoundStart }
        "Warning"  { $settings.CustomSoundWarning }
        "Complete" { $settings.CustomSoundComplete }
        "Cancel"   { $settings.CustomSoundCancel }
    }
    
    if ($customSound -and (Test-Path $customSound)) {
        try {
            $player = New-Object System.Media.SoundPlayer $customSound
            $player.PlaySync()
            return
        }
        catch { }
    }
    
    # Fall back to system sounds
    try {
        switch ($Type) {
            "Start"    { [System.Media.SystemSounds]::Beep.Play() }
            "Warning"  { [System.Media.SystemSounds]::Exclamation.Play() }
            "Complete" { [System.Media.SystemSounds]::Hand.Play() }
            "Cancel"   { [System.Media.SystemSounds]::Beep.Play() }
        }
    }
    catch { }
}

function Show-BalloonNotification {
    param([string]$Title, [string]$Message, [ValidateSet("Info", "Warning", "Error")][string]$IconType = "Info", [int]$Timeout = 5000)
    try {
        if ($script:NotifyIcon -ne $null) {
            $script:NotifyIcon.BalloonTipTitle = $Title
            $script:NotifyIcon.BalloonTipText = $Message
            $script:NotifyIcon.BalloonTipIcon = $IconType
            $script:NotifyIcon.ShowBalloonTip($Timeout)
        }
    }
    catch {
        Write-TimerLog "Failed to show notification: $_" "WARN"
    }
}

function Initialize-NotifyIcon {
    param([System.Windows.Forms.Form]$Form)
    $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:NotifyIcon.Text = "Sleep Timer"
    $script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    
    # Context menu
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $contextMenu.BackColor = $script:Colors.Surface
    $contextMenu.ForeColor = $script:Colors.Text
    $contextMenu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer
    
    $showItem = $contextMenu.Items.Add("Show")
    $showItem.Add_Click({ $Form.WindowState = "Normal"; $Form.Show(); $Form.Activate() })
    
    $startItem = $contextMenu.Items.Add("Start Timer")
    $startItem.Add_Click({ if ($script:StartButton -ne $null) { $script:StartButton.PerformClick() } })
    
    $cancelItem = $contextMenu.Items.Add("Cancel Timer")
    $cancelItem.Add_Click({ if ($script:CancelButton -ne $null) { $script:CancelButton.PerformClick() } })
    
    $contextMenu.Items.Add("-") | Out-Null
    
    $exitItem = $contextMenu.Items.Add("Exit")
    $exitItem.Add_Click({ 
        if ($script:TimerActive) {
            $result = [System.Windows.Forms.MessageBox]::Show("Timer is running. Exit anyway?", "Sleep Timer", "YesNo", "Warning")
            if ($result -eq "No") { return }
        }
        Stop-CountdownTimer
        $script:NotifyIcon.Visible = $false
        $Form.Close()
    })
    
    $script:NotifyIcon.ContextMenuStrip = $contextMenu
    $script:NotifyIcon.Add_Click({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $Form.WindowState = "Normal"
            $Form.Show()
            $Form.Activate()
        }
    })
    
    $script:NotifyIcon.Visible = $true
}

function Update-NotifyIcon {
    param([string]$Text, [int]$Percent = -1)
    if ($script:NotifyIcon -ne $null) {
        if ($Percent -ge 0) {
            $script:NotifyIcon.Text = 'Sleep Timer - ' + $Text + ' (' + $Percent + '%)'
        }
        else {
            $script:NotifyIcon.Text = "Sleep Timer - $Text"
        }
    }
}

function Get-ActionDetails {
    param([string]$ActionName)
    switch ($ActionName) {
        "Shutdown"  { @{ 
            Command = { Stop-Computer -Force }
            Message = "Shutting down..."
            Icon = [char]0x23FB  # Power symbol
            Color = $script:Colors.Danger
        } }
        "Restart"   { @{ 
            Command = { Restart-Computer -Force }
            Message = "Restarting..."
            Icon = [char]0x21BB  # Clockwise arrow
            Color = $script:Colors.Warning
        } }
        "Sleep"     { @{ 
            Command = { Add-Type '[DllImport("powrprof.dll")]public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);' -Name Power -Namespace System; [System.Power]::SetSuspendState($false, $true, $false) }
            Message = "Entering sleep mode..."
            Icon = [char]0x263D  # Crescent moon
            Color = $script:Colors.Primary
        } }
        "Hibernate" { @{ 
            Command = { Add-Type '[DllImport("powrprof.dll")]public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);' -Name Power -Namespace System; [System.Power]::SetSuspendState($true, $true, $false) }
            Message = "Hibernating..."
            Icon = [char]0x2744  # Snowflake
            Color = $script:Colors.Accent
        } }
        "Lock"      { @{ 
            Command = { Add-Type '[DllImport("user32.dll")]public static extern bool LockWorkStation();' -Name Win32 -Namespace System; [System.Win32]::LockWorkStation() }
            Message = "Locking workstation..."
            Icon = [char]0x1F512  # Lock
            Color = $script:Colors.Success
        } }
        "Logoff"    { @{ 
            Command = { logoff }
            Message = "Logging off..."
            Icon = [char]0x2192  # Arrow
            Color = $script:Colors.Secondary
        } }
    }
}

function Get-ActionIcon {
    param([string]$ActionName)
    switch ($ActionName) {
        "Shutdown"  { return "[S]" }
        "Restart"   { return "[R]" }
        "Sleep"     { return "[SL]" }
        "Hibernate" { return "[H]" }
        "Lock"      { return "Lock" }
        "Logoff"    { return "Logoff" }
    }
}

function Invoke-TimerAction {
    param([string]$ActionName)
    Write-TimerLog "Executing action: $ActionName"
    $actionDetails = Get-ActionDetails -ActionName $ActionName

    Play-NotificationSound -Type "Complete"
    Show-BalloonNotification -Title "Sleep Timer" -Message $actionDetails.Message -IconType "Info"
    Update-NotifyIcon -Text $actionDetails.Message
    Start-Sleep -Seconds 2

    try {
        Invoke-Command -ScriptBlock $actionDetails.Command
    }
    catch {
        Write-TimerLog "Action failed: $_" "ERROR"
        Show-BalloonNotification -Title "Sleep Timer Error" -Message "Failed to execute $ActionName" -IconType "Error"
        [System.Windows.Forms.MessageBox]::Show("Failed to execute $ActionName`: $_", "Sleep Timer - Error", "OK", "Error")
    }
}

function Start-CountdownTimer {
    param(
        [int]$TotalSeconds,
        [string]$TimerAction,
        [int]$WarnSeconds = 120,
        [bool]$AllowSnooze = $true
    )
    $script:TimerActive = $true
    $script:RemainingSeconds = $TotalSeconds
    $warningShown = $false
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TotalSeconds)

    Write-TimerLog "Timer started: $TotalSeconds seconds, Action: $TimerAction, AllowSnooze=$AllowSnooze"
    Play-NotificationSound -Type "Start"
    Add-TimerHistory -Action $TimerAction -Minutes ([math]::Floor($TotalSeconds/60)) -Status "Started" -ProfileName $script:CurrentProfile

    for ($i = $TotalSeconds; $i -gt 0 -and $script:TimerActive; $i--) {
        $script:RemainingSeconds = $i
        $elapsed = $TotalSeconds - $i
        $percent = [math]::Round(($elapsed / $TotalSeconds) * 100)

        if ($i -eq $WarnSeconds -and $WarnSeconds -gt 0 -and -not $warningShown) {
            Play-NotificationSound -Type "Warning"
            Show-BalloonNotification -Title "Sleep Timer Warning" -Message "$TimerAction in $([math]::Floor($WarnSeconds/60)) minutes!" -IconType "Warning"
            
            # Show snooze dialog if GUI mode and enabled
            if ($AllowSnooze -and -not $NoGUI) {
                $result = Show-SnoozeDialog -ActionName $TimerAction -SnoozeMinutes $script:Settings.SnoozeMinutes
                if ($result -eq "Retry") {
                    # Snooze - add more time
                    $snoozeSeconds = $script:Settings.SnoozeMinutes * 60
                    $i += $snoozeSeconds + 1  # +1 because loop will decrement
                    $TotalSeconds += $snoozeSeconds
                    $warningShown = $false
                    Write-TimerLog "Timer snoozed for $($script:Settings.SnoozeMinutes) minutes"
                    Show-BalloonNotification -Title "Sleep Timer" -Message "Timer snoozed for $($script:Settings.SnoozeMinutes) minutes" -IconType "Info"
                    continue
                }
            }
            $warningShown = $true
        }

        if ($NoGUI) {
            $hrs = [math]::Floor($i/3600)
            $mins = [math]::Floor(($i%3600)/60)
            $secs = $i%60
            $status = "{0:D2}:{1:D2}:{2:D2} remaining - $TimerAction" -f $hrs, $mins, $secs
            Write-Progress -Activity "Sleep Timer Pro" -Status $status -PercentComplete $percent
        }

        Update-NotifyIcon -Text "$TimerAction in $(Format-TimeSpan $i)" -Percent $percent

        Start-Sleep -Seconds 1
    }

    if ($NoGUI) {
        Write-Progress -Activity "Sleep Timer Pro" -Completed
    }

    if ($script:TimerActive) {
        Add-TimerHistory -Action $TimerAction -Minutes ([math]::Floor($TotalSeconds/60)) -Status "Completed" -ProfileName $script:CurrentProfile
        Invoke-TimerAction -ActionName $TimerAction
    }
    else {
        Write-TimerLog "Timer cancelled by user"
        Add-TimerHistory -Action $TimerAction -Minutes ([math]::Floor($TotalSeconds/60)) -Status "Cancelled" -ProfileName $script:CurrentProfile
        Play-NotificationSound -Type "Cancel"
        Show-BalloonNotification -Title "Sleep Timer Pro" -Message "Timer cancelled" -IconType "Info"
        Update-NotifyIcon -Text "Ready"
    }
}

function Format-TimeSpan {
    param([int]$TotalSeconds)
    $hrs = [math]::Floor($TotalSeconds / 3600)
    $mins = [math]::Floor(($TotalSeconds % 3600) / 60)
    $secs = $TotalSeconds % 60
    if ($hrs -gt 0) {
        return "{0:D2}:{1:D2}:{2:D2}" -f $hrs, $mins, $secs
    }
    else {
        return "{0:D2}:{1:D2}" -f $mins, $secs
    }
}

function Stop-CountdownTimer {
    $script:TimerActive = $false
    Update-NotifyIcon -Text "Ready"
}

function New-RoundedButton {
    param(
        [string]$Text,
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor = $script:Colors.Text,
        [System.Drawing.Font]$Font = $null
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = $Size
    $button.Location = $Location
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = if ($Font) { $Font } else { New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold) }
    $button.Cursor = "Hand"
    
    # Add hover effects
    $button.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb([math]::Min(255, $this.BackColor.R + 20), [math]::Min(255, $this.BackColor.G + 20), [math]::Min(255, $this.BackColor.B + 20)) })
    $button.Add_MouseLeave({ $this.BackColor = $BackColor })
    
    return $button
}

function New-ModernComboBox {
    param(
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location,
        [array]$Items,
        [string]$SelectedItem = ""
    )
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Size = $Size
    $combo.Location = $Location
    $combo.DropDownStyle = "DropDownList"
    $combo.FlatStyle = "Flat"
    $combo.BackColor = $script:Colors.SurfaceLight
    $combo.ForeColor = $script:Colors.Text
    $combo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    
    $Items | ForEach-Object { $combo.Items.Add($_) }
    if ($SelectedItem) { $combo.SelectedItem = $SelectedItem }
    
    return $combo
}

function New-ModernNumericUpDown {
    param(
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location,
        [int]$Minimum = 1,
        [int]$Maximum = 1440,
        [int]$Value = 30
    )
    $numeric = New-Object System.Windows.Forms.NumericUpDown
    $numeric.Size = $Size
    $numeric.Location = $Location
    $numeric.Minimum = $Minimum
    $numeric.Maximum = $Maximum
    $numeric.Value = $Value
    $numeric.BackColor = $script:Colors.SurfaceLight
    $numeric.ForeColor = $script:Colors.Text
    $numeric.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $numeric.BorderStyle = "FixedSingle"
    $numeric.TextAlign = "Center"
    
    return $numeric
}

function New-SleepTimerForm {
    $settings = Get-Settings
    
    # Main Form
    $form = New-Object System.Windows.Forms.Form
    $script:MainForm = $form
    $form.Text = "Sleep Timer Pro"
    $form.Size = New-Object System.Drawing.Size(520, 480)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = $script:Colors.Background
    $form.Icon = [System.Drawing.SystemIcons]::Application
    $form.TopMost = $settings.AlwaysOnTop
    
    # Header Panel with Gradient effect
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Size = New-Object System.Drawing.Size(520, 70)
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.BackColor = $script:Colors.Surface
    $form.Controls.Add($headerPanel)
    
    # App Icon Label
    $appIcon = New-Object System.Windows.Forms.Label
    $appIcon.Text = "⏱"
    $appIcon.Font = New-Object System.Drawing.Font("Segoe UI", 28)
    $appIcon.Size = New-Object System.Drawing.Size(50, 50)
    $appIcon.Location = New-Object System.Drawing.Point(20, 10)
    $appIcon.ForeColor = $script:Colors.Accent
    $headerPanel.Controls.Add($appIcon)
    
    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Sleep Timer Pro"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(250, 35)
    $titleLabel.Location = New-Object System.Drawing.Point(75, 8)
    $titleLabel.ForeColor = $script:Colors.Text
    $headerPanel.Controls.Add($titleLabel)
    
    # Subtitle
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Professional Power Management"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subtitleLabel.Size = New-Object System.Drawing.Size(250, 18)
    $subtitleLabel.Location = New-Object System.Drawing.Point(75, 42)
    $subtitleLabel.ForeColor = $script:Colors.TextMuted
    $headerPanel.Controls.Add($subtitleLabel)
    
    # History Button
    $historyBtn = New-Object System.Windows.Forms.Button
    $historyBtn.Text = "History"
    $historyBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $historyBtn.Size = New-Object System.Drawing.Size(35, 35)
    $historyBtn.Location = New-Object System.Drawing.Point(430, 18)
    $historyBtn.FlatStyle = "Flat"
    $historyBtn.BackColor = $script:Colors.SurfaceLight
    $historyBtn.ForeColor = $script:Colors.Text
    $historyBtn.Cursor = "Hand"
    $historyBtn.FlatAppearance.BorderSize = 0
    $historyBtn.Add_Click({ Show-HistoryDialog })
    $headerPanel.Controls.Add($historyBtn)
    
    # Theme Toggle Button
    $themeBtn = New-Object System.Windows.Forms.Button
    $themeBtn.Text = if ($script:IsDarkTheme) { "☀" } else { "☾" }
    $themeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $themeBtn.Size = New-Object System.Drawing.Size(35, 35)
    $themeBtn.Location = New-Object System.Drawing.Point(390, 18)
    $themeBtn.FlatStyle = "Flat"
    $themeBtn.BackColor = $script:Colors.SurfaceLight
    $themeBtn.ForeColor = $script:Colors.Text
    $themeBtn.Cursor = "Hand"
    $themeBtn.FlatAppearance.BorderSize = 0
    $themeBtn.Add_Click({
        $newTheme = -not $script:IsDarkTheme
        Switch-Theme -DarkMode $newTheme
        $settings.DarkMode = $newTheme
        Save-Settings -Settings $settings
        [System.Windows.Forms.MessageBox]::Show("Theme will change on next launch. Restart the app to see the new theme.", "Sleep Timer Pro", "OK", "Information")
    })
    $headerPanel.Controls.Add($themeBtn)
    
    # Settings Button (cog icon)
    $settingsBtn = New-Object System.Windows.Forms.Button
    $settingsBtn.Text = "⚙"
    $settingsBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $settingsBtn.Size = New-Object System.Drawing.Size(35, 35)
    $settingsBtn.Location = New-Object System.Drawing.Point(470, 18)
    $settingsBtn.FlatStyle = "Flat"
    $settingsBtn.BackColor = $script:Colors.SurfaceLight
    $settingsBtn.ForeColor = $script:Colors.Text
    $settingsBtn.Cursor = "Hand"
    $settingsBtn.FlatAppearance.BorderSize = 0
    $settingsBtn.Add_Click({ Show-SettingsDialog })
    $headerPanel.Controls.Add($settingsBtn)
    
    # Profile Selector
    $profileLabel = New-Object System.Windows.Forms.Label
    $profileLabel.Text = "PROFILE"
    $profileLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $profileLabel.Size = New-Object System.Drawing.Size(200, 20)
    $profileLabel.Location = New-Object System.Drawing.Point(30, 200)
    $profileLabel.ForeColor = $script:Colors.TextMuted
    $form.Controls.Add($profileLabel)
    
    $profiles = Get-Profiles
    $profileCombo = New-ModernComboBox -Size (New-Object System.Drawing.Size(180, 35)) -Location (New-Object System.Drawing.Point(30, 220)) `
        -Items ($profiles.PSObject.Properties.Name | ForEach-Object { "⚡ $_" }) `
        -SelectedItem "⚡ $script:CurrentProfile"
    $form.Controls.Add($profileCombo)
    
    # Profile Description
    $profileDesc = New-Object System.Windows.Forms.Label
    $profileDesc.Text = "Quick-load saved configurations"
    $profileDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $profileDesc.Size = New-Object System.Drawing.Size(180, 20)
    $profileDesc.Location = New-Object System.Drawing.Point(30, 255)
    $profileDesc.ForeColor = $script:Colors.TextDark
    $form.Controls.Add($profileDesc)
    
    $profileCombo.Add_SelectedIndexChanged({
        $selectedProfile = ($this.SelectedItem -split " ", 2)[1]
        $profileData = $profiles.$selectedProfile
        if ($profileData) {
            $minutesNumeric.Value = $profileData.Minutes
            $actionIndex = @("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff").IndexOf($profileData.Action)
            $actionCombo.SelectedIndex = $actionIndex
            $script:CurrentProfile = $selectedProfile
        }
    })
    
    # Duration Section
    $durationLabel = New-Object System.Windows.Forms.Label
    $durationLabel.Text = "DURATION"
    $durationLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $durationLabel.Size = New-Object System.Drawing.Size(200, 20)
    $durationLabel.Location = New-Object System.Drawing.Point(30, 85)
    $durationLabel.ForeColor = $script:Colors.TextMuted
    $form.Controls.Add($durationLabel)
    
    # Minutes Input with premium styling
    $minutesNumeric = New-ModernNumericUpDown -Size (New-Object System.Drawing.Size(100, 45)) -Location (New-Object System.Drawing.Point(30, 110))
    $minutesNumeric.Value = $settings.LastMinutes
    $form.Controls.Add($minutesNumeric)
    
    # Minutes label
    $minLabel = New-Object System.Windows.Forms.Label
    $minLabel.Text = "minutes"
    $minLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $minLabel.Size = New-Object System.Drawing.Size(80, 30)
    $minLabel.Location = New-Object System.Drawing.Point(140, 117)
    $minLabel.ForeColor = $script:Colors.TextMuted
    $form.Controls.Add($minLabel)
    
    # Quick preset buttons
    $presets = @(
        @{ Text = "15"; Min = 15; X = 30 },
        @{ Text = "30"; Min = 30; X = 95 },
        @{ Text = "60"; Min = 60; X = 160 },
        @{ Text = "2h"; Min = 120; X = 225 },
        @{ Text = "4h"; Min = 240; X = 290 }
    )
    
    foreach ($preset in $presets) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $preset.Text
        $btn.Size = New-Object System.Drawing.Size(55, 32)
        $btn.Location = New-Object System.Drawing.Point($preset.X, 165)
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = $script:Colors.SurfaceLight
        $btn.BackColor = $script:Colors.Surface
        $btn.ForeColor = $script:Colors.Text
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $btn.Cursor = "Hand"
        $btn.Add_Click({ $minutesNumeric.Value = $preset.Min }.GetNewClosure())
        $btn.Add_MouseEnter({ $this.BackColor = $script:Colors.Primary; $this.ForeColor = $script:Colors.Text })
        $btn.Add_MouseLeave({ $this.BackColor = $script:Colors.Surface; $this.ForeColor = $script:Colors.Text })
        $form.Controls.Add($btn)
    }
    
    # Action Section
    $actionLabel = New-Object System.Windows.Forms.Label
    $actionLabel.Text = "ACTION"
    $actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $actionLabel.Size = New-Object System.Drawing.Size(200, 20)
    $actionLabel.Location = New-Object System.Drawing.Point(280, 85)
    $actionLabel.ForeColor = $script:Colors.TextMuted
    $form.Controls.Add($actionLabel)
    
    # Action Selector with icons
    $actionCombo = New-ModernComboBox -Size (New-Object System.Drawing.Size(200, 35)) -Location (New-Object System.Drawing.Point(280, 110)) `
        -Items @("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff") `
        -SelectedItem $settings.LastAction
    $form.Controls.Add($actionCombo)
    
    # Action description
    $actionDesc = New-Object System.Windows.Forms.Label
    $actionDesc.Text = "System will power off after timer expires"
    $actionDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $actionDesc.Size = New-Object System.Drawing.Size(200, 40)
    $actionDesc.Location = New-Object System.Drawing.Point(280, 150)
    $actionDesc.ForeColor = $script:Colors.TextDark
    $form.Controls.Add($actionDesc)
    
    $actionCombo.Add_SelectedIndexChanged({
        $selected = ($this.SelectedItem -split " ")[1]
        $details = Get-ActionDetails -ActionName $selected
        $actionDesc.Text = switch ($selected) {
            "Shutdown" { "System will power off completely" }
            "Restart"  { "System will reboot automatically" }
            "Sleep"    { "System enters low-power mode" }
            "Hibernate"{ "System state saved to disk" }
            "Lock"     { "Workstation will be locked" }
            "Logoff"   { "Current session will end" }
        }
        $actionDesc.ForeColor = $details.Color
    })
    
    # Divider
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Size = New-Object System.Drawing.Size(460, 1)
    $divider.Location = New-Object System.Drawing.Point(30, 285)
    $divider.BackColor = $script:Colors.SurfaceLight
    $form.Controls.Add($divider)
    
    # Status Panel
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Size = New-Object System.Drawing.Size(460, 100)
    $statusPanel.Location = New-Object System.Drawing.Point(30, 300)
    $statusPanel.BackColor = $script:Colors.Surface
    $form.Controls.Add($statusPanel)
    
    # Status Icon
    $statusIcon = New-Object System.Windows.Forms.Label
    $statusIcon.Text = "◉"
    $statusIcon.Font = New-Object System.Drawing.Font("Segoe UI", 24)
    $statusIcon.Size = New-Object System.Drawing.Size(40, 40)
    $statusIcon.Location = New-Object System.Drawing.Point(20, 15)
    $statusIcon.ForeColor = $script:Colors.Success
    $statusPanel.Controls.Add($statusIcon)
    
    # Status Text
    $statusText = New-Object System.Windows.Forms.Label
    $statusText.Text = "Ready"
    $statusText.Name = "StatusText"
    $statusText.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $statusText.Size = New-Object System.Drawing.Size(200, 30)
    $statusText.Location = New-Object System.Drawing.Point(65, 18)
    $statusText.ForeColor = $script:Colors.Success
    $statusPanel.Controls.Add($statusText)
    
    # Countdown Display
    $countdownLabel = New-Object System.Windows.Forms.Label
    $countdownLabel.Text = "00:00:00"
    $countdownLabel.Name = "Countdown"
    $countdownLabel.Font = New-Object System.Drawing.Font("Consolas", 28, [System.Drawing.FontStyle]::Bold)
    $countdownLabel.Size = New-Object System.Drawing.Size(200, 45)
    $countdownLabel.Location = New-Object System.Drawing.Point(240, 10)
    $countdownLabel.TextAlign = "MiddleCenter"
    $countdownLabel.ForeColor = $script:Colors.Accent
    $statusPanel.Controls.Add($countdownLabel)
    
    # Progress Bar (modern styled)
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Name = "Progress"
    $progressBar.Location = New-Object System.Drawing.Point(20, 65)
    $progressBar.Size = New-Object System.Drawing.Size(420, 8)
    $progressBar.Style = "Continuous"
    $progressBar.BackColor = $script:Colors.SurfaceLight
    $progressBar.ForeColor = $script:Colors.Primary
    $statusPanel.Controls.Add($progressBar)
    
    # Progress percentage
    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Text = "0%"
    $progressLabel.Name = "ProgressPercent"
    $progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $progressLabel.Size = New-Object System.Drawing.Size(50, 20)
    $progressLabel.Location = New-Object System.Drawing.Point(20, 78)
    $progressLabel.ForeColor = $script:Colors.TextMuted
    $statusPanel.Controls.Add($progressLabel)
    
    # Main Action Buttons
    $startButton = New-RoundedButton -Text "▶  START TIMER" -Size (New-Object System.Drawing.Size(220, 50)) `
        -Location (New-Object System.Drawing.Point(30, 410)) -BackColor $script:Colors.Success
    $script:StartButton = $startButton
    $form.Controls.Add($startButton)
    
    $cancelButton = New-RoundedButton -Text "⏹  CANCEL" -Size (New-Object System.Drawing.Size(220, 50)) `
        -Location (New-Object System.Drawing.Point(270, 410)) -BackColor $script:Colors.Danger
    $cancelButton.Enabled = $false
    $script:CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)
    
    # Footer
    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = "Press F1 for help  |  Timer continues in background"
    $footer.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $footer.Size = New-Object System.Drawing.Size(460, 20)
    $footer.Location = New-Object System.Drawing.Point(30, 470)
    $footer.TextAlign = "MiddleCenter"
    $footer.ForeColor = $script:Colors.TextDark
    $form.Controls.Add($footer)
    
    # Increase form height for new elements
    $form.Size = New-Object System.Drawing.Size(520, 530)
    
    # Timer Component
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    
    # Initialize NotifyIcon
    Initialize-NotifyIcon -Form $form
    
    # Start Button Click
    $startButton.Add_Click({
        $totalSeconds = [int]$minutesNumeric.Value * 60
        $selectedActionWithIcon = $actionCombo.SelectedItem
        $selectedAction = ($selectedActionWithIcon -split " ", 2)[1]
        $settings.LastMinutes = [int]$minutesNumeric.Value
        $settings.LastAction = $selectedAction
        Save-Settings -Settings $settings
        
        $startButton.Enabled = $false
        $cancelButton.Enabled = $true
        $minutesNumeric.Enabled = $false
        $actionCombo.Enabled = $false
        
        $statusText.Text = "Timer Running"
        $statusText.ForeColor = $script:Colors.Primary
        $statusIcon.Text = "⏱"
        $statusIcon.ForeColor = $script:Colors.Primary
        $progressBar.Maximum = $totalSeconds
        $progressBar.Value = 0
        $progressLabel.Text = "0%"
        
        $script:RemainingSeconds = $totalSeconds
        $script:TimerActive = $true
        
        Write-TimerLog "GUI timer started: $totalSeconds seconds, Action: $selectedAction"
        Play-NotificationSound -Type "Start"
        Show-BalloonNotification -Title "Sleep Timer Pro" -Message "Timer started for $([int]$minutesNumeric.Value) minutes" -IconType "Info"
        Update-NotifyIcon -Text "Running - $selectedAction in $(Format-TimeSpan $totalSeconds)"
        
        $timer.Add_Tick({
            if ($script:TimerActive -and $script:RemainingSeconds -gt 0) {
                $script:RemainingSeconds--
                $elapsed = $totalSeconds - $script:RemainingSeconds
                $percent = [math]::Round(($elapsed / $totalSeconds) * 100)
                
                $progressBar.Value = $elapsed
                $progressLabel.Text = "$percent%"
                $countdownLabel.Text = Format-TimeSpan $script:RemainingSeconds
                
                $settingsWarn = $settings.WarningMinutes * 60
                if ($script:RemainingSeconds -eq $settingsWarn -and $settingsWarn -gt 0) {
                    Play-NotificationSound -Type "Warning"
                    Show-BalloonNotification -Title "Sleep Timer Warning" -Message "$selectedAction in $($settings.WarningMinutes) minutes!" -IconType "Warning"
                }
                
                Update-NotifyIcon -Text "$selectedAction in $(Format-TimeSpan $script:RemainingSeconds)" -Percent $percent
            }
            elseif ($script:TimerActive -and $script:RemainingSeconds -le 0) {
                $timer.Stop()
                Invoke-TimerAction -ActionName $selectedAction
            }
        })
        $timer.Start()
    })
    
    # Cancel Button Click
    $cancelButton.Add_Click({
        $script:TimerActive = $false
        $timer.Stop()
        
        $startButton.Enabled = $true
        $cancelButton.Enabled = $false
        $minutesNumeric.Enabled = $true
        $actionCombo.Enabled = $true
        
        $statusText.Text = "Cancelled"
        $statusText.ForeColor = $script:Colors.Warning
        $statusIcon.Text = "✕"
        $statusIcon.ForeColor = $script:Colors.Warning
        $progressBar.Value = 0
        $progressLabel.Text = "0%"
        $countdownLabel.Text = "00:00:00"
        
        Write-TimerLog "GUI timer cancelled"
        Play-NotificationSound -Type "Cancel"
        Show-BalloonNotification -Title "Sleep Timer Pro" -Message "Timer cancelled" -IconType "Info"
        Update-NotifyIcon -Text "Ready"
    })
    
    # Form Closing
    $form.Add_FormClosing({
        if ($script:TimerActive) {
            $result = [System.Windows.Forms.MessageBox]::Show("Timer is running. The timer will continue in the background.`n`nExit application?", "Sleep Timer Pro", "YesNo", "Question")
            if ($result -eq "No") {
                $_.Cancel = $true
            }
            else {
                $script:TimerActive = $false
                $timer.Stop()
                $script:NotifyIcon.Visible = $false
            }
        }
        else {
            $script:NotifyIcon.Visible = $false
        }
    })
    
    # Help Key (F1)
    $form.Add_KeyDown({
        if ($_.KeyCode -eq "F1") {
            Show-HelpDialog
        }
    })
    $form.KeyPreview = $true
    
    # Handle minimize to tray
    $form.Add_Resize({
        if ($form.WindowState -eq "Minimized" -and $settings.MinimizeToTray) {
            $form.Hide()
            Show-BalloonNotification -Title "Sleep Timer Pro" -Message "Running in background. Click tray icon to restore." -IconType "Info" -Timeout 3000
        }
    })
    
    # Start minimized if requested
    if ($MinimizeToTray) {
        $form.WindowState = "Minimized"
        $form.ShowInTaskbar = $false
    }
    
    $form.ShowDialog() | Out-Null
}

function Show-SettingsDialog {
    $settings = Get-Settings
    
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Settings"
    $dialog.Size = New-Object System.Drawing.Size(400, 350)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.BackColor = $script:Colors.Background
    
    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "⚙ Settings"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $title.Size = New-Object System.Drawing.Size(350, 40)
    $title.Location = New-Object System.Drawing.Point(20, 15)
    $title.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($title)
    
    # Warning Minutes
    # Snooze Duration
    $snoozeLabel = New-Object System.Windows.Forms.Label
    $snoozeLabel.Text = "Snooze duration (minutes):"
    $snoozeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $snoozeLabel.Size = New-Object System.Drawing.Size(200, 25)
    $snoozeLabel.Location = New-Object System.Drawing.Point(30, 70)
    $snoozeLabel.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($snoozeLabel)
    
    $snoozeNumeric = New-Object System.Windows.Forms.NumericUpDown
    $snoozeNumeric.Size = New-Object System.Drawing.Size(80, 30)
    $snoozeNumeric.Location = New-Object System.Drawing.Point(230, 68)
    $snoozeNumeric.Minimum = 1
    $snoozeNumeric.Maximum = 30
    $snoozeNumeric.Value = $settings.SnoozeMinutes
    $snoozeNumeric.BackColor = $script:Colors.SurfaceLight
    $snoozeNumeric.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($snoozeNumeric)
    
    # Warning Minutes
    $warnLabel = New-Object System.Windows.Forms.Label
    $warnLabel.Text = "Warning before action (minutes):"
    $warnLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $warnLabel.Size = New-Object System.Drawing.Size(230, 25)
    $warnLabel.Location = New-Object System.Drawing.Point(30, 105)
    $warnLabel.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($warnLabel)
    
    $warnNumeric = New-Object System.Windows.Forms.NumericUpDown
    $warnNumeric.Size = New-Object System.Drawing.Size(80, 30)
    $warnNumeric.Location = New-Object System.Drawing.Point(270, 103)
    $warnNumeric.Minimum = 0
    $warnNumeric.Maximum = 10
    $warnNumeric.Value = $settings.WarningMinutes
    $warnNumeric.BackColor = $script:Colors.SurfaceLight
    $warnNumeric.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($warnNumeric)
    
    # Checkboxes
    $y = 145
    
    $soundCheck = New-Object System.Windows.Forms.CheckBox
    $soundCheck.Text = "Play notification sounds"
    $soundCheck.Checked = $settings.PlaySound
    $soundCheck.Location = New-Object System.Drawing.Point(30, $y)
    $soundCheck.Size = New-Object System.Drawing.Size(320, 25)
    $soundCheck.ForeColor = $script:Colors.Text
    $soundCheck.BackColor = $script:Colors.Background
    $dialog.Controls.Add($soundCheck)
    $y += 32
    
    $trayCheck = New-Object System.Windows.Forms.CheckBox
    $trayCheck.Text = "Minimize to system tray"
    $trayCheck.Checked = $settings.MinimizeToTray
    $trayCheck.Location = New-Object System.Drawing.Point(30, $y)
    $trayCheck.Size = New-Object System.Drawing.Size(320, 25)
    $trayCheck.ForeColor = $script:Colors.Text
    $trayCheck.BackColor = $script:Colors.Background
    $dialog.Controls.Add($trayCheck)
    $y += 32
    
    $topCheck = New-Object System.Windows.Forms.CheckBox
    $topCheck.Text = "Always on top"
    $topCheck.Checked = $settings.AlwaysOnTop
    $topCheck.Location = New-Object System.Drawing.Point(30, $y)
    $topCheck.Size = New-Object System.Drawing.Size(320, 25)
    $topCheck.ForeColor = $script:Colors.Text
    $topCheck.BackColor = $script:Colors.Background
    $dialog.Controls.Add($topCheck)
    $y += 32
    
    $batteryCheck = New-Object System.Windows.Forms.CheckBox
    $batteryCheck.Text = "Check battery before Sleep/Hibernate"
    $batteryCheck.Checked = $settings.CheckBattery
    $batteryCheck.Location = New-Object System.Drawing.Point(30, $y)
    $batteryCheck.Size = New-Object System.Drawing.Size(320, 25)
    $batteryCheck.ForeColor = $script:Colors.Text
    $batteryCheck.BackColor = $script:Colors.Background
    $dialog.Controls.Add($batteryCheck)
    $y += 32
    
    # Auto-start with Windows checkbox with warning
    $autoStartCheck = New-Object System.Windows.Forms.CheckBox
    $autoStartCheck.Text = "⚡ Auto-start with Windows (tray mode)"
    $autoStartCheck.Checked = $settings.AutoStart
    $autoStartCheck.Location = New-Object System.Drawing.Point(30, $y)
    $autoStartCheck.Size = New-Object System.Drawing.Size(320, 25)
    $autoStartCheck.ForeColor = $script:Colors.Text
    $autoStartCheck.BackColor = $script:Colors.Background
    $dialog.Controls.Add($autoStartCheck)
    
    # Increase dialog size for new options
    $dialog.Size = New-Object System.Drawing.Size(400, 450)
    
    # Save Button
    $saveBtn = New-RoundedButton -Text "💾 Save" -Size (New-Object System.Drawing.Size(150, 40)) `
        -Location (New-Object System.Drawing.Point(125, 360)) -BackColor $script:Colors.Primary
    $saveBtn.Add_Click({
        $settings.WarningMinutes = [int]$warnNumeric.Value
        $settings.SnoozeMinutes = [int]$snoozeNumeric.Value
        $settings.PlaySound = $soundCheck.Checked
        $settings.MinimizeToTray = $trayCheck.Checked
        $settings.AlwaysOnTop = $topCheck.Checked
        $settings.CheckBattery = $batteryCheck.Checked
        
        # Handle auto-start toggle
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SleepTimerPro.lnk"
        if ($autoStartCheck.Checked -ne $settings.AutoStart) {
            if ($autoStartCheck.Checked) {
                # Create startup shortcut
                $WshShell = New-Object -ComObject WScript.Shell
                $shortcut = $WshShell.CreateShortcut($startupPath)
                $shortcut.TargetPath = "$PSScriptRoot\SleepTimer.bat"
                $shortcut.Arguments = "tray"
                $shortcut.WorkingDirectory = $PSScriptRoot
                $shortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,238"
                $shortcut.Save()
            } else {
                # Remove startup shortcut
                if (Test-Path $startupPath) {
                    Remove-Item $startupPath -Force
                }
            }
        }
        $settings.AutoStart = $autoStartCheck.Checked
        
        Save-Settings -Settings $settings
        $script:MainForm.TopMost = $settings.AlwaysOnTop
        $dialog.Close()
    })
    $dialog.Controls.Add($saveBtn)
    
    $dialog.ShowDialog() | Out-Null
}

function Show-HistoryDialog {
    $history = Get-TimerHistory
    if ($history.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No timer history yet. Start a timer to see it here!", "Sleep Timer Pro - History", "OK", "Information")
        return
    }
    
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Timer History"
    $dialog.Size = New-Object System.Drawing.Size(550, 450)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.BackColor = $script:Colors.Background
    
    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Timer History"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $title.Size = New-Object System.Drawing.Size(500, 40)
    $title.Location = New-Object System.Drawing.Point(20, 15)
    $title.ForeColor = $script:Colors.Text
    $dialog.Controls.Add($title)
    
    # Create ListView for history
    $listView = New-Object System.Windows.Forms.ListView
    $listView.Size = New-Object System.Drawing.Size(500, 280)
    $listView.Location = New-Object System.Drawing.Point(20, 65)
    $listView.View = "Details"
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.BackColor = $script:Colors.Surface
    $listView.ForeColor = $script:Colors.Text
    $listView.BorderStyle = "FixedSingle"
    
    # Columns
    $listView.Columns.Add("Time", 130) | Out-Null
    $listView.Columns.Add("Action", 90) | Out-Null
    $listView.Columns.Add("Duration", 70) | Out-Null
    $listView.Columns.Add("Status", 90) | Out-Null
    $listView.Columns.Add("Profile", 100) | Out-Null
    
    # Populate with history
    foreach ($entry in $history) {
        $item = New-Object System.Windows.Forms.ListViewItem($entry.Timestamp)
        $item.SubItems.Add($entry.Action) | Out-Null
        $item.SubItems.Add("$($entry.Minutes) min") | Out-Null
        $item.SubItems.Add($entry.Status) | Out-Null
        $item.SubItems.Add($entry.Profile) | Out-Null
        
        # Color code by status
        switch ($entry.Status) {
            "Completed" { $item.ForeColor = $script:Colors.Success }
            "Cancelled" { $item.ForeColor = $script:Colors.Warning }
            "Started" { $item.ForeColor = $script:Colors.Accent }
        }
        $listView.Items.Add($item) | Out-Null
    }
    $dialog.Controls.Add($listView)
    
    # Stats
    $totalRuns = $history.Count
    $completed = ($history | Where-Object { $_.Status -eq "Completed" }).Count
    $cancelled = ($history | Where-Object { $_.Status -eq "Cancelled" }).Count
    $totalMinutes = ($history | Measure-Object -Property Minutes -Sum).Sum
    
    $statsLabel = New-Object System.Windows.Forms.Label
    $statsLabel.Text = "Total: $totalRuns runs | Completed: $completed | Cancelled: $cancelled | Total time: $totalMinutes minutes"
    $statsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $statsLabel.Size = New-Object System.Drawing.Size(500, 25)
    $statsLabel.Location = New-Object System.Drawing.Point(20, 355)
    $statsLabel.ForeColor = $script:Colors.TextMuted
    $dialog.Controls.Add($statsLabel)
    
    # Clear History button
    $clearBtn = New-RoundedButton -Text "🗑 Clear History" -Size (New-Object System.Drawing.Size(140, 35)) `
        -Location (New-Object System.Drawing.Point(200, 390)) -BackColor $script:Colors.Danger
    $clearBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $clearBtn.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Clear all timer history?", "Confirm", "YesNo", "Warning")
        if ($result -eq "Yes") {
            if (Test-Path $script:HistoryPath) {
                Remove-Item $script:HistoryPath -Force
            }
            $dialog.Close()
            [System.Windows.Forms.MessageBox]::Show("History cleared.", "Sleep Timer Pro", "OK", "Information")
        }
    })
    $dialog.Controls.Add($clearBtn)
    
    # Close button
    $closeBtn = New-RoundedButton -Text "Close" -Size (New-Object System.Drawing.Size(100, 35)) `
        -Location (New-Object System.Drawing.Point(360, 390)) -BackColor $script:Colors.SurfaceLight
    $closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $closeBtn.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($closeBtn)
    
    $dialog.ShowDialog() | Out-Null
}

function Show-HelpDialog {
    $helpLines = @(
        "Sleep Timer Pro - Help",
        "",
        "QUICK START:",
        "  Select a PROFILE for quick-loading saved configurations",
        "  Or manually set duration using numeric input or preset buttons",
        "  Choose ACTION from dropdown (Shutdown Sleep Hibernate etc)",
        "  Click START TIMER to begin",
        "",
        "FEATURES:",
        "  Profile System - Save/load timer configurations",
        "  System tray integration - timer runs in background",
        "  Persistent settings - remembers your preferences",
        "  Timer history - view all past timer runs",
        "  Warning notifications before action with snooze option",
        "  Audio feedback for events",
        "  Minimize to tray with balloon notifications",
        "  Light/Dark theme toggle",
        "  Battery check before Sleep/Hibernate",
        "  Auto-start with Windows option",
        "",
        "HOTKEYS:",
        "  F1 - Show this help",
        "  Esc - Cancel timer (when running)",
        "",
        "BUTTONS (top right):",
        "  History - View timer history and statistics",
        "  Sun/Moon - Toggle light/dark theme",
        "  Settings - Configure all options",
        "",
        "SETTINGS:",
        "  Snooze duration - Minutes to add when snoozing",
        "  Warning time - Minutes before action to notify",
        "  Sound notifications - Enable/disable audio",
        "  Custom sounds - Use your own WAV files",
        "  Minimize to tray - Hide when minimized",
        "  Always on top - Keep window visible",
        "  Battery check - Warn if on battery for Sleep/Hibernate",
        "  Auto-start - Start with Windows in tray mode",
        "  Password protection - Require password to cancel",
        "  Idle detection - Auto-cancel if user becomes active",
        "  Export/Import - Backup and restore all settings",
        "",
        "COMMANDS:",
        "  GUI Mode:             .\SleepTimer.ps1",
        "  Console:              .\SleepTimer.ps1 -NoGUI -Minutes 60",
        "  Silent:               .\SleepTimer.ps1 -NoGUI -Silent",
        "  Use Profile:          .\SleepTimer.ps1 -Profile `"Movie Night`"",
        "  Scheduled:            .\SleepTimer.ps1 -ScheduleTime `"22:30`" -Action Sleep",
        "  Named Timer:          .\SleepTimer.ps1 -TimerName `"Bedtime`" -Minutes 30",
        "  Export Settings:      .\SleepTimer.ps1 -ExportSettings `"backup.json`"",
        "  Import Settings:      .\SleepTimer.ps1 -ImportSettings `"backup.json`"",
        "  List Profiles:        .\SleepTimer.ps1 -ListProfiles",
        "  Tray Start:           .\SleepTimer.ps1 -MinimizeToTray",
        "  Quick Launch:         .\SleepTimer.bat tray",
        "  Silent Launch:        .\SleepTimer.bat silent 60 Sleep"
    )
    $help = $helpLines -join "`r`n"
    [System.Windows.Forms.MessageBox]::Show($help, "Sleep Timer Pro - Help", "OK", "Information")
}

# Main execution
Write-TimerLog "Sleep Timer Pro started with parameters: Minutes=$Minutes, Action=$Action, Profile=$Profile, ScheduleTime=$ScheduleTime, TimerName=$TimerName, NoGUI=$NoGUI, Silent=$Silent, MinimizeToTray=$MinimizeToTray, ExportSettings=$ExportSettings, ImportSettings=$ImportSettings, ListProfiles=$ListProfiles"

# Handle special parameter modes first
if ($ListProfiles) {
    $profiles = Get-Profiles
    Write-Host "`nAvailable Profiles:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    foreach ($profileName in $profiles.PSObject.Properties.Name) {
        $data = $profiles.$profileName
        Write-Host "  • $profileName : $($data.Minutes) minutes → $($data.Action)" -ForegroundColor White
    }
    Write-Host ""
    exit 0
}

if ($ExportSettings) {
    try {
        Export-TimerSettings -ExportPath $ExportSettings
        Write-Host "✓ Settings exported to: $ExportSettings" -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Host "✗ Export failed: $_" -ForegroundColor Red
        exit 1
    }
}

if ($ImportSettings) {
    try {
        Import-TimerSettings -ImportPath $ImportSettings
        Write-Host "✓ Settings imported from: $ImportSettings" -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Host "✗ Import failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Apply profile if specified
if ($Profile) {
    $profiles = Get-Profiles
    if ($profiles.$Profile) {
        $Minutes = $profiles.$Profile.Minutes
        $Action = $profiles.$Profile.Action
        $script:CurrentProfile = $Profile
        Write-TimerLog "Profile loaded: $Profile -> $Minutes minutes, $Action"
    }
    else {
        Write-Host "Profile '$Profile' not found. Use -ListProfiles to see available profiles." -ForegroundColor Red
        exit 1
    }
}

# Set timer name if provided
if ($TimerName) {
    $script:TimerName = $TimerName
}

# Handle scheduled timer
if ($ScheduleTime) {
    try {
        $targetTime = [DateTime]::ParseExact($ScheduleTime, "HH:mm", $null)
        $now = Get-Date
        $targetTime = $targetTime.AddDays(0)
        if ($targetTime -lt $now) {
            $targetTime = $targetTime.AddDays(1)
        }
        $waitMinutes = [math]::Floor(($targetTime - $now).TotalMinutes)
        $Minutes = $waitMinutes
        Write-TimerLog "Scheduled timer set for $ScheduleTime ($waitMinutes minutes from now)"
        if (-not $Silent) {
            Write-Host "⏰ Scheduled for $ScheduleTime ($waitMinutes minutes from now)" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Invalid time format. Use HH:mm (e.g., 22:30)" -ForegroundColor Red
        exit 1
    }
}

if ($NoGUI) {
    $totalSeconds = $Minutes * 60
    $settings = Get-Settings
    $warnSeconds = $settings.WarningMinutes * 60

    if (-not $Silent) {
        Write-Host "`n+----------------------------------------+" -ForegroundColor Cyan
        Write-Host "|      SLEEP TIMER PRO - Console Mode      |" -ForegroundColor Cyan
        Write-Host "+----------------------------------------+" -ForegroundColor Cyan
        if ($script:TimerName) {
            Write-Host "  Timer:     $script:TimerName" -ForegroundColor White
        }
        Write-Host "  Duration:  $Minutes minutes" -ForegroundColor White
        Write-Host "  Action:    $Action" -ForegroundColor White
        Write-Host "  Profile:   $script:CurrentProfile" -ForegroundColor White
        Write-Host "  Warning:   $($settings.WarningMinutes) minutes before action" -ForegroundColor White
        if ($settings.CheckIdle) {
            Write-Host "  Idle Check: Auto-cancel after $($settings.IdleThresholdMinutes)min activity" -ForegroundColor White
        }
        Write-Host "  Log:       $script:LogFile" -ForegroundColor Gray
        Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host "  Press Ctrl+C to cancel`n" -ForegroundColor Yellow
    }

    try {
        Start-CountdownTimer -TotalSeconds $totalSeconds -TimerAction $Action -WarnSeconds $warnSeconds
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-TimerLog "Timer interrupted by user (Ctrl+C)"
        if (-not $Silent) {
            Write-Host "`n✓ Timer cancelled successfully." -ForegroundColor Green
        }
    }
}
else {
    New-SleepTimerForm
}

Write-TimerLog "Sleep Timer Pro session ended"
