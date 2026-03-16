# ============================================
# Script: Start Backend + LocalTunnel (ASCII-safe)
# ============================================

$ErrorActionPreference = 'Stop'

Write-Host "Starting Refmind backend + LocalTunnel..." -ForegroundColor Cyan
Write-Host ""

# Check LocalTunnel installation
$ltInstalled = Get-Command lt -ErrorAction SilentlyContinue
if (-not $ltInstalled) {
    Write-Host "LocalTunnel is not installed. Installing..." -ForegroundColor Yellow
    npm install -g localtunnel
    Write-Host "LocalTunnel installed." -ForegroundColor Green
    Write-Host ""
}

# Backend path
$backendPath = Join-Path $PSScriptRoot "..\backend_api"
Set-Location $backendPath

# Stop old process on port 3000 (if any)
$port = 3000
$process = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique

if ($process) {
    Write-Host "Stopping old process on port $port..." -ForegroundColor Yellow
    Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start backend in background job
Write-Host "Starting backend server..." -ForegroundColor Cyan
$backendJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    npm run dev
} -ArgumentList $backendPath

# Wait backend startup
Write-Host "Waiting for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Verify backend health
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "Backend is running." -ForegroundColor Green
} catch {
    Write-Host "Backend failed to start. Logs:" -ForegroundColor Red
    Receive-Job -Job $backendJob
    Remove-Job -Job $backendJob -Force
    exit 1
}

Write-Host ""
Write-Host "Creating LocalTunnel..." -ForegroundColor Cyan
Write-Host "Public URL: https://refmind-api.loca.lt" -ForegroundColor Yellow
Write-Host "If first time today, open URL and click Continue." -ForegroundColor Yellow
Write-Host "Keep this window open." -ForegroundColor Yellow
Write-Host ""

# LocalTunnel auto-restart loop
$restartCount = 0
$maxRestarts = 10

while ($restartCount -lt $maxRestarts) {
    Write-Host "Starting LocalTunnel (attempt $($restartCount + 1))..." -ForegroundColor Cyan

    try {
        lt --port 3000 --subdomain refmind-api
    } catch {
        Write-Host "LocalTunnel stopped: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $restartCount++
    if ($restartCount -lt $maxRestarts) {
        Write-Host "Restarting in 5 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

# Cleanup
Write-Host ""
Write-Host "Stopping services..." -ForegroundColor Yellow
Stop-Job -Job $backendJob -ErrorAction SilentlyContinue
Remove-Job -Job $backendJob -Force -ErrorAction SilentlyContinue
Write-Host "Stopped." -ForegroundColor Green
