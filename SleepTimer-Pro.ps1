#Requires -Version 5.1
# Sleep Timer Pro - Professional Edition
param([switch]$Tray)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings
$SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimerPro\settings.json"
$ProfilesPath = Join-Path $env:LOCALAPPDATA "SleepTimerPro\profiles.json"
$SettingsDir = Split-Path $SettingsPath -Parent
if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }

$script:Settings = @{
    Minutes = 30
    Action = "Sleep"
    WarningMinutes = 5
    PlaySound = $true
    MinimizeToTray = $false
    DarkMode = $true
    LastProfile = ""
}

if (Test-Path $SettingsPath) {
    try { $loaded = Get-Content $SettingsPath | ConvertFrom-Json; $loaded.PSObject.Properties | ForEach-Object { $script:Settings[$_.Name] = $_.Value } } catch {}
}

# Default Profiles
$script:Profiles = @{
    "Movie Night" = @{ Minutes = 120; Action = "Sleep" }
    "Work Session" = @{ Minutes = 60; Action = "Shutdown" }
    "Quick Nap" = @{ Minutes = 20; Action = "Sleep" }
    "Bedtime" = @{ Minutes = 30; Action = "Sleep" }
    "Download" = @{ Minutes = 180; Action = "Shutdown" }
}

if (Test-Path $ProfilesPath) {
    try { $loaded = Get-Content $ProfilesPath | ConvertFrom-Json; $loaded.PSObject.Properties | ForEach-Object { $script:Profiles[$_.Name] = $_.Value } } catch {}
} else {
    $script:Profiles | ConvertTo-Json | Set-Content $ProfilesPath
}

# Colors
$script:Colors = @{
    Background = [System.Drawing.Color]::FromArgb(32, 32, 32)
    Surface = [System.Drawing.Color]::FromArgb(45, 45, 45)
    SurfaceLight = [System.Drawing.Color]::FromArgb(60, 60, 60)
    Text = [System.Drawing.Color]::FromArgb(240, 240, 240)
    TextMuted = [System.Drawing.Color]::FromArgb(160, 160, 160)
    Accent = [System.Drawing.Color]::FromArgb(0, 150, 255)
    AccentHover = [System.Drawing.Color]::FromArgb(0, 120, 212)
    Danger = [System.Drawing.Color]::FromArgb(220, 53, 69)
    Success = [System.Drawing.Color]::FromArgb(40, 167, 69)
    Warning = [System.Drawing.Color]::FromArgb(255, 193, 7)
}

# State
$script:TimerActive = $false
$script:Timer = $null
$script:RemainingSeconds = 0
$script:NotifyIcon = $null

