# =============================================================
#  Mine Sarthi - One-Command Stop Script
#  Stops Docker infra and all local service processes.
#
#  Usage:   ./stop-all.ps1
# =============================================================

$Root = $PSScriptRoot
$Pipeline = Join-Path $Root "data pipeline"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# -------------------------------------------------------------
# 1. Stop Docker infrastructure
# -------------------------------------------------------------
Write-Step "Stopping Docker infrastructure"
Push-Location $Pipeline
docker compose down
Pop-Location

# -------------------------------------------------------------
# 2. Stop local Python + Node service processes
# -------------------------------------------------------------
Write-Step "Stopping local service processes"
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -match 'uvicorn fastapi_app|consumer\.py|publisher_mqtt\.py|vite|npm run dev'
} | ForEach-Object {
    Write-Host "  Stopping PID $($_.ProcessId) ($($_.Name))" -ForegroundColor Yellow
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# 3. Free any lingering service windows opened by start-all
# -------------------------------------------------------------
Get-Process | Where-Object { $_.MainWindowTitle -like 'Mine Sarthi - *' } |
    ForEach-Object {
        Write-Host "  Closing window: $($_.MainWindowTitle)" -ForegroundColor Yellow
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  Mine Sarthi stopped. All services shut down." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
