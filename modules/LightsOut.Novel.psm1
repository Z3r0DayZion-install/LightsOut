#Requires -Version 5.1
<#
.SYNOPSIS
    Novel Lights Out features: Sleep Ledger, Bedtime Pact, Household Harmony.
#>

function Get-SleepLedgerStats {
    param(
        [string]$AuditLogPath,
        [int]$LookbackDays = 60
    )
    $stats = [ordered]@{
        Streak       = 0
        BestStreak   = 0
        NightsDone   = 0
        Snoozes      = 0
        Cancels      = 0
        LastDone     = $null
        LastDoneLabel = 'never'
        WeekDots     = @()
    }
    if (-not (Test-Path $AuditLogPath)) { return [pscustomobject]$stats }

    $doneDays = [System.Collections.Generic.HashSet[string]]::new()
    $snooze = 0
    $cancel = 0
    $lastDone = $null

    foreach ($line in Get-Content $AuditLogPath -ErrorAction SilentlyContinue) {
        if ($line -notmatch '^(\S+)\s+(\S+)') { continue }
        $ts = $Matches[1]
        $ev = $Matches[2]
        try { $dt = [DateTime]::Parse($ts) } catch { continue }
        $day = $dt.ToString('yyyy-MM-dd')
        switch -Regex ($ev) {
            '^power_action' { [void]$doneDays.Add($day); if (-not $lastDone -or $dt -gt $lastDone) { $lastDone = $dt } }
            '^snooze' { $snooze++ }
            '^(emergency_cancel|final_cancelled|timer_cancelled)' { $cancel++ }
        }
    }

    $stats.NightsDone = $doneDays.Count
    $stats.Snoozes = $snooze
    $stats.Cancels = $cancel
    if ($lastDone) {
        $stats.LastDone = $lastDone
        $stats.LastDoneLabel = $lastDone.ToString('ddd MMM d')
    }

    $cursor = (Get-Date).Date
    $streak = 0
    while ($true) {
        $key = $cursor.ToString('yyyy-MM-dd')
        if ($doneDays.Contains($key)) { $streak++ } else { break }
        $cursor = $cursor.AddDays(-1)
        if ($streak -gt $LookbackDays) { break }
    }
    $stats.Streak = $streak

    $best = 0
    $run = 0
    $prev = $null
    foreach ($d in ($doneDays | Sort-Object)) {
        $cur = [DateTime]::ParseExact($d, 'yyyy-MM-dd', $null)
        if ($prev -and ($cur - $prev).Days -eq 1) { $run++ } else { $run = 1 }
        if ($run -gt $best) { $best = $run }
        $prev = $cur
    }
    $stats.BestStreak = [math]::Max($best, $streak)

    for ($i = 6; $i -ge 0; $i--) {
        $day = (Get-Date).Date.AddDays(-$i).ToString('yyyy-MM-dd')
        $stats.WeekDots += [pscustomobject]@{
            Day   = $day
            Label = (Get-Date).Date.AddDays(-$i).ToString('ddd')
            Done  = $doneDays.Contains($day)
        }
    }
    return [pscustomobject]$stats
}

function Get-PactDeadline {
    param([string]$PactTimeHm)
    $hm = if ($PactTimeHm) { $PactTimeHm } else { '23:00' }
    $parts = $hm.Split(':')
    $h = [int]$parts[0]
    $m = [int]$parts[1]
    $now = Get-Date
    $deadline = Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour $h -Minute $m -Second 0
    if ($deadline -le $now) { $deadline = $deadline.AddDays(1) }
    return $deadline
}

function Test-SnoozeCrossesPact {
    param(
        [int]$SecondsToAdd,
        [int]$RemainingSeconds,
        [string]$PactTimeHm
    )
    if (-not $PactTimeHm) { return $false }
    $deadline = Get-PactDeadline $PactTimeHm
    $endAt = (Get-Date).AddSeconds($RemainingSeconds + $SecondsToAdd)
    return ($endAt -gt $deadline)
}

function New-HouseholdSyncPayload {
    param(
        [string]$Action,
        [DateTime]$TargetWhen,
        [string]$MachineName = $env:COMPUTERNAME
    )
    $code = -join ((48..57) + (65..90) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    return [ordered]@{
        version    = 1
        code       = $code
        machine    = $MachineName
        action     = $Action
        targetIso  = $TargetWhen.ToString('o')
        exportedAt = (Get-Date).ToString('o')
    }
}

function Import-HouseholdSyncPayload {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Not found: $Path" }
    $j = Get-Content $Path -Raw | ConvertFrom-Json
    if (-not $j.targetIso) { throw 'Invalid household sync file' }
    $target = [DateTime]::Parse([string]$j.targetIso)
    return [pscustomobject]@{
        Code      = [string]$j.code
        Machine   = [string]$j.machine
        Action    = [string]$j.action
        Target    = $target
        ExportedAt = if ($j.exportedAt) { [DateTime]::Parse([string]$j.exportedAt) } else { Get-Date }
    }
}

function Test-HouseholdPlansAlign {
    param(
        [DateTime]$LocalTarget,
        [DateTime]$PartnerTarget,
        [int]$WindowMinutes = 15
    )
    $delta = [math]::Abs(($LocalTarget - $PartnerTarget).TotalMinutes)
    return ($delta -le $WindowMinutes)
}

Export-ModuleMember -Function @(
    'Get-SleepLedgerStats'
    'Get-PactDeadline'
    'Test-SnoozeCrossesPact'
    'New-HouseholdSyncPayload'
    'Import-HouseholdSyncPayload'
    'Test-HouseholdPlansAlign'
)
