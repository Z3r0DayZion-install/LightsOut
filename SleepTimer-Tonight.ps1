#Requires -Version 5.1
# Sleep Timer - desktop nightly build
param(
    [switch]$NoAutoStart,
    [switch]$DryRun,
    [switch]$Minimized,
    [switch]$Start,
    [switch]$Help,
    [Alias('m', 'mins')]
    [int]$Minutes = 0,
    [Alias('a')]
    [string]$Action = '',
    [Alias('sec', 's')]
    [int]$Seconds = 0,
    [Alias('at')]
    [string]$At = '',
    [Alias('calendar', 'ics')]
    [string]$Calendar = ''
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Global hotkey type must load before ps2exe compile / at startup (tray-safe cancel)
if (-not ('GlobalHotKey' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class GlobalHotKey : NativeWindow, IDisposable {
    public event EventHandler HotKeyPressed;
    const int WM_HOTKEY = 0x0312;
    readonly int _id;
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public GlobalHotKey(IntPtr handle, int hotkeyId, uint mod, uint key) {
        _id = hotkeyId;
        AssignHandle(handle);
        if (!RegisterHotKey(handle, hotkeyId, mod, key))
            throw new InvalidOperationException("RegisterHotKey failed");
    }
    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == _id) {
            HotKeyPressed?.Invoke(this, EventArgs.Empty);
            return;
        }
        base.WndProc(ref m);
    }
    public void Dispose() {
        UnregisterHotKey(Handle, _id);
        ReleaseHandle();
    }
}
'@
}

$script:AppVersion = '5.1.0'
$script:AppName = 'Lights Out'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:AuditLogPath = Join-Path $script:SettingsDir 'actions.log'
$script:MinTimerSec = 60
$script:DefaultSec = 1700
$script:Action = 'Shutdown'
$script:Total = 0
$script:Left = 0
$script:Running = $false
$script:Paused = $false
$script:Warn5 = $false
$script:Warn60 = $false
$script:Warn30 = $false
$script:Pulse = 0.0
if ($env:SLEEPTIMER_SECONDS) { $Seconds = [int]$env:SLEEPTIMER_SECONDS }
if ($env:SLEEPTIMER_MINUTES) { $Minutes = [int]$env:SLEEPTIMER_MINUTES }
if ($env:SLEEPTIMER_ACTION) { $Action = [string]$env:SLEEPTIMER_ACTION }
if ($env:SLEEPTIMER_MINIMIZED -eq '1') { $Minimized = $true }
if ($env:SLEEPTIMER_NO_AUTOSTART -eq '1') { $NoAutoStart = $true }
if ($env:SLEEPTIMER_START -eq '1') { $Start = $true; $NoAutoStart = $false }
if ($env:SLEEPTIMER_AT) { $At = [string]$env:SLEEPTIMER_AT }
if ($env:SLEEPTIMER_CALENDAR) { $script:CliCalendar = [string]$env:SLEEPTIMER_CALENDAR }

$modRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PSCommandPath -Parent }
foreach ($modName in @('LightsOut.Calendar.psm1', 'LightsOut.Novel.psm1')) {
    $modPath = Join-Path $modRoot "modules\$modName"
    if (Test-Path $modPath) { Import-Module $modPath -Force -ErrorAction SilentlyContinue }
}

function Normalize-ActionName {
    param([string]$Raw)
    if (-not $Raw) { return $null }
    switch ($Raw.Trim().ToLower()) {
        'shutdown' { return 'Shutdown' }
        'shut' { return 'Shutdown' }
        'sleep' { return 'Sleep' }
        'restart' { return 'Restart' }
        'reboot' { return 'Restart' }
        'hibernate' { return 'Hibernate' }
        'hib' { return 'Hibernate' }
        'lock' { return 'Lock' }
        default { return $null }
    }
}

function Show-CliHelp {
    $msg = @"
Lights Out v$script:AppVersion

Examples:
  SleepTimer.exe -Minutes 28 -Action Shutdown -Start
  SleepTimer.exe /minutes 28 /action shutdown /start /min

-Minutes, /minutes     Countdown length in minutes
-Seconds, /seconds     Countdown length in seconds
-Action, /action       shutdown | sleep | restart | hibernate | lock
-Start, /start          Auto-start countdown (default)
-NoAutoStart            Open settings without starting
-Minimized, /min         Start minimized to tray
-DryRun                 Safe mode - no power action
-Help, /help            Show this help
-At, /at                Time or date+time (23:30, 2026-06-15 23:30, 6/15/2026 11:30 PM)
-Calendar, /calendar     Path to .ics file (Google/Outlook/Apple export)

Graceful exit (default on): lets apps save before shutdown.
Emergency cancel anytime: Ctrl+Shift+S
"@
    [System.Windows.Forms.MessageBox]::Show($msg, $script:AppName, 'OK', 'Information') | Out-Null
}

function Apply-StartupArguments {
    for ($i = 0; $i -lt $args.Count; $i++) {
        $tok = [string]$args[$i]
        $next = if ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { $null }
        $hasNext = ($null -ne $next) -and ($next -notmatch '^(/|-)')
        switch -Regex ($tok) {
            '^(/|-)(help|\?|h)$' { $script:CliHelp = $true; continue }
            '^(/|-)(minutes|mins|m)$' { if ($hasNext) { $script:CliMinutes = [int]$next; $i++ }; continue }
            '^(/|-)(seconds|sec|s)$' { if ($hasNext) { $script:CliSeconds = [int]$next; $i++ }; continue }
            '^(/|-)(action|a)$' { if ($hasNext) { $script:CliAction = $next; $i++ }; continue }
            '^(/|-)(start)$' { $script:CliStart = $true; continue }
            '^(/|-)(no(start)?|wait)$' { $script:CliNoStart = $true; continue }
            '^(/|-)(minimized|min|tray)$' { $script:CliMinimized = $true; continue }
            '^(/|-)(dryrun|dry-run)$' { $script:CliDryRun = $true; continue }
            '^(/|-)(at|time)$' { if ($hasNext) { $script:CliAt = $next; $i++ }; continue }
            '^(/|-)(calendar|ics)$' { if ($hasNext) { $script:CliCalendar = $next; $i++ }; continue }
        }
    }
}

$script:CliHelp = $false
$script:CliMinutes = 0
$script:CliSeconds = 0
$script:CliAction = $null
$script:CliStart = $false
$script:CliNoStart = $false
$script:CliMinimized = $false
$script:CliDryRun = $false
$script:CliAt = $null
$script:CliCalendar = $null
$script:ScheduledAt = $null
$script:CalendarSource = ''
$script:CalendarEventUid = ''
$script:CalendarEventTitle = ''
$script:PactBreaks = 0
$script:PactSnoozeLocked = $false
$script:HouseholdPartner = $null
$script:DimPhaseSec = 90
Apply-StartupArguments

if ($Help -or $script:CliHelp) { Show-CliHelp; return }
if ($Start -or $script:CliStart) { $NoAutoStart = $false }
if ($script:CliNoStart) { $NoAutoStart = $true }
if ($Minimized -or $script:CliMinimized) { $Minimized = $true }
$script:DryRun = $DryRun -or $script:CliDryRun -or ($env:SLEEPTIMER_DRY_RUN -eq '1') -or ($env:SLEEPTIMER_CI -eq '1')
if ($Minutes -gt 0) { $script:CliMinutes = $Minutes }
if ($Seconds -gt 0) { $script:CliSeconds = $Seconds }
if ($Action) { $script:CliAction = $Action }
if ($At) { $script:CliAt = $At }
if ($Calendar) { $script:CliCalendar = $Calendar }

