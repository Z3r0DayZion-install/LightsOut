#Requires -Version 5.1
# Sleep Timer Ultimate - Professional Edition
param([switch]$Tray)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =====================================================
# SETTINGS & STATE
# =====================================================
$SettingsPath = Join-Path $env:LOCALAPPDATA "SleepTimerUltimate\settings.json"
$ProfilesPath = Join-Path $env:LOCALAPPDATA "SleepTimerUltimate\profiles.json"
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

$script:Profiles = @{
    "Movie Night" = @{ Minutes = 120; Action = "Sleep"; Icon = "🎬" }
    "Work Session" = @{ Minutes = 60; Action = "Shutdown"; Icon = "💼" }
    "Quick Nap" = @{ Minutes = 20; Action = "Sleep"; Icon = "😴" }
    "Bedtime" = @{ Minutes = 30; Action = "Sleep"; Icon = "🌙" }
    "Download" = @{ Minutes = 180; Action = "Shutdown"; Icon = "⬇️" }
    "Gaming" = @{ Minutes = 90; Action = "Sleep"; Icon = "🎮" }
}

if (Test-Path $ProfilesPath) {
    try { $loaded = Get-Content $ProfilesPath | ConvertFrom-Json; $loaded.PSObject.Properties | ForEach-Object { $script:Profiles[$_.Name] = $_.Value } } catch {}
}

# =====================================================
# MODERN COLOR PALETTE
# =====================================================
$script:Theme = @{
    Background = [System.Drawing.Color]::FromArgb(18, 18, 24)
    Surface = [System.Drawing.Color]::FromArgb(28, 28, 38)
    SurfaceLight = [System.Drawing.Color]::FromArgb(38, 38, 52)
    SurfaceHover = [System.Drawing.Color]::FromArgb(48, 48, 68)
    TextPrimary = [System.Drawing.Color]::FromArgb(255, 255, 255)
    TextSecondary = [System.Drawing.Color]::FromArgb(160, 160, 180)
    TextMuted = [System.Drawing.Color]::FromArgb(100, 100, 120)
    Accent = [System.Drawing.Color]::FromArgb(0, 200, 255)
    AccentGlow = [System.Drawing.Color]::FromArgb(0, 150, 255)
    Success = [System.Drawing.Color]::FromArgb(0, 255, 136)
    Warning = [System.Drawing.Color]::FromArgb(255, 200, 0)
    Danger = [System.Drawing.Color]::FromArgb(255, 80, 80)
    DangerGlow = [System.Drawing.Color]::FromArgb(255, 50, 50)
}

# State
$script:TimerActive = $false
$script:Timer = $null
$script:RemainingSeconds = 0
$script:TotalSeconds = 0
$script:NotifyIcon = $null

# =====================================================
# CUSTOM CONTROLS
# =====================================================

class ModernButton : System.Windows.Forms.Button {
    ModernButton() {
        $this.FlatStyle = "Flat"
        $this.FlatAppearance.BorderSize = 0
        $this.Cursor = "Hand"
        $this.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $this.BackColor = $script:Theme.SurfaceLight
        $this.ForeColor = $script:Theme.TextPrimary
        $this.Size = New-Object System.Drawing.Size(140, 45)
    }
}

class CircularProgressBar : System.Windows.Forms.Control {
    hidden [int]$Value = 0
    hidden [int]$Maximum = 100
    
