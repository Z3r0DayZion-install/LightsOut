#Requires -Version 5.1
<#
.SYNOPSIS
    Modular Sleep Timer System Launcher
.DESCRIPTION
    Unified launcher for the modular timer + RGB system
#>

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

function Show-Menu {
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║     🧩 Modular Sleep Timer System                        ║" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║   Two independent apps that work together:               ║" -ForegroundColor Gray
    Write-Host "║                                                          ║" -ForegroundColor Gray
    Write-Host "║   🕐 SleepTimer-Core    → Timer engine                   ║" -ForegroundColor White
    Write-Host "║   🎨 RGB-Controller     → RGB display                    ║" -ForegroundColor White
    Write-Host "║                                                          ║" -ForegroundColor Gray
    Write-Host "║   They communicate via event files in %TEMP%             ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [1] 🕐 Timer Only (Console)                             ║" -ForegroundColor Green
    Write-Host "║      Just the countdown, no RGB                          ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [2] 🎨 RGB Only (Standalone)                            ║" -ForegroundColor Magenta
    Write-Host "║      Show thermal temps on keyboard only                 ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [3] 🧩 BOTH (Timer + RGB) ⭐ Recommended                ║" -ForegroundColor Yellow
    Write-Host "║      Timer events control RGB colors                     ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [4] 🧪 Test Mode                                        ║" -ForegroundColor Blue
    Write-Host "║      30-second demo with all events                      ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [5] 📦 Module Mode                                      ║" -ForegroundColor Cyan
    Write-Host "║      Load as PowerShell modules                          ║" -ForegroundColor DarkGray
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║  [Q] ❌ Quit                                             ║" -ForegroundColor Red
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Start-TimerOnly {
    Clear-Host
    Write-Host "`n🕐 Timer Only Mode" -ForegroundColor Green
    Write-Host "═══════════════════" -ForegroundColor Green
    
    $minutes = Read-Host "Enter duration (minutes)"
    $action = Read-Host "Action (Shutdown/Restart/Sleep/Hibernate/Lock/Logoff)"
    
    $corePath = Join-Path $PSScriptRoot "SleepTimer-Core.ps1"
    if (Test-Path $corePath) {
        & $corePath -Minutes $minutes -Action $action
    }
    else {
        Write-Host "❌ SleepTimer-Core.ps1 not found!" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
}

function Start-RGBOnly {
    Clear-Host
    Write-Host "`n🎨 RGB Only Mode" -ForegroundColor Magenta
    Write-Host "══════════════════" -ForegroundColor Magenta
    
    Write-Host "`nOptions:" -ForegroundColor White
    Write-Host "  [1] Thermal Display (CPU/GPU temps)" -ForegroundColor Gray
    Write-Host "  [2] Demo Mode (rainbow/wave effects)" -ForegroundColor Gray
    Write-Host "  [3] Custom Mode" -ForegroundColor Gray
    
    $mode = Read-Host "`nSelect mode"
    
    $rgbPath = Join-Path $PSScriptRoot "RGB-Controller.ps1"
    if (Test-Path $rgbPath) {
        switch ($mode) {
            "1" { & $rgbPath -Standalone }
            "2" { 
                # Demo mode - standalone with visual effects
                & $rgbPath -Standalone
            }
            "3" {
                # Launch RGB Studio if available
                $studioPath = Join-Path $PSScriptRoot "RGB-Studio.ps1"
                if (Test-Path $studioPath) {
                    Start-Process powershell -ArgumentList "-File `"$studioPath`"" -WindowStyle Normal
                }
                else {
                    & $rgbPath -Standalone
                }
            }
        }
    }
    else {
        Write-Host "❌ RGB-Controller.ps1 not found!" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
}

function Start-Both {
    Clear-Host
    Write-Host "`n🧩 Combined Mode (Timer + RGB)" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════" -ForegroundColor Yellow
    
    $minutes = Read-Host "Enter duration (minutes)"
    $action = Read-Host "Action (Shutdown/Restart/Sleep/Hibernate/Lock/Logoff)"
    
    $corePath = Join-Path $PSScriptRoot "SleepTimer-Core.ps1"
    $rgbPath = Join-Path $PSScriptRoot "RGB-Controller.ps1"
    
    if (-not (Test-Path $corePath)) {
        Write-Host "❌ SleepTimer-Core.ps1 not found!" -ForegroundColor Red
        Read-Host "Press Enter to return"
        return
    }
    
    if (-not (Test-Path $rgbPath)) {
        Write-Host "⚠ RGB-Controller.ps1 not found, running timer only" -ForegroundColor Yellow
        & $corePath -Minutes $minutes -Action $action
        Read-Host "Press Enter to return"
        return
    }
    
    Write-Host "`nStarting Timer + RGB..." -ForegroundColor Green
    Write-Host "Timer will run in this window" -ForegroundColor Gray
    Write-Host "RGB will update automatically`n" -ForegroundColor Gray
    
    # Create a synchronized event for RGB to watch
    $eventPath = Join-Path $env:TEMP "SleepTimer\Events"
    if (-not (Test-Path $eventPath)) {
        New-Item -ItemType Directory -Path $eventPath -Force | Out-Null
    }
    
    # Start RGB in background job
    $rgbJob = Start-Job -ScriptBlock {
        param($Path, $RgbScript)
        & $RgbScript -SubscribeToTimer
    } -ArgumentList $eventPath, $rgbPath
    
    # Give RGB a moment to connect
    Start-Sleep -Seconds 2
    
    # Start timer (this blocks until complete)
    & $corePath -Minutes $minutes -Action $action -EventMode
    
    # Cleanup
    Write-Host "`nCleaning up RGB job..." -ForegroundColor Gray
    Stop-Job $rgbJob -ErrorAction SilentlyContinue
    Remove-Job $rgbJob -ErrorAction SilentlyContinue
    
    Read-Host "`nPress Enter to return to menu"
}

function Start-TestMode {
    Clear-Host
    Write-Host "`n🧪 Test Mode - 30 Second Demo" -ForegroundColor Blue
    Write-Host "══════════════════════════════" -ForegroundColor Blue
    
    $corePath = Join-Path $PSScriptRoot "SleepTimer-Core.ps1"
    $rgbPath = Join-Path $PSScriptRoot "RGB-Controller.ps1"
    
    Write-Host "`nThis will:" -ForegroundColor White
    Write-Host "  1. Start a 30-second timer" -ForegroundColor Gray
    Write-Host "  2. Start RGB controller watching events" -ForegroundColor Gray
    Write-Host "  3. Show timer progress on your keyboard!" -ForegroundColor Gray
    Write-Host "`nMake sure OpenRGB is running with SDK Server started!" -ForegroundColor Yellow
    
    Read-Host "`nPress Enter to start test..."
    
    if ((Test-Path $corePath) -and (Test-Path $rgbPath)) {
        Start-BothInternal -Minutes 0.5 -Action "Shutdown" -Silent
    }
    else {
        Write-Host "❌ Required files not found!" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
}

function Start-BothInternal {
    param([double]$Minutes, [string]$Action, [switch]$Silent)
    
    $corePath = Join-Path $PSScriptRoot "SleepTimer-Core.ps1"
    $rgbPath = Join-Path $PSScriptRoot "RGB-Controller.ps1"
    
    # Start RGB watching
    $rgbJob = Start-Job -ScriptBlock {
        param($RgbScript)
        & $RgbScript -SubscribeToTimer
    } -ArgumentList $rgbPath
    
    Start-Sleep -Seconds 2
    
    # Run timer
    & $corePath -Minutes $Minutes -Action $Action -EventMode
    
    # Cleanup
    Stop-Job $rgbJob -ErrorAction SilentlyContinue
    Remove-Job $rgbJob -ErrorAction SilentlyContinue
}

function Start-ModuleMode {
    Clear-Host
    Write-Host "`n📦 Module Mode" -ForegroundColor Cyan
    Write-Host "═══════════════" -ForegroundColor Cyan
    
    $corePath = Join-Path $PSScriptRoot "SleepTimer-Core.ps1"
    $rgbPath = Join-Path $PSScriptRoot "RGB-Controller.ps1"
    
    Write-Host "`nLoading modules..." -ForegroundColor Gray
    
    if (Test-Path $corePath) {
        Import-Module $corePath -Force
        Write-Host "✓ SleepTimer-Core loaded" -ForegroundColor Green
    }
    
    if (Test-Path $rgbPath) {
        Import-Module $rgbPath -Force
        Write-Host "✓ RGB-Controller loaded" -ForegroundColor Green
    }
    
    Write-Host "`nAvailable functions:" -ForegroundColor White
    Get-Command -Module "SleepTimer-Core" | ForEach-Object { Write-Host "  Timer: $($_.Name)" -ForegroundColor Gray }
    Get-Command -Module "RGB-Controller" | ForEach-Object { Write-Host "  RGB: $($_.Name)" -ForegroundColor Gray }
    
    Write-Host "`nExample usage:" -ForegroundColor Yellow
    Write-Host '  Connect-RGBController' -ForegroundColor Cyan
    Write-Host '  Register-TimerModule -ModuleName "RGB" -OnTick { param($RemainingSeconds) Write-Host $RemainingSeconds }' -ForegroundColor Cyan
    Write-Host '  Start-TimerEngine -DurationSeconds 60 -TimerAction "Shutdown"' -ForegroundColor Cyan
    
    Write-Host "`nModules loaded! Use functions above or type Exit to return." -ForegroundColor Green
    
    # Keep session open
    while ($true) {
        $cmd = Read-Host "`nPS Modular>"
        if ($cmd -eq "Exit" -or $cmd -eq "exit") { break }
        try {
            Invoke-Expression $cmd
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "`nSelect option"
    
    switch ($choice) {
        "1" { Start-TimerOnly }
        "2" { Start-RGBOnly }
        "3" { Start-Both }
        "4" { Start-TestMode }
        "5" { Start-ModuleMode }
        "Q" { break }
        "q" { break }
        default { 
            Write-Host "`nInvalid option!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
    
    Clear-Host
} while ($choice -notin @("Q", "q"))

Write-Host "`n👋 Goodbye!`n" -ForegroundColor Cyan