function Parse-ClockTime {
    param([string]$Raw)
    if (-not $Raw) { return $null }
    $Raw = $Raw.Trim()
    foreach ($fmt in @('HH:mm', 'H:mm', 'h:mm tt', 'hh:mm tt')) {
        try {
            $dt = [DateTime]::ParseExact($Raw, $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
            return $dt.ToString('HH:mm')
        } catch { }
    }
    try {
        return ([DateTime]::Parse($Raw)).ToString('HH:mm')
    } catch {
        return $null
    }
}

function Parse-ScheduleDateTime {
    param([string]$Raw)
    if (-not $Raw) { return $null }
    $Raw = $Raw.Trim()
    if ($Raw -match '^\d{1,2}:\d{2}') { return $null }
    $formats = @(
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-ddTHH:mm',
        'yyyy-MM-dd HH:mm:ss',
        'MM/dd/yyyy h:mm tt',
        'M/d/yyyy h:mm tt',
        'dd/MM/yyyy HH:mm'
    )
    foreach ($fmt in $formats) {
        try {
            return [DateTime]::ParseExact($Raw, $fmt, [System.Globalization.CultureInfo]::CurrentCulture)
        } catch { }
    }
    try { return [DateTime]::Parse($Raw) } catch { return $null }
}

function Sync-ScheduledFromPickers {
    if ($script:TimerMode -ne 'calendar') { return }
    if (-not $script:dtpDate -or -not $script:dtpClock) { return }
    $d = $script:dtpDate.Value.Date
    $t = $script:dtpClock.Value
    $script:ScheduledAt = $d.AddHours($t.Hour).AddMinutes($t.Minute).AddSeconds(0)
    $script:ClockTime = $script:dtpClock.Value.ToString('HH:mm')
}

function Set-ScheduledTarget {
    param(
        [DateTime]$When,
        [string]$Title = '',
        [string]$Uid = '',
        [string]$SourcePath = ''
    )
    $script:ScheduledAt = $When
    $script:CalendarEventTitle = $Title
    $script:CalendarEventUid = $Uid
    if ($SourcePath) { $script:CalendarSource = $SourcePath }
    if ($script:UiReady -and $script:dtpDate -and $script:dtpClock) {
        $script:dtpDate.Value = $When
        $script:dtpClock.Value = $When
        $script:ClockTime = $When.ToString('HH:mm')
    }
    Set-TimerMode 'calendar'
}

function Get-ClockTargetDateTime {
    param([string]$TimeStr)
    if ($script:TimerMode -eq 'calendar' -and $script:ScheduledAt) {
        $t = [DateTime]$script:ScheduledAt
        if ($t -gt (Get-Date)) { return $t }
    }
    $hm = if ($TimeStr) { Parse-ClockTime $TimeStr }
          elseif ($script:ClockTime) { $script:ClockTime }
          elseif ($script:UiReady -and $script:dtpClock) { $script:dtpClock.Value.ToString('HH:mm') }
          else { '23:30' }
    if (-not $hm) { $hm = '23:30' }
    $parts = $hm.Split(':')
    $h = [int]$parts[0]
    $m = [int]$parts[1]
    $now = Get-Date
    $target = Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour $h -Minute $m -Second 0
    if ($target -le $now) { $target = $target.AddDays(1) }
    return $target
}

function Get-SecondsUntilClock {
    param([string]$TimeStr)
    $target = Get-ClockTargetDateTime $TimeStr
    $sec = [int][math]::Ceiling(($target - (Get-Date)).TotalSeconds)
    return [math]::Max((Get-MinTimerSec), $sec)
}

function Format-ClockDisplay {
    param([DateTime]$When)
    if ($script:TimerMode -eq 'calendar') {
        return $When.ToString('ddd MMM d, h:mm tt')
    }
    return $When.ToString('h:mm tt')
}

function Show-CalendarEventDialog {
    if (-not (Get-Command Import-IcsCalendarFile -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Calendar module not found. Run from the Lights Out folder or reinstall.',
            $script:AppName, 'OK', 'Error') | Out-Null
        return $false
    }
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Import calendar (.ics)'
    $dlg.Filter = 'iCalendar (*.ics)|*.ics|All files (*.*)|*.*'
    $last = if ($script:CalendarSource) { Split-Path $script:CalendarSource -Parent } else { [Environment]::GetFolderPath('MyDocuments') }
    if ($last -and (Test-Path $last)) { $dlg.InitialDirectory = $last }
    if ($dlg.ShowDialog() -ne 'OK') { return $false }

    try {
        $imported = Import-IcsCalendarFile -Path $dlg.FileName
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null
        return $false
    }

    $upcoming = Get-IcsUpcomingEvents -Events $imported.Events
    if (-not $upcoming.Count) {
        [System.Windows.Forms.MessageBox]::Show(
            'No upcoming events in the next 90 days. Export a fresh .ics from your calendar app.',
            $script:AppName, 'OK', 'Information') | Out-Null
        return $false
    }

    $pick = New-Object System.Windows.Forms.Form
    $pick.Text = "$script:AppName - pick calendar event"
    $pick.Size = New-Object System.Drawing.Size(520, 380)
    $pick.StartPosition = 'CenterParent'
    $pick.FormBorderStyle = 'FixedDialog'
    $pick.MaximizeBox = $false
    $pick.MinimizeBox = $false
    $pick.BackColor = $script:C.Bg

    $hint = New-Object System.Windows.Forms.Label
    $hint.Location = New-Object System.Drawing.Point(12, 10)
    $hint.Size = New-Object System.Drawing.Size(480, 36)
    $hint.Text = "From: $([IO.Path]::GetFileName($dlg.FileName))`nSelect an event - Lights Out will $($script:Action.ToLower()) at that date and time."
    $hint.ForeColor = $script:C.Muted
    $hint.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $pick.Controls.Add($hint)

    $list = New-Object System.Windows.Forms.ListView
    $list.Location = New-Object System.Drawing.Point(12, 52)
    $list.Size = New-Object System.Drawing.Size(480, 230)
    $list.View = 'Details'
    $list.FullRowSelect = $true
    $list.GridLines = $false
    $list.BackColor = $script:C.Card
    $list.ForeColor = $script:C.Ink
    $list.BorderStyle = 'FixedSingle'
    [void]$list.Columns.Add('When', 160)
    [void]$list.Columns.Add('Event', 300)
    foreach ($ev in $upcoming) {
        $li = New-Object System.Windows.Forms.ListViewItem ($ev.Start.ToString('ddd MMM d, h:mm tt'))
        $li.SubItems.Add($ev.Summary) | Out-Null
        $li.Tag = $ev
        [void]$list.Items.Add($li)
    }
    if ($list.Items.Count -gt 0) { $list.Items[0].Selected = $true }
    $pick.Controls.Add($list)

    $script:calendarPickResult = $null
    $okPick = {
        if ($list.SelectedItems.Count -lt 1) { return }
        $script:calendarPickResult = $list.SelectedItems[0].Tag
        $pick.DialogResult = 'OK'
        $pick.Close()
    }.GetNewClosure()

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = 'Use this event'
    $btnOk.Size = New-Object System.Drawing.Size(140, 36)
    $btnOk.Location = New-Object System.Drawing.Point(232, 292)
    Style-Button $btnOk $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 9
    $btnOk.Add_Click($okPick)
    $pick.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.Size = New-Object System.Drawing.Size(100, 36)
    $btnCancel.Location = New-Object System.Drawing.Point(380, 292)
    Style-Button $btnCancel ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 9
    $btnCancel.Add_Click({ $pick.Close() })
    $pick.Controls.Add($btnCancel)

    $list.Add_DoubleClick($okPick)
    [void]$pick.ShowDialog($form)
    if (-not $script:calendarPickResult) { return $false }

    $ev = $script:calendarPickResult
    Set-ScheduledTarget -When $ev.Start -Title $ev.Summary -Uid $ev.Uid -SourcePath $dlg.FileName
    Write-AuditLog 'calendar_event' "$($ev.Summary) at $($ev.Start.ToString('o'))"
    if (-not $script:Running) { Save-Settings; Update-Ui }
    return $true
}

function Format-DurationLong {
    param([int]$Seconds)
    if ($Seconds -ge 3600) {
        $h = [int][math]::Floor($Seconds / 3600.0)
        $m = [int][math]::Floor(($Seconds % 3600) / 60.0)
        if ($m -eq 0) { return "${h}h" }
        return "${h}h ${m}m"
    }
    $m = [math]::Ceiling($Seconds / 60.0)
    if ($m -le 1) { return 'under a minute' }
    return "$m minutes"
}

function Get-StartSeconds {
    if ($script:TimerMode -in @('clock', 'calendar')) { return Get-SecondsUntilClock }
    return $script:DefaultSec
}

function Get-RitualCatalog {
    return @(
        @{ Id = 'weeknight'; Label = 'Weeknight'; Hint = '24m off'; Seconds = 1440; Action = 'Shutdown'; Mode = 'duration' }
        @{ Id = 'classic'; Label = '28:20'; Hint = 'shut down'; Seconds = 1700; Action = 'Shutdown'; Mode = 'duration' }
        @{ Id = 'movie'; Label = 'Movie'; Hint = '45m sleep'; Seconds = 2700; Action = 'Sleep'; Mode = 'duration' }
        @{ Id = 'bedtime'; Label = 'Bedtime'; Hint = '11:30 PM'; Action = 'Shutdown'; Mode = 'clock'; Clock = '23:30' }
    )
}

function Invoke-Ritual {
    param([hashtable]$Ritual)
    if (-not $Ritual) { return }
    Set-Action $Ritual.Action
    if ($Ritual.Mode -eq 'clock') {
        Set-TimerMode 'clock'
        $script:ClockTime = $Ritual.Clock
        if ($script:UiReady -and $script:dtpClock) {
            $parts = $script:ClockTime.Split(':')
            $script:dtpClock.Value = Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0
        }
    } else {
        Set-TimerMode 'duration'
        $script:DefaultSec = [int]$Ritual.Seconds
    }
    $script:LastRitualId = $Ritual.Id
    Write-AuditLog 'ritual_selected' "$($Ritual.Id) action=$($Ritual.Action) mode=$($Ritual.Mode)"
    if ($script:Running) {
        if ($Ritual.Mode -eq 'duration') {
            $script:Left = [int]$Ritual.Seconds
            $script:Total = [int]$Ritual.Seconds
            $script:Warn5 = $false
        }
        Save-Settings
        Update-Ui
        return
    }
    if ($script:Paused) { Cancel-PausedTimer }
    Save-Settings
    Update-Ui
    Invoke-StartTimer (Get-StartSeconds)
}

function Format-PowerBlockerTarget {
    param([string]$Target)
    $t = $Target.Trim()
    if ($t -match '\\([^\\]+\.exe)\s*$') { return $Matches[1] }
    if ($t -match '\\([^\\]+)\s*$') { return $Matches[1] }
    return $t
}

function Get-PowerRequestBlockers {
    param([string]$ForAction = $script:Action)
    if ($ForAction -eq 'Lock') { return @() }
    try {
        $lines = @(& powercfg.exe /requests 2>&1)
    } catch {
        return @()
    }
    $found = [System.Collections.Generic.List[object]]::new()
    $section = $null
    $pending = $null
    foreach ($line in $lines) {
        $t = "$line".Trim()
        if ($t -match '^([A-Z][A-Z0-9]+):$') {
            if ($pending -and $section) {
                $found.Add([pscustomobject]@{
                        Section = $section
                        Kind    = $pending.Kind
                        Name    = (Format-PowerBlockerTarget $pending.Target)
                        Reason  = if ($pending.Detail) { $pending.Detail } else { 'Power request active' }
                    })
            }
            $section = $Matches[1]
            $pending = $null
            continue
        }
        if (-not $section) { continue }
        if (-not $t -or $t -eq 'None.' -or $t -eq 'None') {
            if ($pending) {
                $found.Add([pscustomobject]@{
                        Section = $section
                        Kind    = $pending.Kind
                        Name    = (Format-PowerBlockerTarget $pending.Target)
                        Reason  = if ($pending.Detail) { $pending.Detail } else { 'Power request active' }
                    })
                $pending = $null
            }
            continue
        }
        if ($t -match '^\[(.+?)\]\s*(.+)$') {
            if ($pending) {
                $found.Add([pscustomobject]@{
                        Section = $section
                        Kind    = $pending.Kind
                        Name    = (Format-PowerBlockerTarget $pending.Target)
                        Reason  = if ($pending.Detail) { $pending.Detail } else { 'Power request active' }
                    })
            }
            $pending = @{ Kind = $Matches[1]; Target = $Matches[2].Trim(); Detail = '' }
        } elseif ($pending) {
            $pending.Detail = $t
            $found.Add([pscustomobject]@{
                    Section = $section
                    Kind    = $pending.Kind
                    Name    = (Format-PowerBlockerTarget $pending.Target)
                    Reason  = $t
                })
            $pending = $null
        }
    }
    if ($pending -and $section) {
        $found.Add([pscustomobject]@{
                Section = $section
                Kind    = $pending.Kind
                Name    = (Format-PowerBlockerTarget $pending.Target)
                Reason  = if ($pending.Detail) { $pending.Detail } else { 'Power request active' }
            })
    }
    $sleepSections = @('DISPLAY', 'SYSTEM', 'AWAYMODE', 'EXECUTION', 'PERFBOOST', 'ACTIVELOCKSCREEN')
    $all = @($found)
    switch ($ForAction) {
        'Sleep' { return @($all | Where-Object { $_.Section -in $sleepSections }) }
        'Hibernate' { return @($all | Where-Object { $_.Section -in $sleepSections }) }
        default { return @($all | Where-Object { $_.Section -in @('DISPLAY', 'SYSTEM', 'EXECUTION') }) }
    }
}

function Test-ShouldWarnPowerBlockers {
    if (Test-NoPowerAction) { return $false }
    if ($script:Action -eq 'Lock') { return $false }
    if ($script:UiReady -and $script:chkPowerWarn) { return [bool]$script:chkPowerWarn.Checked }
    return [bool]$script:WarnPowerBlockers
}

function Confirm-PowerBlockerWarning {
    param([array]$Blockers)
    $verb = switch ($script:Action) {
        'Sleep' { 'sleep' }
        'Hibernate' { 'hibernate' }
        'Restart' { 'restart' }
        default { 'shut down' }
    }
    $lines = @($Blockers | Select-Object -First 6 | ForEach-Object {
            "- $($_.Name): $($_.Reason) [$($_.Section)]"
        })
    if ($Blockers.Count -gt 6) { $lines += "- and $($Blockers.Count - 6) more" }
    $body = @(
        "Windows reports apps that may block $verb when the timer ends:"
        ''
        ($lines -join [Environment]::NewLine)
        ''
        'Start the countdown anyway?'
    ) -join [Environment]::NewLine
    $r = [System.Windows.Forms.MessageBox]::Show(
        $body, "$script:AppName - sleep blockers", 'YesNo', 'Warning')
    return ($r -eq 'Yes')
}

function Invoke-StartTimer {
    param([int]$Sec)
    if (Test-ShouldWarnPowerBlockers) {
        $blockers = @(Get-PowerRequestBlockers)
        if ($blockers.Count -gt 0) {
            Write-AuditLog 'power_blockers' "count=$($blockers.Count) action=$script:Action"
            if (-not (Confirm-PowerBlockerWarning $blockers)) {
                Write-AuditLog 'power_blockers' 'user_cancelled'
                return
            }
            Write-AuditLog 'power_blockers' 'user_confirmed'
        }
    }
    Start-Timer $Sec
}

function Test-NoPowerAction {
    # CI/tests must NEVER shut down, sleep, or restart the machine.
    return $script:DryRun -or ($env:SLEEPTIMER_DRY_RUN -eq '1') -or ($env:SLEEPTIMER_CI -eq '1')
}

function Get-MinTimerSec {
    if (Test-NoPowerAction) { return 3 }
    return $script:MinTimerSec
}

function Write-AuditLog {
    param([string]$Event, [string]$Detail = '')
    try {
        if (-not (Test-Path $script:SettingsDir)) {
            New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
        }
        $line = "$(Get-Date -Format o) $Event"
        if ($Detail) { $line += " $Detail" }
        $line | Add-Content $script:AuditLogPath -Encoding UTF8
    } catch { }
}

$script:LuxGridEventDir = Join-Path $env:LOCALAPPDATA 'LuxGrid\events\inbox'
$script:LuxGridTimerName = 'Sleep Ritual'
$script:EmitLuxGridEvents = $false

function Test-LuxGridEnabled {
    if ($script:UiReady -and $chkLuxGrid) { return [bool]$chkLuxGrid.Checked }
    return [bool]$script:EmitLuxGridEvents
}

function Get-LuxGridPhase {
    param([int]$Remaining)
    if ($Remaining -le 0) { return 'completed' }
    if ($Remaining -lt 120) { return 'warning' }
    return 'countdown'
}

function Publish-LuxGridEvent {
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [hashtable]$Payload = @{}
    )
    if (-not (Test-LuxGridEnabled)) { return }
    try {
        if (-not (Test-Path $script:LuxGridEventDir)) {
            New-Item -ItemType Directory -Path $script:LuxGridEventDir -Force | Out-Null
        }
        $body = @{
            id        = [guid]::NewGuid().ToString()
            timestamp = (Get-Date).ToUniversalTime().ToString('o')
            sourceApp = 'LightsOut'
            eventName = $EventName
            channel   = 'sleep'
            payload   = $Payload
            processed = $false
        }
        $file = Join-Path $script:LuxGridEventDir ("lightsout_{0}.json" -f ([guid]::NewGuid().ToString('N')))
        $body | ConvertTo-Json -Depth 6 | Set-Content $file -Encoding UTF8
    } catch { }
}

function Publish-LuxGridTick {
    param([int]$Remaining, [int]$Total = $script:Total)
    $pct = if ($Total -gt 0) { [math]::Round(($Remaining / $Total) * 100, 1) } else { 0 }
    Publish-LuxGridEvent -EventName 'timer.tick' -Payload @{
        timerName        = $script:LuxGridTimerName
        totalSeconds     = $Total
        remainingSeconds = $Remaining
        percentRemaining = $pct
        phase            = (Get-LuxGridPhase $Remaining)
        action           = $script:Action
    }
}

function Publish-LuxGridWarning {
    param(
        [int]$Remaining,
        [ValidateSet('info', 'warning', 'critical')]
        [string]$Severity = 'warning'
    )
    Publish-LuxGridEvent -EventName 'timer.warning' -Payload @{
        remainingSeconds = $Remaining
        severity         = $Severity
        timerName        = $script:LuxGridTimerName
        action           = $script:Action
    }
}

function Publish-LuxGridCancelled {
    param([string]$Reason = 'pause')
    Publish-LuxGridEvent -EventName 'timer.cancelled' -Payload @{
        result           = 'cancelled'
        timerName        = $script:LuxGridTimerName
        durationSeconds  = [math]::Max(0, $script:Total - $script:Left)
        reason           = $Reason
        remainingSeconds = $script:Left
    }
}

function Publish-LuxGridCompleted {
    Publish-LuxGridEvent -EventName 'timer.completed' -Payload @{
        result          = 'completed'
        timerName       = $script:LuxGridTimerName
        durationSeconds = $script:Total
        action          = $script:Action
    }
}

function Invoke-EmergencyCancel {
    if (-not $script:Running -and -not $script:Paused) { return }
    Write-AuditLog 'emergency_cancel' "action=$script:Action left=$script:Left"
    Publish-LuxGridCancelled -Reason 'emergency'
    Stop-TrayFlash
    Stop-Timer -Reason 'emergency'
    Show-MainWindow
    $script:tray.ShowBalloonTip(
        3500, $script:AppName, 'Countdown cancelled (Ctrl+Shift+S).',
        [System.Windows.Forms.ToolTipIcon]::Info)
}

$script:C = @{
    Bg       = [System.Drawing.Color]::FromArgb(8, 8, 12)
    Card     = [System.Drawing.Color]::FromArgb(18, 18, 26)
    RingCard = [System.Drawing.Color]::FromArgb(14, 14, 20)
    Ink      = [System.Drawing.Color]::FromArgb(250, 248, 242)
    Muted    = [System.Drawing.Color]::FromArgb(105, 105, 118)
    Amber    = [System.Drawing.Color]::FromArgb(237, 175, 88)
    Mint     = [System.Drawing.Color]::FromArgb(88, 210, 168)
    Rose     = [System.Drawing.Color]::FromArgb(235, 100, 115)
    Blue     = [System.Drawing.Color]::FromArgb(120, 170, 255)
    Violet   = [System.Drawing.Color]::FromArgb(170, 140, 230)
    Slate    = [System.Drawing.Color]::FromArgb(165, 170, 190)
    Track    = [System.Drawing.Color]::FromArgb(34, 34, 48)
    Glow     = [System.Drawing.Color]::FromArgb(99, 102, 241)
}

Add-Type @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class TrayIconFactory {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr hIcon);
    public static Icon FromBitmap(Bitmap bmp) {
        IntPtr h = bmp.GetHicon();
        Icon tmp = Icon.FromHandle(h);
        Icon clone = (Icon)tmp.Clone();
        tmp.Dispose();
        DestroyIcon(h);
        return clone;
    }
}
"@

function Get-ActionIconColor {
    switch ($script:Action) {
        'Sleep' { return $script:C.Mint }
        'Restart' { return $script:C.Blue }
        'Hibernate' { return $script:C.Violet }
        'Lock' { return $script:C.Slate }
        default { return $script:C.Amber }
    }
}

function Test-GracefulApplies {
    return $script:Action -in @('Shutdown', 'Restart')
}

function New-ProgressTrayIcon {
    param(
        [double]$RemainRatio,
        [System.Drawing.Color]$ArcColor,
        [int]$Size = 32
    )
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(14, 14, 18))

    $pad = [math]::Max(2, [int]($Size * 0.1))
    $rect = New-Object System.Drawing.Rectangle $pad, $pad, ($Size - 2 * $pad), ($Size - 2 * $pad)
    $w = [math]::Max(2, [int]($Size / 7.5))

    $trackPen = New-Object System.Drawing.Pen $script:C.Track, $w
    $g.DrawArc($trackPen, $rect, 0, 360)
    $trackPen.Dispose()

    $sweep = 360.0 * [math]::Max(0, [math]::Min(1.0, $RemainRatio))
    if ($sweep -gt 0.5) {
        $arcPen = New-Object System.Drawing.Pen $ArcColor, $w
        $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($arcPen, $rect, -90, $sweep)
        $arcPen.Dispose()
    }

    $g.Dispose()
    return [TrayIconFactory]::FromBitmap($bmp)
}

function Set-TrayIconSafe {
    param([System.Drawing.Icon]$NewIcon)
    if ($script:trayLiveIcon -and $script:trayLiveIcon -ne $NewIcon) {
        $script:trayLiveIcon.Dispose()
    }
    $script:trayLiveIcon = $NewIcon
    $script:tray.Icon = $NewIcon
}