    CircularProgressBar() {
        $this.SetStyle([System.Windows.Forms.ControlStyles]::UserPaint -bor [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer, $true)
        $this.Size = New-Object System.Drawing.Size(200, 200)
        $this.BackColor = [System.Drawing.Color]::Transparent
    }
    
    [void] OnPaint([System.Windows.Forms.PaintEventArgs]$e) {
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        
        $rect = New-Object System.Drawing.Rectangle(10, 10, 180, 180)
        
        # Background circle
        $bgPen = New-Object System.Drawing.Pen($script:Theme.Surface, 15)
        $g.DrawArc($bgPen, $rect, 0, 360)
        
        # Progress arc
        if ($this.Value -gt 0) {
            $angle = ($this.Value / $this.Maximum) * 360
            $progressPen = New-Object System.Drawing.Pen($script:Theme.Accent, 15)
            $progressPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $progressPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawArc($progressPen, $rect, -90, $angle)
        }
        
        # Glow effect
        if ($this.Value -gt 0 -and $this.Value -lt $this.Maximum) {
            $glowSize = 30 + ($this.Value / $this.Maximum) * 20
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, $script:Theme.Accent))
            $glowRect = New-Object System.Drawing.Rectangle(
                100 - $glowSize/2 + [math]::Cos(($this.Value / $this.Maximum) * 6.28 - 1.57) * 85,
                100 - $glowSize/2 + [math]::Sin(($this.Value / $this.Maximum) * 6.28 - 1.57) * 85,
                $glowSize, $glowSize
            )
            $g.FillEllipse($glowBrush, $glowRect)
        }
    }
}

# =====================================================
# SNOOZE DIALOG
# =====================================================
function Show-SnoozeDialog {
    param([string]$ActionName, [int]$Minutes)
    
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Action Warning"
    $dialog.Size = New-Object System.Drawing.Size(420, 240)
    $dialog.StartPosition = "CenterScreen"
    $dialog.FormBorderStyle = "None"
    $dialog.BackColor = $script:Theme.Background
    $dialog.TopMost = $true
    
    # Border panel
    $border = New-Object System.Windows.Forms.Panel
    $border.Dock = "Fill"
    $border.BackColor = $script:Theme.Accent
    $border.Padding = New-Object System.Windows.Forms.Padding(2)
    $dialog.Controls.Add($border)
    
    $content = New-Object System.Windows.Forms.Panel
    $content.Dock = "Fill"
    $content.BackColor = $script:Theme.Surface
    $border.Controls.Add($content)
    
    # Warning icon
    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = "⚠"
    $icon.Font = New-Object System.Drawing.Font("Segoe UI", 48)
    $icon.ForeColor = $script:Theme.Warning
    $icon.AutoSize = $true
    $icon.Location = New-Object System.Drawing.Point(40, 30)
    $content.Controls.Add($icon)
    
    # Message
    $msg = New-Object System.Windows.Forms.Label
    $msg.Text = "$ActionName in $Minutes minutes"
    $msg.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $msg.ForeColor = $script:Theme.TextPrimary
    $msg.AutoSize = $true
    $msg.Location = New-Object System.Drawing.Point(110, 35)
    $content.Controls.Add($msg)
    
    # Sub message
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "Click SNOOZE to delay 10 minutes, or PROCEED to continue"
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $sub.ForeColor = $script:Theme.TextSecondary
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(110, 65)
    $content.Controls.Add($sub)
    
    # Snooze Button
    $snoozeBtn = [ModernButton]::new()
    $snoozeBtn.Text = "SNOOZE +10m"
    $snoozeBtn.Location = New-Object System.Drawing.Point(80, 140)
    $snoozeBtn.BackColor = $script:Theme.SurfaceLight
    $snoozeBtn.ForeColor = $script:Theme.TextPrimary
    $snoozeBtn.Size = New-Object System.Drawing.Size(130, 45)
    $snoozeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $snoozeBtn.Add_Click({ $dialog.Tag = "Snooze"; $dialog.Close() })
    $content.Controls.Add($snoozeBtn)
    
    # Proceed Button
    $proceedBtn = [ModernButton]::new()
    $proceedBtn.Text = "PROCEED"
    $proceedBtn.Location = New-Object System.Drawing.Point(230, 140)
    $proceedBtn.BackColor = $script:Theme.Accent
    $proceedBtn.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 24)
    $proceedBtn.Size = New-Object System.Drawing.Size(110, 45)
    $proceedBtn.Add_Click({ $dialog.Tag = "Proceed"; $dialog.Close() })
    $content.Controls.Add($proceedBtn)
    
    # Close on escape
    $dialog.Add_KeyDown({ if ($_.KeyCode -eq "Escape") { $dialog.Close() } })
    $dialog.KeyPreview = $true
    
    $dialog.ShowDialog() | Out-Null
    return $dialog.Tag
}

