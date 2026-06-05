#Requires -Version 5.1
# Sleep Timer Ultimate - Final Edition
param([switch]$Tray)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings
$SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimerUltimate\settings.json"
$SettingsDir = Split-Path $SettingsPath -Parent
if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }

$script:Settings = @{
    Minutes = 30
    Action = "Sleep"
    WarningMinutes = 5
    PlaySound = $true
    MinimizeToTray = $false
    LastProfile = ""
    ForceShutdown = $true
}

if (Test-Path $SettingsPath) {
    try { $loaded = Get-Content $SettingsPath | ConvertFrom-Json; $loaded.PSObject.Properties | ForEach-Object { $script:Settings[$_.Name] = $_.Value } } catch {}
}

$script:Profiles = @{
    "Movie Night" = @{ Minutes = 120; Action = "Sleep" }
    "Work Session" = @{ Minutes = 60; Action = "Shutdown" }
    "Quick Nap" = @{ Minutes = 20; Action = "Sleep" }
    "Bedtime" = @{ Minutes = 30; Action = "Sleep" }
    "Download" = @{ Minutes = 180; Action = "Shutdown" }
}

$ProfilesPath = Join-Path $env:LOCALAPPDATA "SleepTimerUltimate\profiles.json"
if (Test-Path $ProfilesPath) {
    try { $loaded = Get-Content $ProfilesPath | ConvertFrom-Json; $loaded.PSObject.Properties | ForEach-Object { $script:Profiles[$_.Name] = $_.Value } } catch {}
}

# Modern Dark Theme
$script:Colors = @{
    Background = [System.Drawing.Color]::FromArgb(22, 22, 30)
    Surface = [System.Drawing.Color]::FromArgb(35, 35, 48)
    SurfaceLight = [System.Drawing.Color]::FromArgb(50, 50, 68)
    Text = [System.Drawing.Color]::FromArgb(255, 255, 255)
    TextMuted = [System.Drawing.Color]::FromArgb(140, 140, 160)
    Accent = [System.Drawing.Color]::FromArgb(0, 180, 255)
    AccentGlow = [System.Drawing.Color]::FromArgb(0, 120, 255)
    Success = [System.Drawing.Color]::FromArgb(0, 230, 150)
    Warning = [System.Drawing.Color]::FromArgb(255, 180, 0)
    Danger = [System.Drawing.Color]::FromArgb(255, 70, 70)
}

$script:TimerActive = $false
$script:Timer = $null
$script:RemainingSeconds = 0
$script:TotalSeconds = 0
$script:NotifyIcon = $null

