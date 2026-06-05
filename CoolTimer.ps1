#Requires -Version 5.1
<#
.SYNOPSIS
    Nightfall - bedtime countdown.
#>
[CmdletBinding()]
param(
    [int]$Seconds,
    [switch]$NoSave,
    [switch]$NoAutoStart,
    [switch]$TestMode,
    [alias('DryRun')]
    [switch]$SafeMode
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$corePsm1 = Join-Path $script:Root 'modules\Nightfall.Core.psm1'
if (Test-Path $corePsm1) { Import-Module $corePsm1 -Force }
$channelFile = Join-Path $script:Root 'channel.txt'
if (-not (Test-Path $channelFile)) {
    $exeDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    $channelFile = Join-Path $exeDir 'channel.txt'
}
if (Test-Path $channelFile) {
    Set-NightfallChannel -Name ((Get-Content $channelFile -Raw).Trim())
} else {
    Set-NightfallChannel -Name 'Dev'
}
$script:Version = Get-NightfallVersion
$script:IsRelease = ($script:Channel -eq 'Release')

#region Theme
$script:C = @{
    Bg     = [System.Drawing.Color]::FromArgb(12, 12, 16)
    Card   = [System.Drawing.Color]::FromArgb(22, 22, 30)
    Ink    = [System.Drawing.Color]::FromArgb(250, 248, 242)
    Muted  = [System.Drawing.Color]::FromArgb(105, 105, 118)
    Amber  = [System.Drawing.Color]::FromArgb(237, 175, 88)
    Mint   = [System.Drawing.Color]::FromArgb(88, 210, 168)
    Rose   = [System.Drawing.Color]::FromArgb(235, 100, 115)
    Track  = [System.Drawing.Color]::FromArgb(36, 36, 48)
    Glow   = [System.Drawing.Color]::FromArgb(60, 45, 20)
}
#endregion

#region Settings (Nightfall.Core)
$script:S = Get-NightfallSettings
$script:DryRun = $TestMode -or $SafeMode -or $NoSave -or ($env:COOLTIMER_TEST -eq '1')
if (-not $script:IsRelease -and $script:S.DryRun) { $script:DryRun = $true }
Set-NightfallDryRun $script:DryRun

function Save-Settings {
    if ($NoSave) { return }
    $script:S.DefaultSeconds = Get-SelectedSeconds
    $script:S.Action = $script:Action
    $script:S.ConfirmAtEnd = $chkConfirm.Checked
    $script:S.TopMost = $chkTop.Checked
    $script:S.WarnAt5Min = $chkWarn5.Checked
    if (-not $script:IsRelease) {
        $script:S.DryRun = $chkDryRun.Checked
        $script:DryRun = $chkDryRun.Checked
        Set-NightfallDryRun $script:DryRun
    }
    $script:S.EmitLuxGridEvents = $chkLuxGrid.Checked
    if ($chkLogin) {
        $script:S.RunAtLogin = $chkLogin.Checked
        try { Set-NightfallRunAtLogin -Enabled $chkLogin.Checked } catch { }
    }
    Save-NightfallSettings $script:S
    Update-DryRunBanner
}

function Get-SelectedSeconds {
    [int][math]::Round([decimal]$numMin.Value * 60)
}

function Get-LuxGridEnabled { $chkLuxGrid.Checked }

function Show-About {
    [System.Windows.Forms.MessageBox]::Show(
        @"
Nightfall v$script:Version
Channel: $script:Channel

Bedtime countdown for Windows.
Your ritual: ~28:20 then power off.

Settings: %LOCALAPPDATA%\CoolTimer\
Docs: PRODUCT.md in repo
"@,
        'About Nightfall',
        'OK',
        'Information') | Out-Null
}
#endregion

#region State
$script:Action = $script:S.Action
$script:Running = $false
$script:Total = 0
$script:Left = 0
$script:Warn60 = $false
$script:Warn300 = $false
$script:Pulse = 0.0
#endregion

#region UI helpers
function Enable-DoubleBuffer {
    param($Control)
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Control.GetType().GetProperty('DoubleBuffered', $flags)
    if ($prop) { $prop.SetValue($Control, $true, $null) }
}

function Style-Button {
    param($B, $Bg, $Fg = $script:C.Ink, [int]$Size = 9, [System.Drawing.Color]$Hover = $null)
    $B.FlatStyle = 'Flat'
    $B.FlatAppearance.BorderSize = 0
    $B.BackColor = $Bg
    $B.ForeColor = $Fg
    $B.Font = New-Object System.Drawing.Font('Segoe UI', $Size)
    $B.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Hover) { $B.FlatAppearance.MouseOverBackColor = $Hover }
}

