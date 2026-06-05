# Sleep Timer - Clean Working Version
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings
$SettingsDir = Join-Path $env:LOCALAPPDATA "SleepTimer"
if (!(Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }
$SettingsFile = Join-Path $SettingsDir "settings.json"

$script:Settings = @{ Minutes = 30; Action = "Sleep"; WarningMinutes = 5; PlaySound = $true; MinimizeToTray = $false; ForceShutdown = $true }
if (Test-Path $SettingsFile) {
    try { $loaded = Get-Content $SettingsFile | ConvertFrom-Json
        $loaded.PSObject.Properties | ForEach-Object { $script:Settings[$_.Name] = $_.Value }
    } catch {}
}

$script:Profiles = @{
    "Movie Night" = @{ Minutes = 120; Action = "Sleep" }
    "Work Session" = @{ Minutes = 60; Action = "Shutdown" }
    "Quick Nap" = @{ Minutes = 20; Action = "Sleep" }
    "Bedtime" = @{ Minutes = 30; Action = "Sleep" }
    "Download" = @{ Minutes = 180; Action = "Shutdown" }
}

# Colors
$BG = [System.Drawing.Color]::FromArgb(28, 28, 36)
$Surface = [System.Drawing.Color]::FromArgb(42, 42, 56)
$SurfaceLight = [System.Drawing.Color]::FromArgb(56, 56, 72)
$Text = [System.Drawing.Color]::FromArgb(240, 240, 255)
$TextDim = [System.Drawing.Color]::FromArgb(140, 140, 160)
$Accent = [System.Drawing.Color]::FromArgb(0, 180, 255)
$Success = [System.Drawing.Color]::FromArgb(0, 230, 150)
$Warning = [System.Drawing.Color]::FromArgb(255, 180, 0)
$Danger = [System.Drawing.Color]::FromArgb(255, 80, 80)

# State
$script:Active = $false
$script:Timer = $null
$script:Remaining = 0
$script:Total = 0

# Snooze Dialog
function Show-Snooze {
    param($Action, $Minutes)
    $d = New-Object System.Windows.Forms.Form
    $d.Text = "Timer Warning"
    $d.Size = New-Object System.Drawing.Size(380, 180)
    $d.StartPosition = "CenterParent"
    $d.FormBorderStyle = "FixedDialog"
    $d.BackColor = $BG
    $d.TopMost = $true
    
    $i = New-Object System.Windows.Forms.Label
    $i.Text = "!"
    $i.Font = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
    $i.ForeColor = $Warning
    $i.Location = New-Object System.Drawing.Point(25, 20)
    $i.Size = New-Object System.Drawing.Size(40, 50)
    $d.Controls.Add($i)
    
    $m = New-Object System.Windows.Forms.Label
    $m.Text = "$Action in $Minutes minutes!"
    $m.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $m.ForeColor = $Text
    $m.Location = New-Object System.Drawing.Point(75, 25)
    $m.Size = New-Object System.Drawing.Size(280, 30)
    $d.Controls.Add($m)
    
    $s = New-Object System.Windows.Forms.Label
    $s.Text = "Snooze for 10 minutes or proceed now"
    $s.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $s.ForeColor = $TextDim
    $s.Location = New-Object System.Drawing.Point(75, 55)
    $s.Size = New-Object System.Drawing.Size(280, 25)
    $d.Controls.Add($s)
    
    $sn = New-Object System.Windows.Forms.Button
    $sn.Text = "SNOOZE"
    $sn.Size = New-Object System.Drawing.Size(110, 38)
    $sn.Location = New-Object System.Drawing.Point(60, 100)
    $sn.BackColor = $SurfaceLight
    $sn.ForeColor = $Text
    $sn.FlatStyle = "Flat"
    $sn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $sn.Add_Click({ $d.Tag = "Snooze"; $d.Close() })
    $d.Controls.Add($sn)
    
    $pr = New-Object System.Windows.Forms.Button
    $pr.Text = "PROCEED"
    $pr.Size = New-Object System.Drawing.Size(100, 38)
    $pr.Location = New-Object System.Drawing.Point(200, 100)
    $pr.BackColor = $Accent
    $pr.ForeColor = $BG
    $pr.FlatStyle = "Flat"
    $pr.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $pr.Add_Click({ $d.Tag = "Proceed"; $d.Close() })
    $d.Controls.Add($pr)
    
    $d.ShowDialog() | Out-Null
    return $d.Tag
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer"
$form.Size = New-Object System.Drawing.Size(480, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.BackColor = $BG
$form.MaximizeBox = $false

# Header
$h = New-Object System.Windows.Forms.Label
$h.Text = "SLEEP TIMER"
$h.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$h.ForeColor = $Text
$h.Location = New-Object System.Drawing.Point(25, 15)
$h.AutoSize = $true
$form.Controls.Add($h)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "ULTIMATE"
$sub.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$sub.ForeColor = $Accent
$sub.Location = New-Object System.Drawing.Point(205, 25)
$sub.AutoSize = $true
$form.Controls.Add($sub)

# Big Time
$time = New-Object System.Windows.Forms.Label
$time.Text = "30:00"
$time.Font = New-Object System.Drawing.Font("Segoe UI Light", 64)
$time.ForeColor = $Accent
$time.TextAlign = "MiddleCenter"
$time.Size = New-Object System.Drawing.Size(430, 100)
$time.Location = New-Object System.Drawing.Point(25, 70)
$form.Controls.Add($time)

# Action Label
$act = New-Object System.Windows.Forms.Label
$act.Text = "SLEEP"
$act.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$act.ForeColor = $TextDim
$act.TextAlign = "MiddleCenter"
$act.Size = New-Object System.Drawing.Size(430, 25)
$act.Location = New-Object System.Drawing.Point(25, 175)
$form.Controls.Add($act)

# Progress
$prog = New-Object System.Windows.Forms.ProgressBar
$prog.Location = New-Object System.Drawing.Point(25, 210)
$prog.Size = New-Object System.Drawing.Size(430, 6)
$prog.Minimum = 0
$prog.Maximum = 100
$prog.Value = 0
$prog.Style = "Continuous"
$form.Controls.Add($prog)

# Profile
$pl = New-Object System.Windows.Forms.Label
$pl.Text = "PROFILE"
$pl.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$pl.ForeColor = $TextDim
$pl.Location = New-Object System.Drawing.Point(25, 235)
$pl.Size = New-Object System.Drawing.Size(60, 20)
$form.Controls.Add($pl)

$prof = New-Object System.Windows.Forms.ComboBox
$prof.Location = New-Object System.Drawing.Point(90, 230)
$prof.Size = New-Object System.Drawing.Size(160, 25)
$prof.DropDownStyle = "DropDownList"
$prof.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$prof.BackColor = $Surface
$prof.ForeColor = $Text
$prof.FlatStyle = "Flat"
$prof.Items.Add("(Custom)")
$script:Profiles.Keys | Sort-Object | ForEach-Object { $prof.Items.Add($_) }
$prof.SelectedIndex = 0
$form.Controls.Add($prof)

# Minutes
$ml = New-Object System.Windows.Forms.Label
$ml.Text = "MINUTES"
$ml.Font = New-Object System.Windows.Forms.Label
$ml.Text = "MINUTES"
$ml.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$ml.ForeColor = $TextDim
$ml.Location = New-Object System.Drawing.Point(25, 270)
$ml.Size = New-Object System.Drawing.Size(60, 20)
$form.Controls.Add($ml)

$min = New-Object System.Windows.Forms.NumericUpDown
$min.Location = New-Object System.Drawing.Point(25, 290)
$min.Size = New-Object System.Drawing.Size(90, 30)
$min.Minimum = 1
$min.Maximum = 1440
$min.Value = $script:Settings.Minutes
$min.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$min.BackColor = $Surface
$min.ForeColor = $Text
$min.BorderStyle = "None"
$form.Controls.Add($min)

# Action Dropdown
$al = New-Object System.Windows.Forms.Label
$al.Text = "ACTION"
$al.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$al.ForeColor = $TextDim
$al.Location = New-Object System.Drawing.Point(130, 270)
$al.Size = New-Object System.Drawing.Size(60, 20)
$form.Controls.Add($al)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = New-Object System.Drawing.Point(130, 290)
$combo.Size = New-Object System.Drawing.Size(120, 30)
$combo.DropDownStyle = "DropDownList"
$combo.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$combo.BackColor = $Surface
$combo.ForeColor = $Text
$combo.FlatStyle = "Flat"
$combo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$combo.SelectedItem = $script:Settings.Action
$form.Controls.Add($combo)

# Presets
$presets = @(15, 30, 60)
$x = 270
foreach ($p in $presets) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "$p`m"
    $b.Size = New-Object System.Drawing.Size(50, 35)
    $b.Location = New-Object System.Drawing.Point($x, 290)
    $b.BackColor = $SurfaceLight
    $b.ForeColor = $Text
    $b.FlatStyle = "Flat"
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $val = $p
    $b.Add_Click({ $min.Value = $val; $prof.SelectedIndex = 0 })
    $form.Controls.Add($b)
    $x += 58
}

# Main Button
$btn = New-Object System.Windows.Forms.Button
$btn.Text = "START TIMER"
$btn.Size = New-Object System.Drawing.Size(280, 50)
$btn.Location = New-Object System.Drawing.Point(100, 360)
$btn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$btn.BackColor = $Accent
$btn.ForeColor = $BG
$btn.FlatStyle = "Flat"
$btn.FlatAppearance.BorderSize = 0
$form.Controls.Add($btn)

# Cancel Button (hidden)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "CANCEL"
$cancel.Size = New-Object System.Drawing.Size(90, 35)
$cancel.Location = New-Object System.Drawing.Point(25, 425)
$cancel.BackColor = $Danger
$cancel.ForeColor = $Text
$cancel.FlatStyle = "Flat"
$cancel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$cancel.Visible = $false
$form.Controls.Add($cancel)

# Settings Button
$set = New-Object System.Windows.Forms.Button
$set.Text = "Settings"
$set.Size = New-Object System.Drawing.Size(90, 35)
$set.Location = New-Object System.Drawing.Point(25, 425)
$set.BackColor = $Surface
$set.ForeColor = $Text
$set.FlatStyle = "Flat"
$form.Controls.Add($set)

# Profile change
$prof.Add_SelectedIndexChanged({
    $s = $prof.SelectedItem
    if ($s -ne "(Custom)" -and $script:Profiles[$s]) {
        $min.Value = $script:Profiles[$s].Minutes
        $combo.SelectedItem = $script:Profiles[$s].Action
        $time.Text = "{0:D2}:00" -f $script:Profiles[$s].Minutes
        $act.Text = $script:Profiles[$s].Action.ToUpper()
    }
})

# Action change
$combo.Add_SelectedIndexChanged({ $act.Text = $combo.SelectedItem.ToString().ToUpper() })

# Minutes change
$min.Add_ValueChanged({ if (!$script:Active) { $time.Text = "{0:D2}:00" -f [int]$min.Value } })

# Cancel click
$cancel.Add_Click({
    if ($script:Active) {
        $script:Active = $false
        $script:Timer.Stop()
        $time.Text = "{0:D2}:00" -f [int]$min.Value
        $prog.Value = 0
        $btn.Text = "START TIMER"
        $btn.BackColor = $Accent
        $btn.ForeColor = $BG
        $min.Enabled = $true
        $combo.Enabled = $true
        $prof.Enabled = $true
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $TextDim
        $cancel.Visible = $false
        $set.Visible = $true
    }
})

# Main button click
$btn.Add_Click({
    if (!$script:Active) {
        $script:Active = $true
        $script:Total = [int]$min.Value * 60
        $script:Remaining = $script:Total
        
        $btn.Text = "STOP"
        $btn.BackColor = $Danger
        $btn.ForeColor = $Text
        $min.Enabled = $false
        $combo.Enabled = $false
        $prof.Enabled = $false
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $Success
        $set.Visible = $false
        $cancel.Visible = $true
        
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 1000
        $script:Timer.Add_Tick({
            if ($script:Remaining -gt 0 -and $script:Active) {
                $script:Remaining--
                $m = [math]::Floor($script:Remaining / 60)
                $s = $script:Remaining % 60
                $time.Text = "{0:D2}:{1:D2}" -f $m, $s
                
                $p = 100 - (($script:Remaining / $script:Total) * 100)
                $prog.Value = [math]::Min(100, [math]::Max(0, [int]$p))
                
                if ($script:Remaining -eq ($script:Settings.WarningMinutes * 60) -and $script:Settings.WarningMinutes -gt 0) {
                    try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
                    $r = Show-Snooze -Action $combo.SelectedItem -Minutes $script:Settings.WarningMinutes
                    if ($r -eq "Snooze") {
                        $script:Remaining += 600
                        $script:Total += 600
                    }
                }
            } else {
                $script:Timer.Stop()
                $script:Active = $false
                switch ($combo.SelectedItem) {
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
        $script:Active = $false
        $script:Timer.Stop()
        $time.Text = "{0:D2}:00" -f [int]$min.Value
        $prog.Value = 0
        $btn.Text = "START TIMER"
        $btn.BackColor = $Accent
        $btn.ForeColor = $BG
        $min.Enabled = $true
        $combo.Enabled = $true
        $prof.Enabled = $true
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $TextDim
        $cancel.Visible = $false
        $set.Visible = $true
    }
})

# Settings dialog
$set.Add_Click({
    $s = New-Object System.Windows.Forms.Form
    $s.Text = "Settings"
    $s.Size = New-Object System.Drawing.Size(300, 260)
    $s.StartPosition = "CenterParent"
    $s.FormBorderStyle = "FixedDialog"
    $s.BackColor = $BG
    
    $y = 20
    
    $wl = New-Object System.Windows.Forms.Label
    $wl.Text = "Warning (min before):"
    $wl.Location = New-Object System.Drawing.Point(20, $y)
    $wl.Size = New-Object System.Drawing.Size(120, 25)
    $wl.ForeColor = $TextDim
    $s.Controls.Add($wl)
    
    $wi = New-Object System.Windows.Forms.NumericUpDown
    $wi.Location = New-Object System.Drawing.Point(150, $y)
    $wi.Size = New-Object System.Drawing.Size(60, 25)
    $wi.Minimum = 0; $wi.Maximum = 30; $wi.Value = $script:Settings.WarningMinutes
    $wi.BackColor = $Surface; $wi.ForeColor = $Text
    $s.Controls.Add($wi)
    $y += 45
    
    $sc = New-Object System.Windows.Forms.CheckBox
    $sc.Text = "Play notification sounds"
    $sc.Location = New-Object System.Drawing.Point(20, $y)
    $sc.Size = New-Object System.Drawing.Size(220, 25)
    $sc.Checked = $script:Settings.PlaySound
    $sc.ForeColor = $Text
    $s.Controls.Add($sc)
    $y += 35
    
    $tc = New-Object System.Windows.Forms.CheckBox
    $tc.Text = "Minimize to system tray"
    $tc.Location = New-Object System.Drawing.Point(20, $y)
    $tc.Size = New-Object System.Drawing.Size(220, 25)
    $tc.Checked = $script:Settings.MinimizeToTray
    $tc.ForeColor = $Text
    $s.Controls.Add($tc)
    $y += 35
    
    $fc = New-Object System.Windows.Forms.CheckBox
    $fc.Text = "Force shutdown/restart"
    $fc.Location = New-Object System.Drawing.Point(20, $y)
    $fc.Size = New-Object System.Drawing.Size(220, 25)
    $fc.Checked = $script:Settings.ForceShutdown
    $fc.ForeColor = $Text
    $s.Controls.Add($fc)
    $y += 50
    
    $sb = New-Object System.Windows.Forms.Button
    $sb.Text = "SAVE"
    $sb.Size = New-Object System.Drawing.Size(100, 35)
    $sb.Location = New-Object System.Drawing.Point(100, $y)
    $sb.BackColor = $Accent
    $sb.ForeColor = $BG
    $sb.FlatStyle = "Flat"
    $sb.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $sb.Add_Click({
        $script:Settings.WarningMinutes = [int]$wi.Value
        $script:Settings.PlaySound = $sc.Checked
        $script:Settings.MinimizeToTray = $tc.Checked
        $script:Settings.ForceShutdown = $fc.Checked
        $script:Settings.Minutes = [int]$min.Value
        $script:Settings.Action = $combo.SelectedItem
        $script:Settings | ConvertTo-Json | Set-Content $SettingsFile
        [System.Windows.Forms.MessageBox]::Show("Saved!", "Done", "OK", "Information")
        $s.Close()
    })
    $s.Controls.Add($sb)
    
    $s.ShowDialog()
})

# Save on close
$form.Add_FormClosing({
    $script:Settings.Minutes = [int]$min.Value
    $script:Settings.Action = $combo.SelectedItem
    $script:Settings | ConvertTo-Json | Set-Content $SettingsFile
})

$form.ShowDialog()
