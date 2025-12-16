# Script PowerShell para listar todos los microfrontends corriendo

Write-Host "📋 Listando microfrontends corriendo..." -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".mf-pids"

$MF_DIRS = @(
  "agendia-template-mf",
  "agendia-mf-shell",
  "agendia-mf-auth",
  "agendia-mf-agenda",
  "agendia-mf-sales",
  "agendia-mf-clients",
  "agendia-mf-dashboard",
  "agendia-mf-organization",
  "agendia-mf-platform",
  "agendia-mf-landing",
  "agendia-mf-public-booking"
)

$RUNNING = 0
$STOPPED = 0
$NOT_STARTED = 0

$runningMfs = @{}

if (Test-Path $PIDS_FILE) {
  Write-Host "📂 Leyendo PIDs desde archivo..." -ForegroundColor Gray
  Write-Host ""
  
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
        $port = $null
        try {
          $connections = Get-NetTCPConnection -OwningProcess $processId -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Listen" }
          if ($connections) {
            $port = ($connections | Select-Object -First 1).LocalPort
          }
        } catch {
        }
        
        $portInfo = if ($port) { " (Puerto: $port)" } else { "" }
        Write-Host "   ✅ $dirName" -ForegroundColor Green -NoNewline
        Write-Host " - PID: $processId$portInfo" -ForegroundColor Gray
        $runningMfs[$dirName] = $true
        $RUNNING++
      } else {
        Write-Host "   ⚠️  $dirName" -ForegroundColor Yellow -NoNewline
        Write-Host " - PID: $processId (proceso detenido)" -ForegroundColor Gray
        $STOPPED++
      }
    } catch {
      Write-Host "   ⚠️  $dirName" -ForegroundColor Yellow -NoNewline
      Write-Host " - PID: $processId (proceso no encontrado)" -ForegroundColor Gray
      $STOPPED++
    }
  }
} else {
  Write-Host "⚠️  No se encontró archivo de PIDs (.mf-pids)" -ForegroundColor Yellow
  Write-Host "   Buscando procesos de Node/Vite manualmente..." -ForegroundColor Gray
  Write-Host ""
  
  $nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
    $cmdLine = ""
    try {
      $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    } catch {
    }
    $cmdLine -like "*vite*" -or $cmdLine -like "*npm*dev*" -or $cmdLine -like "*run dev*"
  }
  
  if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
      $port = $null
      try {
        $connections = Get-NetTCPConnection -OwningProcess $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Listen" }
        if ($connections) {
          $port = ($connections | Select-Object -First 1).LocalPort
        }
      } catch {
      }
      
      $portInfo = if ($port) { " (Puerto: $port)" } else { "" }
      Write-Host "   ✅ Proceso Node" -ForegroundColor Green -NoNewline
      Write-Host " - PID: $($proc.Id)$portInfo" -ForegroundColor Gray
      $RUNNING++
    }
  } else {
    Write-Host "   ℹ️  No se encontraron procesos de Node/Vite corriendo" -ForegroundColor Gray
  }
}

Write-Host ""

foreach ($dirName in $MF_DIRS) {
  if (-not $runningMfs.ContainsKey($dirName)) {
    $NOT_STARTED++
  }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Corriendo: $RUNNING" -ForegroundColor Green
if ($STOPPED -gt 0) {
  Write-Host "   ⚠️  Detenidos: $STOPPED" -ForegroundColor Yellow
}
Write-Host "   ⏭️  No iniciados: $NOT_STARTED" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($RUNNING -eq 0) {
  Write-Host ""
  Write-Host "ℹ️  No hay microfrontends corriendo actualmente" -ForegroundColor Gray
  Write-Host "   Para iniciarlos: ./start-all-mf.ps1" -ForegroundColor Cyan
}