function Set-Action {
    param([string]$Name)
    $script:Action = $Name
    foreach ($p in $script:Pills) {
        $on = ($p.Tag -eq $Name)
        if ($on) {
            $p.BackColor = if ($Name -eq 'Sleep') { $script:C.Mint } else { $script:C.Amber }
            $p.ForeColor = [System.Drawing.Color]::FromArgb(18, 16, 12)
        } else {
            $p.BackColor = $script:C.Card
            $p.ForeColor = $script:C.Muted
        }
    }
    if (-not $script:Running) {
        Save-Settings
        if (Get-Command Update-Display -ErrorAction SilentlyContinue) { Update-Display }
    }
}

function Get-RingColor {
    if ($script:Left -le 30 -and $script:Running) {
        $t = [int]($script:Pulse * 255)
        return [System.Drawing.Color]::FromArgb(255, 120 + $t/2, 90 + $t/3)
    }
    switch ($script:Action) {
        'Sleep' { return $script:C.Mint }
        'Restart' { return [System.Drawing.Color]::FromArgb(160, 190, 255) }
        default { return $script:C.Amber }
    }
}

function Draw-Ring {
    param($G)
    $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(12, 12, 196, 196)
    $remainPct = if ($script:Total -gt 0) { $script:Left / $script:Total } else { 1 }
    $sweep = [int](360 * $remainPct)

    $trackPen = New-Object System.Drawing.Pen($script:C.Track, 11)
    $G.DrawArc($trackPen, $rect, 0, 360)
    $trackPen.Dispose()

    if ($sweep -gt 0) {
        $col = Get-RingColor
        $arcPen = New-Object System.Drawing.Pen($col, 11)
        $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $G.DrawArc($arcPen, $rect, -90, $sweep)
        $arcPen.Dispose()

        $rad = (-90 + $sweep) * [math]::PI / 180
        $cx = $rect.X + $rect.Width / 2 + ($rect.Width / 2 - 4) * [math]::Cos($rad)
        $cy = $rect.Y + $rect.Height / 2 + ($rect.Height / 2 - 4) * [math]::Sin($rad)
        $G.FillEllipse((New-Object System.Drawing.SolidBrush($col)), $cx - 5, $cy - 5, 10, 10)
    }
}

function Format-RemainingFriendly {
    $m = [math]::Ceiling($script:Left / 60.0)
    if ($m -le 1) { return 'under a minute left' }
    if ($m -eq 1) { return '1 minute left' }
    return "$m minutes left"
}
#endregion

#region Form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Nightfall'
$form.Size = New-Object System.Drawing.Size(400, 480)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.ShowInTaskbar = $true
$form.TopMost = $script:S.TopMost
$form.BackColor = $script:C.Bg
$form.KeyPreview = $true

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = 'Nightfall'
$lblBrand.Location = New-Object System.Drawing.Point(28, 18)
$lblBrand.AutoSize = $true
$lblBrand.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$lblBrand.ForeColor = $script:C.Ink
$lblBrand.BackColor = $script:C.Bg
$lblBrand.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblBrand.Add_Click({ Show-About })
$form.Controls.Add($lblBrand)

