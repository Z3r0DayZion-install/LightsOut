$dir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
@{
    DefaultSeconds    = 1700
    Action            = 'Shutdown'
    ConfirmAtEnd      = $true
    AutoStart         = $true
    TopMost           = $true
    WarnAt5Min        = $true
    DryRun            = $false
    EmitLuxGridEvents = $false
    RunAtLogin        = $false
} | ConvertTo-Json | Set-Content (Join-Path $dir 'settings.json') -Encoding UTF8
Write-Host 'Settings fixed: 28:20, shutdown, dry run OFF'