function Update-TrayProgressIcon {
    if (-not $script:tray) { return }
    if ($script:trayFlash -and $script:trayFlash.Enabled -and $script:trayFlashState) {
        if ($script:tray.Icon -ne [System.Drawing.SystemIcons]::Warning) {
            $script:tray.Icon = [System.Drawing.SystemIcons]::Warning
        }
        return
    }
    $ratio = if ($script:Running -and $script:Total -gt 0) {
        $script:Left / $script:Total
    } elseif (-not $script:Running) {
        1.0
    } else { 1.0 }
    $color = if ($script:Running -and $script:Left -le 30) { Get-RingColor } else { Get-ActionIconColor }
    Set-TrayIconSafe (New-ProgressTrayIcon -RemainRatio $ratio -ArcColor $color)
}

function Get-AppDir {
    if ($PSScriptRoot) { return $PSScriptRoot }
    try { return Split-Path ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) -Parent }
    catch { return $env:USERPROFILE }
}

function Get-AppIconPath {
    $dir = Get-AppDir
    foreach ($name in @('SleepTimer.ico', 'LightsOut.ico', 'Nightfall.ico')) {
        $p = Join-Path $dir $name
        if (Test-Path $p) { return $p }
    }
    $repoIcon = Join-Path (Split-Path $dir -Parent) 'assets\Nightfall.ico'
    if (Test-Path $repoIcon) { return $repoIcon }
    return $null
}

function Get-LogoPath {
    $dir = Get-AppDir
    foreach ($p in @(
        (Join-Path $dir 'LightsOut-Logo.png')
        (Join-Path $dir 'assets\LightsOut-Logo.png')
    )) {
        if (Test-Path $p) { return $p }
    }
    $parent = Split-Path $dir -Parent
    foreach ($p in @(
        (Join-Path $parent 'assets\LightsOut-Logo.png')
        (Join-Path $parent 'windsurf-project\assets\LightsOut-Logo.png')
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-StartupShortcutPath {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'Lights Out.lnk'
}

function Test-RunAtLogin { Test-Path (Get-StartupShortcutPath) }

function Set-RunAtLogin {
    param([bool]$Enabled)
    $lnk = Get-StartupShortcutPath
    $oldLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Sleep Timer.lnk'
    if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force }
    if (-not $Enabled) {
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
        return
    }
    $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $wsh = New-Object -ComObject WScript.Shell
    $s = $wsh.CreateShortcut($lnk)
    $s.TargetPath = $exe
    $s.WorkingDirectory = Split-Path $exe -Parent
    $s.Description = 'Lights Out - bedtime countdown'
    $icon = Get-AppIconPath
    if ($icon) { $s.IconLocation = "$icon,0" }
    $s.Save()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh)
}

function Get-Settings {
    $s = @{
        DefaultSeconds = 1700
        Action         = 'Shutdown'
        TopMost        = $true
        Warn5Min       = $true
        RunAtLogin     = $false
        MinimizeToTray = $true
        EmitLuxGridEvents = $false
        GracefulShutdown  = $true
        TimerMode           = 'duration'
        ClockTime           = '23:30'
        ScheduledAt         = ''
        CalendarSource      = ''
        CalendarEventUid    = ''
        CalendarEventTitle  = ''
        WarnPowerBlockers = $true
        QuickWarnPanel    = $true
        DimPhaseEnabled   = $true
        DimPhaseSeconds   = 90
        PactEnabled       = $false
        PactTime          = '23:00'
        LastRitualId      = ''
    }
    if (Test-Path $script:SettingsPath) {
        try {
            $j = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
            if ($j.DefaultSeconds) { $s.DefaultSeconds = [math]::Max((Get-MinTimerSec), [int]$j.DefaultSeconds) }
            if ($j.Action -in @('Shutdown', 'Restart', 'Sleep', 'Hibernate', 'Lock')) { $s.Action = [string]$j.Action }
            elseif ($j.Restart -eq $true) { $s.Action = 'Restart' }
            if ($null -ne $j.TopMost) { $s.TopMost = [bool]$j.TopMost }
            if ($null -ne $j.WarnAt5Min) { $s.Warn5Min = [bool]$j.WarnAt5Min }
            if ($null -ne $j.RunAtLogin) { $s.RunAtLogin = [bool]$j.RunAtLogin }
            if ($null -ne $j.MinimizeToTray) { $s.MinimizeToTray = [bool]$j.MinimizeToTray }
            if ($null -ne $j.EmitLuxGridEvents) { $s.EmitLuxGridEvents = [bool]$j.EmitLuxGridEvents }
            if ($null -ne $j.GracefulShutdown) { $s.GracefulShutdown = [bool]$j.GracefulShutdown }
            if ($j.TimerMode -in @('duration', 'clock', 'calendar')) { $s.TimerMode = [string]$j.TimerMode }
            if ($j.ClockTime) {
                $ct = Parse-ClockTime ([string]$j.ClockTime)
                if ($ct) { $s.ClockTime = $ct }
            }
            if ($j.ScheduledAt) {
                try {
                    $sa = [DateTime]::Parse([string]$j.ScheduledAt)
                    if ($sa -gt (Get-Date)) { $s.ScheduledAt = $sa.ToString('o') }
                } catch { }
            }
            if ($j.CalendarSource) { $s.CalendarSource = [string]$j.CalendarSource }
            if ($j.CalendarEventUid) { $s.CalendarEventUid = [string]$j.CalendarEventUid }
            if ($j.CalendarEventTitle) { $s.CalendarEventTitle = [string]$j.CalendarEventTitle }
            if ($null -ne $j.WarnPowerBlockers) { $s.WarnPowerBlockers = [bool]$j.WarnPowerBlockers }
            if ($null -ne $j.QuickWarnPanel) { $s.QuickWarnPanel = [bool]$j.QuickWarnPanel }
            if ($null -ne $j.DimPhaseEnabled) { $s.DimPhaseEnabled = [bool]$j.DimPhaseEnabled }
            if ($j.DimPhaseSeconds) { $s.DimPhaseSeconds = [math]::Max(15, [int]$j.DimPhaseSeconds) }
            if ($null -ne $j.PactEnabled) { $s.PactEnabled = [bool]$j.PactEnabled }
            if ($j.PactTime) {
                $pt = Parse-ClockTime ([string]$j.PactTime)
                if ($pt) { $s.PactTime = $pt }
            }
            if ($j.LastRitualId) { $s.LastRitualId = [string]$j.LastRitualId }
        } catch { }
    }
    return $s
}

function Save-Settings {
    if (-not (Test-Path $script:SettingsDir)) {
        New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
    }
    try { Set-RunAtLogin -Enabled $chkLogin.Checked } catch { }
    @{
        DefaultSeconds = $script:DefaultSec
        Action         = $script:Action
        ConfirmAtEnd   = $true
        AutoStart      = $true
        TopMost        = $chkTop.Checked
        WarnAt5Min     = $chkWarn5.Checked
        RunAtLogin     = $chkLogin.Checked
        MinimizeToTray    = $chkMinTray.Checked
        EmitLuxGridEvents = $chkLuxGrid.Checked
        GracefulShutdown  = $chkGraceful.Checked
        TimerMode           = $script:TimerMode
        ClockTime           = if ($script:UiReady -and $script:dtpClock) { $script:dtpClock.Value.ToString('HH:mm') } else { $script:ClockTime }
        ScheduledAt         = if ($script:ScheduledAt) { ([DateTime]$script:ScheduledAt).ToString('o') } else { '' }
        CalendarSource      = $script:CalendarSource
        CalendarEventUid    = $script:CalendarEventUid
        CalendarEventTitle  = $script:CalendarEventTitle
        WarnPowerBlockers = $script:chkPowerWarn.Checked
        QuickWarnPanel    = $chkQuick.Checked
        DimPhaseEnabled   = $script:chkDimPhase.Checked
        DimPhaseSeconds   = $script:DimPhaseSec
        PactEnabled       = $script:chkPact.Checked
        PactTime          = if ($script:dtpPact) { $script:dtpPact.Value.ToString('HH:mm') } else { $script:PactTime }
        LastRitualId      = $script:LastRitualId
        DryRun            = $false
    } | ConvertTo-Json | Set-Content $script:SettingsPath -Encoding UTF8
    $script:EmitLuxGridEvents = $chkLuxGrid.Checked
    $script:GracefulShutdown = $chkGraceful.Checked
    $script:WarnPowerBlockers = $script:chkPowerWarn.Checked
    $script:QuickWarnPanel = $chkQuick.Checked
    if ($script:chkDimPhase) { $script:DimPhaseEnabled = $script:chkDimPhase.Checked }
    if ($script:chkPact) { $script:PactEnabled = $script:chkPact.Checked }
    if ($script:dtpPact) { $script:PactTime = $script:dtpPact.Value.ToString('HH:mm') }
    if ($script:UiReady -and $script:dtpClock) { $script:ClockTime = $script:dtpClock.Value.ToString('HH:mm') }
}

function Enable-DoubleBuffer {
    param($Control)
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Control.GetType().GetProperty('DoubleBuffered', $flags)
    if ($prop) { $prop.SetValue($Control, $true, $null) }
}

function Style-Button {
    param($B, $Bg, $Fg = $script:C.Ink, [int]$Size = 9, $Hover = $null)
    $B.FlatStyle = 'Flat'
    $B.FlatAppearance.BorderSize = 0
    $B.BackColor = $Bg
    $B.ForeColor = $Fg
    try {
        $B.Font = New-Object System.Drawing.Font('Segoe UI', $Size, [System.Drawing.FontStyle]::Bold)
    } catch {
        $B.Font = New-Object System.Drawing.Font('Segoe UI', $Size)
    }
    $B.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($null -ne $Hover) { $B.FlatAppearance.MouseOverBackColor = $Hover }
}

function Set-Action {
    param([string]$Name)
    $script:Action = $Name
    foreach ($p in $script:Pills) {
        $on = ($p.Tag -eq $Name)
        if ($on) {
            $p.BackColor = switch ($Name) {
                'Sleep' { $script:C.Mint }
                'Restart' { $script:C.Blue }
                'Hibernate' { $script:C.Violet }
                'Lock' { $script:C.Slate }
                default { $script:C.Amber }
            }
            $p.ForeColor = [System.Drawing.Color]::FromArgb(14, 12, 10)
        } else {
            $p.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 44)
            $p.ForeColor = $script:C.Muted
        }
    }
    if (-not $script:Running -and $script:UiReady) { Save-Settings }
    Update-GracefulCheckbox
    Update-Ui
}

function Get-ActionAccentColor {
    switch ($script:Action) {
        'Sleep' { return $script:C.Mint }
        'Restart' { return $script:C.Blue }
        'Hibernate' { return $script:C.Violet }
        'Lock' { return $script:C.Slate }
        default { return $script:C.Amber }
    }
}

function Get-CountdownAccentColor {
    if (-not $script:Running) { return Get-ActionAccentColor }
    if ($script:Left -le 30) {
        $t = [int]($script:Pulse * 255)
        return [System.Drawing.Color]::FromArgb(255, 110 + $t / 2, 80 + $t / 3)
    }
    if ($script:Left -le 60) { return $script:C.Rose }
    if ($script:Left -le 300) { return $script:C.Amber }
    return Get-ActionAccentColor
}

function Get-RingColor { Get-CountdownAccentColor }

function Get-CountdownUrgencyLevel {
    if (-not $script:Running) { return 'idle' }
    if ($script:Left -le 30) { return 'critical' }
    if ($script:Left -le 60) { return 'final' }
    if ($script:Left -le 300) { return 'soon' }
    return 'calm'
}

function Get-UrgencyRingBackColor {
    switch (Get-CountdownUrgencyLevel) {
        'critical' { return [System.Drawing.Color]::FromArgb(28, 14, 16) }
        'final' { return [System.Drawing.Color]::FromArgb(24, 16, 18) }
        'soon' { return [System.Drawing.Color]::FromArgb(20, 18, 14) }
        default { return $script:C.RingCard }
    }
}

function Draw-Ring {
    param($G, [int]$W, [int]$H)
    $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.Clear((Get-UrgencyRingBackColor))

    $card = New-Object System.Drawing.Rectangle 8, 8, ($W - 16), ($H - 16)
    $cardBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(26, 26, 36))
    $G.FillEllipse($cardBrush, $card)
    $cardBrush.Dispose()

    $accent = Get-CountdownAccentColor
    $glowA = switch (Get-CountdownUrgencyLevel) {
        'critical' { 48 }
        'final' { 32 }
        'soon' { 18 }
        default { 10 }
    }
    if ($glowA -gt 0) {
        $glowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($glowA, $accent.R, $accent.G, $accent.B))
        $glowRect = New-Object System.Drawing.Rectangle 18, 18, ($W - 36), ($H - 36)
        $G.FillEllipse($glowBrush, $glowRect)
        $glowBrush.Dispose()
    }

    $rect = New-Object System.Drawing.Rectangle(14, 14, ($W - 28), ($H - 28))
    $remainPct = if ($script:Total -gt 0) { $script:Left / $script:Total } else { 1.0 }
    $sweep = [int](360 * $remainPct)

    $trackPen = New-Object System.Drawing.Pen($script:C.Track, 12)
    $G.DrawArc($trackPen, $rect, 0, 360)
    $trackPen.Dispose()

    if ($sweep -gt 0) {
        $arcPen = New-Object System.Drawing.Pen($accent, 12)
        $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $G.DrawArc($arcPen, $rect, -90, $sweep)
        $arcPen.Dispose()
    }
}

function Draw-Fist {
    param($G, [int]$Cx, [int]$Cy, [float]$Scale, [float]$Deg)
    $state = $G.Save()
    $G.TranslateTransform($Cx, $Cy)
    $G.RotateTransform($Deg)
    $G.ScaleTransform($Scale, $Scale)
    $skin = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(228, 188, 148))
    $shade = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(168, 118, 78))
    $glove = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(42, 38, 52))
    $G.FillEllipse($skin, -30, -16, 58, 50)
    foreach ($kx in @(-20, -7, 7, 20)) {
        $G.FillEllipse($skin, ($kx - 9), -34, 18, 18)
    }
    $G.FillRectangle($glove, -24, 14, 48, 16)
    $G.FillEllipse($shade, -12, 20, 24, 10)
    $skin.Dispose()
    $shade.Dispose()
    $glove.Dispose()
    $G.Restore($state)
}