# Snooze Dialog
function Show-SnoozeDialog {
    param([string]$ActionName, [int]$Minutes)
    
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Warning"
    $dlg.Size = New-Object System.Drawing.Size(400, 200)
    $dlg.StartPosition = "CenterScreen"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.BackColor = $script:Colors.Background
    $dlg.ForeColor = $script:Colors.Text
    $dlg.TopMost = $true
    
    $warn = New-Object System.Windows.Forms.Label
    $warn.Text = "!"
    $warn.Font = New-Object System.Drawing.Font("Segoe UI", 40, [System.Drawing.FontStyle]::Bold)
    $warn.ForeColor = $script:Colors.Warning
    $warn.Location = New-Object System.Drawing.Point(30, 20)
    $warn.Size = New-Object System.Drawing.Size(50, 60)
    $dlg.Controls.Add($warn)
    
    $msg = New-Object System.Windows.Forms.Label
    $msg.Text = "$ActionName in $Minutes minutes!"
    $msg.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $msg.ForeColor = $script:Colors.Text
    $msg.Location = New-Object System.Drawing.Point(100, 25)
    $msg.Size = New-Object System.Drawing.Size(280, 30)
    $dlg.Controls.Add($msg)
    
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "Click SNOOZE to delay 10 minutes"
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $sub.ForeColor = $script:Colors.TextMuted
    $sub.Location = New-Object System.Drawing.Point(100, 60)
    $sub.Size = New-Object System.Drawing.Size(280, 25)
    $dlg.Controls.Add($sub)
    
    $snz = New-Object System.Windows.Forms.Button
    $snz.Text = "SNOOZE +10m"
    $snz.Size = New-Object System.Drawing.Size(120, 40)
    $snz.Location = New-Object System.Drawing.Point(70, 110)
    $snz.BackColor = $script:Colors.SurfaceLight
    $snz.ForeColor = $script:Colors.Text
    $snz.FlatStyle = "Flat"
    $snz.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $snz.Add_Click({ $dlg.Tag = "Snooze"; $dlg.Close() })
    $dlg.Controls.Add($snz)
    
    $pro = New-Object System.Windows.Forms.Button
    $pro.Text = "PROCEED"
    $pro.Size = New-Object System.Drawing.Size(100, 40)
    $pro.Location = New-Object System.Drawing.Point(210, 110)
    $pro.BackColor = $script:Colors.Accent
    $pro.ForeColor = [System.Drawing.Color]::FromArgb(22, 22, 30)
    $pro.FlatStyle = "Flat"
    $pro.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $pro.Add_Click({ $dlg.Tag = "Proceed"; $dlg.Close() })
    $dlg.Controls.Add($pro)
    
    $dlg.ShowDialog() | Out-Null
    return $dlg.Tag
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer Ultimate"
$form.Size = New-Object System.Drawing.Size(520, 550)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $script:Colors.Background

# Main Panel with border effect
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.Padding = New-Object System.Windows.Forms.Padding(25)
$panel.BackColor = $script:Colors.Background
$form.Controls.Add($panel)

# Header
$hdr = New-Object System.Windows.Forms.Label
$hdr.Text = "SLEEP TIMER"
$hdr.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$hdr.ForeColor = $script:Colors.Text
$hdr.Location = New-Object System.Drawing.Point(25, 20)
$hdr.AutoSize = $true
$panel.Controls.Add($hdr)

$ver = New-Object System.Windows.Forms.Label
$ver.Text = "ULTIMATE"
$ver.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$ver.ForeColor = $script:Colors.Accent
$ver.Location = New-Object System.Drawing.Point(220, 35)
$ver.AutoSize = $true
$panel.Controls.Add($ver)

# Close X
$close = New-Object System.Windows.Forms.Label
$close.Text = "X"
$close.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$close.ForeColor = $script:Colors.TextMuted
$close.Location = New-Object System.Drawing.Point(460, 20)
$close.Size = New-Object System.Drawing.Size(25, 25)
$close.Cursor = "Hand"
$close.Add_Click({ $form.Close() })
$close.Add_MouseEnter({ $close.ForeColor = $script:Colors.Danger })
$close.Add_MouseLeave({ $close.ForeColor = $script:Colors.TextMuted })
$panel.Controls.Add($close)

# Big Time Display
$bigTime = New-Object System.Windows.Forms.Label
$bigTime.Text = "{0:D2}:00" -f $script:Settings.Minutes
$bigTime.Font = New-Object System.Drawing.Font("Segoe UI Light", 72)
$bigTime.ForeColor = $script:Colors.Accent
$bigTime.TextAlign = "MiddleCenter"
$bigTime.Size = New-Object System.Drawing.Size(470, 120)
$bigTime.Location = New-Object System.Drawing.Point(0, 80)
$panel.Controls.Add($bigTime)

# Action Label
$actLabel = New-Object System.Windows.Forms.Label
$actLabel.Text = $script:Settings.Action.ToUpper()
$actLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$actLabel.ForeColor = $script:Colors.TextMuted
$actLabel.TextAlign = "MiddleCenter"
$actLabel.Size = New-Object System.Drawing.Size(470, 30)
$actLabel.Location = New-Object System.Drawing.Point(0, 200)
$panel.Controls.Add($actLabel)

# Progress Bar
$prog = New-Object System.Windows.Forms.ProgressBar
$prog.Location = New-Object System.Drawing.Point(25, 240)
$prog.Size = New-Object System.Drawing.Size(470, 8)
$prog.Minimum = 0
$prog.Maximum = 100
$prog.Value = 0
$prog.Style = "Continuous"
$prog.BackColor = $script:Colors.Surface
$prog.ForeColor = $script:Colors.Accent
$panel.Controls.Add($prog)

# Profile Section
$profLbl = New-Object System.Windows.Forms.Label
$profLbl.Text = "PROFILE"
$profLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$profLbl.ForeColor = $script:Colors.TextMuted
$profLbl.Location = New-Object System.Drawing.Point(25, 270)
$profLbl.Size = New-Object System.Drawing.Size(60, 25)
$panel.Controls.Add($profLbl)

$profCombo = New-Object System.Windows.Forms.ComboBox
$profCombo.Location = New-Object System.Drawing.Point(95, 265)
$profCombo.Size = New-Object System.Drawing.Size(180, 28)
$profCombo.DropDownStyle = "DropDownList"
$profCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$profCombo.BackColor = $script:Colors.Surface
$profCombo.ForeColor = $script:Colors.Text
$profCombo.FlatStyle = "Flat"
$profCombo.Items.Add("(Custom)")
$script:Profiles.Keys | Sort-Object | ForEach-Object { $profCombo.Items.Add($_) }
if ($script:Settings.LastProfile -and $script:Profiles[$script:Settings.LastProfile]) {
    $profCombo.SelectedItem = $script:Settings.LastProfile
} else {
    $profCombo.SelectedIndex = 0
}
$panel.Controls.Add($profCombo)

# Controls Row
$ctrlY = 310

# Minutes
$minLbl = New-Object System.Windows.Forms.Label
$minLbl.Text = "MINUTES"
$minLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$minLbl.ForeColor = $script:Colors.TextMuted
$minLbl.Location = New-Object System.Drawing.Point(25, $ctrlY)
$minLbl.Size = New-Object System.Drawing.Size(80, 25)
$panel.Controls.Add($minLbl)

$minInput = New-Object System.Windows.Forms.NumericUpDown
$minInput.Location = New-Object System.Drawing.Point(25, $ctrlY + 25)
$minInput.Size = New-Object System.Drawing.Size(100, 35)
$minInput.Minimum = 1
$minInput.Maximum = 1440
$minInput.Value = $script:Settings.Minutes
$minInput.Font = New-Object System.Drawing.Font("Segoe UI", 16)
$minInput.BackColor = $script:Colors.Surface
$minInput.ForeColor = $script:Colors.Text
$minInput.BorderStyle = "None"
$panel.Controls.Add($minInput)

# Action
$actCombo = New-Object System.Windows.Forms.ComboBox
$actCombo.Location = New-Object System.Drawing.Point(145, $ctrlY + 25)
$actCombo.Size = New-Object System.Drawing.Size(140, 35)
$actCombo.DropDownStyle = "DropDownList"
$actCombo.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$actCombo.BackColor = $script:Colors.Surface
$actCombo.ForeColor = $script:Colors.Text
$actCombo.FlatStyle = "Flat"
$actCombo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$actCombo.SelectedItem = $script:Settings.Action
$panel.Controls.Add($actCombo)

# Quick Presets
$presets = @(15, 30, 60)
$px = 305
foreach ($p in $presets) {
    $pb = New-Object System.Windows.Forms.Button
    $pb.Text = "$p`m"
    $pb.Size = New-Object System.Drawing.Size(55, 35)
    $pb.Location = New-Object System.Drawing.Point($px, $ctrlY + 25)
    $pb.BackColor = $script:Colors.SurfaceLight
    $pb.ForeColor = $script:Colors.Text
    $pb.FlatStyle = "Flat"
    $pb.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $v = $p
    $pb.Add_Click({ $minInput.Value = $v; $profCombo.SelectedIndex = 0 })
    $panel.Controls.Add($pb)
    $px += 65
}

# Main Button
$mainBtn = New-Object System.Windows.Forms.Button
$mainBtn.Text = "START TIMER"
$mainBtn.Size = New-Object System.Drawing.Size(320, 55)
$mainBtn.Location = New-Object System.Drawing.Point(100, 410)
$mainBtn.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$mainBtn.BackColor = $script:Colors.Accent
$mainBtn.ForeColor = [System.Drawing.Color]::FromArgb(22, 22, 30)
$mainBtn.FlatStyle = "Flat"
$mainBtn.FlatAppearance.BorderSize = 0
$mainBtn.Cursor = "Hand"
$panel.Controls.Add($mainBtn)

# Cancel Button (hidden by default, shown when running)
$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Text = "CANCEL"
$cancelBtn.Size = New-Object System.Drawing.Size(100, 35)
$cancelBtn.Location = New-Object System.Drawing.Point(25, 480)
$cancelBtn.BackColor = $script:Colors.Danger
$cancelBtn.ForeColor = $script:Colors.Text
$cancelBtn.FlatStyle = "Flat"
$cancelBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$cancelBtn.Visible = $false
$cancelBtn.Add_Click({
    if ($script:TimerActive) {
        $script:TimerActive = $false
        $script:Timer.Stop()
        $bigTime.Text = "{0:D2}:00" -f [int]$minInput.Value
        $prog.Value = 0
        $mainBtn.Text = "START TIMER"
        $mainBtn.BackColor = $script:Colors.Accent
        $mainBtn.ForeColor = [System.Drawing.Color]::FromArgb(22, 22, 30)
        $minInput.Enabled = $true
        $actCombo.Enabled = $true
        $profCombo.Enabled = $true
        $actLabel.Text = $actCombo.SelectedItem.ToString().ToUpper()
        $actLabel.ForeColor = $script:Colors.TextMuted
        $cancelBtn.Visible = $false
        $setBtn.Visible = $true
    }
})
$panel.Controls.Add($cancelBtn)

# Settings Button
$setBtn = New-Object System.Windows.Forms.Button
$setBtn.Text = "Settings"
$setBtn.Size = New-Object System.Drawing.Size(100, 35)
$setBtn.Location = New-Object System.Drawing.Point(25, 480)
$setBtn.BackColor = $script:Colors.Surface
$setBtn.ForeColor = $script:Colors.Text
$setBtn.FlatStyle = "Flat"
$setBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panel.Controls.Add($setBtn)

# Timer Logic
$mainBtn.Add_Click({
    if (-not $script:TimerActive) {
        $script:TimerActive = $true
        $script:TotalSeconds = [int]$minInput.Value * 60
        $script:RemainingSeconds = $script:TotalSeconds
        
        $mainBtn.Text = "STOP TIMER"
        $mainBtn.BackColor = $script:Colors.Danger
        $mainBtn.ForeColor = $script:Colors.Text
        $minInput.Enabled = $false
        $actCombo.Enabled = $false
        $profCombo.Enabled = $false
        $actLabel.Text = $actCombo.SelectedItem.ToString().ToUpper()
        $actLabel.ForeColor = $script:Colors.Success
        $setBtn.Visible = $false
        $cancelBtn.Visible = $true
        
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 1000
        $script:Timer.Add_Tick({
            if ($script:RemainingSeconds -gt 0 -and $script:TimerActive) {
                $script:RemainingSeconds--
                $m = [math]::Floor($script:RemainingSeconds / 60)
                $s = $script:RemainingSeconds % 60
                $bigTime.Text = "{0:D2}:{1:D2}" -f $m, $s
                
                $pct = 100 - (($script:RemainingSeconds / $script:TotalSeconds) * 100)
                $prog.Value = [math]::Min(100, [math]::Max(0, [int]$pct))
                
                # Warning
                if ($script:RemainingSeconds -eq ($script:Settings.WarningMinutes * 60) -and $script:Settings.WarningMinutes -gt 0) {
                    $script:NotifyIcon.Visible = $true
                    $script:NotifyIcon.ShowBalloonTip(5000, "Warning", "$($actCombo.SelectedItem) in $($script:Settings.WarningMinutes) min!", "Warning")
                    try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
                    $res = Show-SnoozeDialog -ActionName $actCombo.SelectedItem -Minutes $script:Settings.WarningMinutes
                    if ($res -eq "Snooze") {
                        $script:RemainingSeconds += 600
                        $script:TotalSeconds += 600
                    }
                }
            } else {
                # Complete
                $script:Timer.Stop()
                $script:TimerActive = $false
                switch ($actCombo.SelectedItem) {
                    "Shutdown" { if ($script:Settings.ForceShutdown) { Stop-Computer -Force } else { Stop-Computer } }
                    "Restart" { if ($script:Settings.ForceShutdown) { Restart-Computer -Force } else { Restart-Computer } }
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
        $script:Timer.Start()
    } else {
        $script:TimerActive = $false
        $script:Timer.Stop()
        $bigTime.Text = "{0:D2}:00" -f [int]$minInput.Value
        $prog.Value = 0
        $mainBtn.Text = "START TIMER"
        $mainBtn.BackColor = $script:Colors.Accent
        $mainBtn.ForeColor = [System.Drawing.Color]::FromArgb(22, 22, 30)
        $minInput.Enabled = $true
        $actCombo.Enabled = $true
        $profCombo.Enabled = $true
        $actLabel.Text = $actCombo.SelectedItem.ToString().ToUpper()
        $actLabel.ForeColor = $script:Colors.TextMuted
    }
})

# Profile change
$profCombo.Add_SelectedIndexChanged({
    $sel = $profCombo.SelectedItem
    if ($sel -ne "(Custom)" -and $script:Profiles[$sel]) {
        $minInput.Value = $script:Profiles[$sel].Minutes
        $actCombo.SelectedItem = $script:Profiles[$sel].Action
        $script:Settings.LastProfile = $sel
        $bigTime.Text = "{0:D2}:00" -f $script:Profiles[$sel].Minutes
        $actLabel.Text = $script:Profiles[$sel].Action.ToUpper()
    }
})

# Action change
$actCombo.Add_SelectedIndexChanged({
    $actLabel.Text = $actCombo.SelectedItem.ToString().ToUpper()
})

# Minutes change
$minInput.Add_ValueChanged({
    if (-not $script:TimerActive) {
        $bigTime.Text = "{0:D2}:00" -f [int]$minInput.Value
    }
})

# Settings
$setBtn.Add_Click({
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Settings"
    $sf.Size = New-Object System.Drawing.Size(300, 250)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"
    $sf.BackColor = $script:Colors.Background
    $sf.ForeColor = $script:Colors.Text
    
    $y = 20
    
    $w = New-Object System.Windows.Forms.Label
    $w.Text = "Warning (min before):"
    $w.Location = New-Object System.Drawing.Point(20, $y)
    $w.Size = New-Object System.Drawing.Size(130, 25)
    $w.ForeColor = $script:Colors.TextMuted
    $sf.Controls.Add($w)
    
    $wi = New-Object System.Windows.Forms.NumericUpDown
    $wi.Location = New-Object System.Drawing.Point(160, $y)
    $wi.Size = New-Object System.Drawing.Size(60, 25)
    $wi.Minimum = 0
    $wi.Maximum = 30
    $wi.Value = $script:Settings.WarningMinutes
    $wi.BackColor = $script:Colors.Surface
    $wi.ForeColor = $script:Colors.Text
    $sf.Controls.Add($wi)
    $y += 45
    
    $sc = New-Object System.Windows.Forms.CheckBox
    $sc.Text = "Play notification sounds"
    $sc.Location = New-Object System.Drawing.Point(20, $y)
    $sc.Size = New-Object System.Drawing.Size(250, 25)
    $sc.Checked = $script:Settings.PlaySound
    $sc.ForeColor = $script:Colors.Text
    $sf.Controls.Add($sc)
    $y += 35
    
    $tc = New-Object System.Windows.Forms.CheckBox
    $tc.Text = "Minimize to system tray"
    $tc.Location = New-Object System.Drawing.Point(20, $y)
    $tc.Size = New-Object System.Drawing.Size(250, 25)
    $tc.Checked = $script:Settings.MinimizeToTray
    $tc.ForeColor = $script:Colors.Text
    $sf.Controls.Add($tc)
    $y += 35
    
    $fc = New-Object System.Windows.Forms.CheckBox
    $fc.Text = "Force shutdown/restart (no confirmation)"
    $fc.Location = New-Object System.Drawing.Point(20, $y)
    $fc.Size = New-Object System.Drawing.Size(250, 25)
    $fc.Checked = $script:Settings.ForceShutdown
    $fc.ForeColor = $script:Colors.Text
    $sf.Controls.Add($fc)
    $y += 55
    
    $sb = New-Object System.Windows.Forms.Button
    $sb.Text = "SAVE"
    $sb.Size = New-Object System.Drawing.Size(100, 35)
    $sb.Location = New-Object System.Drawing.Point(100, $y)
    $sb.BackColor = $script:Colors.Accent
    $sb.ForeColor = [System.Drawing.Color]::FromArgb(22, 22, 30)
    $sb.FlatStyle = "Flat"
    $sb.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $sb.Add_Click({
        $script:Settings.WarningMinutes = [int]$wi.Value
        $script:Settings.PlaySound = $sc.Checked
        $script:Settings.MinimizeToTray = $tc.Checked
        $script:Settings.ForceShutdown = $fc.Checked
        $script:Settings.Minutes = [int]$minInput.Value
        $script:Settings.Action = $actCombo.SelectedItem
        $script:Settings.LastProfile = $profCombo.SelectedItem
        $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
        [System.Windows.Forms.MessageBox]::Show("Saved!", "Done", "OK", "Information")
        $sf.Close()
    })
    $sf.Controls.Add($sb)
    
    $sf.ShowDialog()
})

# Drag to move
$script:drag = $false
$script:offset = $null
$panel.Add_MouseDown({ $script:drag = $true; $script:offset = New-Object System.Drawing.Point($_.X, $_.Y) })
$panel.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point([System.Windows.Forms.Cursor]::Position.X - $script:offset.X, [System.Windows.Forms.Cursor]::Position.Y - $script:offset.Y) } })
$panel.Add_MouseUp({ $script:drag = $false })

# Tray
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Sleep Timer Ultimate"
$script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:NotifyIcon.Visible = $false

$ctx = New-Object System.Windows.Forms.ContextMenuStrip
$sh = New-Object System.Windows.Forms.ToolStripMenuItem; $sh.Text = "Show"; $sh.Add_Click({ $form.Show(); $form.WindowState = "Normal"; $script:NotifyIcon.Visible = $false }); $ctx.Items.Add($sh)
$ex = New-Object System.Windows.Forms.ToolStripMenuItem; $ex.Text = "Exit"; $ex.Add_Click({ $form.Close() }); $ctx.Items.Add($ex)
$script:NotifyIcon.ContextMenuStrip = $ctx

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized" -and $script:Settings.MinimizeToTray) {
        $form.Hide()
        $script:NotifyIcon.Visible = $true
    }
})

# Save on close
$form.Add_FormClosing({
    $script:Settings.Minutes = [int]$minInput.Value
    $script:Settings.Action = $actCombo.SelectedItem
    $script:Settings.LastProfile = $profCombo.SelectedItem
    $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
})

$form.ShowDialog()
$script:NotifyIcon.Visible = $false
