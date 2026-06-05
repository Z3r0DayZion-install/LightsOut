# Sleep Timer - Modern UI Edition
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings
$SettingsDir = Join-Path $env:LOCALAPPDATA "SleepTimerModern"
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

# Modern Color Scheme - Dark Professional
$script:C = @{
    BG = [System.Drawing.Color]::FromArgb(16, 16, 24)
    Panel = [System.Drawing.Color]::FromArgb(24, 24, 36)
    Card = [System.Drawing.Color]::FromArgb(32, 32, 48)
    CardHover = [System.Drawing.Color]::FromArgb(40, 40, 60)
    Text = [System.Drawing.Color]::FromArgb(255, 255, 255)
    TextDim = [System.Drawing.Color]::FromArgb(150, 150, 170)
    Accent = [System.Drawing.Color]::FromArgb(56, 189, 248)
    AccentDark = [System.Drawing.Color]::FromArgb(14, 165, 233)
    Success = [System.Drawing.Color]::FromArgb(52, 211, 153)
    Warning = [System.Drawing.Color]::FromArgb(251, 191, 36)
    Danger = [System.Drawing.Color]::FromArgb(248, 113, 113)
}

$script:Active = $false
$script:Timer = $null
$script:Remaining = 0
$script:Total = 0

# Snooze Dialog - Modern
function Show-Snooze {
    param($Action, $Minutes)
    $d = New-Object System.Windows.Forms.Form
    $d.Text = "Timer Warning"
    $d.Size = New-Object System.Drawing.Size(420, 200)
    $d.StartPosition = "CenterScreen"
    $d.FormBorderStyle = "None"
    $d.BackColor = $script:C.BG
    $d.TopMost = $true
    
    # Border
    $border = New-Object System.Windows.Forms.Panel
    $border.Dock = "Fill"
    $border.BackColor = $script:C.Accent
    $border.Padding = New-Object System.Windows.Forms.Padding(2)
    $d.Controls.Add($border)
    
    $inner = New-Object System.Windows.Forms.Panel
    $inner.Dock = "Fill"
    $inner.BackColor = $script:C.Panel
    $border.Controls.Add($inner)
    
    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = "⚠"
    $icon.Font = New-Object System.Drawing.Font("Segoe UI", 36)
    $icon.ForeColor = $script:C.Warning
    $icon.Location = New-Object System.Drawing.Point(30, 25)
    $icon.Size = New-Object System.Drawing.Size(50, 50)
    $inner.Controls.Add($icon)
    
    $msg = New-Object System.Windows.Forms.Label
    $msg.Text = "$Action in $Minutes minutes"
    $msg.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $msg.ForeColor = $script:C.Text
    $msg.Location = New-Object System.Drawing.Point(90, 20)
    $msg.Size = New-Object System.Drawing.Size(300, 30)
    $inner.Controls.Add($msg)
    
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "Snooze for 10 minutes or proceed now"
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $sub.ForeColor = $script:C.TextDim
    $sub.Location = New-Object System.Drawing.Point(90, 50)
    $sub.Size = New-Object System.Drawing.Size(300, 25)
    $inner.Controls.Add($sub)
    
    $sn = New-Object System.Windows.Forms.Button
    $sn.Text = "SNOOZE +10m"
    $sn.Size = New-Object System.Drawing.Size(130, 42)
    $sn.Location = New-Object System.Drawing.Point(70, 110)
    $sn.BackColor = $script:C.Card
    $sn.ForeColor = $script:C.Text
    $sn.FlatStyle = "Flat"
    $sn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $sn.FlatAppearance.BorderSize = 0
    $sn.Cursor = "Hand"
    $sn.Add_Click({ $d.Tag = "Snooze"; $d.Close() })
    $inner.Controls.Add($sn)
    
    $pr = New-Object System.Windows.Forms.Button
    $pr.Text = "PROCEED"
    $pr.Size = New-Object System.Drawing.Size(110, 42)
    $pr.Location = New-Object System.Drawing.Point(220, 110)
    $pr.BackColor = $script:C.Accent
    $pr.ForeColor = $script:C.BG
    $pr.FlatStyle = "Flat"
    $pr.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $pr.FlatAppearance.BorderSize = 0
    $pr.Cursor = "Hand"
    $pr.Add_Click({ $d.Tag = "Proceed"; $d.Close() })
    $inner.Controls.Add($pr)
    
    $d.ShowDialog() | Out-Null
    return $d.Tag
}

