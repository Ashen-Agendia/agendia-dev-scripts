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
  Write-Host "   Intentando detener procesos de Java/sbt manualmente..." -ForegroundColor Yellow
  Write-Host ""
  
  # Intentar detener procesos de Java/sbt relacionados con los MS
  $ports = @(4001, 8080, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090)
  
  foreach ($port in $ports) {
    $processes = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    
    foreach ($processId in $processes) {
      $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
      if ($proc -and ($proc.ProcessName -eq "java")) {
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
}

# Intentar detener cualquier proceso de Java/sbt restante relacionado con MS
Write-Host ""
Write-Host "🔍 Buscando procesos restantes de Java/sbt..." -ForegroundColor Cyan

# Lista de nombres de microservicios para buscar en la línea de comandos
$msNames = @("agendia-template-ms", "agendia-ms-agenda", "agendia-ms-clients", "agendia-ms-notifications", "agendia-ms-organization", "agendia-ms-platform", "agendia-ms-sales")

try {
  # Usar WMI para obtener procesos Java con su command line (compatible con PowerShell 5+)
  $javaProcesses = Get-WmiObject Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $cmdLine = $_.CommandLine
    if (-not $cmdLine) { return $false }
    # Buscar procesos relacionados con sbt o con nombres de microservicios
    $isSbt = $cmdLine -like "*sbt*"
    $isMs = ($msNames | Where-Object { $cmdLine -like "*$_*" }) -ne $null
    return ($isSbt -or $isMs)
  }
  
  foreach ($proc in $javaProcesses) {
    Write-Host "   Deteniendo proceso Java (PID: $($proc.ProcessId))..." -ForegroundColor Yellow
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    if ($?) {
      $STOPPED++
    }
  }
} catch {
  # Si WMI falla, intentar método alternativo más simple
  $javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
  foreach ($proc in $javaProcesses) {
    try {
      $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
      if ($cmdLine) {
        $isSbt = $cmdLine -like "*sbt*"
        $isMs = ($msNames | Where-Object { $cmdLine -like "*$_*" }) -ne $null
        if ($isSbt -or $isMs) {
          Write-Host "   Deteniendo proceso Java (PID: $($proc.Id))..." -ForegroundColor Yellow
          Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
          if ($?) {
            $STOPPED++
          }
        }
      }
    } catch {
      # Ignorar errores al obtener command line
    }
  }
}

Write-Host "" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   🛑 Detenidos: $STOPPED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
  Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Yellow
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STOPPED -gt 0) {
  Write-Host "✅ Todos los microservicios han sido detenidos" -ForegroundColor Green
} else {
  Write-Host "ℹ️  No se encontraron procesos para detener" -ForegroundColor Gray
}
