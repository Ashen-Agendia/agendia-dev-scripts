# Script PowerShell para reiniciar todos los microfrontends que están corriendo

Write-Host "🔄 Reiniciando microfrontends activos..." -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$ROOT_DIR = Split-Path -Parent $SCRIPTS_ROOT
$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".mf-pids"
$LOGS_ROOT = Join-Path $SCRIPTS_ROOT "logs"
$LOGS_DIR = Join-Path $LOGS_ROOT "mf"

$RESTARTED = 0
$NOT_FOUND = 0
$FAILED = 0

# Localizar npm (compatible con PowerShell 5+)
$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) {
  $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
}
$npmPath = $null
if ($npmCmd) {
  $npmPath = $npmCmd.Source
}
if (-not $npmPath) {
  Write-Host "❌ No se encontró npm en el PATH. Instala Node.js o abre la terminal de Node." -ForegroundColor Red
  exit 1
}

if (-not (Test-Path $PIDS_FILE)) {
  Write-Host "⚠️  No se encontró archivo de PIDs (.mf-pids)" -ForegroundColor Yellow
  Write-Host "   No hay microfrontends corriendo para reiniciar." -ForegroundColor Gray
  Write-Host "   Usa ./start-all-mf.ps1 para iniciarlos." -ForegroundColor Cyan
  exit 0
}

Write-Host "📋 Leyendo PIDs desde $PIDS_FILE..." -ForegroundColor Cyan
Write-Host ""

$runningMfs = @{}
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
  $dirName = $parts[1]
  
  try {
    $process = Get-Process -Id $processId -ErrorAction Stop
    if ($process -and -not $process.HasExited) {
      Write-Host "   🛑 Deteniendo $dirName (PID: $processId)..." -ForegroundColor Yellow
      Stop-Process -Id $processId -Force
      Write-Host "      ✅ $dirName detenido" -ForegroundColor Green
      $runningMfs[$dirName] = $true
    } else {
      Write-Host "   ⚠️  $dirName (PID: $processId) ya no está corriendo" -ForegroundColor Gray
      $NOT_FOUND++
    }
  } catch {
    Write-Host "   ⚠️  $dirName (PID: $processId) ya no está corriendo" -ForegroundColor Gray
    $NOT_FOUND++
  }
}

if ($runningMfs.Count -eq 0) {
  Write-Host ""
  Write-Host "ℹ️  No hay microfrontends corriendo para reiniciar" -ForegroundColor Gray
  exit 0
}

Write-Host ""
Write-Host "🚀 Reiniciando microfrontends..." -ForegroundColor Cyan
Write-Host ""

# Limpiar archivo de PIDs para agregar los nuevos
if (Test-Path $PIDS_FILE) {
  Remove-Item $PIDS_FILE
}

Start-Sleep -Seconds 1

foreach ($dirName in $runningMfs.Keys) {
  $dirPath = Join-Path $ROOT_DIR $dirName
  $packageJsonPath = Join-Path $dirPath "package.json"
  
  if ((Test-Path $dirPath) -and (Test-Path $packageJsonPath)) {
    Write-Host "🚀 Reiniciando $dirName..." -ForegroundColor Yellow
    
    Push-Location $dirPath
    
    $logFile = Join-Path $LOGS_DIR "${dirName}.log"
    $errorLogFile = Join-Path $LOGS_DIR "${dirName}.error.log"
    
    $process = Start-Process -FilePath $npmPath -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    
    "$($process.Id):$dirName" | Add-Content -Path $PIDS_FILE
    
    Pop-Location
    
    Start-Sleep -Milliseconds 500
    
    if ($process -and -not $process.HasExited) {
      Write-Host "   ✅ $dirName reiniciado (PID: $($process.Id))" -ForegroundColor Green
      $RESTARTED++
    } else {
      Write-Host "   ❌ Error reiniciando $dirName" -ForegroundColor Red
      $FAILED++
    }
  } else {
    Write-Host "   ⚠️  Saltando $dirName (no existe o no tiene package.json)" -ForegroundColor Gray
    $FAILED++
  }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Reiniciados: $RESTARTED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
  Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Gray
}
if ($FAILED -gt 0) {
  Write-Host "   ❌ Fallidos: $FAILED" -ForegroundColor Red
}
Write-Host ""
Write-Host "📝 Logs guardados en: $LOGS_DIR" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($RESTARTED -gt 0) {
  Write-Host ""
  Write-Host "💡 Los microfrontends han sido reiniciados." -ForegroundColor Cyan
  Write-Host "   Revisa los logs en logs/mf/ para ver el output de cada uno." -ForegroundColor Cyan
}

