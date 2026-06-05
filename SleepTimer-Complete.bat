@echo off
:: ============================================================
::  Sleep Timer Pro - Complete Suite Launcher
::  Launches main app with all RGB modules available
:: ============================================================

title Sleep Timer Pro - Complete Suite
setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo.
echo  ==========================================
echo  🎨 Sleep Timer Pro - Complete Suite
echo  ==========================================
echo.

:: Check for PowerShell
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo  ❌ PowerShell not found!
    echo  Please install PowerShell 5.1 or higher
    pause
    exit 1
)

:: Check for RGB modules
echo  Checking RGB modules...
set "RGB_MODULES=0"
if exist "RGB-Countdown.ps1" (
    echo    ✓ RGB Countdown
    set /a RGB_MODULES+=1
)
if exist "RGB-ThermalMonitor.ps1" (
    echo    ✓ RGB Thermal Monitor
    set /a RGB_MODULES+=1
)
if exist "RGB-CustomZones.ps1" (
    echo    ✓ RGB Custom Zones
    set /a RGB_MODULES+=1
)
if exist "RGB-Studio.ps1" (
    echo    ✓ RGB Studio
    set /a RGB_MODULES+=1
)

if %RGB_MODULES% gtr 0 (
    echo    %RGB_MODULES% RGB modules found
) else (
    echo    ⚠ No RGB modules (timer only)
)

echo.
echo  ==========================================
echo  Launch options:
echo  ==========================================
echo.
echo   [1] 🕐 Launch Sleep Timer Pro (GUI)
echo   [2] 🎨 Launch RGB Studio (Designer)
echo   [3] 🌡 Quick Thermal Monitor (Console)
echo   [4] 🔧 Advanced Options
echo   [5] ❌ Exit
echo.

set /p choice="Select option (1-5): "

if "%choice%"=="1" goto LAUNCH_GUI
if "%choice%"=="2" goto LAUNCH_STUDIO
if "%choice%"=="3" goto LAUNCH_THERMAL
if "%choice%"=="4" goto ADVANCED
if "%choice%"=="5" goto EXIT
goto EXIT

:LAUNCH_GUI
cls
echo Launching Sleep Timer Pro...
echo.
powershell -ExecutionPolicy Bypass -File "SleepTimer.ps1"
goto END

:LAUNCH_STUDIO
if not exist "RGB-Studio.ps1" (
    echo ❌ RGB-Studio.ps1 not found!
    pause
    goto END
)
cls
echo Launching RGB Studio...
echo.
start powershell -ExecutionPolicy Bypass -File "RGB-Studio.ps1"
goto END

:LAUNCH_THERMAL
if not exist "RGB-ThermalMonitor.ps1" (
    echo ❌ RGB-ThermalMonitor.ps1 not found!
    pause
    goto END
)
cls
echo Launching Thermal Monitor...
echo Press Ctrl+C to stop monitoring
echo.
powershell -ExecutionPolicy Bypass -Command "& 'RGB-ThermalMonitor.ps1'; Start-ThermalMonitor -UpdateIntervalSeconds 2"
goto END

:ADVANCED
cls
echo.
echo  🔧 Advanced Options
echo  ==========================================
echo.
echo   [a] 📊 List available profiles
echo   [b] 🔧 Edit custom RGB zones
echo   [c] 🧪 Test RGB countdown (10 sec demo)
echo   [d] 📁 Open data folder
echo   [e] ⬅ Back to main menu
echo.
set /p adv="Select option: "

if "%adv%"=="a" goto LIST_PROFILES
if "%adv%"=="b" goto EDIT_ZONES
if "%adv%"=="c" goto TEST_RGB
if "%adv%"=="d" goto OPEN_FOLDER
if "%adv%"=="e" goto MAIN
goto END

:LIST_PROFILES
powershell -ExecutionPolicy Bypass -Command "& 'SleepTimer.ps1' -ListProfiles"
pause
goto ADVANCED

:EDIT_ZONES
if not exist "RGB-CustomZones.ps1" (
    echo ❌ RGB-CustomZones.ps1 not found!
    pause
    goto ADVANCED
)
start powershell -ExecutionPolicy Bypass -Command "& 'RGB-CustomZones.ps1'; Edit-CustomZones"
goto ADVANCED

:TEST_RGB
if not exist "RGB-Countdown.ps1" (
    echo ❌ RGB-Countdown.ps1 not found!
    pause
    goto ADVANCED
)
echo Running 10-second RGB countdown demo...
powershell -ExecutionPolicy Bypass -Command "& 'RGB-Countdown.ps1'; Show-RGBCountdownDemo"
pause
goto ADVANCED

:OPEN_FOLDER
start explorer "%LOCALAPPDATA%\SleepTimer"
goto ADVANCED

:MAIN
goto MAIN_MENU

:END
echo.
echo  ==========================================
echo  Session ended. Press any key to exit.
echo  ==========================================
pause >nul

:EXIT
exit /b