$lblVer = New-Object System.Windows.Forms.Label
$lblVer.Text = "v$script:Version"
$lblVer.Location = New-Object System.Drawing.Point(120, 20)
$lblVer.AutoSize = $true
$lblVer.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblVer.ForeColor = $script:C.Muted
$lblVer.BackColor = $script:C.Bg
$form.Controls.Add($lblVer)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Location = New-Object System.Drawing.Point(28, 44)
$lblSub.Size = New-Object System.Drawing.Size(344, 18)
$lblSub.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$lblSub.ForeColor = $script:C.Muted
$lblSub.BackColor = $script:C.Bg
$form.Controls.Add($lblSub)

$lblDryRun = New-Object System.Windows.Forms.Label
$lblDryRun.Text = 'DRY RUN - PC will not shut down, sleep, or restart'
$lblDryRun.Location = New-Object System.Drawing.Point(28, 62)
$lblDryRun.Size = New-Object System.Drawing.Size(344, 18)
$lblDryRun.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
$lblDryRun.ForeColor = $script:C.Amber
$lblDryRun.BackColor = $script:C.Bg
$lblDryRun.Visible = $false
$form.Controls.Add($lblDryRun)

$pnlRing = New-Object System.Windows.Forms.Panel
$pnlRing.Location = New-Object System.Drawing.Point(78, 84)
$pnlRing.Size = New-Object System.Drawing.Size(220, 220)
$pnlRing.BackColor = $script:C.Bg
Enable-DoubleBuffer $pnlRing
$pnlRing.Add_Paint({ param($s, $e); Draw-Ring $e.Graphics })
$form.Controls.Add($pnlRing)

$timeFont = 'Consolas'
try { $null = New-Object System.Drawing.Font('Cascadia Mono', 12); $timeFont = 'Cascadia Mono' } catch { }

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Location = New-Object System.Drawing.Point(0, 62)
$lblTime.Size = New-Object System.Drawing.Size(220, 48)
$lblTime.TextAlign = 'MiddleCenter'
$lblTime.Font = New-Object System.Drawing.Font($timeFont, 34, [System.Drawing.FontStyle]::Bold)
$lblTime.ForeColor = $script:C.Ink
$lblTime.BackColor = $script:C.Bg
$pnlRing.Controls.Add($lblTime)

$lblRemain = New-Object System.Windows.Forms.Label
$lblRemain.Location = New-Object System.Drawing.Point(0, 112)
$lblRemain.Size = New-Object System.Drawing.Size(220, 20)
$lblRemain.TextAlign = 'MiddleCenter'
$lblRemain.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$lblRemain.ForeColor = $script:C.Muted
$lblRemain.BackColor = $script:C.Bg
$pnlRing.Controls.Add($lblRemain)

$lblEnd = New-Object System.Windows.Forms.Label
$lblEnd.Location = New-Object System.Drawing.Point(28, 296)
$lblEnd.Size = New-Object System.Drawing.Size(344, 22)
$lblEnd.TextAlign = 'MiddleCenter'
$lblEnd.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$lblEnd.ForeColor = $script:C.Muted
$lblEnd.BackColor = $script:C.Bg
$form.Controls.Add($lblEnd)

$pnlCard = New-Object System.Windows.Forms.Panel
$pnlCard.Location = New-Object System.Drawing.Point(20, 318)
$pnlCard.Size = New-Object System.Drawing.Size(360, 158)
$pnlCard.BackColor = $script:C.Card
$form.Controls.Add($pnlCard)

$script:Pills = @()
foreach ($a in @('Shutdown', 'Sleep', 'Restart')) {
    $i = $script:Pills.Count
    $p = New-Object System.Windows.Forms.Button
    $p.Text = $a
    $p.Tag = $a
    $p.Size = New-Object System.Drawing.Size(104, 34)
    $p.Location = New-Object System.Drawing.Point((12 + $i * 112), 12)
    Style-Button $p $script:C.Bg $script:C.Muted 9 ([System.Drawing.Color]::FromArgb(42, 42, 56))
    $p.Add_Click({ Set-Action $this.Tag })
    $pnlCard.Controls.Add($p)
    $script:Pills += $p
}

