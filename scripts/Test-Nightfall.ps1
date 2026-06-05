#Requires -Version 5.1
# Legacy entry — forwards to Test-SleepTimer.ps1
& (Join-Path $PSScriptRoot 'Test-SleepTimer.ps1') @args
exit $LASTEXITCODE
