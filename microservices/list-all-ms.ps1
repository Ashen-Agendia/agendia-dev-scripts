# Script PowerShell para listar todos los microservicios corriendo

Write-Host "📋 Listando microservicios corriendo..." -ForegroundColor Cyan
Write-Host "" 

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$PIDS_FILE   = Join-Path $SCRIPTS_ROOT ".ms-pids"

$MS_DIRS = @(
  "agendia-template-ms",
  "agendia-ms-agenda",
  "agendia-ms-clients",
  "agendia-ms-notifications",
  "agendia-ms-organization",
  "agendia-ms-platform",
  "agendia-ms-sales"
)

$RUNNING = 0
$STOPPED = 0
$NOT_STARTED = 0

$runningMs = @{}

if (Test-Path $PIDS_FILE) {
  Write-Host "📂 Leyendo PIDs desde archivo..." -ForegroundColor Gray
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
      if ($process -and -not $process.HasExited) {
        Write-Host "   ✅ $dir" -ForegroundColor Green -NoNewline
        Write-Host " - PID: $processId" -ForegroundColor Gray
        $runningMs[$dir] = $true
        $RUNNING++
      } else {
        Write-Host "   ⚠️  $dir" -ForegroundColor Yellow -NoNewline
        Write-Host " - PID: $processId (proceso detenido)" -ForegroundColor Gray
        $STOPPED++
      }
    } catch {
      Write-Host "   ⚠️  $dir" -ForegroundColor Yellow -NoNewline
      Write-Host " - PID: $processId (proceso no encontrado)" -ForegroundColor Gray
      $STOPPED++
    }
  }
} else {
  Write-Host "⚠️  No se encontró archivo de PIDs (.ms-pids)" -ForegroundColor Yellow
  Write-Host "   Usa ./start-all-ms.ps1 para iniciar microservicios." -ForegroundColor Gray
}

Write-Host "" 

foreach ($dirName in $MS_DIRS) {
  if (-not $runningMs.ContainsKey($dirName)) {
    $NOT_STARTED++
  }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Corriendo: $RUNNING" -ForegroundColor Green
if ($STOPPED -gt 0) {
  Write-Host "   ⚠️  Detenidos: $STOPPED" -ForegroundColor Yellow
}
Write-Host "   ⏭️  No iniciados (según lista fija): $NOT_STARTED" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($RUNNING -eq 0) {
  Write-Host "" 
  Write-Host "ℹ️  No hay microservicios corriendo actualmente" -ForegroundColor Gray
  Write-Host "   Para iniciarlos: ./start-all-ms.ps1" -ForegroundColor Cyan
}
