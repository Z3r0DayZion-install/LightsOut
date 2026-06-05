#Requires -Version 5.1
# Sleep Timer Pro - Working UI Version
param(
    [switch]$Tray
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings file
$SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimer\settings.json"
$SettingsDir = Split-Path $SettingsPath -Parent
if (-not (Test-Path $SettingsDir)) {
    New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
}

# Default settings
$DefaultSettings = @{
    Minutes = 30
    Action = "Sleep"
    WarningMinutes = 5
    PlaySound = $true
    MinimizeToTray = $false
}

# Load or create settings
if (Test-Path $SettingsPath) {
    try {
        $Settings = Get-Content $SettingsPath | ConvertFrom-Json
        # Ensure all properties exist
        $DefaultSettings.GetEnumerator() | ForEach-Object {
            if (-not (Get-Member -InputObject $Settings -Name $_.Key -MemberType NoteProperty)) {
                $Settings | Add-Member -NotePropertyName $_.Key -NotePropertyValue $_.Value
            }
        }
    } catch {
        $Settings = $DefaultSettings
    }
} else {
    $Settings = $DefaultSettings
    $Settings | ConvertTo-Json | Set-Content $SettingsPath
}

# Global timer state
$script:TimerActive = $false
$script:Timer = $null
$script:RemainingSeconds = 0

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer Pro"
$form.Size = New-Object System.Drawing.Size(450, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Sleep Timer Pro"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.Size = New-Object System.Drawing.Size(400, 40)
$titleLabel.Location = New-Object System.Drawing.Point(0, 15)
$titleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($titleLabel)

# Time Section
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "Timer Duration"
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$timeLabel.Location = New-Object System.Drawing.Point(30, 70)
$timeLabel.Size = New-Object System.Drawing.Size(150, 25)
$form.Controls.Add($timeLabel)

# Minutes input
$minutesInput = New-Object System.Windows.Forms.NumericUpDown
$minutesInput.Location = New-Object System.Drawing.Point(30, 100)
$minutesInput.Size = New-Object System.Drawing.Size(100, 25)
$minutesInput.Minimum = 1
$minutesInput.Maximum = 1440
$minutesInput.Value = $Settings.Minutes
$minutesInput.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($minutesInput)

$minutesLabel = New-Object System.Windows.Forms.Label
$minutesLabel.Text = "minutes"
$minutesLabel.Location = New-Object System.Drawing.Point(140, 103)
$minutesLabel.Size = New-Object System.Drawing.Size(60, 25)
$minutesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($minutesLabel)

# Quick presets
$presets = @(
    @{ Text = "15 min"; Value = 15; X = 30 },
    @{ Text = "30 min"; Value = 30; X = 100 },
    @{ Text = "60 min"; Value = 60; X = 170 },
    @{ Text = "90 min"; Value = 90; X = 240 }
)

foreach ($preset in $presets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $preset.Text
    $btn.Size = New-Object System.Drawing.Size(60, 30)
    $btn.Location = New-Object System.Drawing.Point($preset.X, 140)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = [System.Drawing.Color]::White
    $val = $preset.Value
    $btn.Add_Click({ $minutesInput.Value = $val })
    $form.Controls.Add($btn)
}

# Action Section
$actionLabel = New-Object System.Windows.Forms.Label
$actionLabel.Text = "Action"
$actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$actionLabel.Location = New-Object System.Drawing.Point(30, 185)
$actionLabel.Size = New-Object System.Drawing.Size(150, 25)
$form.Controls.Add($actionLabel)

# Action dropdown
$actionCombo = New-Object System.Windows.Forms.ComboBox
$actionCombo.Location = New-Object System.Drawing.Point(30, 215)
$actionCombo.Size = New-Object System.Drawing.Size(180, 25)
$actionCombo.DropDownStyle = "DropDownList"
$actionCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$actionCombo.Items.AddRange(@("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff"))
$actionCombo.SelectedItem = $Settings.Action
$form.Controls.Add($actionCombo)

# Status Display
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$statusLabel.Location = New-Object System.Drawing.Point(250, 95)
$statusLabel.Size = New-Object System.Drawing.Size(170, 60)
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$statusLabel.BorderStyle = "FixedSingle"
$form.Controls.Add($statusLabel)

# Start Button
$startBtn = New-Object System.Windows.Forms.Button
$startBtn.Text = "START TIMER"
$startBtn.Size = New-Object System.Drawing.Size(150, 50)
$startBtn.Location = New-Object System.Drawing.Point(250, 170)
$startBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$startBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$startBtn.ForeColor = [System.Drawing.Color]::White
$startBtn.FlatStyle = "Flat"

$startBtn.Add_Click({
    if (-not $script:TimerActive) {
        $script:TimerActive = $true
        $script:RemainingSeconds = [int]$minutesInput.Value * 60
        $startBtn.Text = "STOP"
        $startBtn.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
        $minutesInput.Enabled = $false
        $actionCombo.Enabled = $false
        
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 1000
        $script:Timer.Add_Tick({
            if ($script:RemainingSeconds -gt 0 -and $script:TimerActive) {
                $script:RemainingSeconds--
                $min = [math]::Floor($script:RemainingSeconds / 60)
                $sec = $script:RemainingSeconds % 60
                $statusLabel.Text = "{0:D2}:{1:D2}" -f $min, $sec
                
                # Warning at 5 minutes
                if ($script:RemainingSeconds -eq 300 -and $Settings.WarningMinutes -gt 0) {
                    [System.Windows.Forms.MessageBox]::Show("5 minutes remaining!", "Warning", "OK", "Warning")
                }
            } else {
                $script:Timer.Stop()
                $script:TimerActive = $false
                
                # Execute action
                $action = $actionCombo.SelectedItem
                switch ($action) {
                    "Shutdown" { Stop-Computer -Force }
                    "Restart" { Restart-Computer -Force }
                    "Sleep" { rundll32.exe powrprof.dll,SetSuspendState 0,1,0 }
                    "Hibernate" { rundll3232.exe powrprof.dll,SetSuspendState 1,1,0 }
                    "Lock" { rundll32.exe user32.dll,LockWorkStation }
                    "Logoff" { shutdown.exe /l }
                }
                
                $form.Close()
            }
        })
        $script:Timer.Start()
    } else {
        # Stop timer
        $script:TimerActive = $false
        $script:Timer.Stop()
        $statusLabel.Text = "Stopped"
        $startBtn.Text = "START TIMER"
        $startBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
        $minutesInput.Enabled = $true
        $actionCombo.Enabled = $true
    }
})
$form.Controls.Add($startBtn)

# Settings Button
$settingsBtn = New-Object System.Windows.Forms.Button
$settingsBtn.Text = "Settings"
$settingsBtn.Size = New-Object System.Drawing.Size(100, 35)
$settingsBtn.Location = New-Object System.Drawing.Point(30, 280)
$settingsBtn.FlatStyle = "Flat"
$settingsBtn.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "Settings"
    $settingsForm.Size = New-Object System.Drawing.Size(350, 300)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.FormBorderStyle = "FixedDialog"
    
    $y = 20
    
    # Warning minutes
    $warnLabel = New-Object System.Windows.Forms.Label
    $warnLabel.Text = "Warning (minutes before):"
    $warnLabel.Location = New-Object System.Drawing.Point(20, $y)
    $warnLabel.Size = New-Object System.Drawing.Size(150, 25)
    $settingsForm.Controls.Add($warnLabel)
    
    $warnInput = New-Object System.Windows.Forms.NumericUpDown
    $warnInput.Location = New-Object System.Drawing.Point(180, $y)
    $warnInput.Size = New-Object System.Drawing.Size(60, 25)
    $warnInput.Minimum = 0
    $warnInput.Maximum = 30
    $warnInput.Value = $Settings.WarningMinutes
    $settingsForm.Controls.Add($warnInput)
    $y += 40
    
    # Sound checkbox
    $soundCheck = New-Object System.Windows.Forms.CheckBox
    $soundCheck.Text = "Play notification sounds"
    $soundCheck.Location = New-Object System.Drawing.Point(20, $y)
    $soundCheck.Size = New-Object System.Drawing.Size(250, 25)
    $soundCheck.Checked = $Settings.PlaySound
    $settingsForm.Controls.Add($soundCheck)
    $y += 40
    
    # Tray checkbox
    $trayCheck = New-Object System.Windows.Forms.CheckBox
    $trayCheck.Text = "Minimize to system tray"
    $trayCheck.Location = New-Object System.Drawing.Point(20, $y)
    $trayCheck.Size = New-Object System.Drawing.Size(250, 25)
    $trayCheck.Checked = $Settings.MinimizeToTray
    $settingsForm.Controls.Add($trayCheck)
    $y += 60
    
    # Save button
    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "Save Settings"
    $saveBtn.Size = New-Object System.Drawing.Size(120, 35)
    $saveBtn.Location = New-Object System.Drawing.Point(110, $y)
    $saveBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $saveBtn.ForeColor = [System.Drawing.Color]::White
    $saveBtn.FlatStyle = "Flat"
    $saveBtn.Add_Click({
        $Settings.WarningMinutes = [int]$warnInput.Value
        $Settings.PlaySound = $soundCheck.Checked
        $Settings.MinimizeToTray = $trayCheck.Checked
        $Settings.Minutes = [int]$minutesInput.Value
        $Settings.Action = $actionCombo.SelectedItem
        $Settings | ConvertTo-Json | Set-Content $SettingsPath
        [System.Windows.Forms.MessageBox]::Show("Settings saved!", "Success", "OK", "Information")
        $settingsForm.Close()
    })
    $settingsForm.Controls.Add($saveBtn)
    
    $settingsForm.ShowDialog()
})
$form.Controls.Add($settingsBtn)

# Save on close
$form.Add_FormClosing({
    $Settings.Minutes = [int]$minutesInput.Value
    $Settings.Action = $actionCombo.SelectedItem
    $Settings | ConvertTo-Json | Set-Content $SettingsPath
})

# Show the form
$form.ShowDialog()