function Draw-PunchScene {
    param($G, [int]$Frame, [int]$W, [int]$H)
    $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.Clear($script:C.Bg)
    $cx = [int]($W / 2)
    $cy = [int]($H / 2)

    # Flickering bulb at top ( dims on punch )
    $bulbA = if ($Frame -lt 12) { 255 } else { [int](255 * [math]::Max(0, 1 - (($Frame - 12) / 6.0))) }
    if ($bulbA -gt 8) {
        $bulb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($bulbA, 255, 230, 160))
        $G.FillEllipse($bulb, ($cx - 14), 18, 28, 28)
        $glow = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb([int]($bulbA / 2), 255, 220, 120)), 3
        $G.DrawLine($glow, ($cx - 6), 46, ($cx - 6), 58)
        $G.DrawLine($glow, ($cx + 6), 46, ($cx + 6), 58)
        $bulb.Dispose()
        $glow.Dispose()
    }

    # Ring shatters / drains after impact
    if ($Frame -lt 14) {
        $rect = New-Object System.Drawing.Rectangle 14, 14, ($W - 28), ($H - 28)
        $trackPen = New-Object System.Drawing.Pen $script:C.Track, 10
        $G.DrawArc($trackPen, $rect, 0, 360)
        $col = Get-ActionIconColor
        $arcPen = New-Object System.Drawing.Pen $col, 10
        $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $G.DrawArc($arcPen, $rect, -90, 360)
        $trackPen.Dispose()
        $arcPen.Dispose()
    } elseif ($Frame -lt 24) {
        $shrink = [math]::Max(0, 1 - (($Frame - 14) / 8.0))
        if ($shrink -gt 0.05) {
            $inset = [int](14 + (1 - $shrink) * 40)
            $size = [int](($W - 28) * $shrink)
            $rect = New-Object System.Drawing.Rectangle $inset, $inset, $size, $size
            $frag = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb([int](200 * $shrink), 237, 175, 88)), 4
            $G.DrawArc($frag, $rect, -90 + ($Frame * 17), 80)
            $G.DrawArc($frag, $rect, 40 - ($Frame * 11), 60)
            $frag.Dispose()
        }
    }

    # Fist motion: wind-up -> punch -> recoil -> exit
    $t = [math]::Min(1.0, $Frame / 12.0)
    $ease = $t * $t * (3 - 2 * $t)
    $fx = if ($Frame -lt 13) {
        [int]($W + 40 - ($W * 0.55 + 40) * $ease)
    } elseif ($Frame -lt 18) {
        $cx + ($Frame - 13) * 3
    } else {
        [int]($cx + 20 + ($Frame - 18) * 14)
    }
    $fScale = if ($Frame -eq 12 -or $Frame -eq 13) { 1.35 } else { 0.95 + 0.1 * $ease }
    $fDeg = -30 + (35 * $ease)
    if ($Frame -ge 13) { $fDeg = 8 + ($Frame - 13) * 4 }
    Draw-Fist $G $fx $cy $fScale $fDeg

    # Impact flash
    if ($Frame -ge 11 -and $Frame -le 16) {
        $flashA = [int](160 * (1 - [math]::Abs($Frame - 13) / 3.5))
        if ($flashA -gt 0) {
            $flash = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($flashA, 255, 210, 120))
            $G.FillRectangle($flash, 0, 0, $W, $H)
            $flash.Dispose()
        }
    }

    # Sparks
    if ($Frame -ge 12 -and $Frame -le 22) {
        $sparkPen = New-Object System.Drawing.Pen $script:C.Amber, 2
        for ($i = 0; $i -lt 10; $i++) {
            $rad = ($i * 36 + $Frame * 13) * [math]::PI / 180
            $len = 12 + ($Frame - 12) * 4 + ($i * 2)
            $x1 = $cx + [math]::Cos($rad) * 8
            $y1 = $cy + [math]::Sin($rad) * 8
            $x2 = $cx + [math]::Cos($rad) * $len
            $y2 = $cy + [math]::Sin($rad) * $len
            $G.DrawLine($sparkPen, $x1, $y1, $x2, $y2)
        }
        $sparkPen.Dispose()
    }

    # LIGHTS OUT title slam
    if ($Frame -ge 16) {
        $textA = [int][math]::Min(255, ($Frame - 16) * 28)
        $fontSize = 11.0 + [math]::Min(9.0, ($Frame - 16) * 0.85)
        $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($textA, 237, 175, 88))
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'
        $sf.LineAlignment = 'Center'
        $shake = if ($Frame -le 20) { ($Frame % 2) * 2 - 1 } else { 0 }
        $rect = New-Object System.Drawing.RectangleF (0, ($cy + 36 + $shake), $W, 44)
        $G.DrawString('LIGHTS OUT', $font, $brush, $rect, $sf)
        $font.Dispose()
        $brush.Dispose()
        $sf.Dispose()
    }
}

function Test-UseDimPhase {
    if ($script:UiReady -and $script:chkDimPhase) { return [bool]$script:chkDimPhase.Checked }
    return [bool]$script:DimPhaseEnabled
}

function Get-DimPhaseDuration {
    if (Test-NoPowerAction) { return 5 }
    return [math]::Max(15, [int]$script:DimPhaseSec)
}

function Start-LightsDimPhase {
    param([scriptblock]$OnComplete)
    if (-not (Test-UseDimPhase)) {
        & $OnComplete
        return
    }
    Show-MainWindow
    $sec = Get-DimPhaseDuration
    $script:dimLeft = $sec
    $script:dimComplete = $OnComplete
    Write-AuditLog 'dim_phase_start' "seconds=$sec"
    Publish-LuxGridEvent -EventName 'lights.dim' -Payload @{
        timerName = $script:LuxGridTimerName
        seconds   = $sec
        action    = $script:Action
    }
    if ($script:pnlDim) {
        $script:pnlDim.Visible = $true
        $script:pnlDim.BringToFront()
    }
    if ($script:lblDimMsg) { $script:lblDimMsg.Text = "Dim the room - $($script:Action) in ${sec}s" }
    if ($script:dimTimer) { $script:dimTimer.Start() }
}

function Stop-LightsDimPhase {
    if ($script:dimTimer) { $script:dimTimer.Stop() }
    if ($script:pnlDim) { $script:pnlDim.Visible = $false }
}

function Invoke-AfterTimerEnd {
    if (Test-UseDimPhase) { Start-LightsDimPhase { Complete-TimerEnd } }
    else { Complete-TimerEnd }
}

function Test-AllowSnooze {
    param([int]$AddSeconds)
    if ($script:PactSnoozeLocked) {
        [System.Windows.Forms.MessageBox]::Show(
            'Bedtime pact: snooze locked after repeated late extensions. Cancel or proceed.',
            $script:AppName, 'OK', 'Warning') | Out-Null
        return $false
    }
    if (-not $script:PactEnabled) { return $true }
    if (-not (Test-SnoozeCrossesPact -SecondsToAdd $AddSeconds -RemainingSeconds $script:Left -PactTimeHm $script:PactTime)) {
        return $true
    }
    $script:PactBreaks++
    Write-AuditLog 'pact_break' "breaks=$($script:PactBreaks) add=$AddSeconds"
    $deadline = Get-PactDeadline $script:PactTime
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Bedtime pact: you pledged to $($script:Action.ToLower()) by $(Format-ClockDisplay $deadline).`n`nSnooze anyway?",
        "$script:AppName - pact warning", 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return $false }
    if ($script:PactBreaks -ge 2) {
        $script:PactSnoozeLocked = $true
        Write-AuditLog 'pact_snooze_locked' ''
    }
    return $true
}

function Update-SleepLedgerBadge {
    if (-not $script:lblLedger -or -not (Get-Command Get-SleepLedgerStats -ErrorAction SilentlyContinue)) { return }
    $stats = Get-SleepLedgerStats -AuditLogPath $script:AuditLogPath
    $script:lblLedger.Text = if ($stats.Streak -gt 0) { "Sleep streak: $($stats.Streak) night$(if ($stats.Streak -ne 1) { 's' }) }" } else { 'Sleep ledger' }
}

function Show-SleepLedgerDialog {
    if (-not (Get-Command Get-SleepLedgerStats -ErrorAction SilentlyContinue)) { return }
    $stats = Get-SleepLedgerStats -AuditLogPath $script:AuditLogPath
    $week = ($stats.WeekDots | ForEach-Object { if ($_.Done) { '[' + $_.Label + ' OK]' } else { '(' + $_.Label + ')' } }) -join ' '
    $body = @"
Sleep Ledger (from your local audit log)

Current streak: $($stats.Streak) nights
Best streak: $($stats.BestStreak) nights
Completed nights: $($stats.NightsDone)
Snoozes logged: $($stats.Snoozes)
Cancels logged: $($stats.Cancels)
Last lights-out: $($stats.LastDoneLabel)

Last 7 days:
$week
"@
    [System.Windows.Forms.MessageBox]::Show($body, "$script:AppName - Sleep Ledger", 'OK', 'Information') | Out-Null
    Write-AuditLog 'ledger_view' "streak=$($stats.Streak)"
}

function Show-HouseholdHarmonyDialog {
    if (-not (Get-Command New-HouseholdSyncPayload -ErrorAction SilentlyContinue)) { return }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "$script:AppName - Household Harmony"
    $dlg.Size = New-Object System.Drawing.Size(440, 280)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.BackColor = $script:C.Bg

    $info = New-Object System.Windows.Forms.Label
    $info.Location = New-Object System.Drawing.Point(16, 12)
    $info.Size = New-Object System.Drawing.Size(400, 56)
    $info.ForeColor = $script:C.Muted
    $info.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $info.Text = 'Sync shutdown with another PC in your home. Export a plan, send the file (or code), partner imports - both machines aim for the same lights-out moment.'
    $dlg.Controls.Add($info)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = 'Export my plan'
    $btnExport.Size = New-Object System.Drawing.Size(190, 40)
    $btnExport.Location = New-Object System.Drawing.Point(16, 80)
    Style-Button $btnExport $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 9
    $btnExport.Add_Click({
        $target = Get-ClockTargetDateTime
        if ($script:Running) { $target = (Get-Date).AddSeconds($script:Left) }
        $payload = New-HouseholdSyncPayload -Action $script:Action -TargetWhen $target
        $out = Join-Path $script:SettingsDir 'household-export.json'
        ($payload | ConvertTo-Json) | Set-Content $out -Encoding UTF8
        [System.Windows.Forms.Clipboard]::SetText([string]$payload.code)
        [System.Windows.Forms.MessageBox]::Show(
            "Plan exported.`nCode: $($payload.code) (copied)`nFile: $out`n`nShare the file or code with your partner PC.",
            $script:AppName, 'OK', 'Information') | Out-Null
        Write-AuditLog 'household_export' "code=$($payload.code) target=$($payload.targetIso)"
    }.GetNewClosure())
    $dlg.Controls.Add($btnExport)

    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Text = 'Import partner plan'
    $btnImport.Size = New-Object System.Drawing.Size(190, 40)
    $btnImport.Location = New-Object System.Drawing.Point(220, 80)
    Style-Button $btnImport ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 9
    $btnImport.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = 'JSON (*.json)|*.json|All (*.*)|*.*'
        if ($ofd.ShowDialog() -ne 'OK') { return }
        try {
            $partner = Import-HouseholdSyncPayload -Path $ofd.FileName
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null
            return
        }
        if ($partner.Target -le (Get-Date)) {
            [System.Windows.Forms.MessageBox]::Show('Partner plan is in the past. Ask them to export again.', $script:AppName) | Out-Null
            return
        }
        $script:HouseholdPartner = $partner
        $localTarget = Get-ClockTargetDateTime
        if ($script:Running) { $localTarget = (Get-Date).AddSeconds($script:Left) }
        $aligned = Test-HouseholdPlansAlign -LocalTarget $localTarget -PartnerTarget $partner.Target
        $alignMsg = if ($aligned) { 'Plans align within 15 minutes - harmonious!' } else { 'Plans differ - consider matching times.' }
        Set-ScheduledTarget -When $partner.Target -Title "Household: $($partner.Machine)" -Uid "household-$($partner.Code)"
        if ($partner.Action -in @('Shutdown', 'Restart', 'Sleep', 'Hibernate', 'Lock')) { Set-Action $partner.Action }
        Write-AuditLog 'household_import' "code=$($partner.Code) machine=$($partner.Machine) aligned=$aligned"
        [System.Windows.Forms.MessageBox]::Show(
            "Partner: $($partner.Machine)`nAction: $($partner.Action)`nAt: $(Format-ClockDisplay $partner.Target)`n`n$alignMsg",
            $script:AppName, 'OK', 'Information') | Out-Null
        Save-Settings
        Update-Ui
    }.GetNewClosure())
    $dlg.Controls.Add($btnImport)

    [void]$dlg.ShowDialog($form)
}

function Start-PunchAnimation {
    param([scriptblock]$OnComplete)
    Publish-LuxGridTick -Remaining 0
    Publish-LuxGridEvent -EventName 'lights.out' -Payload @{
        timerName = $script:LuxGridTimerName
        action    = $script:Action
    }
    $script:punchComplete = $OnComplete
    $script:punchFrame = 0
    $script:punchImpactPlayed = $false
    $lblTime.Text = '00:00'
    $lblRemain.Text = ''
    $pnlPunch.Visible = $true
    $pnlPunch.BringToFront()
    $script:punchTimer.Start()
}

function Complete-TimerEnd {
    $r = Show-FinalConfirm
    if ($r -eq 'Retry') {
        if (-not (Test-AllowSnooze 600)) { Update-Ui; return }
        Write-AuditLog 'snooze_final' '600s'
        $script:Left = 600
        $script:Running = $true
        Reset-CountdownWarnFlags
        $script:timer.Start()
        $script:pulse.Start()
        Update-Ui
        return
    }
    if ($r -eq 'Retry5') {
        if (-not (Test-AllowSnooze 300)) { Update-Ui; return }
        Write-AuditLog 'snooze_final' '300s'
        $script:Left = 300
        $script:Running = $true
        Reset-CountdownWarnFlags
        $script:timer.Start()
        $script:pulse.Start()
        Update-Ui
        return
    }
    if ($r -eq 'Cancel') {
        Write-AuditLog 'final_cancelled' "action=$($script:Action)"
        Publish-LuxGridCancelled -Reason 'final_cancel'
        $script:Left = 0
        Update-Ui
        return
    }
    if ($r -in @('Shutdown', 'Restart', 'Sleep', 'Hibernate', 'Lock')) {
        Set-Action $r
        Save-Settings
    }
    Publish-LuxGridCompleted
    Do-PowerAction
}

function Format-RemainingFriendly {
    $m = [math]::Ceiling($script:Left / 60.0)
    if ($script:Left -le 60) { return 'under a minute' }
    if ($m -eq 1) { return '1 minute left' }
    return "$m minutes left"
}

function Format-EndClock {
    param([int]$SecondsFromNow)
    (Get-Date).AddSeconds([math]::Max(0, $SecondsFromNow)).ToString('h:mm tt')
}

function Format-EndLine {
    param([int]$SecondsFromNow, [switch]$Preview)
    $clock = Format-EndClock $SecondsFromNow
    $verb = $script:Action.ToLower()
    if ($Preview) { return "Start now -> ends about $clock - $verb" }
    return "Ends at $clock - $verb"
}

# Mutex
$mutex = $null
if ($env:SLEEPTIMER_CI -ne '1') {
    $mutex = New-Object System.Threading.Mutex($false, 'Global\SleepTimerTonight')
    if (-not $mutex.WaitOne(0, $false)) {
        [System.Windows.Forms.MessageBox]::Show("$script:AppName is already running. Check the tray.", $script:AppName) | Out-Null
        return
    }
}

