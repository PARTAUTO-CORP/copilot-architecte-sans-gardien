@echo off
rem Double-click, or run by an AI with -NoPrompt. Works before PowerShell 7 is installed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
set RESULT=%ERRORLEVEL%
if "%~1"=="" pause
exit /b %RESULT%