# Main Form - Borderless Modern
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer"
$form.Size = New-Object System.Drawing.Size(520, 580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $script:C.BG

# Custom Title Bar
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size(520, 50)
$titleBar.BackColor = $script:C.Panel
$titleBar.Dock = "Top"
$form.Controls.Add($titleBar)

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Text = "SLEEP TIMER"
$titleLbl.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = $script:C.Text
$titleLbl.Location = New-Object System.Drawing.Point(20, 12)
$titleLbl.AutoSize = $true
$titleBar.Controls.Add($titleLbl)

$ver = New-Object System.Windows.Forms.Label
$ver.Text = "PRO"
$ver.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$ver.ForeColor = $script:C.Accent
$ver.Location = New-Object System.Drawing.Point(155, 15)
$ver.AutoSize = $true
$titleBar.Controls.Add($ver)

# Close Button
$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "×"
$closeBtn.Size = New-Object System.Drawing.Size(45, 45)
$closeBtn.Location = New-Object System.Drawing.Point(475, 3)
$closeBtn.BackColor = [System.Drawing.Color]::Transparent
$closeBtn.ForeColor = $script:C.TextDim
$closeBtn.FlatStyle = "Flat"
$closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 16)
$closeBtn.FlatAppearance.BorderSize = 0
$closeBtn.Cursor = "Hand"
$closeBtn.Add_Click({ $form.Close() })
$closeBtn.Add_MouseEnter({ $closeBtn.ForeColor = $script:C.Danger })
$closeBtn.Add_MouseLeave({ $closeBtn.ForeColor = $script:C.TextDim })
$titleBar.Controls.Add($closeBtn)

# Main Content Panel
$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(0, 50)
$content.Size = New-Object System.Drawing.Size(520, 530)
$content.BackColor = $script:C.BG
$form.Controls.Add($content)

# Timer Circle Panel (visual only)
$circlePanel = New-Object System.Windows.Forms.Panel
$circlePanel.Size = New-Object System.Drawing.Size(280, 160)
$circlePanel.Location = New-Object System.Drawing.Point(120, 20)
$circlePanel.BackColor = $script:C.Card
$panelRadius = 20
$content.Controls.Add($circlePanel)

# Big Time
$time = New-Object System.Windows.Forms.Label
$time.Text = "{0:D2}:00" -f $script:Settings.Minutes
$time.Font = New-Object System.Drawing.Font("Segoe UI", 52, [System.Drawing.FontStyle]::Bold)
$time.ForeColor = $script:C.Accent
$time.TextAlign = "MiddleCenter"
$time.Size = New-Object System.Drawing.Size(280, 90)
$time.Location = New-Object System.Drawing.Point(0, 25)
$circlePanel.Controls.Add($time)

# Action Label
$act = New-Object System.Windows.Forms.Label
$act.Text = $script:Settings.Action.ToUpper()
$act.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$act.ForeColor = $script:C.TextDim
$act.TextAlign = "MiddleCenter"
$act.Size = New-Object System.Drawing.Size(280, 25)
$act.Location = New-Object System.Drawing.Point(0, 115)
$circlePanel.Controls.Add($act)

# Progress Bar
$prog = New-Object System.Windows.Forms.ProgressBar
$prog.Location = New-Object System.Drawing.Point(45, 195)
$prog.Size = New-Object System.Drawing.Size(430, 4)
$prog.Minimum = 0
$prog.Maximum = 100
$prog.Value = 0
$prog.Style = "Continuous"
$prog.BackColor = $script:C.Card
$prog.ForeColor = $script:C.Accent
$content.Controls.Add($prog)

