@echo off
:: ============================================================
::  Sleep Timer Pro Launcher
::  Professional Power Management Tool
:: ============================================================
:: Usage:
::   SleepTimer.bat              - Launch GUI normally
::   SleepTimer.bat tray         - Start minimized to tray
::   SleepTimer.bat silent 60    - Silent 60-min timer (default: shutdown)
:: ============================================================

title Sleep Timer Pro
setlocal EnableDelayedExpansion

:: Parse arguments
set "MODE="
set "MINUTES="
set "ACTION="

if /i "%~1"=="tray" set "MODE=-MinimizeToTray"
if /i "%~1"=="silent" (
    set "MODE=-NoGUI -Silent"
    if not "%~2"=="" set "MINUTES=-Minutes %~2"
    if not "%~3"=="" set "ACTION=-Action %~3"
)

:: Launch PowerShell with proper parameters
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& '%~dp0SleepTimer.ps1' %MODE% %MINUTES% %ACTION%"

if errorlevel 1 (
    echo.
    echo  Sleep Timer Pro - Error
    echo  ======================
    echo.
    echo  The application failed to start.
    echo.
    echo  Requirements:
    echo    - Windows 7 or later
    echo    - PowerShell 5.1 or higher
    echo    - .NET Framework 4.5+
    echo.
    pause
)