$cfg = Get-Settings
$startupSec = 0
if ($script:CliMinutes -gt 0) { $startupSec = $script:CliMinutes * 60 }
elseif ($script:CliSeconds -gt 0) { $startupSec = $script:CliSeconds }
elseif ($Seconds -gt 0) { $startupSec = $Seconds }
$script:DefaultSec = if ($startupSec -gt 0) { [math]::Max((Get-MinTimerSec), $startupSec) } else { $cfg.DefaultSeconds }
$script:Action = $cfg.Action
$cliAct = Normalize-ActionName $script:CliAction
if ($cliAct) { $script:Action = $cliAct }
$script:EmitLuxGridEvents = [bool]$cfg.EmitLuxGridEvents
$script:GracefulShutdown = [bool]$cfg.GracefulShutdown
$script:TimerMode = if ($cfg.TimerMode -in @('clock', 'calendar')) { $cfg.TimerMode } else { 'duration' }
$script:ClockTime = [string]$cfg.ClockTime
$script:CalendarSource = [string]$cfg.CalendarSource
$script:CalendarEventUid = [string]$cfg.CalendarEventUid
$script:CalendarEventTitle = [string]$cfg.CalendarEventTitle
if ($cfg.ScheduledAt) {
    try { $script:ScheduledAt = [DateTime]::Parse([string]$cfg.ScheduledAt) } catch { $script:ScheduledAt = $null }
} else { $script:ScheduledAt = $null }
$script:WarnPowerBlockers = [bool]$cfg.WarnPowerBlockers
$script:DimPhaseEnabled = [bool]$cfg.DimPhaseEnabled
$script:DimPhaseSec = [int]$cfg.DimPhaseSeconds
$script:PactEnabled = [bool]$cfg.PactEnabled
$script:PactTime = [string]$cfg.PactTime
$script:LastRitualId = [string]$cfg.LastRitualId
$cliAt = Parse-ClockTime $script:CliAt
if ($cliAt) {
    $script:ClockTime = $cliAt
    $script:TimerMode = 'clock'
}
$cliSchedule = Parse-ScheduleDateTime $script:CliAt
if ($cliSchedule -and $cliSchedule -gt (Get-Date)) {
    $script:ScheduledAt = $cliSchedule
    $script:TimerMode = 'calendar'
}
if ($script:CliCalendar -and (Test-Path $script:CliCalendar) -and (Get-Command Import-IcsCalendarFile -ErrorAction SilentlyContinue)) {
    try {
        $imported = Import-IcsCalendarFile -Path $script:CliCalendar
        $next = Get-IcsUpcomingEvents -Events $imported.Events -MaxCount 1
        if ($next.Count -gt 0) {
            $ev = $next[0]
            $script:ScheduledAt = $ev.Start
            $script:CalendarSource = $script:CliCalendar
            $script:CalendarEventUid = $ev.Uid
            $script:CalendarEventTitle = $ev.Summary
            $script:TimerMode = 'calendar'
        }
    } catch {
        Write-AuditLog 'calendar_cli_fail' $_.Exception.Message
    }
}

$script:LogoPath = Get-LogoPath
$script:yCal = 18
$script:yNovel = 34
$script:yBoost = if ($script:LogoPath) { 16 } else { 0 }

$form = New-Object System.Windows.Forms.Form
$form.Text = $script:AppName
$form.Size = New-Object System.Drawing.Size(420, (654 + $script:yBoost + $script:yCal + $script:yNovel))
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.StartPosition = 'CenterScreen'
$form.TopMost = $cfg.TopMost
$form.BackColor = $script:C.Bg
$form.ShowInTaskbar = $true

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = $script:AppName
$lblBrand.Visible = $false

$logoPath = $script:LogoPath
if ($logoPath) {
    $picLogo = New-Object System.Windows.Forms.PictureBox
    $picLogo.Location = New-Object System.Drawing.Point(20, 10)
    $picLogo.Size = New-Object System.Drawing.Size(240, 48)
    $picLogo.SizeMode = 'Zoom'
    $picLogo.BackColor = $script:C.Bg
    $picLogo.Image = [System.Drawing.Image]::FromFile($logoPath)
    $form.Controls.Add($picLogo)
    $lblVer.Location = New-Object System.Drawing.Point(268, 26)
    $lblSub.Location = New-Object System.Drawing.Point(24, 58)
} else {
    $lblBrand.Visible = $true
    $lblBrand.Location = New-Object System.Drawing.Point(24, 16)
    $lblBrand.AutoSize = $true
    $lblBrand.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $lblBrand.ForeColor = $script:C.Ink
    $lblBrand.BackColor = $script:C.Bg
    $form.Controls.Add($lblBrand)
    $lblVer.Location = New-Object System.Drawing.Point(132, 20)
    $lblSub.Location = New-Object System.Drawing.Point(24, 42)
}

$lblVer = New-Object System.Windows.Forms.Label
$lblVer.Text = "v$script:AppVersion"
$lblVer.AutoSize = $true
$lblVer.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblVer.ForeColor = $script:C.Muted
$lblVer.BackColor = $script:C.Bg
$form.Controls.Add($lblVer)

$script:lblLedger = New-Object System.Windows.Forms.LinkLabel
$script:lblLedger.Text = 'Sleep ledger'
$script:lblLedger.AutoSize = $true
$script:lblLedger.Location = New-Object System.Drawing.Point(300, 26)
$script:lblLedger.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$script:lblLedger.LinkColor = $script:C.Mint
$script:lblLedger.ActiveLinkColor = $script:C.Amber
$script:lblLedger.BackColor = $script:C.Bg
$script:lblLedger.Add_Click({ Show-SleepLedgerDialog })
$form.Controls.Add($script:lblLedger)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Size = New-Object System.Drawing.Size(372, 18)
$lblSub.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$lblSub.ForeColor = $script:C.Muted
$lblSub.BackColor = $script:C.Bg
$form.Controls.Add($lblSub)

$lblDry = New-Object System.Windows.Forms.Label
$lblDry.Text = 'DRY RUN - no power action'
$lblDry.Location = New-Object System.Drawing.Point(24, (58 + $script:yBoost))
$lblDry.Size = New-Object System.Drawing.Size(372, 16)
$lblDry.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
$lblDry.ForeColor = $script:C.Amber
$lblDry.BackColor = $script:C.Bg
$lblDry.Visible = (Test-NoPowerAction)
$form.Controls.Add($lblDry)

$lblHotkey = New-Object System.Windows.Forms.Label
$lblHotkey.Text = 'Ctrl+Shift+S = emergency cancel'
$lblHotkey.Location = New-Object System.Drawing.Point(24, (58 + $script:yBoost))
$lblHotkey.Size = New-Object System.Drawing.Size(372, 16)
$lblHotkey.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblHotkey.ForeColor = $script:C.Muted
$lblHotkey.BackColor = $script:C.Bg
$lblHotkey.Visible = -not (Test-NoPowerAction)
$form.Controls.Add($lblHotkey)

$pnlRing = New-Object System.Windows.Forms.Panel
$pnlRing.Location = New-Object System.Drawing.Point(88, (78 + $script:yBoost))
$pnlRing.Size = New-Object System.Drawing.Size(220, 220)
$pnlRing.BackColor = $script:C.Bg
Enable-DoubleBuffer $pnlRing
$pnlRing.Add_Paint({ param($s, $e); Draw-Ring $e.Graphics $pnlRing.Width $pnlRing.Height })
$form.Controls.Add($pnlRing)

$pnlPunch = New-Object System.Windows.Forms.Panel
$pnlPunch.Location = $pnlRing.Location
$pnlPunch.Size = $pnlRing.Size
$pnlPunch.BackColor = $script:C.Bg
$pnlPunch.Visible = $false
Enable-DoubleBuffer $pnlPunch
$pnlPunch.Add_Paint({
    param($s, $e)
    if ($script:punchFrame -ge 0) {
        Draw-PunchScene $e.Graphics $script:punchFrame $pnlPunch.Width $pnlPunch.Height
    }
})
$form.Controls.Add($pnlPunch)

$script:pnlDim = New-Object System.Windows.Forms.Panel
$script:pnlDim.Dock = 'Fill'
$script:pnlDim.BackColor = [System.Drawing.Color]::FromArgb(220, 0, 0, 0)
$script:pnlDim.Visible = $false
$form.Controls.Add($script:pnlDim)

$script:lblDimMsg = New-Object System.Windows.Forms.Label
$script:lblDimMsg.Size = New-Object System.Drawing.Size(380, 48)
$script:lblDimMsg.Location = New-Object System.Drawing.Point(20, 120)
$script:lblDimMsg.TextAlign = 'MiddleCenter'
$script:lblDimMsg.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$script:lblDimMsg.ForeColor = $script:C.Amber
$script:lblDimMsg.BackColor = [System.Drawing.Color]::Transparent
$script:pnlDim.Controls.Add($script:lblDimMsg)

$script:lblDimCount = New-Object System.Windows.Forms.Label
$script:lblDimCount.Size = New-Object System.Drawing.Size(380, 36)
$script:lblDimCount.Location = New-Object System.Drawing.Point(20, 168)
$script:lblDimCount.TextAlign = 'MiddleCenter'
$script:lblDimCount.Font = New-Object System.Drawing.Font('Consolas', 28, [System.Drawing.FontStyle]::Bold)
$script:lblDimCount.ForeColor = $script:C.Ink
$script:lblDimCount.BackColor = [System.Drawing.Color]::Transparent
$script:pnlDim.Controls.Add($script:lblDimCount)

$btnDimSnooze = New-Object System.Windows.Forms.Button
$btnDimSnooze.Text = '+5 min wind-down'
$btnDimSnooze.Size = New-Object System.Drawing.Size(160, 36)
$btnDimSnooze.Location = New-Object System.Drawing.Point(40, 260)
Style-Button $btnDimSnooze ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 9
$btnDimSnooze.Add_Click({
    Stop-LightsDimPhase
    Write-AuditLog 'dim_phase_snooze' '300'
    $script:Left = 300
    $script:Running = $true
    Reset-CountdownWarnFlags
    $script:timer.Start()
    $script:pulse.Start()
    Update-Ui
})
$script:pnlDim.Controls.Add($btnDimSnooze)

$btnDimProceed = New-Object System.Windows.Forms.Button
$btnDimProceed.Text = 'Proceed now'
$btnDimProceed.Size = New-Object System.Drawing.Size(160, 36)
$btnDimProceed.Location = New-Object System.Drawing.Point(220, 260)
Style-Button $btnDimProceed $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 9
$btnDimProceed.Add_Click({
    Stop-LightsDimPhase
    Write-AuditLog 'dim_phase_skip' ''
    if ($script:dimComplete) { & $script:dimComplete }
})
$script:pnlDim.Controls.Add($btnDimProceed)

$script:dimTimer = New-Object System.Windows.Forms.Timer
$script:dimTimer.Interval = 1000
$script:dimTimer.Add_Tick({
    if ($script:dimLeft -le 0) {
        Stop-LightsDimPhase
        if ($script:dimComplete) { & $script:dimComplete }
        return
    }
    $script:dimLeft--
    $total = Get-DimPhaseDuration
    $ratio = $script:dimLeft / [math]::Max(1, $total)
    $alpha = [int](220 * (1 - $ratio) + 40)
    $script:pnlDim.BackColor = [System.Drawing.Color]::FromArgb($alpha, 0, 0, 0)
    $script:lblDimCount.Text = ([TimeSpan]::FromSeconds($script:dimLeft)).ToString('mm\:ss')
    $script:lblDimMsg.Text = "Dim the room - breathe - $($script:Action.ToLower()) in $script:dimLeft s"
})

$script:punchFrame = -1
$script:punchComplete = $null
$script:punchImpactPlayed = $false
$script:punchTimer = New-Object System.Windows.Forms.Timer
$script:punchTimer.Interval = 36
$script:punchTimer.Add_Tick({
    if ($script:punchFrame -lt 0) { return }
    if ($script:punchFrame -eq 12 -and -not $script:punchImpactPlayed) {
        [System.Media.SystemSounds]::Hand.Play()
        $script:punchImpactPlayed = $true
    }
    $script:punchFrame++
    $pnlPunch.Invalidate()
    if ($script:punchFrame -gt 34) {
        $script:punchTimer.Stop()
        $pnlPunch.Visible = $false
        $script:punchFrame = -1
        if ($script:punchComplete) {
            $cb = $script:punchComplete
            $script:punchComplete = $null
            & $cb
        }
    }
})

$timeFont = 'Consolas'
try { $null = New-Object System.Drawing.Font('Cascadia Mono', 12); $timeFont = 'Cascadia Mono' } catch { }

$lblUrgent = New-Object System.Windows.Forms.Label
$lblUrgent.Location = New-Object System.Drawing.Point(0, 6)
$lblUrgent.Size = New-Object System.Drawing.Size(220, 18)
$lblUrgent.TextAlign = 'MiddleCenter'
$lblUrgent.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
$lblUrgent.ForeColor = $script:C.Rose
$lblUrgent.BackColor = [System.Drawing.Color]::Transparent
$lblUrgent.Visible = $false
$pnlRing.Controls.Add($lblUrgent)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Location = New-Object System.Drawing.Point(0, 72)
$lblTime.Size = New-Object System.Drawing.Size(220, 48)
$lblTime.TextAlign = 'MiddleCenter'
$lblTime.Font = New-Object System.Drawing.Font($timeFont, 36, [System.Drawing.FontStyle]::Bold)
$lblTime.ForeColor = $script:C.Ink
$lblTime.BackColor = [System.Drawing.Color]::Transparent
$pnlRing.Controls.Add($lblTime)

$lblRemain = New-Object System.Windows.Forms.Label
$lblRemain.Location = New-Object System.Drawing.Point(0, 118)
$lblRemain.Size = New-Object System.Drawing.Size(220, 18)

$lblPct = New-Object System.Windows.Forms.Label
$lblPct.Location = New-Object System.Drawing.Point(0, 136)
$lblPct.Size = New-Object System.Drawing.Size(220, 16)
$lblPct.TextAlign = 'MiddleCenter'
$lblPct.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblPct.ForeColor = $script:C.Muted
$lblPct.BackColor = [System.Drawing.Color]::Transparent
$pnlRing.Controls.Add($lblPct)
$lblRemain.TextAlign = 'MiddleCenter'
$lblRemain.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$lblRemain.ForeColor = $script:C.Muted
$lblRemain.BackColor = [System.Drawing.Color]::Transparent
$pnlRing.Controls.Add($lblRemain)

$lblEnd = New-Object System.Windows.Forms.Label
$lblEnd.Location = New-Object System.Drawing.Point(24, (302 + $script:yBoost))
$lblEnd.Size = New-Object System.Drawing.Size(372, 22)
$lblEnd.TextAlign = 'MiddleCenter'
$lblEnd.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$lblEnd.ForeColor = $script:C.Muted
$lblEnd.BackColor = $script:C.Bg
$form.Controls.Add($lblEnd)

# Control row
$btnSnooze5 = New-Object System.Windows.Forms.Button
$btnSnooze5.Text = '+5'
$btnSnooze5.Location = New-Object System.Drawing.Point(24, (328 + $script:yBoost))
$btnSnooze5.Size = New-Object System.Drawing.Size(52, 38)
Style-Button $btnSnooze5 ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 10 ([System.Drawing.Color]::FromArgb(48, 48, 64))
$form.Controls.Add($btnSnooze5)

$btnSnooze = New-Object System.Windows.Forms.Button
$btnSnooze.Text = '+10'
$btnSnooze.Location = New-Object System.Drawing.Point(82, (328 + $script:yBoost))
$btnSnooze.Size = New-Object System.Drawing.Size(52, 38)
Style-Button $btnSnooze ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 10 ([System.Drawing.Color]::FromArgb(48, 48, 64))
$form.Controls.Add($btnSnooze)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = 'Pause'
$btnStop.Location = New-Object System.Drawing.Point(140, (328 + $script:yBoost))
$btnStop.Size = New-Object System.Drawing.Size(120, 38)
Style-Button $btnStop ([System.Drawing.Color]::FromArgb(36, 36, 50)) $script:C.Ink 10 ([System.Drawing.Color]::FromArgb(48, 48, 64))
$form.Controls.Add($btnStop)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(266, (328 + $script:yBoost))
$btnStart.Size = New-Object System.Drawing.Size(130, 38)
Style-Button $btnStart $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 10 ([System.Drawing.Color]::FromArgb(255, 195, 110))
$form.Controls.Add($btnStart)

# Mode + presets
$pnlMode = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlMode.Location = New-Object System.Drawing.Point(24, (372 + $script:yBoost))
$pnlMode.Size = New-Object System.Drawing.Size(372, 30)
$pnlMode.BackColor = $script:C.Bg
$form.Controls.Add($pnlMode)