$pnlDur = New-Object System.Windows.Forms.Panel
$pnlDur.Location = New-Object System.Drawing.Point(0, 52)
$pnlDur.Size = New-Object System.Drawing.Size(360, 36)
$pnlDur.BackColor = $script:C.Card
$pnlCard.Controls.Add($pnlDur)

$numMin = New-Object System.Windows.Forms.NumericUpDown
$numMin.Location = New-Object System.Drawing.Point(12, 4)
$numMin.Size = New-Object System.Drawing.Size(76, 28)
$numMin.DecimalPlaces = 2
$numMin.Increment = 0.5
$numMin.Minimum = 1
$numMin.Maximum = 720
$numMin.BackColor = $script:C.Bg
$numMin.ForeColor = $script:C.Ink
$numMin.BorderStyle = 'FixedSingle'
$secDefault = [math]::Max(60, [int]$script:S.DefaultSeconds)
$numMin.Value = [decimal]($secDefault / 60.0)
$pnlDur.Controls.Add($numMin)

$lblM = New-Object System.Windows.Forms.Label
$lblM.Text = 'min tonight'
$lblM.Location = New-Object System.Drawing.Point(92, 9)
$lblM.AutoSize = $true
$lblM.ForeColor = $script:C.Muted
$lblM.BackColor = $script:C.Card
$pnlDur.Controls.Add($lblM)

$px = 168
foreach ($pr in @(
    @{ T = '28:20'; V = 28.33 }
    @{ T = '30'; V = 30 }
    @{ T = '45'; V = 45 }
    @{ T = '60'; V = 60 }
)) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $pr.T
    $b.Size = New-Object System.Drawing.Size(44, 28)
    $b.Location = New-Object System.Drawing.Point($px, 4)
    $v = $pr.V
    Style-Button $b $script:C.Bg $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(42, 42, 56))
    $b.Add_Click({ $numMin.Value = [decimal]$v }.GetNewClosure())
    $pnlDur.Controls.Add($b)
    $px += 46
}

$pnlRun = New-Object System.Windows.Forms.Panel
$pnlRun.Location = New-Object System.Drawing.Point(0, 52)
$pnlRun.Size = New-Object System.Drawing.Size(360, 44)
$pnlRun.BackColor = $script:C.Card
$pnlRun.Visible = $false
$pnlCard.Controls.Add($pnlRun)

$btnSnooze5 = New-Object System.Windows.Forms.Button
$btnSnooze5.Text = '+5'
$btnSnooze5.Size = New-Object System.Drawing.Size(72, 36)
$btnSnooze5.Location = New-Object System.Drawing.Point(8, 4)
Style-Button $btnSnooze5 $script:C.Bg $script:C.Ink 9 ([System.Drawing.Color]::FromArgb(42, 42, 56))
$pnlRun.Controls.Add($btnSnooze5)

$btnSnooze = New-Object System.Windows.Forms.Button
$btnSnooze.Text = '+10 min'
$btnSnooze.Size = New-Object System.Drawing.Size(88, 36)
$btnSnooze.Location = New-Object System.Drawing.Point(86, 4)
Style-Button $btnSnooze $script:C.Bg $script:C.Ink 9 ([System.Drawing.Color]::FromArgb(42, 42, 56))
$pnlRun.Controls.Add($btnSnooze)

$btnPause = New-Object System.Windows.Forms.Button
$btnPause.Text = 'Pause'
$btnPause.Size = New-Object System.Drawing.Size(80, 36)
$btnPause.Location = New-Object System.Drawing.Point(180, 4)
Style-Button $btnPause $script:C.Bg $script:C.Ink 9 ([System.Drawing.Color]::FromArgb(42, 42, 56))
$pnlRun.Controls.Add($btnPause)