# Controls Section
$y = 220

# Profile Row
$profLbl = New-Object System.Windows.Forms.Label
$profLbl.Text = "Profile"
$profLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$profLbl.ForeColor = $script:C.TextDim
$profLbl.Location = New-Object System.Drawing.Point(45, $y)
$profLbl.Size = New-Object System.Drawing.Size(100, 20)
$content.Controls.Add($profLbl)

$prof = New-Object System.Windows.Forms.ComboBox
$prof.Location = New-Object System.Drawing.Point(45, $y + 22)
$prof.Size = New-Object System.Drawing.Size(180, 32)
$prof.DropDownStyle = "DropDownList"
$prof.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$prof.BackColor = $script:C.Card
$prof.ForeColor = $script:C.Text
$prof.FlatStyle = "Flat"
$prof.Items.Add("Custom")
$script:Profiles.Keys | Sort-Object | ForEach-Object { $prof.Items.Add($_) }
$prof.SelectedIndex = 0
$content.Controls.Add($prof)

$y += 70

# Minutes Row
$minLbl = New-Object System.Windows.Forms.Label
$minLbl.Text = "Duration"
$minLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$minLbl.ForeColor = $script:C.TextDim
$minLbl.Location = New-Object System.Drawing.Point(45, $y)
$minLbl.Size = New-Object System.Drawing.Size(100, 20)
$content.Controls.Add($minLbl)

$min = New-Object System.Windows.Forms.NumericUpDown
$min.Location = New-Object System.Drawing.Point(45, $y + 22)
$min.Size = New-Object System.Drawing.Size(100, 35)
$min.Minimum = 1
$min.Maximum = 1440
$min.Value = $script:Settings.Minutes
$min.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$min.BackColor = $script:C.Card
$min.ForeColor = $script:C.Text
$min.BorderStyle = "None"
$content.Controls.Add($min)

$minTxt = New-Object System.Windows.Forms.Label
$minTxt.Text = "minutes"
$minTxt.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$minTxt.ForeColor = $script:C.TextDim
$minTxt.Location = New-Object System.Drawing.Point(155, $y + 28)
$minTxt.Size = New-Object System.Drawing.Size(70, 25)
$content.Controls.Add($minTxt)

# Action Dropdown
$actLbl = New-Object System.Windows.Forms.Label
$actLbl.Text = "Action"
$actLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$actLbl.ForeColor = $script:C.TextDim
$actLbl.Location = New-Object System.Drawing.Point(245, $y)
$actLbl.Size = New-Object System.Drawing.Size(100, 20)
$content.Controls.Add($actLbl)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = New-Object System.Drawing.Point(245, $y + 22)
$combo.Size = New-Object System.Drawing.Size(130, 35)
$combo.DropDownStyle = "DropDownList"
$combo.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$combo.BackColor = $script:C.Card
$combo.ForeColor = $script:C.Text
$combo.FlatStyle = "Flat"
$combo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$combo.SelectedItem = $script:Settings.Action
$content.Controls.Add($combo)

# Quick presets
$x = 395
$presets = @(15, 30, 60)
foreach ($p in $presets) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "$p`m"
    $b.Size = New-Object System.Drawing.Size(48, 35)
    $b.Location = New-Object System.Drawing.Point($x, $y + 20)
    $b.BackColor = $script:C.Card
    $b.ForeColor = $script:C.Text
    $b.FlatStyle = "Flat"
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $b.FlatAppearance.BorderSize = 0
    $b.Cursor = "Hand"
    $val = $p
    $b.Add_Click({ $min.Value = $val; $prof.SelectedIndex = 0 })
    $b.Add_MouseEnter({ $b.BackColor = $script:C.CardHover })
    $b.Add_MouseLeave({ $b.BackColor = $script:C.Card })
    $content.Controls.Add($b)
    $x += 54
}

