@echo off
title Cozy Corner - Automated Build, Upload ^& Release
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\publish_latest_build.ps1"
pause