$btnNow = New-Object System.Windows.Forms.Button
$btnNow.Text = 'Now'
$btnNow.Size = New-Object System.Drawing.Size(72, 36)
$btnNow.Location = New-Object System.Drawing.Point(268, 4)
Style-Button $btnNow $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 16, 10)) 9 $script:C.Glow
$pnlRun.Controls.Add($btnNow)

$pnlOpts = New-Object System.Windows.Forms.Panel
$pnlOpts.Location = New-Object System.Drawing.Point(0, 96)
$pnlOpts.Size = New-Object System.Drawing.Size(360, 52)
$pnlOpts.BackColor = $script:C.Card
$pnlCard.Controls.Add($pnlOpts)

$chkConfirm = New-Object System.Windows.Forms.CheckBox
$chkConfirm.Text = '5s confirm'
$chkConfirm.Location = New-Object System.Drawing.Point(12, 10)
$chkConfirm.AutoSize = $true
$chkConfirm.ForeColor = $script:C.Muted
$chkConfirm.BackColor = $script:C.Card
$chkConfirm.Checked = $script:S.ConfirmAtEnd
$pnlOpts.Controls.Add($chkConfirm)

$chkWarn5 = New-Object System.Windows.Forms.CheckBox
$chkWarn5.Text = 'Chime @ 5 min'
$chkWarn5.Location = New-Object System.Drawing.Point(110, 10)
$chkWarn5.AutoSize = $true
$chkWarn5.ForeColor = $script:C.Muted
$chkWarn5.BackColor = $script:C.Card
$chkWarn5.Checked = $script:S.WarnAt5Min
$pnlOpts.Controls.Add($chkWarn5)

$chkTop = New-Object System.Windows.Forms.CheckBox
$chkTop.Text = 'On top'
$chkTop.Location = New-Object System.Drawing.Point(220, 10)
$chkTop.AutoSize = $true
$chkTop.ForeColor = $script:C.Muted
$chkTop.BackColor = $script:C.Card
$chkTop.Checked = $script:S.TopMost
$chkTop.Add_CheckedChanged({ $form.TopMost = $chkTop.Checked; Save-Settings })
$pnlOpts.Controls.Add($chkTop)

$chkDryRun = New-Object System.Windows.Forms.CheckBox
$chkDryRun.Text = 'Dry run'
$chkDryRun.Location = New-Object System.Drawing.Point(290, 10)
$chkDryRun.AutoSize = $true
$chkDryRun.ForeColor = $script:C.Amber
$chkDryRun.BackColor = $script:C.Card
$chkDryRun.Checked = $script:DryRun
$chkDryRun.Add_CheckedChanged({
    $script:DryRun = $chkDryRun.Checked
    Set-NightfallDryRun $script:DryRun
    if (-not $script:Running) { Save-Settings } else { Update-DryRunBanner }
})
$pnlOpts.Controls.Add($chkDryRun)

$chkLuxGrid = New-Object System.Windows.Forms.CheckBox
$chkLuxGrid.Text = 'RGB events'
$chkLuxGrid.Location = New-Object System.Drawing.Point(12, 28)
$chkLuxGrid.AutoSize = $true
$chkLuxGrid.ForeColor = $script:C.Muted
$chkLuxGrid.BackColor = $script:C.Card
$chkLuxGrid.Checked = [bool]$script:S.EmitLuxGridEvents
$chkLuxGrid.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })
$pnlOpts.Controls.Add($chkLuxGrid)

$chkLogin = New-Object System.Windows.Forms.CheckBox
$chkLogin.Text = 'Run at login'
$chkLogin.Location = New-Object System.Drawing.Point(120, 28)
$chkLogin.AutoSize = $true
$chkLogin.ForeColor = $script:C.Muted
$chkLogin.BackColor = $script:C.Card
$chkLogin.Checked = [bool]$script:S.RunAtLogin
if (-not $chkLogin.Checked) { $chkLogin.Checked = Test-NightfallRunAtLogin }
$chkLogin.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })
$pnlOpts.Controls.Add($chkLogin)

if ($script:IsRelease) {
    $chkDryRun.Visible = $false
    $pnlOpts.Height = 56
}

