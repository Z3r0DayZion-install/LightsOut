# Sleep Timer - Improved UI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings
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

# Colors - Better contrast
$C_BG = [System.Drawing.Color]::FromArgb(22, 22, 30)
$C_Panel = [System.Drawing.Color]::FromArgb(35, 35, 50)
$C_Card = [System.Drawing.Color]::FromArgb(50, 50, 70)
$C_CardHover = [System.Drawing.Color]::FromArgb(65, 65, 90)
$C_Text = [System.Drawing.Color]::White
$C_TextDim = [System.Drawing.Color]::FromArgb(160, 160, 180)
$C_Accent = [System.Drawing.Color]::FromArgb(0, 200, 255)
$C_Success = [System.Drawing.Color]::FromArgb(0, 230, 150)
$C_Warning = [System.Drawing.Color]::FromArgb(255, 200, 50)
$C_Danger = [System.Drawing.Color]::FromArgb(255, 70, 70)

# State
$Active = $false
$Timer = $null
$Remaining = 0
$Total = 0

function Show-SnoozeDialog($ActionName, $MinutesLeft) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Timer Warning"
    $form.Size = New-Object System.Drawing.Size(380, 200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.BackColor = $C_BG
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "$ActionName in $MinutesLeft minutes"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $C_Warning
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(340, 35)
    $form.Controls.Add($lbl)
    
    $sublbl = New-Object System.Windows.Forms.Label
    $sublbl.Text = "Your computer will $ActionName soon"
    $sublbl.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $sublbl.ForeColor = $C_Text
    $sublbl.Location = New-Object System.Drawing.Point(20, 55)
    $sublbl.Size = New-Object System.Drawing.Size(340, 25)
    $form.Controls.Add($sublbl)
    
    $snoozeBtn = New-Object System.Windows.Forms.Button
    $snoozeBtn.Text = "SNOOZE (+10 min)"
    $snoozeBtn.Size = New-Object System.Drawing.Size(140, 45)
    $snoozeBtn.Location = New-Object System.Drawing.Point(40, 100)
    $snoozeBtn.BackColor = $C_Card
    $snoozeBtn.ForeColor = $C_Text
    $snoozeBtn.FlatStyle = "Flat"
    $snoozeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $snoozeBtn.Add_Click({ $form.Tag = "Snooze"; $form.Close() })
    $form.Controls.Add($snoozeBtn)
    
    $proceedBtn = New-Object System.Windows.Forms.Button
    $proceedBtn.Text = "PROCEED NOW"
    $proceedBtn.Size = New-Object System.Drawing.Size(130, 45)
    $proceedBtn.Location = New-Object System.Drawing.Point(200, 100)
    $proceedBtn.BackColor = $C_Warning
    $proceedBtn.ForeColor = [System.Drawing.Color]::Black
    $proceedBtn.FlatStyle = "Flat"
    $proceedBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $proceedBtn.Add_Click({ $form.Tag = "Proceed"; $form.Close() })
    $form.Controls.Add($proceedBtn)
    
    $form.ShowDialog() | Out-Null
    return $form.Tag
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer"
$form.Size = New-Object System.Drawing.Size(460, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.BackColor = $C_BG
$form.MaximizeBox = $false

# Title
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Size = New-Object System.Drawing.Size(460, 60)
$titlePanel.BackColor = $C_Panel
$form.Controls.Add($titlePanel)

$title = New-Object System.Windows.Forms.Label
$title.Text = "SLEEP TIMER"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $C_Text
$title.Location = New-Object System.Drawing.Point(25, 12)
$title.AutoSize = $true
$titlePanel.Controls.Add($title)

$version = New-Object System.Windows.Forms.Label
$version.Text = "PRO"
$version.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$version.ForeColor = $C_Accent
$version.Location = New-Object System.Drawing.Point(195, 18)
$version.AutoSize = $true
$titlePanel.Controls.Add($version)

# Status Label (above timer)
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready to start"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$statusLabel.ForeColor = $C_TextDim
$statusLabel.Location = New-Object System.Drawing.Point(25, 75)
$statusLabel.Size = New-Object System.Drawing.Size(400, 25)
$form.Controls.Add($statusLabel)

# Timer Display - Bigger and centered
$timePanel = New-Object System.Windows.Forms.Panel
$timePanel.Size = New-Object System.Drawing.Size(400, 130)
$timePanel.Location = New-Object System.Drawing.Point(25, 105)
$timePanel.BackColor = $C_Panel
$form.Controls.Add($timePanel)

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "$($Settings.Minutes):00"
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 56, [System.Drawing.FontStyle]::Bold)
$timeLabel.ForeColor = $C_Accent
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Size = New-Object System.Drawing.Size(400, 85)
$timeLabel.Location = New-Object System.Drawing.Point(0, 10)
$timePanel.Controls.Add($timeLabel)

$actionLabel = New-Object System.Windows.Forms.Label
$actionLabel.Text = $Settings.Action.ToUpper()
$actionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$actionLabel.ForeColor = $C_TextDim
$actionLabel.TextAlign = "MiddleCenter"
$actionLabel.Size = New-Object System.Drawing.Size(400, 30)
$actionLabel.Location = New-Object System.Drawing.Point(0, 95)
$timePanel.Controls.Add($actionLabel)

# Progress Bar - Thicker and styled
$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.Size = New-Object System.Drawing.Size(400, 20)
$progressPanel.Location = New-Object System.Drawing.Point(25, 245)
$progressPanel.BackColor = $C_Card
$form.Controls.Add($progressPanel)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(3, 3)
$progress.Size = New-Object System.Drawing.Size(394, 14)
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$progress.Style = "Continuous"
$progressPanel.Controls.Add($progress)

# Controls Panel
$controlsPanel = New-Object System.Windows.Forms.Panel
$controlsPanel.Size = New-Object System.Drawing.Size(400, 200)
$controlsPanel.Location = New-Object System.Drawing.Point(25, 280)
$controlsPanel.BackColor = $C_Panel
$form.Controls.Add($controlsPanel)

# Profile
$profileLbl = New-Object System.Windows.Forms.Label
$profileLbl.Text = "Profile"
$profileLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$profileLbl.ForeColor = $C_TextDim
$profileLbl.Location = New-Object System.Drawing.Point(20, 15)
$profileLbl.Size = New-Object System.Drawing.Size(100, 20)
$controlsPanel.Controls.Add($profileLbl)

$profileCombo = New-Object System.Windows.Forms.ComboBox
$profileCombo.Location = New-Object System.Drawing.Point(20, 38)
$profileCombo.Size = New-Object System.Drawing.Size(170, 28)
$profileCombo.DropDownStyle = "DropDownList"
$profileCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$profileCombo.BackColor = $C_Card
$profileCombo.ForeColor = $C_Text
$profileCombo.FlatStyle = "Flat"
$profileCombo.Items.Add("(Custom)")
$Profiles.Keys | Sort-Object | ForEach-Object { $profileCombo.Items.Add($_) }
$profileCombo.SelectedIndex = 0
$controlsPanel.Controls.Add($profileCombo)

# Minutes
$minutesLbl = New-Object System.Windows.Forms.Label
$minutesLbl.Text = "Duration"
$minutesLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$minutesLbl.ForeColor = $C_TextDim
$minutesLbl.Location = New-Object System.Drawing.Point(210, 15)
$minutesLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($minutesLbl)

$minutesInput = New-Object System.Windows.Forms.NumericUpDown
$minutesInput.Location = New-Object System.Drawing.Point(210, 38)
$minutesInput.Size = New-Object System.Drawing.Size(80, 28)
$minutesInput.Minimum = 1
$minutesInput.Maximum = 1440
$minutesInput.Value = $Settings.Minutes
$minutesInput.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$minutesInput.BackColor = $C_Card
$minutesInput.ForeColor = $C_Text
$minutesInput.BorderStyle = "None"
$controlsPanel.Controls.Add($minutesInput)

$minutesTxt = New-Object System.Windows.Forms.Label
$minutesTxt.Text = "min"
$minutesTxt.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$minutesTxt.ForeColor = $C_TextDim
$minutesTxt.Location = New-Object System.Drawing.Point(295, 42)
$minutesTxt.Size = New-Object System.Drawing.Size(40, 25)
$controlsPanel.Controls.Add($minutesTxt)

# Action
$actionLbl = New-Object System.Windows.Forms.Label
$actionLbl.Text = "Action"
$actionLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$actionLbl.ForeColor = $C_TextDim
$actionLbl.Location = New-Object System.Drawing.Point(340, 15)
$actionLbl.Size = New-Object System.Drawing.Size(60, 20)
$controlsPanel.Controls.Add($actionLbl)

$actionCombo = New-Object System.Windows.Forms.ComboBox
$actionCombo.Location = New-Object System.Drawing.Point(340, 38)
$actionCombo.Size = New-Object System.Drawing.Size(95, 28)
$actionCombo.DropDownStyle = "DropDownList"
$actionCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$actionCombo.BackColor = $C_Card
$actionCombo.ForeColor = $C_Text
$actionCombo.FlatStyle = "Flat"
$actionCombo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$actionCombo.SelectedItem = $Settings.Action
$controlsPanel.Controls.Add($actionCombo)

# Quick Presets Row
$presetY = 80
$presetLbl = New-Object System.Windows.Forms.Label
$presetLbl.Text = "Quick Set"
$presetLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$presetLbl.ForeColor = $C_TextDim
$presetLbl.Location = New-Object System.Drawing.Point(20, $presetY)
$presetLbl.Size = New-Object System.Drawing.Size(80, 20)
$controlsPanel.Controls.Add($presetLbl)

$presets = @(
    @{ Text = "15m"; Val = 15; X = 20 },
    @{ Text = "30m"; Val = 30; X = 82 },
    @{ Text = "60m"; Val = 60; X = 144 },
    @{ Text = "120m"; Val = 120; X = 206 }
)

foreach ($p in $presets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $p.Text
    $btn.Size = New-Object System.Drawing.Size(55, 32)
    $btn.Location = New-Object System.Drawing.Point($p.X, $presetY + 22)
    $btn.BackColor = $C_Card
    $btn.ForeColor = $C_Text
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $val = $p.Val
    $btn.Add_Click({ $minutesInput.Value = $val; $profileCombo.SelectedIndex = 0 })
    $btn.Add_MouseEnter({ $btn.BackColor = $C_CardHover })
    $btn.Add_MouseLeave({ $btn.BackColor = $C_Card })
    $controlsPanel.Controls.Add($btn)
}

# Main Button - Bigger and centered
$mainButton = New-Object System.Windows.Forms.Button
$mainButton.Text = "START TIMER"
$mainButton.Size = New-Object System.Drawing.Size(300, 55)
$mainButton.Location = New-Object System.Drawing.Point(50, 145)
$mainButton.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$mainButton.BackColor = $C_Accent
$mainButton.ForeColor = [System.Drawing.Color]::Black
$mainButton.FlatStyle = "Flat"
$mainButton.FlatAppearance.BorderSize = 0
$mainButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$controlsPanel.Controls.Add($mainButton)

# Bottom area - Cancel and Settings
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Size = New-Object System.Drawing.Size(400, 50)
$bottomPanel.Location = New-Object System.Drawing.Point(25, 490)
$form.Controls.Add($bottomPanel)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "CANCEL TIMER"
$cancelButton.Size = New-Object System.Drawing.Size(140, 40)
$cancelButton.Location = New-Object System.Drawing.Point(0, 5)
$cancelButton.BackColor = $C_Danger
$cancelButton.ForeColor = $C_Text
$cancelButton.FlatStyle = "Flat"
$cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cancelButton.FlatAppearance.BorderSize = 0
$cancelButton.Visible = $false
$cancelButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$bottomPanel.Controls.Add($cancelButton)

$settingsButton = New-Object System.Windows.Forms.Button
$settingsButton.Text = "Settings"
$settingsButton.Size = New-Object System.Drawing.Size(100, 40)
$settingsButton.Location = New-Object System.Drawing.Point(0, 5)
$settingsButton.BackColor = $C_Card
$settingsButton.ForeColor = $C_Text
$settingsButton.FlatStyle = "Flat"
$settingsButton.FlatAppearance.BorderSize = 0
$settingsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$settingsButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$bottomPanel.Controls.Add($settingsButton)

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
        $statusLabel.Text = "Timer cancelled"
        $statusLabel.ForeColor = $C_TextDim
        $mainButton.Text = "START TIMER"
        $mainButton.BackColor = $C_Accent
        $mainButton.ForeColor = [System.Drawing.Color]::Black
        $mainButton.Visible = $true
        $minutesInput.Enabled = $true
        $actionCombo.Enabled = $true
        $profileCombo.Enabled = $true
        $actionLabel.Text = $actionCombo.SelectedItem.ToString().ToUpper()
        $actionLabel.ForeColor = $C_TextDim
        $cancelButton.Visible = $false
        $settingsButton.Visible = $true
        foreach ($ctrl in $controlsPanel.Controls) { 
            if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl.Text -match "m$") { $ctrl.Enabled = $true }
        }
    }
})

