# Sleep Timer - Clean Working Version
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings storage
$SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimer\settings.json"
if (!(Test-Path (Split-Path $SettingsPath))) { New-Item -ItemType Directory -Path (Split-Path $SettingsPath) -Force | Out-Null }

$Settings = @{ Minutes = 30; Action = "Sleep"; WarningMinutes = 5; PlaySound = $true; ForceShutdown = $true }
if (Test-Path $SettingsPath) {
    try { 
        $loaded = Get-Content $SettingsPath | ConvertFrom-Json
        $loaded.PSObject.Properties | ForEach-Object { $Settings[$_.Name] = $_.Value }
    } catch {}
}

$Profiles = @{
    "Movie Night" = @{ Minutes = 120; Action = "Sleep" }
    "Work Session" = @{ Minutes = 60; Action = "Shutdown" }
    "Quick Nap" = @{ Minutes = 20; Action = "Sleep" }
    "Bedtime" = @{ Minutes = 30; Action = "Sleep" }
    "Download" = @{ Minutes = 180; Action = "Shutdown" }
}

# Colors
$C_BG = [System.Drawing.Color]::FromArgb(30, 30, 40)
$C_Panel = [System.Drawing.Color]::FromArgb(45, 45, 60)
$C_Card = [System.Drawing.Color]::FromArgb(60, 60, 80)
$C_Text = [System.Drawing.Color]::White
$C_TextDim = [System.Drawing.Color]::FromArgb(180, 180, 200)
$C_Accent = [System.Drawing.Color]::FromArgb(0, 200, 255)
$C_Success = [System.Drawing.Color]::FromArgb(0, 255, 150)
$C_Danger = [System.Drawing.Color]::FromArgb(255, 80, 80)

# State
$Active = $false
$Timer = $null
$Remaining = 0
$Total = 0