$btnBegin = New-Object System.Windows.Forms.Button
$btnBegin.Text = 'Begin tonight'
$btnBegin.Size = New-Object System.Drawing.Size(336, 42)
$btnBegin.Location = New-Object System.Drawing.Point(12, 118)
Style-Button $btnBegin $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 16, 10)) 10 $script:C.Glow
$btnBegin.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$pnlCard.Controls.Add($btnBegin)

# Tray
$tray = New-Object System.Windows.Forms.NotifyIcon
$iconPath = Join-Path $script:Root 'Nightfall.ico'
if (-not (Test-Path $iconPath)) { $iconPath = Join-Path $script:Root 'assets\Nightfall.ico' }
if (Test-Path $iconPath) {
    $tray.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    $tray.Icon = [System.Drawing.SystemIcons]::Application
}
$tray.Visible = $true
$tray.Add_DoubleClick({ Show-MainWindow })
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('Show', $null, { Show-MainWindow })
[void]$menu.Items.Add('Pause', $null, { if ($script:Running) { Set-IdleUI } })
[void]$menu.Items.Add('+10 minutes', $null, { Add-Snooze 600 })
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Exit', $null, {
    $script:Running = $false
    $tick.Stop(); $pulse.Stop()
    $tray.Visible = $false
    $form.Close()
})
$tray.ContextMenuStrip = $menu
#endregion

#region Logic
function Update-DryRunBanner {
    $on = Test-NightfallDryRun
    $lblDryRun.Visible = $on
    if ($on) {
        $form.Text = 'Nightfall [DRY RUN]'
        $pnlRing.Location = New-Object System.Drawing.Point(78, 84)
    } else {
        $form.Text = 'Nightfall'
        $pnlRing.Location = New-Object System.Drawing.Point(78, 68)
    }
    if ($script:Running) {
        $lblSub.Text = if ($on) {
            'Dry run - timer only, no power off'
        } else {
            "$([int](100 * $script:Left / [math]::Max(1, $script:Total)))% remaining - Space pause, S +10m"
        }
    }
}

function Show-MainWindow {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.Activate()
}

function Set-TrayText {
    param([string]$Text)
    # NotifyIcon.Text max 63 chars; must be plain string (not $label.Text interpolation bug)
    if ($Text.Length -gt 63) { $Text = $Text.Substring(0, 63) }
    try { $tray.Text = $Text } catch { }
}

function Update-Display {
    $timeStr = ([TimeSpan]::FromSeconds([math]::Max(0, $script:Left))).ToString('mm\:ss')
    $lblTime.Text = $timeStr
    $lblRemain.Text = Format-RemainingFriendly
    $lblEnd.Text = "Tonight ends with $($script:Action.ToLower())"
    Update-DryRunBanner
    if ($script:Running) {
        if (Test-NightfallDryRun) {
            Set-TrayText "Nightfall [TEST] $timeStr"
        } else {
            Set-TrayText "Nightfall $timeStr ($($script:Action))"
        }
    } else {
        $lblSub.Text = 'Set tonight, then begin - or just open to auto-start'
        Set-TrayText 'Nightfall - ready'
    }
    $pnlRing.Invalidate()
}

function Set-IdleUI {
    if ($script:Running) {
        Publish-NightfallEvent -EventName 'timer.cancel' -Enabled (Get-LuxGridEnabled) -Payload @{
            remainingSeconds = $script:Left
            totalSeconds = $script:Total
        }
    }
    $script:Running = $false
    $tick.Stop()
    $pulse.Stop()
    $script:Pulse = 0
    $pnlRun.Visible = $false
    $pnlDur.Visible = $true
    $btnBegin.Visible = $true
    foreach ($p in $script:Pills) { $p.Visible = $true }
    $pnlOpts.Visible = $true
    Update-Display
}

