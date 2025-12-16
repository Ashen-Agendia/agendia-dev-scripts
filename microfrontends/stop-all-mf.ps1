# Script PowerShell para detener todos los microfrontends en Windows

Write-Host "🛑 Deteniendo todos los microfrontends..." -ForegroundColor Yellow
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".mf-pids"
$STOPPED = 0
$NOT_FOUND = 0

if (-not (Test-Path $PIDS_FILE)) {
  Write-Host "⚠️  No se encontró archivo de PIDs (.mf-pids)" -ForegroundColor Yellow
  Write-Host "   Intentando detener procesos de Vite/Node manualmente..." -ForegroundColor Yellow
  Write-Host ""
  
  # Intentar detener procesos de Node/Vite relacionados con los MFs
  $ports = @(3000, 3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008, 3009, 3010)
  
  foreach ($port in $ports) {
    $processes = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    
    foreach ($processId in $processes) {
      $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
      if ($proc -and ($proc.ProcessName -eq "node")) {
        Write-Host "   Deteniendo proceso en puerto $port (PID: $processId)..." -ForegroundColor Yellow
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        if ($?) {
          $STOPPED++
        }
      }
    }
  }
  
  if ($STOPPED -eq 0) {
    Write-Host "   ℹ️  No se encontraron procesos corriendo en los puertos comunes" -ForegroundColor Gray
  }
} else {
  Write-Host "📋 Leyendo PIDs desde $PIDS_FILE..." -ForegroundColor Cyan
  
  $pids = Get-Content $PIDS_FILE
  
  foreach ($line in $pids) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    
    $parts = $line.Split(':')
    if ($parts.Length -lt 2) {
      continue
    }
    
    $processId = $parts[0]
    $dir = $parts[1]
    
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
  
  # Limpiar archivo de PIDs
  Remove-Item $PIDS_FILE
}

# Intentar detener cualquier proceso de Node/Vite restante relacionado con MFs
Write-Host ""
Write-Host "🔍 Buscando procesos restantes de Node/Vite..." -ForegroundColor Cyan

$nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
  $_.CommandLine -like "*vite*" -or $_.CommandLine -like "*npm*dev*"
}

foreach ($proc in $nodeProcesses) {
  Write-Host "   Deteniendo proceso Node (PID: $($proc.Id))..." -ForegroundColor Yellow
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  if ($?) {
    $STOPPED++
  }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   🛑 Detenidos: $STOPPED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
  Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Gray
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STOPPED -gt 0) {
  Write-Host "✅ Todos los microfrontends han sido detenidos" -ForegroundColor Green
} else {
  Write-Host "ℹ️  No se encontraron procesos para detener" -ForegroundColor Gray
}