$btnModeDuration = New-Object System.Windows.Forms.Button
$btnModeDuration.Text = 'Duration'
$btnModeDuration.Size = New-Object System.Drawing.Size(72, 26)
$btnModeDuration.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
Style-Button $btnModeDuration ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
$pnlMode.Controls.Add($btnModeDuration)

$btnModeClock = New-Object System.Windows.Forms.Button
$btnModeClock.Text = 'At time'
$btnModeClock.Size = New-Object System.Drawing.Size(64, 26)
$btnModeClock.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
Style-Button $btnModeClock ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
$pnlMode.Controls.Add($btnModeClock)

$btnModeCalendar = New-Object System.Windows.Forms.Button
$btnModeCalendar.Text = 'Calendar'
$btnModeCalendar.Size = New-Object System.Drawing.Size(72, 26)
$btnModeCalendar.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
Style-Button $btnModeCalendar ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
$pnlMode.Controls.Add($btnModeCalendar)

function Set-TimerMode {
    param([ValidateSet('duration', 'clock', 'calendar')][string]$Mode)
    $script:TimerMode = $Mode
    $onDuration = ($Mode -eq 'duration')
    $pnlPresets.Visible = $onDuration
    $pnlClock.Visible = ($Mode -in @('clock', 'calendar'))
    if ($script:dtpDate) { $script:dtpDate.Visible = ($Mode -eq 'calendar') }
    if ($script:btnCalImport) { $script:btnCalImport.Visible = ($Mode -eq 'calendar') }
    if ($script:lblCalEvent) { $script:lblCalEvent.Visible = ($Mode -eq 'calendar') }
    $muted = [System.Drawing.Color]::FromArgb(30, 30, 42)
    $mutedFg = $script:C.Muted
    $hi = $script:C.Amber
    $hiBg = [System.Drawing.Color]::FromArgb(18, 14, 8)
    Style-Button $btnModeDuration $(if ($Mode -eq 'duration') { $hi } else { $muted }) $(if ($Mode -eq 'duration') { $hiBg } else { $mutedFg }) 8
    Style-Button $btnModeClock $(if ($Mode -eq 'clock') { $hi } else { $muted }) $(if ($Mode -eq 'clock') { $hiBg } else { $mutedFg }) 8
    Style-Button $btnModeCalendar $(if ($Mode -eq 'calendar') { $hi } else { $muted }) $(if ($Mode -eq 'calendar') { $hiBg } else { $mutedFg }) 8
    if ($Mode -eq 'calendar' -and -not $script:ScheduledAt) { Sync-ScheduledFromPickers }
    if (-not $script:Running -and $script:UiReady) { Save-Settings }
    Update-Ui
}

$btnModeDuration.Add_Click({ Set-TimerMode 'duration' })
$btnModeClock.Add_Click({ Set-TimerMode 'clock' })
$btnModeCalendar.Add_Click({ Set-TimerMode 'calendar' })

# One-tap rituals
$lblRitual = New-Object System.Windows.Forms.Label
$lblRitual.Text = 'Rituals (one tap = start)'
$lblRitual.Location = New-Object System.Drawing.Point(24, (404 + $script:yBoost + $script:yCal))
$lblRitual.Size = New-Object System.Drawing.Size(200, 16)
$lblRitual.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblRitual.ForeColor = $script:C.Muted
$lblRitual.BackColor = $script:C.Bg
$form.Controls.Add($lblRitual)

$pnlRituals = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlRituals.Location = New-Object System.Drawing.Point(24, (422 + $script:yBoost + $script:yCal))
$pnlRituals.Size = New-Object System.Drawing.Size(372, 34)
$pnlRituals.BackColor = $script:C.Bg
$form.Controls.Add($pnlRituals)

$script:RitualBtns = @()
$script:uiToolTip = New-Object System.Windows.Forms.ToolTip
foreach ($rit in Get-RitualCatalog) {
    $rb = New-Object System.Windows.Forms.Button
    $rb.Text = $rit.Label
    $rb.Tag = $rit
    $rb.Size = New-Object System.Drawing.Size(86, 30)
    $rb.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
    $ritCopy = $rit
    Style-Button $rb ([System.Drawing.Color]::FromArgb(28, 26, 38)) $script:C.Ink 8 ([System.Drawing.Color]::FromArgb(42, 40, 56))
    $rb.Add_Click({ Invoke-Ritual $ritCopy })
    $script:uiToolTip.SetToolTip($rb, $rit.Hint)
    $pnlRituals.Controls.Add($rb)
    $script:RitualBtns += $rb
}

# Duration presets
$pnlPresets = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlPresets.Location = New-Object System.Drawing.Point(24, (460 + $script:yBoost + $script:yCal))
$pnlPresets.Size = New-Object System.Drawing.Size(372, 34)
$pnlPresets.BackColor = $script:C.Bg
$form.Controls.Add($pnlPresets)

$script:PresetBtns = @()
foreach ($preset in @(
    @{ L = '24m'; S = 1440 }
    @{ L = '28:20'; S = 1700 }
    @{ L = '30m'; S = 1800 }
    @{ L = '45m'; S = 2700 }
)) {
    $pb = New-Object System.Windows.Forms.Button
    $pb.Text = $preset.L
    $pb.Tag = $preset.S
    $pb.Size = New-Object System.Drawing.Size(58, 28)
    $pb.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
    $sec = $preset.S
    Style-Button $pb ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
    $pb.Add_Click({
        $script:DefaultSec = $sec
        $script:LastRitualId = ''
        if ($script:Running) {
            $script:Left = $sec
            $script:Total = $sec
            $script:Warn5 = $false
        }
        Save-Settings
        Update-Ui
    }.GetNewClosure())
    $pnlPresets.Controls.Add($pb)
    $script:PresetBtns += $pb
}

# Clock / calendar schedule row
$pnlClock = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlClock.Location = New-Object System.Drawing.Point(24, (460 + $script:yBoost))
$pnlClock.Size = New-Object System.Drawing.Size(372, 34)
$pnlClock.BackColor = $script:C.Bg
$pnlClock.Visible = $false
$form.Controls.Add($pnlClock)

$script:dtpDate = New-Object System.Windows.Forms.DateTimePicker
$script:dtpDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
$script:dtpDate.Width = 108
$script:dtpDate.Height = 28
$script:dtpDate.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
$script:dtpDate.Visible = $false
if ($script:ScheduledAt) { $script:dtpDate.Value = [DateTime]$script:ScheduledAt }
$script:dtpDate.Add_ValueChanged({ Sync-ScheduledFromPickers; if (-not $script:Running) { Save-Settings }; Update-Ui })
$pnlClock.Controls.Add($script:dtpDate)

$script:dtpClock = New-Object System.Windows.Forms.DateTimePicker
$script:dtpClock.Format = [System.Windows.Forms.DateTimePickerFormat]::Time
$script:dtpClock.ShowUpDown = $true
$script:dtpClock.Width = 110
$script:dtpClock.Height = 28
$script:dtpClock.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
try {
    $ctParts = $script:ClockTime.Split(':')
    $script:dtpClock.Value = Get-Date -Hour ([int]$ctParts[0]) -Minute ([int]$ctParts[1]) -Second 0
} catch {
    $script:dtpClock.Value = Get-Date -Hour 23 -Minute 30 -Second 0
}
$script:dtpClock.Add_ValueChanged({
    if (-not $script:UiReady) { return }
    $script:ClockTime = $script:dtpClock.Value.ToString('HH:mm')
    if ($script:TimerMode -eq 'calendar') { Sync-ScheduledFromPickers }
    if (-not $script:Running) { Save-Settings; Update-Ui }
})
$pnlClock.Controls.Add($script:dtpClock)

$script:btnCalImport = New-Object System.Windows.Forms.Button
$script:btnCalImport.Text = 'Import .ics'
$script:btnCalImport.Size = New-Object System.Drawing.Size(88, 28)
$script:btnCalImport.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
$script:btnCalImport.Visible = $false
Style-Button $script:btnCalImport ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Ink 8
$script:btnCalImport.Add_Click({ Show-CalendarEventDialog | Out-Null })
$pnlClock.Controls.Add($script:btnCalImport)

$script:lblCalEvent = New-Object System.Windows.Forms.Label
$script:lblCalEvent.Size = New-Object System.Drawing.Size(372, 16)
$script:lblCalEvent.Location = New-Object System.Drawing.Point(24, (494 + $script:yBoost))
$script:lblCalEvent.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$script:lblCalEvent.ForeColor = $script:C.Muted
$script:lblCalEvent.BackColor = $script:C.Bg
$script:lblCalEvent.Visible = $false
$form.Controls.Add($script:lblCalEvent)

$script:ClockPresetBtns = @()
foreach ($cp in @(
    @{ L = '10:30 PM'; T = '22:30' }
    @{ L = '11:00 PM'; T = '23:00' }
    @{ L = '11:30 PM'; T = '23:30' }
    @{ L = '12:00 AM'; T = '00:00' }
)) {
    $cb = New-Object System.Windows.Forms.Button
    $cb.Text = $cp.L
    $cb.Tag = $cp.T
    $cb.Size = New-Object System.Drawing.Size(58, 28)
    $cb.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
    $timeTag = $cp.T
    Style-Button $cb ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
    $cb.Add_Click({
        $parts = $timeTag.Split(':')
        $script:dtpClock.Value = Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0
        $script:ClockTime = $timeTag
        if (-not $script:Running) { Save-Settings; Update-Ui }
    }.GetNewClosure())
    $pnlClock.Controls.Add($cb)
    $script:ClockPresetBtns += $cb
}

# Card
$pnlCard = New-Object System.Windows.Forms.Panel
$pnlCard.Location = New-Object System.Drawing.Point(20, (498 + $script:yBoost + $script:yCal + $script:yNovel))
$pnlCard.Size = New-Object System.Drawing.Size(380, 158)
$pnlCard.BackColor = $script:C.Card
$form.Controls.Add($pnlCard)

$script:Pills = @()
foreach ($a in @('Shutdown', 'Sleep', 'Restart', 'Hibernate', 'Lock')) {
    $i = $script:Pills.Count
    $p = New-Object System.Windows.Forms.Button
    $p.Text = $a
    $p.Tag = $a
    $p.Size = New-Object System.Drawing.Size(70, 30)
    $p.Location = New-Object System.Drawing.Point((8 + $i * 74), 10)
    Style-Button $p ([System.Drawing.Color]::FromArgb(32, 32, 44)) $script:C.Muted 9
    $p.Add_Click({ Set-Action $this.Tag })
    $pnlCard.Controls.Add($p)
    $script:Pills += $p
}

function New-Chk {
    param($Text, $X, $Y, $Checked)
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Text
    $c.Location = New-Object System.Drawing.Point($X, $Y)
    $c.AutoSize = $true
    $c.ForeColor = $script:C.Muted
    $c.BackColor = $script:C.Card
    $c.Checked = $Checked
    $c.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $pnlCard.Controls.Add($c)
    return $c
}

$chkTop = New-Chk 'Always on top' 10 50 $cfg.TopMost
$chkTop.Add_CheckedChanged({ $form.TopMost = $chkTop.Checked })

$chkWarn5 = New-Chk '5 min warn' 100 50 $cfg.Warn5Min
$chkQuick = New-Chk 'Quick choices' 200 50 $cfg.QuickWarnPanel
$chkQuick.Add_CheckedChanged({
    $script:QuickWarnPanel = $chkQuick.Checked
    if (-not $script:Running) { Save-Settings }
})
$script:QuickWarnPanel = $cfg.QuickWarnPanel
$chkLogin = New-Chk 'Run at login' 300 50 $(if ($cfg.RunAtLogin) { $true } else { Test-RunAtLogin })
$chkLogin.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })

$chkMinTray = New-Chk 'Tray on minimize' 10 68 $cfg.MinimizeToTray
$chkLuxGrid = New-Chk 'LuxGrid RGB' 130 68 $cfg.EmitLuxGridEvents
$chkLuxGrid.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })

$chkGraceful = New-Chk 'Graceful exit' 230 68 $cfg.GracefulShutdown
$chkGraceful.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })

$script:chkPowerWarn = New-Chk 'Blocker warn' 10 86 $cfg.WarnPowerBlockers
$script:chkPowerWarn.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })

$script:chkDimPhase = New-Chk 'Dim phase (90s)' 130 86 $cfg.DimPhaseEnabled
$script:chkDimPhase.Add_CheckedChanged({ if (-not $script:Running) { Save-Settings } })

$script:chkPact = New-Chk 'Bedtime pact' 10 104 $cfg.PactEnabled
$script:chkPact.Add_CheckedChanged({
    if ($script:dtpPact) { $script:dtpPact.Visible = $script:chkPact.Checked }
    if (-not $script:Running) { Save-Settings }
})

$script:dtpPact = New-Object System.Windows.Forms.DateTimePicker
$script:dtpPact.Format = [System.Windows.Forms.DateTimePickerFormat]::Time
$script:dtpPact.ShowUpDown = $true
$script:dtpPact.Width = 90
$script:dtpPact.Height = 22
$script:dtpPact.Location = New-Object System.Drawing.Point(118, 102)
$ptParts = $cfg.PactTime.Split(':')
$script:dtpPact.Value = Get-Date -Hour ([int]$ptParts[0]) -Minute ([int]$ptParts[1]) -Second 0
$script:dtpPact.Visible = $cfg.PactEnabled
$script:dtpPact.Add_ValueChanged({ if (-not $script:Running) { Save-Settings } })
$pnlCard.Controls.Add($script:dtpPact)

$btnHousehold = New-Object System.Windows.Forms.Button
$btnHousehold.Text = 'Household sync'
$btnHousehold.Size = New-Object System.Drawing.Size(110, 24)
$btnHousehold.Location = New-Object System.Drawing.Point(220, 102)
Style-Button $btnHousehold ([System.Drawing.Color]::FromArgb(28, 32, 44)) $script:C.Mint 8
$btnHousehold.Add_Click({ Show-HouseholdHarmonyDialog })
$pnlCard.Controls.Add($btnHousehold)

function Update-GracefulCheckbox {
    if (-not $script:UiReady) { return }
    $applies = Test-GracefulApplies
    $chkGraceful.Enabled = $applies
    if (-not $applies) { $chkGraceful.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 80) }
    else { $chkGraceful.ForeColor = $script:C.Muted }
}

# Tray
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:trayIconStatic = $null
$iconPath = Get-AppIconPath
if ($iconPath) { $script:trayIconStatic = New-Object System.Drawing.Icon($iconPath) }
$script:trayLiveIcon = $null
$script:trayFlashState = $false
$script:tray.Visible = $true
$script:tray.Text = $script:AppName
Update-TrayProgressIcon

function Show-MainWindow {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.ShowInTaskbar = $true
    $form.Activate()
    $form.BringToFront()
}

function Stop-TrayFlash {
    if ($script:trayFlash) { $script:trayFlash.Stop() }
    $script:trayFlashState = $false
    Update-TrayProgressIcon
}

