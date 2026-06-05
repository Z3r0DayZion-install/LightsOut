#Requires -Version 5.1
<#
.SYNOPSIS
    Sleep Timer Pro - Installation Script
.DESCRIPTION
    Installs Sleep Timer Pro to Program Files, creates shortcuts, and adds to PATH.
.PARAMETER Uninstall
    Remove Sleep Timer Pro from system
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Stop"

# Configuration
$AppName = "Sleep Timer Pro"
$InstallDir = "$env:LOCALAPPDATA\SleepTimerPro"
$ShortcutDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$DesktopShortcut = "$env:USERPROFILE\Desktop\Sleep Timer Pro.lnk"

function Install-SleepTimer {
    Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         SLEEP TIMER PRO - INSTALLER            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Check requirements
    Write-Host "Checking requirements..." -ForegroundColor Yellow
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "ERROR: PowerShell 5.1 or higher required." -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ PowerShell version check passed`n" -ForegroundColor Green

    # Create installation directory
    Write-Host "Creating installation directory..." -ForegroundColor Yellow
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "  ✓ Created: $InstallDir`n" -ForegroundColor Green

    # Copy files
    Write-Host "Copying application files..." -ForegroundColor Yellow
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Copy-Item "$ScriptDir\SleepTimer.ps1" $InstallDir
    Copy-Item "$ScriptDir\SleepTimer.bat" $InstallDir
    Copy-Item "$ScriptDir\SleepTimer-Pro.bat" $InstallDir
    Copy-Item "$ScriptDir\SleepTimer-Silent.ps1" $InstallDir
    Copy-Item "$ScriptDir\README.md" $InstallDir
    Write-Host "  ✓ Copied 5 files`n" -ForegroundColor Green

    # Create Start Menu shortcut
    Write-Host "Creating shortcuts..." -ForegroundColor Yellow
    $WshShell = New-Object -ComObject WScript.Shell
    
    $StartShortcut = $WshShell.CreateShortcut("$ShortcutDir\$AppName.lnk")
    $StartShortcut.TargetPath = "$InstallDir\SleepTimer.bat"
    $StartShortcut.WorkingDirectory = $InstallDir
    $StartShortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,238"
    $StartShortcut.Save()
    
    # Create Desktop shortcut
    $DeskShortcut = $WshShell.CreateShortcut($DesktopShortcut)
    $DeskShortcut.TargetPath = "$InstallDir\SleepTimer.bat"
    $DeskShortcut.WorkingDirectory = $InstallDir
    $DeskShortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,238"
    $DeskShortcut.Save()
    Write-Host "  ✓ Created Start Menu and Desktop shortcuts`n" -ForegroundColor Green

    # Add to PATH (optional)
    $response = Read-Host "Add to PATH for command-line access? (Y/n)"
    if ($response -ne 'n') {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "User")
            Write-Host "  ✓ Added to PATH (restart terminal to use)`n" -ForegroundColor Green
        }
    }

    Write-Host "Installation complete!`n" -ForegroundColor Green
    Write-Host "Launch options:" -ForegroundColor Cyan
    Write-Host "  • Double-click Desktop shortcut"
    Write-Host "  • Start Menu → Sleep Timer Pro"
    Write-Host "  • Run: SleepTimer.bat (from anywhere after PATH update)"
    Write-Host "  • Run: & '$InstallDir\SleepTimer.ps1'`n"
}

function Uninstall-SleepTimer {
    Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║       SLEEP TIMER PRO - UNINSTALLER            ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

    if (-not (Test-Path $InstallDir)) {
        Write-Host "Sleep Timer Pro is not installed.`n" -ForegroundColor Yellow
        return
    }

    Write-Host "Removing installation directory..." -ForegroundColor Yellow
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "  ✓ Removed application files`n" -ForegroundColor Green

    Write-Host "Removing shortcuts..." -ForegroundColor Yellow
    Remove-Item "$ShortcutDir\$AppName.lnk" -ErrorAction SilentlyContinue
    Remove-Item $DesktopShortcut -ErrorAction SilentlyContinue
    Write-Host "  ✓ Removed shortcuts`n" -ForegroundColor Green

    # Remove from PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -like "*$InstallDir*") {
        $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "  ✓ Removed from PATH`n" -ForegroundColor Green
    }

    # Clean up user data
    $response = Read-Host "Remove user data (settings and logs)? (y/N)"
    if ($response -eq 'y') {
        $UserDataDir = "$env:LOCALAPPDATA\SleepTimer"
        if (Test-Path $UserDataDir) {
            Remove-Item $UserDataDir -Recurse -Force
            Write-Host "  ✓ Removed user data`n" -ForegroundColor Green
        }
    }

    Write-Host "Uninstallation complete.`n" -ForegroundColor Green
}

# Main
if ($Uninstall) {
    Uninstall-SleepTimer
}
else {
    Install-SleepTimer
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