# =====================================================
# MAIN FORM
# =====================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer Ultimate"
$form.Size = New-Object System.Drawing.Size(550, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $script:Theme.Background
$form.Padding = New-Object System.Windows.Forms.Padding(20)

# =====================================================
# HEADER
# =====================================================
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(510, 80)
$headerPanel.Location = New-Object System.Drawing.Point(20, 20)
$headerPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($headerPanel)

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "Sleep Timer"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $script:Theme.TextPrimary
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(0, 5)
$headerPanel.Controls.Add($title)

$ultimate = New-Object System.Windows.Forms.Label
$ultimate.Text = "ULTIMATE"
$ultimate.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$ultimate.ForeColor = $script:Theme.Accent
$ultimate.AutoSize = $true
$ultimate.Location = New-Object System.Drawing.Point(215, 20)
$headerPanel.Controls.Add($ultimate)

# Subtitle
$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Professional Power Management"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$subtitle.ForeColor = $script:Theme.TextSecondary
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(0, 50)
$headerPanel.Controls.Add($subtitle)

# Settings button (top right)
$settingsBtn = [ModernButton]::new()
$settingsBtn.Text = "⚙"
$settingsBtn.Size = New-Object System.Drawing.Size(45, 45)
$settingsBtn.Location = New-Object System.Drawing.Point(465, 15)
$settingsBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$settingsBtn.BackColor = $script:Theme.Surface
$form.Controls.Add($settingsBtn)

# =====================================================
# CIRCULAR PROGRESS (CENTER)
# =====================================================
$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.Size = New-Object System.Drawing.Size(220, 220)
$progressPanel.Location = New-Object System.Drawing.Point(165, 120)
$progressPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($progressPanel)

$circle = [CircularProgressBar]::new()
$circle.Size = New-Object System.Drawing.Size(200, 200)
$circle.Location = New-Object System.Drawing.Point(10, 10)
$circle.Maximum = 100
$circle.Value = 0
$progressPanel.Controls.Add($circle)

# Time display in center
$timeDisplay = New-Object System.Windows.Forms.Label
$timeDisplay.Text = "{0:D2}:{1:D2}" -f [math]::Floor($script:Settings.Minutes), 0
$timeDisplay.Font = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$timeDisplay.ForeColor = $script:Theme.TextPrimary
$timeDisplay.TextAlign = "MiddleCenter"
$timeDisplay.Size = New-Object System.Drawing.Size(180, 60)
$timeDisplay.Location = New-Object System.Drawing.Point(20, 70)
$progressPanel.Controls.Add($timeDisplay)
$progressPanel.Controls.SetChildIndex($timeDisplay, 0)

# Action display
$actionDisplay = New-Object System.Windows.Forms.Label
$actionDisplay.Text = $script:Settings.Action
$actionDisplay.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$actionDisplay.ForeColor = $script:Theme.Accent
$actionDisplay.TextAlign = "MiddleCenter"
$actionDisplay.Size = New-Object System.Drawing.Size(180, 25)
$actionDisplay.Location = New-Object System.Drawing.Point(20, 130)
$progressPanel.Controls.Add($actionDisplay)
$progressPanel.Controls.SetChildIndex($actionDisplay, 0)

# =====================================================
# PROFILE SELECTOR
# =====================================================
$profilePanel = New-Object System.Windows.Forms.Panel
$profilePanel.Size = New-Object System.Drawing.Size(510, 40)
$profilePanel.Location = New-Object System.Drawing.Point(20, 360)
$profilePanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($profilePanel)

$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Text = "PROFILE"
$profileLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$profileLabel.ForeColor = $script:Theme.TextMuted
$profileLabel.AutoSize = $true
$profileLabel.Location = New-Object System.Drawing.Point(0, 12)
$profilePanel.Controls.Add($profileLabel)

$profileCombo = New-Object System.Windows.Forms.ComboBox
$profileCombo.Location = New-Object System.Drawing.Point(70, 5)
$profileCombo.Size = New-Object System.Drawing.Size(200, 32)
$profileCombo.DropDownStyle = "DropDownList"
$profileCombo.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$profileCombo.BackColor = $script:Theme.Surface
$profileCombo.ForeColor = $script:Theme.TextPrimary
$profileCombo.FlatStyle = "Flat"
$profileCombo.Items.Add("(Custom)")
$script:Profiles.Keys | Sort-Object | ForEach-Object { $profileCombo.Items.Add($_) }
if ($script:Settings.LastProfile -and $script:Profiles[$script:Settings.LastProfile]) {
    $profileCombo.SelectedItem = $script:Settings.LastProfile
} else {
    $profileCombo.SelectedIndex = 0
}
$profilePanel.Controls.Add($profileCombo)

# =====================================================
# CONTROLS SECTION
# =====================================================
$controlsPanel = New-Object System.Windows.Forms.Panel
$controlsPanel.Size = New-Object System.Drawing.Size(510, 50)
$controlsPanel.Location = New-Object System.Drawing.Point(20, 410)
$controlsPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($controlsPanel)

# Minutes Input
$minInput = New-Object System.Windows.Forms.NumericUpDown
$minInput.Location = New-Object System.Drawing.Point(0, 5)
$minInput.Size = New-Object System.Drawing.Size(100, 30)
$minInput.Minimum = 1
$minInput.Maximum = 1440
$minInput.Value = $script:Settings.Minutes
$minInput.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$minInput.BackColor = $script:Theme.Surface
$minInput.ForeColor = $script:Theme.TextPrimary
$minInput.BorderStyle = "None"
$controlsPanel.Controls.Add($minInput)

$minLabel = New-Object System.Windows.Forms.Label
$minLabel.Text = "min"
$minLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$minLabel.ForeColor = $script:Theme.TextSecondary
$minLabel.AutoSize = $true
$minLabel.Location = New-Object System.Drawing.Point(110, 12)
$controlsPanel.Controls.Add($minLabel)

# Action Dropdown
$actionCombo = New-Object System.Windows.Forms.ComboBox
$actionCombo.Location = New-Object System.Drawing.Point(160, 5)
$actionCombo.Size = New-Object System.Drawing.Size(150, 32)
$actionCombo.DropDownStyle = "DropDownList"
$actionCombo.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$actionCombo.BackColor = $script:Theme.Surface
$actionCombo.ForeColor = $script:Theme.TextPrimary
$actionCombo.FlatStyle = "Flat"
$actionCombo.Items.AddRange(@("Sleep", "Shutdown", "Restart", "Hibernate", "Lock", "Logoff"))
$actionCombo.SelectedItem = $script:Settings.Action
$controlsPanel.Controls.Add($actionCombo)

# Quick presets
$presetX = 330
$presets = @(15, 30, 60)
foreach ($val in $presets) {
    $btn = [ModernButton]::new()
    $btn.Text = "$val`""
    $btn.Size = New-Object System.Drawing.Size(50, 40)
    $btn.Location = New-Object System.Drawing.Point($presetX, 5)
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btn.BackColor = $script:Theme.Surface
    $v = $val
    $btn.Add_Click({ $minInput.Value = $v })
    $controlsPanel.Controls.Add($btn)
    $presetX += 60
}

# =====================================================
# MAIN BUTTON
# =====================================================
$mainBtn = [ModernButton]::new()
$mainBtn.Text = "START TIMER"
$mainBtn.Size = New-Object System.Drawing.Size(300, 60)
$mainBtn.Location = New-Object System.Drawing.Point(125, 480)
$mainBtn.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$mainBtn.BackColor = $script:Theme.Accent
$mainBtn.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 24)
$form.Controls.Add($mainBtn)

