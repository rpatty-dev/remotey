@echo off
title Remotey Server (Port 7777)

:: Self-elevate to Administrator to open firewall and enable input simulation
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/k `\"%~f0`\"' -Verb RunAs"
    exit /b
)

cls
echo ========================================================
echo   Remotey Server (Administrator)
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/2] Opening Port 7777 in Windows Firewall...
netsh advfirewall firewall delete rule name="Remotey" >nul 2>&1
netsh advfirewall firewall add rule name="Remotey" dir=in action=allow protocol=TCP localport=7777 profile=any
echo.

if not exist "remotey_server.ps1" (
    echo [ERROR] remotey_server.ps1 not found in %cd%!
    echo Please make sure both START.bat and remotey_server.ps1 are in the same folder.
    echo.
    pause
    exit /b 1
)

echo [2/2] Starting Remotey Server...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remotey_server.ps1"

echo.
echo Server terminated.
pause