$mainButton.Add_Click({
    if (!$Active) {
        $Active = $true
        $Total = [int]$minutesInput.Value * 60
        $Remaining = $Total
        
        $statusLabel.Text = "Timer running - $actionCombo.SelectedItem in $minutesInput.Value minutes"
        $statusLabel.ForeColor = $C_Success
        $mainButton.Text = "STOP TIMER"
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
        foreach ($ctrl in $controlsPanel.Controls) { 
            if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl.Text -match "m$") { $ctrl.Enabled = $false }
        }
        
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
                        $statusLabel.Text = "Timer snoozed - +10 minutes added"
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
        $statusLabel.Text = "Timer stopped"
        $statusLabel.ForeColor = $C_TextDim
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
        foreach ($ctrl in $controlsPanel.Controls) { 
            if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl.Text -match "m$") { $ctrl.Enabled = $true }
        }
    }
})

$settingsButton.Add_Click({
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Settings"
    $sf.Size = New-Object System.Drawing.Size(320, 260)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"
    $sf.BackColor = $C_BG
    $sf.MaximizeBox = $false
    
    $y = 20
    
    $wl = New-Object System.Windows.Forms.Label
    $wl.Text = "Warning (minutes before):"
    $wl.Location = New-Object System.Drawing.Point(20, $y)
    $wl.Size = New-Object System.Drawing.Size(160, 25)
    $wl.ForeColor = $C_TextDim
    $sf.Controls.Add($wl)
    
    $wi = New-Object System.Windows.Forms.NumericUpDown
    $wi.Location = New-Object System.Drawing.Point(190, $y)
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
    $forceChk.Text = "Force shutdown/restart (no confirmation)"
    $forceChk.Location = New-Object System.Drawing.Point(20, $y)
    $forceChk.Size = New-Object System.Drawing.Size(280, 25)
    $forceChk.Checked = $Settings.ForceShutdown
    $forceChk.ForeColor = $C_Text
    $sf.Controls.Add($forceChk)
    $y += 55
    
    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "SAVE"
    $saveBtn.Size = New-Object System.Drawing.Size(110, 42)
    $saveBtn.Location = New-Object System.Drawing.Point(105, $y)
    $saveBtn.BackColor = $C_Accent
    $saveBtn.ForeColor = [System.Drawing.Color]::Black
    $saveBtn.FlatStyle = "Flat"
    $saveBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $saveBtn.FlatAppearance.BorderSize = 0
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