# Main Start Button
$btn = New-Object System.Windows.Forms.Button
$btn.Text = "START TIMER"
$btn.Size = New-Object System.Drawing.Size(300, 55)
$btn.Location = New-Object System.Drawing.Point(110, 420)
$btn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$btn.BackColor = $script:C.Accent
$btn.ForeColor = $script:C.BG
$btn.FlatStyle = "Flat"
$btn.FlatAppearance.BorderSize = 0
$btn.Cursor = "Hand"
$content.Controls.Add($btn)

# Cancel Button (hidden)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "CANCEL"
$cancel.Size = New-Object System.Drawing.Size(90, 36)
$cancel.Location = New-Object System.Drawing.Point(45, 490)
$cancel.BackColor = $script:C.Card
$cancel.ForeColor = $script:C.Danger
$cancel.FlatStyle = "Flat"
$cancel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$cancel.FlatAppearance.BorderSize = 0
$cancel.Visible = $false
$cancel.Cursor = "Hand"
$content.Controls.Add($cancel)

# Settings Button
$set = New-Object System.Windows.Forms.Button
$set.Text = "Settings"
$set.Size = New-Object System.Drawing.Size(90, 36)
$set.Location = New-Object System.Drawing.Point(45, 490)
$set.BackColor = $script:C.Card
$set.ForeColor = $script:C.TextDim
$set.FlatStyle = "Flat"
$set.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$set.FlatAppearance.BorderSize = 0
$set.Cursor = "Hand"
$content.Controls.Add($set)

# Events
$prof.Add_SelectedIndexChanged({
    $s = $prof.SelectedItem
    if ($s -ne "Custom" -and $script:Profiles[$s]) {
        $min.Value = $script:Profiles[$s].Minutes
        $combo.SelectedItem = $script:Profiles[$s].Action
        $time.Text = "{0:D2}:00" -f $script:Profiles[$s].Minutes
        $act.Text = $script:Profiles[$s].Action.ToUpper()
    }
})

$combo.Add_SelectedIndexChanged({ $act.Text = $combo.SelectedItem.ToString().ToUpper() })
$min.Add_ValueChanged({ if (!$script:Active) { $time.Text = "{0:D2}:00" -f [int]$min.Value } })

$cancel.Add_Click({
    if ($script:Active) {
        $script:Active = $false
        $script:Timer.Stop()
        $time.Text = "{0:D2}:00" -f [int]$min.Value
        $time.ForeColor = $script:C.Accent
        $prog.Value = 0
        $btn.Text = "START TIMER"
        $btn.BackColor = $script:C.Accent
        $btn.ForeColor = $script:C.BG
        $min.Enabled = $true
        $combo.Enabled = $true
        $prof.Enabled = $true
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $script:C.TextDim
        $cancel.Visible = $false
        $set.Visible = $true
    }
})

$btn.Add_Click({
    if (!$script:Active) {
        $script:Active = $true
        $script:Total = [int]$min.Value * 60
        $script:Remaining = $script:Total
        
        $btn.Text = "STOP"
        $btn.BackColor = $script:C.Danger
        $btn.ForeColor = $script:C.Text
        $min.Enabled = $false
        $combo.Enabled = $false
        $prof.Enabled = $false
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $script:C.Success
        $time.ForeColor = $script:C.Success
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
        $time.ForeColor = $script:C.Accent
        $prog.Value = 0
        $btn.Text = "START TIMER"
        $btn.BackColor = $script:C.Accent
        $btn.ForeColor = $script:C.BG
        $min.Enabled = $true
        $combo.Enabled = $true
        $prof.Enabled = $true
        $act.Text = $combo.SelectedItem.ToString().ToUpper()
        $act.ForeColor = $script:C.TextDim
        $cancel.Visible = $false
        $set.Visible = $true
    }
})

