Write-Host "🔄 Reiniciando DevOps Dashboard..." -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "🛑 Deteniendo servicios..." -ForegroundColor Yellow
& "$SCRIPT_DIR\stop-devops.ps1"

Write-Host ""
Write-Host "⏳ Esperando 2 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "🚀 Iniciando servicios..." -ForegroundColor Cyan
& "$SCRIPT_DIR\start-devops.ps1"

