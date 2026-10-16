@echo off
rem Double-click to start a fresh QUOTA run. "play.cmd -Continue" loads the latest save.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\play.ps1" -Pause %*
