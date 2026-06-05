@echo off
:: Sleep Timer Pro - System Tray Quick Launch
:: This launcher starts the timer minimized to the system tray

title Sleep Timer Pro
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& '%~dp0SleepTimer.ps1' -MinimizeToTray"