# Settings Dialog
$set.Add_Click({
    $s = New-Object System.Windows.Forms.Form
    $s.Text = "Settings"
    $s.Size = New-Object System.Drawing.Size(320, 280)
    $s.StartPosition = "CenterParent"
    $s.FormBorderStyle = "FixedDialog"
    $s.BackColor = $script:C.BG
    
    $y = 20
    
    foreach ($item in @(
        @{ L = "Warning (min before)"; T = "num"; V = $script:Settings.WarningMinutes; M = 30 },
        @{ L = "Play notification sounds"; T = "chk"; V = $script:Settings.PlaySound },
        @{ L = "Minimize to system tray"; T = "chk"; V = $script:Settings.MinimizeToTray },
        @{ L = "Force shutdown/restart"; T = "chk"; V = $script:Settings.ForceShutdown }
    )) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $item.L
        $l.Location = New-Object System.Drawing.Point(20, $y)
        $l.Size = New-Object System.Drawing.Size(180, 25)
        $l.ForeColor = $script:C.TextDim
        $s.Controls.Add($l)
        
        if ($item.T -eq "num") {
            $n = New-Object System.Windows.Forms.NumericUpDown
            $n.Location = New-Object System.Drawing.Point(210, $y)
            $n.Size = New-Object System.Drawing.Size(60, 25)
            $n.Minimum = 0; $n.Maximum = $item.M; $n.Value = $item.V
            $n.BackColor = $script:C.Card; $n.ForeColor = $script:C.Text
            $s.Controls.Add($n)
            $s.Tag = @{ $item.L = $n }
        } else {
            $c = New-Object System.Windows.Forms.CheckBox
            $c.Location = New-Object System.Drawing.Point(210, $y)
            $c.Size = New-Object System.Drawing.Size(25, 25)
            $c.Checked = $item.V
            $s.Controls.Add($c)
            $s.Tag = @{ $item.L = $c }
        }
        $y += 45
    }
    
    $sb = New-Object System.Windows.Forms.Button
    $sb.Text = "SAVE"
    $sb.Size = New-Object System.Drawing.Size(110, 40)
    $sb.Location = New-Object System.Drawing.Point(105, $y)
    $sb.BackColor = $script:C.Accent
    $sb.ForeColor = $script:C.BG
    $sb.FlatStyle = "Flat"
    $sb.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $sb.FlatAppearance.BorderSize = 0
    $sb.Add_Click({
        $vals = $s.Tag
        $script:Settings.WarningMinutes = [int]$vals["Warning (min before)"].Value
        $script:Settings.PlaySound = $vals["Play notification sounds"].Checked
        $script:Settings.MinimizeToTray = $vals["Minimize to system tray"].Checked
        $script:Settings.ForceShutdown = $vals["Force shutdown/restart"].Checked
        $script:Settings.Minutes = [int]$min.Value
        $script:Settings.Action = $combo.SelectedItem
        $script:Settings | ConvertTo-Json | Set-Content $SettingsFile
        [System.Windows.Forms.MessageBox]::Show("Settings saved!", "Done", "OK", "Information")
        $s.Close()
    })
    $s.Controls.Add($sb)
    
    $s.ShowDialog()
})

# Drag form
$script:drag = $false
$script:pos = $null
$titleBar.Add_MouseDown({ $script:drag = $true; $script:pos = [System.Windows.Forms.Cursor]::Position })
$titleBar.Add_MouseMove({
    if ($script:drag) {
        $curr = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point($curr.X - ($script:pos.X - $form.Location.X), $curr.Y - ($script:pos.Y - $form.Location.Y))
        $script:pos = $curr
    }
})
$titleBar.Add_MouseUp({ $script:drag = $false })

$form.Add_FormClosing({
    $script:Settings.Minutes = [int]$min.Value
    $script:Settings.Action = $combo.SelectedItem
    $script:Settings | ConvertTo-Json | Set-Content $SettingsFile
})

$form.ShowDialog()