# Close button (X)
$closeBtn = New-Object System.Windows.Forms.Label
$closeBtn.Text = "✕"
$closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$closeBtn.ForeColor = $script:Theme.TextMuted
$closeBtn.AutoSize = $true
$closeBtn.Location = New-Object System.Drawing.Point(515, 5)
$closeBtn.Cursor = "Hand"
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

# =====================================================
# TIMER LOGIC
# =====================================================
$mainBtn.Add_Click({
    if (-not $script:TimerActive) {
        # START
        $script:TimerActive = $true
        $script:TotalSeconds = [int]$minInput.Value * 60
        $script:RemainingSeconds = $script:TotalSeconds
        
        $mainBtn.Text = "STOP TIMER"
        $mainBtn.BackColor = $script:Theme.Danger
        $mainBtn.ForeColor = $script:Theme.TextPrimary
        $minInput.Enabled = $false
        $actionCombo.Enabled = $false
        $profileCombo.Enabled = $false
        $actionDisplay.Text = $actionCombo.SelectedItem
        $actionDisplay.ForeColor = $script:Theme.Success
        
        # Animation timer
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 1000
        $script:Timer.Add_Tick({
            if ($script:RemainingSeconds -gt 0 -and $script:TimerActive) {
                $script:RemainingSeconds--
                $min = [math]::Floor($script:RemainingSeconds / 60)
                $sec = $script:RemainingSeconds % 60
                $timeDisplay.Text = "{0:D2}:{1:D2}" -f $min, $sec
                
                # Update circle progress
                $percent = 100 - (($script:RemainingSeconds / $script:TotalSeconds) * 100)
                $circle.Value = [math]::Min(100, [math]::Max(0, [int]$percent))
                $circle.Invalidate()
                
                # Warning
                if ($script:RemainingSeconds -eq ($script:Settings.WarningMinutes * 60) -and $script:Settings.WarningMinutes -gt 0) {
                    $script:NotifyIcon.Visible = $true
                    $script:NotifyIcon.ShowBalloonTip(5000, "Timer Warning", "$($actionCombo.SelectedItem) in $($script:Settings.WarningMinutes) min!", "Warning")
                    try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
                    
                    $result = Show-SnoozeDialog -ActionName $actionCombo.SelectedItem -Minutes $script:Settings.WarningMinutes
                    if ($result -eq "Snooze") {
                        $script:RemainingSeconds += 600
                        $script:TotalSeconds += 600
                    }
                }
            } else {
                # Complete
                $script:Timer.Stop()
                $script:TimerActive = $false
                
                switch ($actionCombo.SelectedItem) {
                    "Shutdown" { Stop-Computer -Force }
                    "Restart" { Restart-Computer -Force }
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
        # STOP
        $script:TimerActive = $false
        $script:Timer.Stop()
        $timeDisplay.Text = "{0:D2}:{1:D2}" -f [int]$minInput.Value, 0
        $circle.Value = 0
        $circle.Invalidate()
        $mainBtn.Text = "START TIMER"
        $mainBtn.BackColor = $script:Theme.Accent
        $mainBtn.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 24)
        $minInput.Enabled = $true
        $actionCombo.Enabled = $true
        $profileCombo.Enabled = $true
        $actionDisplay.Text = $actionCombo.SelectedItem
        $actionDisplay.ForeColor = $script:Theme.Accent
    }
})

# Profile change
$profileCombo.Add_SelectedIndexChanged({
    $selected = $profileCombo.SelectedItem
    if ($selected -ne "(Custom)" -and $script:Profiles[$selected]) {
        $minInput.Value = $script:Profiles[$selected].Minutes
        $actionCombo.SelectedItem = $script:Profiles[$selected].Action
        $script:Settings.LastProfile = $selected
        $actionDisplay.Text = $script:Profiles[$selected].Action
    }
})

# Action change
$actionCombo.Add_SelectedIndexChanged({
    $actionDisplay.Text = $actionCombo.SelectedItem
})

# Settings dialog
$settingsBtn.Add_Click({
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Settings"
    $sf.Size = New-Object System.Drawing.Size(350, 300)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "FixedDialog"
    $sf.BackColor = $script:Theme.Background
    $sf.ForeColor = $script:Theme.TextPrimary
    
    $y = 20
    @(
        @{ Label = "Warning (min before)"; Control = { $n = New-Object System.Windows.Forms.NumericUpDown; $n.Minimum = 0; $n.Maximum = 30; $n.Value = $script:Settings.WarningMinutes; $n.Width = 60; $n } },
        @{ Label = "Play sounds"; Control = { $c = New-Object System.Windows.Forms.CheckBox; $c.Checked = $script:Settings.PlaySound; $c } },
        @{ Label = "Minimize to tray"; Control = { $c = New-Object System.Windows.Forms.CheckBox; $c.Checked = $script:Settings.MinimizeToTray; $c } }
    ) | ForEach-Object {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $_.Label
        $lbl.Location = New-Object System.Drawing.Point(20, $y)
        $lbl.Size = New-Object System.Drawing.Size(150, 25)
        $lbl.ForeColor = $script:Theme.TextSecondary
        $sf.Controls.Add($lbl)
        
        $ctrl = & $_.Control
        $ctrl.Location = New-Object System.Drawing.Point(180, $y)
        $ctrl.BackColor = $script:Theme.Surface
        $ctrl.ForeColor = $script:Theme.TextPrimary
        $sf.Controls.Add($ctrl)
        $sf.Tag = @{ $_.Label = $ctrl }
        $y += 40
    }
    
    $sb = [ModernButton]::new()
    $sb.Text = "SAVE"
    $sb.Size = New-Object System.Drawing.Size(120, 40)
    $sb.Location = New-Object System.Drawing.Point(115, $y + 10)
    $sb.BackColor = $script:Theme.Accent
    $sb.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 24)
    $sb.Add_Click({
        $script:Settings.WarningMinutes = [int]$sf.Controls[1].Value
        $script:Settings.PlaySound = $sf.Controls[3].Checked
        $script:Settings.MinimizeToTray = $sf.Controls[5].Checked
        $script:Settings.Minutes = [int]$minInput.Value
        $script:Settings.Action = $actionCombo.SelectedItem
        $script:Settings.LastProfile = $profileCombo.SelectedItem
        $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
        $sf.Close()
    })
    $sf.Controls.Add($sb)
    
    $sf.ShowDialog()
})

# Drag to move
$dragging = $false
$dragOffset = New-Object System.Drawing.Point
$form.Add_MouseDown({ $script:dragging = $true; $script:dragOffset = New-Object System.Drawing.Point($_.X, $_.Y) })
$form.Add_MouseMove({ if ($script:dragging) { $form.Location = New-Object System.Drawing.Point([System.Windows.Forms.Cursor]::Position.X - $script:dragOffset.X, [System.Windows.Forms.Cursor]::Position.Y - $script:dragOffset.Y) } })
$form.Add_MouseUp({ $script:dragging = $false })
$headerPanel.Add_MouseDown({ $script:dragging = $true; $script:dragOffset = New-Object System.Drawing.Point($_.X, $_.Y) })
$headerPanel.Add_MouseMove({ if ($script:dragging) { $form.Location = New-Object System.Drawing.Point([System.Windows.Forms.Cursor]::Position.X - $script:dragOffset.X, [System.Windows.Forms.Cursor]::Position.Y - $script:dragOffset.Y) } })
$headerPanel.Add_MouseUp({ $script:dragging = $false })

# Tray icon
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Sleep Timer Ultimate"
$script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:NotifyIcon.Visible = $false

$ctx = New-Object System.Windows.Forms.ContextMenuStrip
$show = New-Object System.Windows.Forms.ToolStripMenuItem
$show.Text = "Show"
$show.Add_Click({ $form.Show(); $form.WindowState = "Normal"; $script:NotifyIcon.Visible = $false })
$ctx.Items.Add($show)
$exit = New-Object System.Windows.Forms.ToolStripMenuItem
$exit.Text = "Exit"
$exit.Add_Click({ $form.Close() })
$ctx.Items.Add($exit)
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
    $script:Settings.Action = $actionCombo.SelectedItem
    $script:Settings.LastProfile = $profileCombo.SelectedItem
    $script:Settings | ConvertTo-Json | Set-Content $SettingsPath
})

# Show
$form.ShowDialog()
$script:NotifyIcon.Visible = $false
