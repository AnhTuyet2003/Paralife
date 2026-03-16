@echo off
REM ============================================
REM Refmind Google Docs Add-on - Quick Start
REM Double-click file này để start backend + tunnel
REM ============================================

title Refmind Backend + LocalTunnel

echo.
echo ========================================
echo   Refmind - Starting Services...
echo ========================================
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if LocalTunnel is installed
where lt >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] LocalTunnel chua duoc cai dat!
    echo.
    echo Dang cai dat LocalTunnel...
    call npm install -g localtunnel
    echo.
)

REM Run PowerShell script
powershell -ExecutionPolicy Bypass -NoExit -File "%~dp0start-dev-server.ps1"

pause