function Hide-ToTray {
    param([switch]$Balloon)
    $form.Hide()
    $form.ShowInTaskbar = $false
    if ($Balloon) {
        $msg = if ($script:Running) {
            "Ends at $(Format-EndClock $script:Left). Double-click to show."
        } elseif ($script:Paused) {
            "Paused $([TimeSpan]::FromSeconds($script:Left).ToString('mm\:ss')). Double-click to resume."
        } else {
            'Countdown in tray. Double-click to show.'
        }
        $script:tray.ShowBalloonTip(3000, $script:AppName, $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

function Set-TrayText {
    param([string]$Text)
    if ($Text.Length -gt 63) { $Text = $Text.Substring(0, 63) }
    try { $script:tray.Text = $Text } catch { }
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.BackColor = $script:C.Card
$menu.ForeColor = $script:C.Ink
[void]$menu.Items.Add('Show', $null, { Show-MainWindow })
[void]$menu.Items.Add('Calendar event...', $null, { Show-CalendarEventDialog | Out-Null })
[void]$menu.Items.Add('Sleep ledger', $null, { Show-SleepLedgerDialog })
[void]$menu.Items.Add('Household sync...', $null, { Show-HouseholdHarmonyDialog })
[void]$menu.Items.Add('+10 min', $null, { if ($script:Running -and (Test-AllowSnooze 600)) { $script:Left += 600; $script:Warn5 = $false; $script:Warn60 = $false; $script:Warn30 = $false; Write-AuditLog 'snooze' 'tray+600'; Update-Ui } })
$script:trayPauseItem = $menu.Items.Add('Pause', $null, {
    if ($script:Paused) { Resume-Timer; Show-MainWindow }
    elseif ($script:Running) { Stop-Timer -Reason 'tray_pause'; Show-MainWindow }
})
[void]$menu.Items.Add('Cancel', $null, { Invoke-EmergencyCancel })
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Exit', $null, {
    $script:Running = $false
    $script:timer.Stop()
    $script:pulse.Stop()
    $script:tray.Visible = $false
    $form.Close()
})
$script:tray.ContextMenuStrip = $menu
$script:tray.Add_DoubleClick({ Show-MainWindow })

function Update-RitualHighlight {
    foreach ($rb in $script:RitualBtns) {
        $rit = $rb.Tag
        if ($rit.Id -eq $script:LastRitualId) {
            Style-Button $rb $script:C.Violet ([System.Drawing.Color]::FromArgb(14, 12, 18)) 8 ([System.Drawing.Color]::FromArgb(190, 160, 255))
        } else {
            Style-Button $rb ([System.Drawing.Color]::FromArgb(28, 26, 38)) $script:C.Ink 8 ([System.Drawing.Color]::FromArgb(42, 40, 56))
        }
    }
}

function Update-PresetHighlight {
    foreach ($pb in $script:PresetBtns) {
        if ($pb.Tag -eq $script:DefaultSec) {
            Style-Button $pb $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 8 ([System.Drawing.Color]::FromArgb(255, 195, 110))
        } else {
            Style-Button $pb ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
        }
    }
}

function Update-ClockPresetHighlight {
    foreach ($cb in $script:ClockPresetBtns) {
        if ($cb.Tag -eq $script:ClockTime) {
            Style-Button $cb $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) 8 ([System.Drawing.Color]::FromArgb(255, 195, 110))
        } else {
            Style-Button $cb ([System.Drawing.Color]::FromArgb(30, 30, 42)) $script:C.Muted 8 ([System.Drawing.Color]::FromArgb(44, 44, 58))
        }
    }
}

function Update-Ui {
    $idleSec = if ($script:TimerMode -in @('clock', 'calendar')) { Get-SecondsUntilClock } else { $script:DefaultSec }
    if ($script:Running) {
        $secs = $script:Left
    } elseif ($script:Paused) {
        $secs = $script:Left
    } else {
        $secs = $idleSec
    }
    $timeStr = ([TimeSpan]::FromSeconds([math]::Max(0, $secs))).ToString('mm\:ss')
    $lblTime.Text = $timeStr
    $accent = Get-CountdownAccentColor
    $lblTime.ForeColor = if ($script:Running) { $accent } else { $script:C.Ink }
    $urgency = Get-CountdownUrgencyLevel
    if ($script:Running -and $urgency -in @('final', 'critical')) {
        $verb = switch ($script:Action) {
            'Sleep' { 'sleep' }
            'Restart' { 'restart' }
            'Hibernate' { 'hibernate' }
            'Lock' { 'lock' }
            default { 'shut down' }
        }
        $lblUrgent.Text = if ($urgency -eq 'critical') { "Last seconds - will $verb" } else { "Under 1 min - will $verb" }
        $lblUrgent.Visible = $true
        $lblUrgent.ForeColor = if ($urgency -eq 'critical') { Get-RingColor } else { $script:C.Rose }
    } else {
        $lblUrgent.Visible = $false
    }
    if ($script:Running -and $script:Total -gt 0) {
        $pctLeft = [int](100 * $script:Left / $script:Total)
        $lblPct.Text = "$pctLeft% remaining"
        $lblPct.ForeColor = $accent
        $lblPct.Visible = $true
    } elseif ($script:Paused) {
        $lblPct.Text = 'paused'
        $lblPct.ForeColor = $script:C.Muted
        $lblPct.Visible = $true
    } else {
        $lblPct.Visible = $false
    }
    $pnlRing.BackColor = Get-UrgencyRingBackColor
    $btnStart.Text = if ($script:Running) {
        'Running'
    } elseif ($script:Paused) {
        "Resume $timeStr"
    } elseif ($script:TimerMode -eq 'clock') {
        "Start at $(Format-ClockDisplay (Get-ClockTargetDateTime))"
    } elseif ($script:TimerMode -eq 'calendar') {
        "Start at $(Format-ClockDisplay (Get-ClockTargetDateTime))"
    } else {
        "Start $(([TimeSpan]::FromSeconds($script:DefaultSec)).ToString('mm\:ss'))"
    }

    if ($script:Running) {
        $pct = [int](100 * ($script:Total - $script:Left) / [math]::Max(1, $script:Total))
        $lblSub.Text = "Countdown active - $pct% elapsed"
        $lblRemain.Text = Format-RemainingFriendly
        $lblEnd.Text = Format-EndLine $script:Left
        $endClock = Format-EndClock $script:Left
        $btnStart.Enabled = $false
        $btnSnooze.Enabled = $true
        $btnSnooze5.Enabled = $true
        $btnStop.Enabled = $true
        $btnStop.Text = 'Pause'
        foreach ($p in $script:Pills) { $p.Enabled = $false }
        $pnlPresets.Enabled = $true
        $pnlMode.Enabled = $false
        if ($script:trayPauseItem) { $script:trayPauseItem.Text = 'Pause' }
        Set-TrayText "$script:AppName $timeStr -> $endClock ($($script:Action))"
        $form.Text = "$script:AppName - $timeStr ($($script:Action))"
    } elseif ($script:Paused) {
        $pct = [int](100 * ($script:Total - $script:Left) / [math]::Max(1, $script:Total))
        $lblSub.Text = "Paused - $($script:Action.ToLower()) in $timeStr"
        $lblRemain.Text = 'tap Resume to continue'
        $lblEnd.Text = Format-EndLine $script:Left
        $btnStart.Enabled = $true
        $btnSnooze.Enabled = $false
        $btnSnooze5.Enabled = $false
        $btnStop.Enabled = $true
        $btnStop.Text = 'Cancel'
        foreach ($p in $script:Pills) { $p.Enabled = $false }
        $pnlPresets.Enabled = $false
        $pnlClock.Enabled = $false
        $pnlMode.Enabled = $false
        if ($script:trayPauseItem) { $script:trayPauseItem.Text = 'Resume' }
        Set-TrayText "$script:AppName PAUSED $timeStr ($($script:Action))"
        $form.Text = "$script:AppName - paused $timeStr"
    } else {
        if ($script:TimerMode -eq 'clock') {
            $target = Get-ClockTargetDateTime
            $lblSub.Text = "Daily time - $($script:Action.ToLower()) at $(Format-ClockDisplay $target)"
            $lblRemain.Text = Format-DurationLong $idleSec
            $lblEnd.Text = "$(Format-ClockDisplay $target) · in $(Format-DurationLong $idleSec)"
        } elseif ($script:TimerMode -eq 'calendar') {
            $target = Get-ClockTargetDateTime
            $evName = if ($script:CalendarEventTitle) { $script:CalendarEventTitle } else { 'scheduled event' }
            $lblSub.Text = "Calendar - $($script:Action.ToLower()) for $evName"
            $lblRemain.Text = Format-DurationLong $idleSec
            $lblEnd.Text = "$(Format-ClockDisplay $target) · in $(Format-DurationLong $idleSec)"
            if ($script:lblCalEvent) {
                $script:lblCalEvent.Text = "Event: $evName"
                $script:lblCalEvent.Visible = $true
            }
        } else {
            if ($script:lblCalEvent) { $script:lblCalEvent.Visible = $false }
            $lblSub.Text = 'Pick action + duration, then Start'
            $lblRemain.Text = 'ready when you are'
            $lblEnd.Text = Format-EndLine $script:DefaultSec -Preview
        }
        $btnStart.Enabled = $true
        $btnSnooze.Enabled = $false
        $btnSnooze5.Enabled = $false
        $btnStop.Enabled = $false
        $btnStop.Text = 'Pause'
        foreach ($p in $script:Pills) { $p.Enabled = $true }
        $pnlPresets.Enabled = $true
        $pnlClock.Enabled = $true
        $pnlMode.Enabled = $true
        if ($script:trayPauseItem) { $script:trayPauseItem.Text = 'Pause' }
        Set-TrayText "$script:AppName - ready"
        $form.Text = $script:AppName
    }
    Update-RitualHighlight
    Update-PresetHighlight
    Update-ClockPresetHighlight
    Update-TrayProgressIcon
    Update-SleepLedgerBadge
    if ($script:HouseholdPartner -and $script:lblCalEvent -and -not $script:Running) {
        $script:lblCalEvent.Text = "Household: $($script:HouseholdPartner.Machine) at $(Format-ClockDisplay $script:HouseholdPartner.Target)"
        $script:lblCalEvent.Visible = $true
    }
    $pnlRing.Invalidate()
}

function Stop-Timer {
    param([string]$Reason = 'pause')
    if ($script:Running) {
        Write-AuditLog 'timer_stopped' "$Reason left=$script:Left"
        if ($Reason -ne 'emergency') { Publish-LuxGridCancelled -Reason $Reason }
    }
    $script:Running = $false
    $script:timer.Stop()
    $script:pulse.Stop()
    Stop-TrayFlash
    if ($Reason -eq 'pause' -and $script:Left -gt 0) {
        $script:Paused = $true
    } else {
        $script:Paused = $false
    }
    Update-Ui
}

function Resume-Timer {
    if ($script:Left -le 0) { return }
    $script:Paused = $false
    $script:Running = $true
    Write-AuditLog 'timer_resumed' "left=$script:Left action=$script:Action"
    Publish-LuxGridEvent -EventName 'timer.start' -Payload @{
        timerName        = $script:LuxGridTimerName
        totalSeconds     = $script:Total
        remainingSeconds = $script:Left
        action           = $script:Action
        resumed          = $true
    }
    $script:timer.Start()
    $script:pulse.Start()
    Update-Ui
    if (-not (Test-NoPowerAction)) {
        $script:tray.ShowBalloonTip(
            3000, $script:AppName, "Resumed - $([TimeSpan]::FromSeconds($script:Left).ToString('mm\:ss')) left",
            [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

function Cancel-PausedTimer {
    if (-not $script:Paused) { return }
    Write-AuditLog 'timer_cancelled' 'paused_clear'
    Publish-LuxGridCancelled -Reason 'cancel'
    $script:Paused = $false
    $script:Left = 0
    Update-Ui
}

function Reset-CountdownWarnFlags {
    $script:Warn5 = $false
    $script:Warn60 = $false
    $script:Warn30 = $false
}

function Add-QuickDialogButton {
    param(
        $Parent,
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [string]$Tag,
        [System.Drawing.Color]$Bg,
        [System.Drawing.Color]$Fg,
        [scriptblock]$OnClick
    )
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Tag = $Tag
    $b.Location = New-Object System.Drawing.Point($X, $Y)
    $b.Size = New-Object System.Drawing.Size($W, $H)
    Style-Button $b $Bg $Fg 9
    $b.Add_Click($OnClick)
    $Parent.Controls.Add($b)
    return $b
}

function Show-CountdownQuickPanel {
    param([int]$MarkerSeconds)
    if (Test-NoPowerAction) { return 'Continue' }
    Show-MainWindow
    Stop-TrayFlash

    $title = switch ($MarkerSeconds) {
        300 { '5 minutes left' }
        60  { '1 minute left' }
        30  { '30 seconds left' }
        default { "$([TimeSpan]::FromSeconds($script:Left).ToString('mm\:ss')) left" }
    }
    $timeLeft = [TimeSpan]::FromSeconds([math]::Max(0, $script:Left)).ToString('mm\:ss')
    $endAt = Format-EndClock $script:Left

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "$script:AppName - quick choices"
    $dlg.Size = New-Object System.Drawing.Size(440, 318)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.TopMost = $true
    $dlg.BackColor = $script:C.Bg
    $dlg.KeyPreview = $true

    $head = New-Object System.Windows.Forms.Label
    $head.Location = New-Object System.Drawing.Point(16, 14)
    $head.Size = New-Object System.Drawing.Size(400, 28)
    $head.Text = $title
    $head.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
    $head.ForeColor = if ($MarkerSeconds -le 60) { $script:C.Rose } else { $script:C.Amber }
    $head.TextAlign = 'MiddleCenter'
    $dlg.Controls.Add($head)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Location = New-Object System.Drawing.Point(16, 44)
    $sub.Size = New-Object System.Drawing.Size(400, 36)
    $sub.Text = "$timeLeft remaining · $($script:Action) at $endAt`nPick more time, change action, or cancel."
    $sub.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $sub.ForeColor = $script:C.Muted
    $sub.TextAlign = 'MiddleCenter'
    $dlg.Controls.Add($sub)

    $pick = {
        param($tag)
        $dlg.Tag = $tag
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    }.GetNewClosure()

    $btnBg = [System.Drawing.Color]::FromArgb(36, 36, 50)
    $btnHi = [System.Drawing.Color]::FromArgb(48, 48, 64)
    Add-QuickDialogButton $dlg '+5 min' 16 92 200 38 'Snooze300' $btnBg $script:C.Ink { & $pick 'Snooze300' } | Out-Null
    Add-QuickDialogButton $dlg '+10 min' 224 92 200 38 'Snooze600' $btnBg $script:C.Ink { & $pick 'Snooze600' } | Out-Null

    $actions = @(
        @{ L = 'Shutdown'; T = 'Shutdown'; C = $script:C.Amber }
        @{ L = 'Restart'; T = 'Restart'; C = $script:C.Blue }
        @{ L = 'Sleep'; T = 'Sleep'; C = $script:C.Mint }
        @{ L = 'Hibernate'; T = 'Hibernate'; C = $script:C.Violet }
        @{ L = 'Lock'; T = 'Lock'; C = $script:C.Slate }
    )
    $ax = 16
    foreach ($act in $actions) {
        $w = 78
        $actionTag = $act.T
        Add-QuickDialogButton $dlg $act.L $ax 138 $w 34 $actionTag ([System.Drawing.Color]::FromArgb(28, 28, 40)) $act.C {
            & $pick $actionTag
        } | Out-Null
        $ax += ($w + 6)
    }

    Add-QuickDialogButton $dlg 'Cancel countdown' 16 182 408 36 'Cancel' ([System.Drawing.Color]::FromArgb(48, 22, 28)) $script:C.Rose {
        & $pick 'Cancel'
    } | Out-Null
    Add-QuickDialogButton $dlg 'Keep countdown' 16 226 408 40 'Continue' $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) {
        & $pick 'Continue'
    } | Out-Null

    $dlg.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') {
            $dlg.Tag = 'Continue'
            $dlg.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $dlg.Close()
        }
    })

    [void]$dlg.ShowDialog($form)
    if ($dlg.Tag) { return [string]$dlg.Tag }
    return 'Continue'
}

function Apply-CountdownQuickResult {
    param([string]$Result, [int]$MarkerSeconds = 0)
    if (-not $Result -or $Result -eq 'Continue') { return }

    Write-AuditLog 'quick_warn_choice' "marker=$MarkerSeconds result=$Result left=$($script:Left)"

    switch ($Result) {
        'Snooze300' {
            if ($script:Running -and (Test-AllowSnooze 300)) {
                $script:Left += 300
                Reset-CountdownWarnFlags
                Update-Ui
            }
        }
        'Snooze600' {
            if ($script:Running -and (Test-AllowSnooze 600)) {
                $script:Left += 600
                Reset-CountdownWarnFlags
                Update-Ui
            }
        }
        'Cancel' { Invoke-EmergencyCancel }
        default {
            if ($Result -in @('Shutdown', 'Restart', 'Sleep', 'Hibernate', 'Lock')) {
                Set-Action $Result
                if ($script:Running) { Save-Settings; Update-Ui }
            }
        }
    }
}

function Invoke-CountdownWarning {
    param([int]$MarkerSeconds)
    $severity = if ($MarkerSeconds -le 30) { 'critical' } elseif ($MarkerSeconds -le 60) { 'warning' } else { 'info' }
    Publish-LuxGridWarning -Remaining $MarkerSeconds -Severity $severity

    if ($MarkerSeconds -le 30) {
        [System.Media.SystemSounds]::Exclamation.Play()
        if ($script:trayFlash -and -not $script:trayFlash.Enabled) { $script:trayFlash.Start() }
    }

    if ($script:QuickWarnPanel) {
        $choice = Show-CountdownQuickPanel -MarkerSeconds $MarkerSeconds
        Apply-CountdownQuickResult -Result $choice -MarkerSeconds $MarkerSeconds
        return
    }

    if (Test-NoPowerAction) { return }
    $verb = switch ($script:Action) {
        'Sleep' { 'sleep' }
        'Restart' { 'restart' }
        'Hibernate' { 'hibernate' }
        'Lock' { 'lock' }
        default { 'shut down' }
    }
    switch ($MarkerSeconds) {
        300 {
            $msg5 = "5 minutes left - ends at $(Format-EndClock $script:Left)"
            $script:tray.ShowBalloonTip(5000, $script:AppName, $msg5, [System.Windows.Forms.ToolTipIcon]::Warning)
        }
        60 {
            $script:tray.ShowBalloonTip(
                5000, $script:AppName,
                "1 minute left - PC will $verb. Ctrl+Shift+S to cancel.",
                [System.Windows.Forms.ToolTipIcon]::Warning)
        }
        30 {
            $script:tray.ShowBalloonTip(
                6000, $script:AppName, '30 seconds - Ctrl+Shift+S to cancel',
                [System.Windows.Forms.ToolTipIcon]::Warning)
        }
    }
}

function Show-FinalConfirm {
    if (Test-NoPowerAction) { return 'OK' }
    Show-MainWindow
    Stop-TrayFlash
    $proceedText = switch ($script:Action) {
        'Restart' { 'Restart now' }
        'Sleep'   { 'Sleep now' }
        'Hibernate' { 'Hibernate now' }
        'Lock' { 'Lock now' }
        default   { 'Shut down now' }
    }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Still awake?'
    $dlg.Size = New-Object System.Drawing.Size(440, 340)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.TopMost = $true
    $dlg.BackColor = $script:C.Bg
    $dlg.KeyPreview = $true
    $t = New-Object System.Windows.Forms.Label
    $t.Location = New-Object System.Drawing.Point(16, 16)
    $t.Size = New-Object System.Drawing.Size(400, 44)
    $t.ForeColor = switch ($script:Action) {
        'Sleep' { $script:C.Mint }
        'Restart' { $script:C.Blue }
        'Hibernate' { $script:C.Violet }
        'Lock' { $script:C.Slate }
        default { $script:C.Amber }
    }
    $t.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $t.TextAlign = 'MiddleCenter'
    $dlg.Controls.Add($t)
    $hint = New-Object System.Windows.Forms.Label
    $hint.Location = New-Object System.Drawing.Point(16, 58)
    $hint.Size = New-Object System.Drawing.Size(400, 32)
    $hint.ForeColor = $script:C.Muted
    $hint.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $hint.TextAlign = 'MiddleCenter'
    $hint.Text = 'Add time, switch action, cancel, or proceed when the countdown ends.'
    $dlg.Controls.Add($hint)
    $script:confirmLeft = 5
    $cd = New-Object System.Windows.Forms.Timer
    $cd.Interval = 1000
    $cd.Add_Tick({
        $script:confirmLeft--
        $t.Text = "$($script:Action) in $script:confirmLeft..."
        if ($script:confirmLeft -le 0) { $cd.Stop(); $dlg.Tag = 'OK'; $dlg.DialogResult = 'OK'; $dlg.Close() }
    })
    $t.Text = "$($script:Action) in 5..."
    $cd.Start()

    $finalPick = {
        param($tag)
        $cd.Stop()
        $dlg.Tag = $tag
        $dlg.DialogResult = 'OK'
        $dlg.Close()
    }.GetNewClosure()

    $btnBg = [System.Drawing.Color]::FromArgb(36, 36, 50)
    Add-QuickDialogButton $dlg '+5 min' 16 98 200 36 'Retry5' $btnBg $script:C.Ink { & $finalPick 'Retry5' } | Out-Null
    Add-QuickDialogButton $dlg '+10 min' 224 98 200 36 'Retry' $btnBg $script:C.Ink { & $finalPick 'Retry' } | Out-Null

    $ax = 16
    foreach ($act in @(
            @{ L = 'Shutdown'; T = 'Shutdown'; C = $script:C.Amber }
            @{ L = 'Restart'; T = 'Restart'; C = $script:C.Blue }
            @{ L = 'Sleep'; T = 'Sleep'; C = $script:C.Mint }
            @{ L = 'Hibernate'; T = 'Hibernate'; C = $script:C.Violet }
            @{ L = 'Lock'; T = 'Lock'; C = $script:C.Slate }
        )) {
        $actionTag = $act.T
        Add-QuickDialogButton $dlg $act.L $ax 142 78 34 $actionTag ([System.Drawing.Color]::FromArgb(28, 28, 40)) $act.C {
            & $finalPick $actionTag
        } | Out-Null
        $ax += 84
    }

    Add-QuickDialogButton $dlg 'Cancel countdown' 16 186 408 34 'Cancel' ([System.Drawing.Color]::FromArgb(48, 22, 28)) $script:C.Rose {
        & $finalPick 'Cancel'
    } | Out-Null
    Add-QuickDialogButton $dlg $proceedText 16 228 408 44 'OK' $script:C.Amber ([System.Drawing.Color]::FromArgb(18, 14, 8)) {
        & $finalPick 'OK'
    } | Out-Null

    $dlg.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') {
            $cd.Stop()
            $dlg.Tag = 'Cancel'
            $dlg.DialogResult = 'Cancel'
            $dlg.Close()
        }
    })

    [void]$dlg.ShowDialog($form)
    $cd.Dispose()
    if ($dlg.Tag) { return [string]$dlg.Tag }
    return 'OK'
}