function Set-ActiveUI {
    $script:Running = $true
    $pnlRun.Visible = $true
    $pnlDur.Visible = $false
    $btnBegin.Visible = $false
    foreach ($p in $script:Pills) { $p.Visible = $false }
    $pnlOpts.Visible = $false
    Update-Display
}

function Start-Night {
    param([int]$Sec)
    if ($Sec -lt 60) { $Sec = 60 }
    $script:Total = $Sec
    $script:Left = $Sec
    $script:Warn60 = $false
    $script:Warn300 = $false
    $script:Pulse = 0
    Save-Settings
    Set-ActiveUI
    Publish-NightfallEvent -EventName 'timer.start' -Enabled (Get-LuxGridEnabled) -Payload @{
        timerName = 'Nightfall'
        totalSeconds = $Sec
        action = $script:Action
    }
    $tick.Start()
    $pulse.Start()
}

function Add-Snooze {
    param([int]$Sec)
    $script:Left += $Sec
    $script:Warn60 = $false
    $script:Warn300 = $false
    Update-Display
}

function Show-FinalConfirm {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Still awake?'
    $dlg.Size = New-Object System.Drawing.Size(360, 210)
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.StartPosition = 'CenterParent'
    $dlg.TopMost = $true
    $dlg.BackColor = $script:C.Card
    $dlg.KeyPreview = $true

    $t = New-Object System.Windows.Forms.Label
    $t.Location = New-Object System.Drawing.Point(20, 20)
    $t.Size = New-Object System.Drawing.Size(320, 50)
    $t.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $t.ForeColor = $script:C.Ink
    $t.BackColor = $script:C.Card
    $dlg.Controls.Add($t)

    $confirmLeft = 5
    $cd = New-Object System.Windows.Forms.Timer
    $cd.Interval = 1000
    $cd.Add_Tick({
        $confirmLeft--
        $t.Text = "$($script:Action) in $confirmLeft...`nSnooze or tap Proceed."
        if ($confirmLeft -le 0) { $cd.Stop(); $dlg.DialogResult = 'OK'; $dlg.Close() }
    })
    $t.Text = "$($script:Action) in 5..."
    $cd.Start()

    $bSn = New-Object System.Windows.Forms.Button
    $bSn.Text = 'Snooze 10 min'
    $bSn.Location = New-Object System.Drawing.Point(20, 95)
    $bSn.Size = New-Object System.Drawing.Size(150, 38)
    Style-Button $bSn $script:C.Bg
    $bSn.Add_Click({ $cd.Stop(); $dlg.DialogResult = 'Retry'; $dlg.Close() })
    $dlg.Controls.Add($bSn)

    $bGo = New-Object System.Windows.Forms.Button
    $bGo.Text = 'Proceed'
    $bGo.Location = New-Object System.Drawing.Point(190, 95)
    $bGo.Size = New-Object System.Drawing.Size(150, 38)
    Style-Button $bGo $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 16, 10))
    $bGo.Add_Click({ $cd.Stop(); $dlg.DialogResult = 'OK'; $dlg.Close() })
    $dlg.Controls.Add($bGo)

    $dlg.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq 'Escape') { $cd.Stop(); $dlg.DialogResult = 'Cancel'; $dlg.Close() }
    })

    $r = $dlg.ShowDialog($form)
    $cd.Stop()
    $dlg.Dispose()
    return $r
}

function Complete-Timer {
    $tick.Stop()
    $pulse.Stop()
    $script:Running = $false

    if ($chkConfirm.Checked) {
        $r = Show-FinalConfirm
        if ($r -eq 'Retry') {
            Add-Snooze 600
            Set-ActiveUI
            $tick.Start()
            $pulse.Start()
            return
        }
        if ($r -ne 'OK') {
            Set-IdleUI
            return
        }
    }
    Save-Settings
    Publish-NightfallEvent -EventName 'timer.complete' -Enabled (Get-LuxGridEnabled) -Payload @{ action = $script:Action }
    if (Test-NightfallDryRun) {
        Invoke-NightfallPowerAction -Action $script:Action | Out-Null
        Set-IdleUI
        return
    }
    $tray.Visible = $false
    Invoke-NightfallPowerAction -Action $script:Action | Out-Null
}

