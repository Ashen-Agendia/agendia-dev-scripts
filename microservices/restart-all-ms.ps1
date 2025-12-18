# Script PowerShell para reiniciar microservicios activos en Windows

Write-Host "🔄 Reiniciando microservicios activos..." -ForegroundColor Cyan
Write-Host "" 

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$ROOT_DIR    = Split-Path -Parent $SCRIPTS_ROOT
$PIDS_FILE   = Join-Path $SCRIPTS_ROOT ".ms-pids"
$LOGS_ROOT   = Join-Path $SCRIPTS_ROOT "logs"
$LOGS_DIR    = Join-Path $LOGS_ROOT "ms"

$RESTARTED = 0
$NOT_FOUND = 0
$FAILED    = 0

if (-not (Test-Path $PIDS_FILE)) {
  Write-Host "⚠️  No se encontró archivo de PIDs (.ms-pids)" -ForegroundColor Yellow
  Write-Host "   No hay microservicios corriendo para reiniciar." -ForegroundColor Gray
  Write-Host "   Usa ./start-all-ms.ps1 para iniciarlos." -ForegroundColor Cyan
  exit 0
}

Write-Host "📋 Leyendo PIDs desde $PIDS_FILE..." -ForegroundColor Cyan
Write-Host "" 

$runningMs = @{}
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
    $runningMs[$dir] = $true
  } catch {
    Write-Host "   ⚠️  $dir (PID: $processId) ya no está corriendo" -ForegroundColor Gray
    $NOT_FOUND++
  }
}

Remove-Item $PIDS_FILE -Force

if ($runningMs.Keys.Count -eq 0) {
  Write-Host "" 
  Write-Host "ℹ️  No hay microservicios corriendo para reiniciar" -ForegroundColor Gray
  exit 0
}

Write-Host "" 
Write-Host "🚀 Reiniciando microservicios..." -ForegroundColor Cyan
Write-Host "" 

if (-not (Test-Path $LOGS_DIR)) {
  New-Item -ItemType Directory -Path $LOGS_DIR -Force | Out-Null
}

$sbtPath = (Get-Command sbt.bat -ErrorAction SilentlyContinue)?.Source
if (-not $sbtPath) {
  $sbtPath = (Get-Command sbt -ErrorAction SilentlyContinue)?.Source
}

$npmPath = (Get-Command npm.cmd -ErrorAction SilentlyContinue)?.Source
if (-not $npmPath) {
  $npmPath = (Get-Command npm -ErrorAction SilentlyContinue)?.Source
}

foreach ($dir in $runningMs.Keys) {
  $dirPath         = Join-Path $ROOT_DIR $dir
  $sbtBuildPath    = Join-Path $dirPath "build.sbt"
  $packageJsonPath = Join-Path $dirPath "package.json"

  if ((Test-Path $dirPath) -and ((Test-Path $sbtBuildPath) -or (Test-Path $packageJsonPath))) {
    Write-Host "🚀 Reiniciando $dir..." -ForegroundColor Yellow

    Push-Location $dirPath

    $logFile      = Join-Path $LOGS_DIR  "${dir}.log"
    $errorLogFile = Join-Path $LOGS_DIR  "${dir}.error.log"

    if (Test-Path $logFile) { Remove-Item $logFile -Force }
    if (Test-Path $errorLogFile) { Remove-Item $errorLogFile -Force }

    $process = $null

    if (Test-Path $sbtBuildPath -and $sbtPath) {
      $process = Start-Process -FilePath $sbtPath -ArgumentList "run" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    } elseif (Test-Path $packageJsonPath -and $npmPath) {
      $process = Start-Process -FilePath $npmPath -ArgumentList "run","dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    }

    if ($process) {
      "$($process.Id):$dir" | Add-Content -Path $PIDS_FILE
      Start-Sleep -Seconds 1

      if (-not $process.HasExited) {
        Write-Host "   ✅ $dir reiniciado (PID: $($process.Id))" -ForegroundColor Green
        $RESTARTED++
      } else {
        Write-Host "   ❌ Error reiniciando $dir" -ForegroundColor Red
        $FAILED++
      }
    } else {
      Write-Host "   ❌ No se pudo determinar comando para $dir (sbt/npm no encontrados)" -ForegroundColor Red
      $FAILED++
    }

    Pop-Location
  } else {
    Write-Host "   ⚠️  Saltando $dir (no existe o no tiene build.sbt / package.json)" -ForegroundColor Yellow
    $FAILED++
  }
}

Write-Host "" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Reiniciados: $RESTARTED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
  Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Yellow
}
if ($FAILED -gt 0) {
  Write-Host "   ❌ Fallidos: $FAILED" -ForegroundColor Red
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($RESTARTED -gt 0) {
  Write-Host "" 
  Write-Host "💡 Los microservicios han sido reiniciados." -ForegroundColor Cyan
  Write-Host "   Revisa los logs en logs/ms/ para ver el output de cada uno." -ForegroundColor Cyan
}
