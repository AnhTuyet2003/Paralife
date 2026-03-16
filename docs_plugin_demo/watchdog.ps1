# ============================================
# Watchdog Script - Auto Restart Backend + Tunnel
# Tự động restart khi backend hoặc tunnel bị dừng
# ============================================

Write-Host "🔍 Watchdog Starting..." -ForegroundColor Cyan
Write-Host "Monitoring backend + LocalTunnel và auto-restart khi cần" -ForegroundColor Gray
Write-Host ""

$backendPath = Join-Path $PSScriptRoot "..\backend_api"
$checkInterval = 30  # Check every 30 seconds

while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] Checking..." -ForegroundColor Gray
    
    # Check Backend
    $backendRunning = $false
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        $backendRunning = $true
        Write-Host "  ✅ Backend OK" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Backend DOWN - Restarting..." -ForegroundColor Red
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$backendPath'; npm run dev" -WindowStyle Minimized
        Start-Sleep -Seconds 10
    }
    
    # Check LocalTunnel
    $tunnelProcess = Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { 
        $_.CommandLine -like "*localtunnel*" -or $_.CommandLine -like "*lt*3000*" 
    }
    
    if ($tunnelProcess) {
        Write-Host "  ✅ Tunnel OK (PID: $($tunnelProcess.Id))" -ForegroundColor Green
        
        # Test tunnel connectivity
        try {
            $tunnelResponse = Invoke-WebRequest -Uri "https://refmind-api.loca.lt" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Write-Host "  ✅ Tunnel reachable" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Tunnel unreachable (may need unlock)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Tunnel DOWN - Restarting..." -ForegroundColor Red
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '🌐 LocalTunnel Auto-Restart' -ForegroundColor Cyan; lt --port 3000 --subdomain refmind-api" -WindowStyle Normal
        Start-Sleep -Seconds 10
    }
    
    Write-Host ""
    Start-Sleep -Seconds $checkInterval
}
