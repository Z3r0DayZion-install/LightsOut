@echo off
title Pro Timer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CoolTimer.ps1" %*
