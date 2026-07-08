# =============================================================
#  Mine Sarthi - One-Command Startup Script
#  Starts the entire stack: Docker infra + backend + bridge
#  + IoT publisher + React frontend
#
#  Usage:   Right-click > Run with PowerShell
#      or:  ./start-all.ps1
#      or:  ./start-all.ps1 -Setup   (first run: installs deps)
# =============================================================

param(
    [switch]$Setup  # Pass -Setup on first run to install dependencies
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Pipeline = Join-Path $Root "data pipeline"
$Frontend = Join-Path $Root "smart-ore-flow-main\smart-ore-flow-main"
$Venv = Join-Path $Pipeline ".venv"
$VenvPy = Join-Path $Venv "Scripts\python.exe"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# -------------------------------------------------------------
# 0. Optional one-time setup (dependencies)
# -------------------------------------------------------------
if ($Setup -or -not (Test-Path $VenvPy)) {
    Write-Step "Setting up Python virtual environment"
    if (-not (Test-Path $VenvPy)) {
        python -m venv $Venv
    }
    & $VenvPy -m pip install --upgrade pip
    & $VenvPy -m pip install -r (Join-Path $Pipeline "requirements.txt")

    Write-Step "Installing frontend dependencies"
    Push-Location $Frontend
    npm install --legacy-peer-deps
    Pop-Location
}

# -------------------------------------------------------------
# 1. Docker infrastructure (Mosquitto, InfluxDB, PostgreSQL, ML)
# -------------------------------------------------------------
Write-Step "Starting Docker infrastructure"
Push-Location $Pipeline
docker compose up -d --build
Pop-Location

Write-Host "Waiting for backend databases to become ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# -------------------------------------------------------------
# 2-5. Launch each service in its own titled PowerShell window
# -------------------------------------------------------------
function Start-Service-Window($title, $workDir, $command) {
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "`$host.UI.RawUI.WindowTitle = '$title'; Set-Location '$workDir'; $command"
    )
}

Write-Step "Starting FastAPI backend (:8000)"
Start-Service-Window "Mine Sarthi - Backend" (Join-Path $Pipeline "backend") `
    "& '$VenvPy' -m uvicorn fastapi_app:app --host 0.0.0.0 --port 8000"
Start-Sleep -Seconds 6

Write-Step "Starting MQTT bridge"
Start-Service-Window "Mine Sarthi - Bridge" (Join-Path $Pipeline "bridge") `
    "& '$VenvPy' consumer.py"
Start-Sleep -Seconds 3

Write-Step "Starting IoT publisher (crusher_01)"
Start-Service-Window "Mine Sarthi - Publisher" (Join-Path $Pipeline "gateway") `
    "& '$VenvPy' publisher_mqtt.py --device crusher_01"
Start-Sleep -Seconds 2

Write-Step "Starting React frontend (:8080)"
Start-Service-Window "Mine Sarthi - Frontend" $Frontend `
    "npm run dev"

# -------------------------------------------------------------
# Done
# -------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  Mine Sarthi is starting up!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Dashboard : http://localhost:8080" -ForegroundColor White
Write-Host "  Backend   : http://localhost:8000/health" -ForegroundColor White
Write-Host "  ML Service: http://localhost:8001/health" -ForegroundColor White
Write-Host "  Login     : admin@mine.com / password123" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  4 service windows opened (backend, bridge, publisher, frontend)." -ForegroundColor Gray
Write-Host "  To stop everything, run:  ./stop-all.ps1" -ForegroundColor Gray
Write-Host ""