$tick = New-Object System.Windows.Forms.Timer
$tick.Interval = 1000
$tick.Add_Tick({
    if (-not $script:Running) { return }
    if ($script:Left -gt 0) {
        $script:Left--
        Update-Display

        if ($chkWarn5.Checked -and -not $script:Warn300 -and $script:Left -eq 300) {
            $script:Warn300 = $true
            [System.Media.SystemSounds]::Asterisk.Play()
        }
        if (-not $script:Warn60 -and $script:Left -eq 60) {
            $script:Warn60 = $true
            [System.Media.SystemSounds]::Exclamation.Play()
            Publish-NightfallEvent -EventName 'timer.warning' -Enabled (Get-LuxGridEnabled) -Payload @{
                remainingSeconds = 60
                totalSeconds = $script:Total
            }
        }
        if ($script:Left % 30 -eq 0) {
            Publish-NightfallEvent -EventName 'timer.tick' -Enabled (Get-LuxGridEnabled) -Payload @{
                remainingSeconds = $script:Left
                totalSeconds = $script:Total
            }
        }
    } else {
        Complete-Timer
    }
})

$pulse = New-Object System.Windows.Forms.Timer
$pulse.Interval = 80
$pulse.Add_Tick({
    if ($script:Running -and $script:Left -le 30) {
        $script:Pulse = ($script:Pulse + 0.12) % 1.0
        $pnlRing.Invalidate()
    }
})

$btnBegin.Add_Click({ Start-Night (Get-SelectedSeconds) })
$btnPause.Add_Click({ Set-IdleUI })
$btnSnooze.Add_Click({ Add-Snooze 600 })
$btnSnooze5.Add_Click({ Add-Snooze 300 })
$btnNow.Add_Click({ Complete-Timer })

$pnlRing.Add_Click({ if ($script:Running) { Set-IdleUI } })
$lblTime.Add_Click({ if ($script:Running) { Set-IdleUI } })

$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'Space') {
        if ($script:Running) { Set-IdleUI } else { Start-Night (Get-SelectedSeconds) }
        $e.Handled = $true
    }
    elseif ($e.KeyCode -eq 'S' -and $script:Running) {
        Add-Snooze 600
        $e.Handled = $true
    }
    elseif ($e.KeyCode -eq 'Enter' -and -not $script:Running) {
        Start-Night (Get-SelectedSeconds)
        $e.Handled = $true
    }
})

$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized' -and $script:Running) { $form.Hide() }
})

$form.Add_FormClosing({
    param($s, $e)
    if ($script:Running) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            'Timer still running. Hide to tray?',
            'Nightfall', 'YesNoCancel', 'Question')
        if ($r -eq 'Yes') { $e.Cancel = $true; $form.Hide() }
        elseif ($r -eq 'No') { $script:Running = $false; $tick.Stop(); $pulse.Stop(); $tray.Visible = $false }
        else { $e.Cancel = $true }
    } else {
        $tray.Visible = $false
    }
})

$chkConfirm.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })
$chkWarn5.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })
$numMin.Add_ValueChanged({ if (-not $script:Running) { Save-Settings } })
#endregion

#region Launch
$script:PendingStart = $null
if ($PSBoundParameters.ContainsKey('Seconds')) {
    $script:PendingStart = $Seconds
} elseif (-not $NoAutoStart -and $script:S.AutoStart) {
    $script:PendingStart = $script:S.DefaultSeconds
}

$form.Add_Shown({
    Show-MainWindow
    Set-Action $script:S.Action
    if ($null -ne $script:PendingStart) {
        Start-Night $script:PendingStart
        $script:PendingStart = $null
    } else {
        Set-IdleUI
    }
})

$chkDryRun.Checked = $script:DryRun
Update-DryRunBanner

[void]$form.ShowDialog()
$tray.Visible = $false
$tray.Dispose()
