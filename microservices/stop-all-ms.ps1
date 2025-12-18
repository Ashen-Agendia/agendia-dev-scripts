# Script PowerShell para detener todos los microservicios en Windows

Write-Host "🛑 Deteniendo todos los microservicios..." -ForegroundColor Yellow
Write-Host "" 

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$PIDS_FILE   = Join-Path $SCRIPTS_ROOT ".ms-pids"

$STOPPED   = 0
$NOT_FOUND = 0

if (-not (Test-Path $PIDS_FILE)) {
  Write-Host "⚠️  No se encontró archivo de PIDs (.ms-pids)" -ForegroundColor Yellow
  Write-Host "   No hay microservicios registrados por start-all-ms.ps1 para detener." -ForegroundColor Gray
  exit 0
}

Write-Host "📋 Leyendo PIDs desde $PIDS_FILE..." -ForegroundColor Cyan
Write-Host "" 

$pids = Get-Content $PIDS_FILE

foreach ($line in $pids) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }

  $parts = $line.Split(':')
  if ($parts.Length -lt 2) { continue }

  $processId = $parts[0]
  $dir       = $parts[1]

  try {
    $process = Get-Process -Id $processId -ErrorAction Stop
    Write-Host "   🛑 Deteniendo $dir (PID: $processId)..." -ForegroundColor Yellow
    Stop-Process -Id $processId -Force
    Write-Host "      ✅ $dir detenido" -ForegroundColor Green
    $STOPPED++
  } catch {
    Write-Host "   ⚠️  $dir (PID: $processId) ya no está corriendo" -ForegroundColor Gray
    $NOT_FOUND++
  }
}

Remove-Item $PIDS_FILE -Force

Write-Host "" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   🛑 Detenidos: $STOPPED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
  Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Yellow
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STOPPED -gt 0) {
  Write-Host "✅ Todos los microservicios han sido detenidos (según .ms-pids)" -ForegroundColor Green
} else {
  Write-Host "ℹ️  No se encontraron procesos para detener" -ForegroundColor Gray
}