# Snooze Dialog Function
function Show-SnoozeDialog {
    param([string]$ActionName, [int]$Minutes)
    
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Timer Warning"
    $dialog.Size = New-Object System.Drawing.Size(400, 220)
    $dialog.StartPosition = "CenterScreen"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.BackColor = $script:Colors.Background
    $dialog.ForeColor = $script:Colors.Text
    $dialog.TopMost = $true
    
    # Icon
    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = "!"
    $icon.Font = New-Object System.Drawing.Font("Segoe UI", 48, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = $script:Colors.Warning
    $icon.Size = New-Object System.Drawing.Size(60, 70)
    $icon.Location = New-Object System.Drawing.Point(30, 20)
    $dialog.Controls.Add($icon)
    
    # Message
    $msg = New-Object System.Windows.Forms.Label
    $msg.Text = "$ActionName will execute in $Minutes minutes!"
    $msg.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $msg.ForeColor = $script:Colors.Text
    $msg.Size = New-Object System.Drawing.Size(280, 50)
    $msg.Location = New-Object System.Drawing.Point(100, 30)
    $dialog.Controls.Add($msg)
    
    # Sub message
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "You can snooze for 10 more minutes or proceed now."
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $sub.ForeColor = $script:Colors.TextMuted
    $sub.Size = New-Object System.Drawing.Size(280, 40)
    $sub.Location = New-Object System.Drawing.Point(100, 80)
    $dialog.Controls.Add($sub)
    
    # Snooze Button
    $snoozeBtn = New-Object System.Windows.Forms.Button
    $snoozeBtn.Text = "SNOOZE (+10 min)"
    $snoozeBtn.Size = New-Object System.Drawing.Size(130, 40)
    $snoozeBtn.Location = New-Object System.Drawing.Point(60, 140)
    $snoozeBtn.BackColor = $script:Colors.Accent
    $snoozeBtn.ForeColor = [System.Drawing.Color]::White
    $snoozeBtn.FlatStyle = "Flat"
    $snoozeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $snoozeBtn.Add_Click({ $dialog.Tag = "Snooze"; $dialog.Close() })
    $dialog.Controls.Add($snoozeBtn)
    
    # Proceed Button
    $proceedBtn = New-Object System.Windows.Forms.Button
    $proceedBtn.Text = "PROCEED"
    $proceedBtn.Size = New-Object System.Drawing.Size(100, 40)
    $proceedBtn.Location = New-Object System.Drawing.Point(210, 140)
    $proceedBtn.BackColor = $script:Colors.SurfaceLight
    $proceedBtn.ForeColor = $script:Colors.Text
    $proceedBtn.FlatStyle = "Flat"
    $proceedBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $proceedBtn.Add_Click({ $dialog.Tag = "Proceed"; $dialog.Close() })
    $dialog.Controls.Add($proceedBtn)
    
    $dialog.ShowDialog() | Out-Null
    return $dialog.Tag
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer Pro"
$form.Size = New-Object System.Drawing.Size(500, 450)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $script:Colors.Background
$form.ForeColor = $script:Colors.Text
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Header Panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(500, 70)
$headerPanel.BackColor = $script:Colors.Surface
$headerPanel.Dock = "Top"
$form.Controls.Add($headerPanel)

# Title
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Sleep Timer Pro"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $script:Colors.Text
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$headerPanel.Controls.Add($titleLabel)

# Subtitle
$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Professional Power Management"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = $script:Colors.TextMuted
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(270, 30)
$headerPanel.Controls.Add($subtitle)

# Profile Selector
$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Text = "Profile"
$profileLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$profileLabel.ForeColor = $script:Colors.Text
$profileLabel.Location = New-Object System.Drawing.Point(30, 80)
$profileLabel.Size = New-Object System.Drawing.Size(80, 25)
$form.Controls.Add($profileLabel)

$profileCombo = New-Object System.Windows.Forms.ComboBox
$profileCombo.Location = New-Object System.Drawing.Point(120, 78)
$profileCombo.Size = New-Object System.Drawing.Size(200, 28)
$profileCombo.DropDownStyle = "DropDownList"
$profileCombo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$profileCombo.BackColor = $script:Colors.Surface
$profileCombo.ForeColor = $script:Colors.Text
$profileCombo.FlatStyle = "Flat"
$profileCombo.Items.Add("(Custom)")
$script:Profiles.Keys | Sort-Object | ForEach-Object { $profileCombo.Items.Add($_) }
if ($script:Settings.LastProfile -and $script:Profiles[$script:Settings.LastProfile]) {
    $profileCombo.SelectedItem = $script:Settings.LastProfile
} else {
    $profileCombo.SelectedIndex = 0
}
$profileCombo.Add_SelectedIndexChanged({
    $selected = $profileCombo.SelectedItem
    if ($selected -ne "(Custom)" -and $script:Profiles[$selected]) {
        $minutesInput.Value = $script:Profiles[$selected].Minutes
        $actionCombo.SelectedItem = $script:Profiles[$selected].Action
        $script:Settings.LastProfile = $selected
    }
})
$form.Controls.Add($profileCombo)

# Time Input Section
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "Duration"
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$timeLabel.ForeColor = $script:Colors.Text
$timeLabel.Location = New-Object System.Drawing.Point(30, 90)
$timeLabel.Size = New-Object System.Drawing.Size(100, 25)
$form.Controls.Add($timeLabel)

# Minutes Input
$minutesInput = New-Object System.Windows.Forms.NumericUpDown
$minutesInput.Location = New-Object System.Drawing.Point(30, 120)
$minutesInput.Size = New-Object System.Drawing.Size(120, 30)
$minutesInput.Minimum = 1
$minutesInput.Maximum = 1440
$minutesInput.Value = $script:Settings.Minutes
$minutesInput.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$minutesInput.BackColor = $script:Colors.Surface
$minutesInput.ForeColor = $script:Colors.Text
$minutesInput.BorderStyle = "FixedSingle"
$form.Controls.Add($minutesInput)

$minLabel = New-Object System.Windows.Forms.Label
$minLabel.Text = "minutes"
$minLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$minLabel.ForeColor = $script:Colors.TextMuted
$minLabel.Location = New-Object System.Drawing.Point(160, 125)
$minLabel.Size = New-Object System.Drawing.Size(60, 25)
$form.Controls.Add($minLabel)

# Quick Presets
$presetPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$presetPanel.Location = New-Object System.Drawing.Point(30, 165)
$presetPanel.Size = New-Object System.Drawing.Size(220, 40)
$presetPanel.BackColor = $script:Colors.Background
$form.Controls.Add($presetPanel)

$presetValues = @(15, 30, 60, 90)
foreach ($val in $presetValues) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "$val min"
    $btn.Size = New-Object System.Drawing.Size(50, 32)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $script:Colors.SurfaceLight
    $btn.ForeColor = $script:Colors.Text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $btn.Margin = New-Object System.Windows.Forms.Padding(2)
    $v = $val
    $btn.Add_Click({ $minutesInput.Value = $v })
    $presetPanel.Controls.Add($btn)
}

# Action Section
$actionLabel = New-Object System.Windows.Forms.Label
$actionLabel.Text = "Action"
$actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$actionLabel.ForeColor = $script:Colors.Text
$actionLabel.Location = New-Object System.Drawing.Point(30, 220)
$actionLabel.Size = New-Object System.Drawing.Size(100, 25)
$form.Controls.Add($actionLabel)

$actionCombo = New-Object System.Windows.Forms.ComboBox
$actionCombo.Location = New-Object System.Drawing.Point(30, 250)
$actionCombo.Size = New-Object System.Drawing.Size(200, 30)
$actionCombo.DropDownStyle = "DropDownList"
$actionCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$actionCombo.BackColor = $script:Colors.Surface
$actionCombo.ForeColor = $script:Colors.Text
$actionCombo.FlatStyle = "Flat"
$actionCombo.Items.AddRange(@("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff"))
$actionCombo.SelectedItem = $script:Settings.Action
$form.Controls.Add($actionCombo)

# Status Display (Big Timer)
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(280, 90)
$statusPanel.Size = New-Object System.Drawing.Size(180, 120)
$statusPanel.BackColor = $script:Colors.Surface
$statusPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($statusPanel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $script:Colors.TextMuted
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.Size = New-Object System.Drawing.Size(180, 80)
$statusLabel.Location = New-Object System.Drawing.Point(0, 10)
$statusPanel.Controls.Add($statusLabel)

$actionDisplay = New-Object System.Windows.Forms.Label
$actionDisplay.Text = "Sleep"
$actionDisplay.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$actionDisplay.ForeColor = $script:Colors.TextMuted
$actionDisplay.TextAlign = "MiddleCenter"
$actionDisplay.Size = New-Object System.Drawing.Size(180, 25)
$actionDisplay.Location = New-Object System.Drawing.Point(0, 90)
$statusPanel.Controls.Add($actionDisplay)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(30, 310)
$progressBar.Size = New-Object System.Drawing.Size(440, 10)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

# Main Button (Start/Stop)
$mainBtn = New-Object System.Windows.Forms.Button
$mainBtn.Text = "START TIMER"
$mainBtn.Size = New-Object System.Drawing.Size(200, 50)
$mainBtn.Location = New-Object System.Drawing.Point(30, 340)
$mainBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$mainBtn.BackColor = $script:Colors.Accent
$mainBtn.ForeColor = [System.Drawing.Color]::White
$mainBtn.FlatStyle = "Flat"
$mainBtn.FlatAppearance.BorderSize = 0
$mainBtn.Cursor = "Hand"

$mainBtn.Add_Click({
    if (-not $script:TimerActive) {
        # Start
        $script:TimerActive = $true
        $totalSeconds = [int]$minutesInput.Value * 60
        $script:RemainingSeconds = $totalSeconds
        
        $mainBtn.Text = "STOP"
        $mainBtn.BackColor = $script:Colors.Danger
        $minutesInput.Enabled = $false
        $actionCombo.Enabled = $false
        $statusLabel.ForeColor = $script:Colors.Accent
        $actionDisplay.Text = $actionCombo.SelectedItem
        
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 1000
        $script:Timer.Add_Tick({
            if ($script:RemainingSeconds -gt 0 -and $script:TimerActive) {
                $script:RemainingSeconds--
                $min = [math]::Floor($script:RemainingSeconds / 60)
                $sec = $script:RemainingSeconds % 60
                $statusLabel.Text = "{0:D2}:{1:D2}" -f $min, $sec
                
                # Update progress
                $percent = 100 - (($script:RemainingSeconds / $totalSeconds) * 100)
                $progressBar.Value = [math]::Min(100, [math]::Max(0, [int]$percent))
                
                # Warning with balloon and snooze option
                if ($script:RemainingSeconds -eq ($script:Settings.WarningMinutes * 60) -and $script:Settings.WarningMinutes -gt 0) {
                    # Balloon tip
                    $script:NotifyIcon.Visible = $true
                    $script:NotifyIcon.ShowBalloonTip(5000, "Timer Warning", "$($actionCombo.SelectedItem) in $($script:Settings.WarningMinutes) minutes! Click to snooze.", "Warning")
                    
                    # Sound alert
                    if ($script:Settings.PlaySound) {
                        try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
                    }
                    
                    # Snooze dialog
                    $snoozeResult = Show-SnoozeDialog -ActionName $actionCombo.SelectedItem -Minutes $script:Settings.WarningMinutes
                    if ($snoozeResult -eq "Snooze") {
                        $script:RemainingSeconds += 600  # Add 10 minutes
                        $totalSeconds += 600
                    }
                }
            } else {
                # Timer complete
                $script:Timer.Stop()
                $script:TimerActive = $false
                
                $action = $actionCombo.SelectedItem
                switch ($action) {
                    "Shutdown" { Stop-Computer -Force }
                    "Restart" { Restart-Computer -Force }
                    "Sleep" { 
                        Add-Type '[DllImport("PowrProf.dll", CharSet=CharSet.Auto)]public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);' -Name Power -Namespace System
                        [System.Power]::SetSuspendState($false, $true, $false) | Out-Null
                    }
                    "Hibernate" {
                        Add-Type '[DllImport("PowrProf.dll", CharSet=CharSet.Auto)]public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);' -Name Power -Namespace System
                        [System.Power]::SetSuspendState($true, $true, $false) | Out-Null
                    }
                    "Lock" { rundll32.exe user32.dll,LockWorkStation }
                    "Logoff" { shutdown.exe /l }
                }
            }
        })
        $script:Timer.Start()
    } else {
        # Stop
        $script:TimerActive = $false
        $script:Timer.Stop()
        $statusLabel.Text = "Stopped"
        $statusLabel.ForeColor = $script:Colors.TextMuted
        $actionDisplay.Text = "-"
        $progressBar.Value = 0
        $mainBtn.Text = "START TIMER"
        $mainBtn.BackColor = $script:Colors.Accent
        $minutesInput.Enabled = $true
        $actionCombo.Enabled = $true
    }
})
$form.Controls.Add($mainBtn)

# Settings Button
$settingsBtn = New-Object System.Windows.Forms.Button
$settingsBtn.Text = "Settings"
$settingsBtn.Size = New-Object System.Drawing.Size(100, 35)
$settingsBtn.Location = New-Object System.Drawing.Point(370, 350)
$settingsBtn.FlatStyle = "Flat"
$settingsBtn.BackColor = $script:Colors.SurfaceLight
$settingsBtn.ForeColor = $script:Colors.Text
$settingsBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$settingsBtn.Add_Click({
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Settings"
    $sf.Size = New-Object System.Drawing.Size(320, 250)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"
    $sf.BackColor = $script:Colors.Background
    $sf.ForeColor = $script:Colors.Text
    
    $y = 20
    
    # Warning
    $wl = New-Object System.Windows.Forms.Label
    $wl.Text = "Warning (min before):"
    $wl.Location = New-Object System.Drawing.Point(20, $y)
    $wl.Size = New-Object System.Drawing.Size(130, 25)
    $wl.ForeColor = $script:Colors.Text
    $sf.Controls.Add($wl)
    
    $wi = New-Object System.Windows.Forms.NumericUpDown
    $wi.Location = New-Object System.Drawing.Point(160, $y)
    $wi.Size = New-Object System.Drawing.Size(60, 25)
    $wi.Minimum = 0
    $wi.Maximum = 30
    $wi.Value = $script:Settings.WarningMinutes
    $wi.BackColor = $script:Colors.Surface
    $wi.ForeColor = $script:Colors.Text
    $sf.Controls.Add($wi)
    $y += 40
    
    # Sound
    $sc = New-Object System.Windows.Forms.CheckBox
    $sc.Text = "Play sounds"
    $sc.Location = New-Object System.Drawing.Point(20, $y)
    $sc.Size = New-Object System.Drawing.Size(200, 25)
    $sc.Checked = $script:Settings.PlaySound
    $sc.ForeColor = $script:Colors.Text
    $sf.Controls.Add($sc)
    $y += 35
    
    # Tray
    $tc = New-Object System.Windows.Forms.CheckBox
    $tc.Text = "Minimize to tray"
    $tc.Location = New-Object System.Drawing.Point(20, $y)
    $tc.Size = New-Object System.Drawing.Size(200, 25)
    $tc.Checked = $script:Settings.MinimizeToTray
    $tc.ForeColor = $script:Colors.Text
    $sf.Controls.Add($tc)
    $y += 50
    
    # Save
    $sb = New-Object System.Windows.Forms.Button
    $sb.Text = "Save"
    $sb.Size = New-Object System.Drawing.Size(100, 35)
    $sb.Location = New-Object System.Drawing.Point(110, $y)
    $sb.BackColor = $script:Colors.Accent
    $sb.ForeColor = [System.Drawing.Color]::White
    $sb.FlatStyle = "Flat"
    $sb.FlatAppearance.BorderSize = 0
    $sb.Add_Click({
        $script:Settings.WarningMinutes = [int]$wi.Value
        $script:Settings.PlaySound = $sc.Checked
        $script:Settings.MinimizeToTray = $tc.Checked
        $script:Settings.Minutes = [int]$minutesInput.Value
        $script:Settings.Action = $actionCombo.SelectedItem
        $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
        [System.Windows.Forms.MessageBox]::Show("Settings saved!", "Done", "OK", "Information")
        $sf.Close()
    })
    $sf.Controls.Add($sb)
    
    $sf.ShowDialog()
})
$form.Controls.Add($settingsBtn)

# Save on close
$form.Add_FormClosing({
    $script:Settings.Minutes = [int]$minutesInput.Value
    $script:Settings.Action = $actionCombo.SelectedItem
    $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
})

# System Tray Icon
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Sleep Timer Pro"
$script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:NotifyIcon.Visible = $false

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showItem.Text = "Show"
$showItem.Add_Click({ $form.Show(); $form.WindowState = "Normal" })
$contextMenu.Items.Add($showItem)

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"
$exitItem.Add_Click({ $form.Close() })
$contextMenu.Items.Add($exitItem)

$script:NotifyIcon.ContextMenuStrip = $contextMenu
$script:NotifyIcon.Add_Click({
    if ($_.Button -eq "Left") {
        $form.Show()
        $form.WindowState = "Normal"
        $script:NotifyIcon.Visible = $false
    }
})

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized" -and $script:Settings.MinimizeToTray) {
        $form.Hide()
        $script:NotifyIcon.Visible = $true
        $script:NotifyIcon.ShowBalloonTip(2000, "Sleep Timer Pro", "Running in background", "Info")
    }
})

$form.ShowDialog()
$script:NotifyIcon.Visible = $false