function Test-UseForcePower {
    if ($script:Action -notin @('Shutdown', 'Restart')) { return $false }
    if ($script:UiReady -and $chkGraceful) { return -not $chkGraceful.Checked }
    return -not [bool]$script:GracefulShutdown
}

function Do-PowerAction {
    Save-Settings
    if (Test-NoPowerAction) {
        Write-AuditLog 'power_blocked' "safe_mode action=$script:Action"
        $logDir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        "$(Get-Date -Format o) SAFE_MODE action=$script:Action (no power command)" | Add-Content (Join-Path $logDir 'ci-smoke.log')
        $script:timer.Stop()
        $script:pulse.Stop()
        $script:tray.Visible = $false
        $form.Close()
        return
    }
    $force = Test-UseForcePower
    Write-AuditLog 'power_action' "action=$script:Action force=$force"
    switch ($script:Action) {
        'Restart' {
            if ($force) { Restart-Computer -Force }
            else { Restart-Computer }
        }
        'Sleep' {
            $crit = if ($force) { 1 } else { 0 }
            & rundll32.exe powrprof.dll,SetSuspendState 0, $crit, 0
        }
        'Hibernate' {
            $crit = if ($force) { 1 } else { 0 }
            & rundll32.exe powrprof.dll,SetSuspendState 1, $crit, 0
        }
        'Lock' {
            & rundll32.exe user32.dll,LockWorkStation
        }
        default {
            if ($force) { Stop-Computer -Force }
            else { Stop-Computer }
        }
    }
}

function Start-Timer {
    param([int]$Sec)
    $script:Paused = $false
    $minSec = Get-MinTimerSec
    if ($Sec -lt $minSec) { $Sec = $minSec }
    $script:DefaultSec = $Sec
    $script:Total = $Sec
    $script:Left = $Sec
    $script:Warn5 = $false
    $script:Warn60 = $false
    $script:Warn30 = $false
    $script:PactBreaks = 0
    $script:PactSnoozeLocked = $false
    $script:Running = $true
    Write-AuditLog 'timer_started' "action=$script:Action seconds=$Sec mode=$($script:TimerMode) clock=$($script:ClockTime)"
    Publish-LuxGridEvent -EventName 'timer.start' -Payload @{
        timerName        = $script:LuxGridTimerName
        totalSeconds     = $Sec
        remainingSeconds = $Sec
        action           = $script:Action
    }
    Save-Settings
    $script:timer.Start()
    $script:pulse.Start()
    Update-Ui
    if (-not (Test-NoPowerAction)) {
        $msg = if ($script:TimerMode -eq 'clock') {
            $target = Format-ClockDisplay (Get-ClockTargetDateTime)
            "Started - $($script:Action) at $target"
        } else {
            "Started - $($script:Action) at $(Format-EndClock $Sec)"
        }
        $script:tray.ShowBalloonTip(3500, $script:AppName, $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 1000
$script:timer.Add_Tick({
    if (-not $script:Running) { return }
    $script:Left--
    if ($chkWarn5.Checked -and $script:Left -eq 300 -and -not $script:Warn5) {
        $script:Warn5 = $true
        Invoke-CountdownWarning -MarkerSeconds 300
    }
    if ($script:Left -eq 60 -and -not $script:Warn60) {
        $script:Warn60 = $true
        Invoke-CountdownWarning -MarkerSeconds 60
    }
    if ($script:Left -eq 30 -and -not $script:Warn30) {
        $script:Warn30 = $true
        Invoke-CountdownWarning -MarkerSeconds 30
    }
    if ($script:Left -gt 0 -and $script:Left % 30 -eq 0) {
        Publish-LuxGridTick -Remaining $script:Left
    }
    if ($script:Left -le 0) {
        $script:timer.Stop()
        $script:pulse.Stop()
        $script:Running = $false
        Stop-TrayFlash
        Update-TrayProgressIcon
        Start-PunchAnimation { Invoke-AfterTimerEnd }
        return
    }
    Update-Ui
})

$script:trayFlash = New-Object System.Windows.Forms.Timer
$script:trayFlash.Interval = 450
$script:trayFlash.Add_Tick({
    if (-not $script:Running -or $script:Left -gt 30) {
        Stop-TrayFlash
        return
    }
    $script:trayFlashState = -not $script:trayFlashState
    Update-TrayProgressIcon
})

$script:pulse = New-Object System.Windows.Forms.Timer
$script:pulse.Interval = 50
$script:pulse.Add_Tick({
    if ($script:Running -and $script:Left -le 30) {
        $script:Pulse = ($script:Pulse + 0.08) % 1.0
        $pnlRing.Invalidate()
    }
})

$btnStart.Add_Click({
    if ($script:Paused) { Resume-Timer }
    else { Invoke-StartTimer (Get-StartSeconds) }
})
$btnSnooze.Add_Click({ if ($script:Running -and (Test-AllowSnooze 600)) { $script:Left += 600; $script:Warn5 = $false; $script:Warn60 = $false; $script:Warn30 = $false; Write-AuditLog 'snooze' '+600'; Update-Ui } })
$btnSnooze5.Add_Click({ if ($script:Running -and (Test-AllowSnooze 300)) { $script:Left += 300; $script:Warn5 = $false; $script:Warn60 = $false; $script:Warn30 = $false; Write-AuditLog 'snooze' '+300'; Update-Ui } })
$btnStop.Add_Click({
    if ($script:Paused) { Cancel-PausedTimer }
    elseif ($script:Running) { Stop-Timer -Reason 'pause' }
})

$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized' -and $script:Running -and $chkMinTray.Checked) {
        Hide-ToTray -Balloon
    }
})

$form.Add_KeyDown({
    if ($_.Control -and $_.Shift -and $_.KeyCode -eq 'S') {
        Invoke-EmergencyCancel
        $_.Handled = $true
    }
})
$form.KeyPreview = $true

$form.Add_FormClosing({
    param($s, $e)
    if (Test-NoPowerAction) { return }
    if ($script:Running -or $script:Paused) {
        $state = if ($script:Paused) { 'paused' } else { 'running' }
        $r = [System.Windows.Forms.MessageBox]::Show(
            "Timer $state ($([TimeSpan]::FromSeconds($script:Left).ToString('mm\:ss'))).`n`nYes = hide to tray`nNo = stop and exit`nCancel = keep open",
            $script:AppName, 'YesNoCancel', 'Question')
        if ($r -eq 'Yes') { $e.Cancel = $true; Hide-ToTray }
        elseif ($r -eq 'No') {
            Publish-LuxGridCancelled -Reason 'exit'
            $script:Running = $false
            $script:Paused = $false
            $script:timer.Stop()
            $script:pulse.Stop()
            $script:tray.Visible = $false
        }
        else { $e.Cancel = $true }
    } else {
        $script:tray.Visible = $false
    }
})

Set-Action $script:Action
Set-TimerMode $script:TimerMode
$script:UiReady = $false
Update-GracefulCheckbox
Update-SleepLedgerBadge
Update-Ui

$form.Add_Load({
    $script:UiReady = $true
    try {
        $script:globalHotkey = New-Object GlobalHotKey($form.Handle, 9001, 6, 0x53)
        $script:globalHotkey.Add_HotKeyPressed({ Invoke-EmergencyCancel })
    } catch {
        Write-AuditLog 'hotkey_failed' $_.Exception.Message
    }
    if ($Minimized) { $form.WindowState = 'Minimized' }
    else { $form.Activate(); $form.BringToFront() }
    if (-not $NoAutoStart) { Invoke-StartTimer (Get-StartSeconds) }
    if ($Minimized -and $script:Running) { Hide-ToTray }
})

$form.Add_FormClosed({
    if ($script:globalHotkey) { $script:globalHotkey.Dispose() }
    if ($script:trayLiveIcon) { $script:trayLiveIcon.Dispose() }
    if ($script:trayIconStatic) { $script:trayIconStatic.Dispose() }
})

[void]$form.ShowDialog()
$script:tray.Visible = $false
$script:tray.Dispose()
if ($mutex) { $mutex.ReleaseMutex() | Out-Null }
