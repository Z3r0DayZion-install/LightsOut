#Requires -Version 5.1
<#
.SYNOPSIS
    Silent Sleep Timer - One-liner replacement for the original
.DESCRIPTION
    Minimal sleep timer for automated/scheduling use.
    Usage: .\SleepTimer-Silent.ps1 -Minutes 30
#>
param(
    [Parameter(Mandatory=$true)]
    [int]$Minutes,
    [ValidateSet("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff")]
    [string]$Action = "Shutdown"
)

$seconds = $Minutes * 60
$actionCmd = switch ($Action) {
    "Shutdown"  { { Stop-Computer -Force } }
    "Restart"   { { Restart-Computer -Force } }
    "Sleep"     { { rundll32.exe powrprof.dll,SetSuspendState 0,1,0 } }
    "Hibernate" { { rundll32.exe powrprof.dll,SetSuspendState 1,1,0 } }
    "Lock"      { { rundll32.exe user32.dll,LockWorkStation } }
    "Logoff"    { { logoff } }
}

Start-Sleep -Seconds $seconds
Invoke-Command -ScriptBlock $actionCmd
