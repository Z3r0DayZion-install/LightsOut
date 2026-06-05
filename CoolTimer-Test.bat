@echo off
title Nightfall TEST
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CoolTimer.ps1" -Seconds 15 -NoSave -NoAutoStart