# Snooze Dialog
function Show-SnoozeDialog($ActionName, $MinutesLeft) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Timer Warning"
    $form.Size = New-Object System.Drawing.Size(350, 180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.BackColor = $C_BG
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "$ActionName in $MinutesLeft minutes!"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $C_Accent
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(310, 30)
    $form.Controls.Add($lbl)
    
    $sublbl = New-Object System.Windows.Forms.Label
    $sublbl.Text = "Snooze for 10 minutes or proceed?"
    $sublbl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $sublbl.ForeColor = $C_TextDim
    $sublbl.Location = New-Object System.Drawing.Point(20, 55)
    $sublbl.Size = New-Object System.Drawing.Size(310, 25)
    $form.Controls.Add($sublbl)
    
    $snoozeBtn = New-Object System.Windows.Forms.Button
    $snoozeBtn.Text = "SNOOZE +10m"
    $snoozeBtn.Size = New-Object System.Drawing.Size(120, 40)
    $snoozeBtn.Location = New-Object System.Drawing.Point(40, 100)
    $snoozeBtn.BackColor = $C_Card
    $snoozeBtn.ForeColor = $C_Text
    $snoozeBtn.FlatStyle = "Flat"
    $snoozeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $snoozeBtn.Add_Click({ $form.Tag = "Snooze"; $form.Close() })
    $form.Controls.Add($snoozeBtn)
    
    $proceedBtn = New-Object System.Windows.Forms.Button
    $proceedBtn.Text = "PROCEED"
    $proceedBtn.Size = New-Object System.Drawing.Size(100, 40)
    $proceedBtn.Location = New-Object System.Drawing.Point(190, 100)
    $proceedBtn.BackColor = $C_Accent
    $proceedBtn.ForeColor = [System.Drawing.Color]::Black
    $proceedBtn.FlatStyle = "Flat"
    $proceedBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $proceedBtn.Add_Click({ $form.Tag = "Proceed"; $form.Close() })
    $form.Controls.Add($proceedBtn)
    
    $form.ShowDialog() | Out-Null
    return $form.Tag
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer"
$form.Size = New-Object System.Drawing.Size(440, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.BackColor = $C_BG
$form.MaximizeBox = $false

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "SLEEP TIMER"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $C_Text
$title.Location = New-Object System.Drawing.Point(20, 15)
$title.AutoSize = $true
$form.Controls.Add($title)

$version = New-Object System.Windows.Forms.Label
$version.Text = "PRO"
$version.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$version.ForeColor = $C_Accent
$version.Location = New-Object System.Drawing.Point(210, 22)
$version.AutoSize = $true
$form.Controls.Add($version)

# Time Display Panel
$timePanel = New-Object System.Windows.Forms.Panel
$timePanel.Size = New-Object System.Drawing.Size(380, 100)
$timePanel.Location = New-Object System.Drawing.Point(25, 60)
$timePanel.BackColor = $C_Panel
$form.Controls.Add($timePanel)

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "$($Settings.Minutes):00"
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 48, [System.Drawing.FontStyle]::Bold)
$timeLabel.ForeColor = $C_Accent
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Size = New-Object System.Drawing.Size(380, 70)
$timeLabel.Location = New-Object System.Drawing.Point(0, 10)
$timePanel.Controls.Add($timeLabel)

$actionLabel = New-Object System.Windows.Forms.Label
$actionLabel.Text = $Settings.Action.ToUpper()
$actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$actionLabel.ForeColor = $C_TextDim
$actionLabel.TextAlign = "MiddleCenter"
$actionLabel.Size = New-Object System.Drawing.Size(380, 25)
$actionLabel.Location = New-Object System.Drawing.Point(0, 75)
$timePanel.Controls.Add($actionLabel)

# Progress Bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(25, 170)
$progress.Size = New-Object System.Drawing.Size(380, 6)
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$progress.Style = "Continuous"
$form.Controls.Add($progress)

# Controls Panel
$controlsPanel = New-Object System.Windows.Forms.Panel
$controlsPanel.Size = New-Object System.Drawing.Size(380, 180)
$controlsPanel.Location = New-Object System.Drawing.Point(25, 190)
$controlsPanel.BackColor = $C_Panel
$form.Controls.Add($controlsPanel)

# Profile
$profileLbl = New-Object System.Windows.Forms.Label
$profileLbl.Text = "Profile"
$profileLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$profileLbl.ForeColor = $C_TextDim
$profileLbl.Location = New-Object System.Drawing.Point(15, 15)
$profileLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($profileLbl)

$profileCombo = New-Object System.Windows.Forms.ComboBox
$profileCombo.Location = New-Object System.Drawing.Point(15, 38)
$profileCombo.Size = New-Object System.Drawing.Size(150, 25)
$profileCombo.DropDownStyle = "DropDownList"
$profileCombo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$profileCombo.BackColor = $C_Card
$profileCombo.ForeColor = $C_Text
$profileCombo.FlatStyle = "Flat"
$profileCombo.Items.Add("(Custom)")
$Profiles.Keys | Sort-Object | ForEach-Object { $profileCombo.Items.Add($_) }
$profileCombo.SelectedIndex = 0
$controlsPanel.Controls.Add($profileCombo)

# Minutes
$minutesLbl = New-Object System.Windows.Forms.Label
$minutesLbl.Text = "Minutes"
$minutesLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$minutesLbl.ForeColor = $C_TextDim
$minutesLbl.Location = New-Object System.Drawing.Point(180, 15)
$minutesLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($minutesLbl)

$minutesInput = New-Object System.Windows.Forms.NumericUpDown
$minutesInput.Location = New-Object System.Drawing.Point(180, 38)
$minutesInput.Size = New-Object System.Drawing.Size(80, 25)
$minutesInput.Minimum = 1
$minutesInput.Maximum = 1440
$minutesInput.Value = $Settings.Minutes
$minutesInput.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$minutesInput.BackColor = $C_Card
$minutesInput.ForeColor = $C_Text
$minutesInput.BorderStyle = "None"
$controlsPanel.Controls.Add($minutesInput)

# Action
$actionLbl = New-Object System.Windows.Forms.Label
$actionLbl.Text = "Action"
$actionLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$actionLbl.ForeColor = $C_TextDim
$actionLbl.Location = New-Object System.Drawing.Point(275, 15)
$actionLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($actionLbl)

$actionCombo = New-Object System.Windows.Forms.ComboBox
$actionCombo.Location = New-Object System.Drawing.Point(275, 38)
$actionCombo.Size = New-Object System.Drawing.Size(90, 25)
$actionCombo.DropDownStyle = "DropDownList"
$actionCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$actionCombo.BackColor = $C_Card
$actionCombo.ForeColor = $C_Text
$actionCombo.FlatStyle = "Flat"
$actionCombo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$actionCombo.SelectedItem = $Settings.Action
$controlsPanel.Controls.Add($actionCombo)

# Quick Presets
$presetLbl = New-Object System.Windows.Forms.Label
$presetLbl.Text = "Quick Set"
$presetLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$presetLbl.ForeColor = $C_TextDim
$presetLbl.Location = New-Object System.Drawing.Point(15, 80)
$presetLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($presetLbl)

$preset15 = New-Object System.Windows.Forms.Button
$preset15.Text = "15m"
$preset15.Size = New-Object System.Drawing.Size(55, 32)
$preset15.Location = New-Object System.Drawing.Point(15, 105)
$preset15.BackColor = $C_Card
$preset15.ForeColor = $C_Text
$preset15.FlatStyle = "Flat"
$preset15.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$preset15.Add_Click({ $minutesInput.Value = 15; $profileCombo.SelectedIndex = 0 })
$controlsPanel.Controls.Add($preset15)

$preset30 = New-Object System.Windows.Forms.Button
$preset30.Text = "30m"
$preset30.Size = New-Object System.Drawing.Size(55, 32)
$preset30.Location = New-Object System.Drawing.Point(78, 105)
$preset30.BackColor = $C_Card
$preset30.ForeColor = $C_Text
$preset30.FlatStyle = "Flat"
$preset30.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$preset30.Add_Click({ $minutesInput.Value = 30; $profileCombo.SelectedIndex = 0 })
$controlsPanel.Controls.Add($preset30)

$preset60 = New-Object System.Windows.Forms.Button
$preset60.Text = "60m"
$preset60.Size = New-Object System.Drawing.Size(55, 32)
$preset60.Location = New-Object System.Drawing.Point(141, 105)
$preset60.BackColor = $C_Card
$preset60.ForeColor = $C_Text
$preset60.FlatStyle = "Flat"
$preset60.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$preset60.Add_Click({ $minutesInput.Value = 60; $profileCombo.SelectedIndex = 0 })
$controlsPanel.Controls.Add($preset60)

$preset120 = New-Object System.Windows.Forms.Button
$preset120.Text = "120m"
$preset120.Size = New-Object System.Drawing.Size(55, 32)
$preset120.Location = New-Object System.Drawing.Point(204, 105)
$preset120.BackColor = $C_Card
$preset120.ForeColor = $C_Text
$preset120.FlatStyle = "Flat"
$preset120.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$preset120.Add_Click({ $minutesInput.Value = 120; $profileCombo.SelectedIndex = 0 })
$controlsPanel.Controls.Add($preset120)

# Main Button
$mainButton = New-Object System.Windows.Forms.Button
$mainButton.Text = "START TIMER"
$mainButton.Size = New-Object System.Drawing.Size(260, 50)
$mainButton.Location = New-Object System.Drawing.Point(60, 145)
$mainButton.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$mainButton.BackColor = $C_Accent
$mainButton.ForeColor = [System.Drawing.Color]::Black
$mainButton.FlatStyle = "Flat"
$mainButton.FlatAppearance.BorderSize = 0
$mainButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$controlsPanel.Controls.Add($mainButton)

# Bottom Buttons
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "CANCEL"
$cancelButton.Size = New-Object System.Drawing.Size(100, 35)
$cancelButton.Location = New-Object System.Drawing.Point(25, 385)
$cancelButton.BackColor = $C_Danger
$cancelButton.ForeColor = $C_Text
$cancelButton.FlatStyle = "Flat"
$cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cancelButton.Visible = $false
$form.Controls.Add($cancelButton)

$settingsButton = New-Object System.Windows.Forms.Button
$settingsButton.Text = "Settings"
$settingsButton.Size = New-Object System.Drawing.Size(100, 35)
$settingsButton.Location = New-Object System.Drawing.Point(25, 385)
$settingsButton.BackColor = $C_Card
$settingsButton.ForeColor = $C_Text
$settingsButton.FlatStyle = "Flat"
$settingsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($settingsButton)

# Event Handlers
$profileCombo.Add_SelectedIndexChanged({
    $sel = $profileCombo.SelectedItem
    if ($sel -ne "(Custom)" -and $Profiles[$sel]) {
        $minutesInput.Value = $Profiles[$sel].Minutes
        $actionCombo.SelectedItem = $Profiles[$sel].Action
        $timeLabel.Text = "$($Profiles[$sel].Minutes):00"
        $actionLabel.Text = $Profiles[$sel].Action.ToUpper()
    }
})

$actionCombo.Add_SelectedIndexChanged({ $actionLabel.Text = $actionCombo.SelectedItem.ToString().ToUpper() })

$minutesInput.Add_ValueChanged({ if (!$Active) { $timeLabel.Text = "$($minutesInput.Value):00" } })

$cancelButton.Add_Click({
    if ($Active) {
        $Active = $false
        $Timer.Stop()
        $timeLabel.Text = "$($minutesInput.Value):00"
        $timeLabel.ForeColor = $C_Accent
        $progress.Value = 0
        $mainButton.Text = "START TIMER"
        $mainButton.BackColor = $C_Accent
        $mainButton.ForeColor = [System.Drawing.Color]::Black
        $minutesInput.Enabled = $true
        $actionCombo.Enabled = $true
        $profileCombo.Enabled = $true
        $actionLabel.Text = $actionCombo.SelectedItem.ToString().ToUpper()
        $actionLabel.ForeColor = $C_TextDim
        $cancelButton.Visible = $false
        $settingsButton.Visible = $true
    }
})

$mainButton.Add_Click({
    if (!$Active) {
        $Active = $true
        $Total = [int]$minutesInput.Value * 60
        $Remaining = $Total
        
        $mainButton.Text = "STOP"
        $mainButton.BackColor = $C_Danger
        $mainButton.ForeColor = $C_Text
        $minutesInput.Enabled = $false
        $actionCombo.Enabled = $false
        $profileCombo.Enabled = $false
        $actionLabel.Text = $actionCombo.SelectedItem.ToString().ToUpper()
        $actionLabel.ForeColor = $C_Success
        $timeLabel.ForeColor = $C_Success
        $settingsButton.Visible = $false
        $cancelButton.Visible = $true
        
        $Timer = New-Object System.Windows.Forms.Timer
        $Timer.Interval = 1000
        $Timer.Add_Tick({
            if ($Remaining -gt 0 -and $Active) {
                $Remaining--
                $m = [math]::Floor($Remaining / 60)
                $s = $Remaining % 60
                $timeLabel.Text = "{0:D2}:{1:D2}" -f $m, $s
                
                $pct = 100 - (($Remaining / $Total) * 100)
                $progress.Value = [math]::Min(100, [math]::Max(0, [int]$pct))
                
                if ($Remaining -eq ($Settings.WarningMinutes * 60) -and $Settings.WarningMinutes -gt 0) {
                    if ($Settings.PlaySound) { try { [System.Media.SystemSounds]::Exclamation.Play() } catch {} }
                    $res = Show-SnoozeDialog -ActionName $actionCombo.SelectedItem -MinutesLeft $Settings.WarningMinutes
                    if ($res -eq "Snooze") {
                        $Remaining += 600
                        $Total += 600
                    }
                }
            } else {
                $Timer.Stop()
                $Active = $false
                switch ($actionCombo.SelectedItem) {
                    "Shutdown" { if ($Settings.ForceShutdown) { Stop-Computer -Force } else { Stop-Computer } }
                    "Restart" { if ($Settings.ForceShutdown) { Restart-Computer -Force } else { Restart-Computer } }
                    "Sleep" { 
                        Add-Type '[DllImport("PowrProf.dll")]public static extern bool SetSuspendState(bool h, bool f, bool d);' -Name P -Namespace S
                        [S.P]::SetSuspendState($false, $true, $false) | Out-Null
                    }
                    "Hibernate" {
                        Add-Type '[DllImport("PowrProf.dll")]public static extern bool SetSuspendState(bool h, bool f, bool d);' -Name P -Namespace S
                        [S.P]::SetSuspendState($true, $true, $false) | Out-Null
                    }
                    "Lock" { rundll32.exe user32.dll,LockWorkStation }
                    "Logoff" { shutdown.exe /l }
                }
            }
        })
        $Timer.Start()
    } else {
        $Active = $false
        $Timer.Stop()
        $timeLabel.Text = "$($minutesInput.Value):00"
        $timeLabel.ForeColor = $C_Accent
        $progress.Value = 0
        $mainButton.Text = "START TIMER"
        $mainButton.BackColor = $C_Accent
        $mainButton.ForeColor = [System.Drawing.Color]::Black
        $minutesInput.Enabled = $true
        $actionCombo.Enabled = $true
        $profileCombo.Enabled = $true
        $actionLabel.Text = $actionCombo.SelectedItem.ToString().ToUpper()
        $actionLabel.ForeColor = $C_TextDim
        $cancelButton.Visible = $false
        $settingsButton.Visible = $true
    }
})

$settingsButton.Add_Click({
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Settings"
    $sf.Size = New-Object System.Drawing.Size(320, 240)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"
    $sf.BackColor = $C_BG
    $sf.MaximizeBox = $false
    
    $y = 20
    
    $wl = New-Object System.Windows.Forms.Label
    $wl.Text = "Warning (minutes before):"
    $wl.Location = New-Object System.Drawing.Point(20, $y)
    $wl.Size = New-Object System.Drawing.Size(150, 25)
    $wl.ForeColor = $C_TextDim
    $sf.Controls.Add($wl)
    
    $wi = New-Object System.Windows.Forms.NumericUpDown
    $wi.Location = New-Object System.Drawing.Point(180, $y)
    $wi.Size = New-Object System.Drawing.Size(60, 25)
    $wi.Minimum = 0
    $wi.Maximum = 30
    $wi.Value = $Settings.WarningMinutes
    $wi.BackColor = $C_Card
    $wi.ForeColor = $C_Text
    $sf.Controls.Add($wi)
    $y += 45
    
    $soundChk = New-Object System.Windows.Forms.CheckBox
    $soundChk.Text = "Play notification sounds"
    $soundChk.Location = New-Object System.Drawing.Point(20, $y)
    $soundChk.Size = New-Object System.Drawing.Size(250, 25)
    $soundChk.Checked = $Settings.PlaySound
    $soundChk.ForeColor = $C_Text
    $sf.Controls.Add($soundChk)
    $y += 35
    
    $forceChk = New-Object System.Windows.Forms.CheckBox
    $forceChk.Text = "Force shutdown/restart"
    $forceChk.Location = New-Object System.Drawing.Point(20, $y)
    $forceChk.Size = New-Object System.Drawing.Size(250, 25)
    $forceChk.Checked = $Settings.ForceShutdown
    $forceChk.ForeColor = $C_Text
    $sf.Controls.Add($forceChk)
    $y += 50
    
    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "SAVE"
    $saveBtn.Size = New-Object System.Drawing.Size(100, 38)
    $saveBtn.Location = New-Object System.Drawing.Point(110, $y)
    $saveBtn.BackColor = $C_Accent
    $saveBtn.ForeColor = [System.Drawing.Color]::Black
    $saveBtn.FlatStyle = "Flat"
    $saveBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $saveBtn.Add_Click({
        $Settings.WarningMinutes = [int]$wi.Value
        $Settings.PlaySound = $soundChk.Checked
        $Settings.ForceShutdown = $forceChk.Checked
        $Settings.Minutes = [int]$minutesInput.Value
        $Settings.Action = $actionCombo.SelectedItem
        $Settings | ConvertTo-Json | Set-Content $SettingsPath
        [System.Windows.Forms.MessageBox]::Show("Settings saved!", "Done", "OK", "Information")
        $sf.Close()
    })
    $sf.Controls.Add($saveBtn)
    
    $sf.ShowDialog()
})

$form.Add_FormClosing({
    $Settings.Minutes = [int]$minutesInput.Value
    $Settings.Action = $actionCombo.SelectedItem
    $Settings | ConvertTo-Json | Set-Content $SettingsPath
})

$form.ShowDialog()
