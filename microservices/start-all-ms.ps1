# Script PowerShell para iniciar todos los microservicios en Windows

Write-Host "🚀 Iniciando todos los microservicios en desarrollo..." -ForegroundColor Cyan
Write-Host "" 

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$ROOT_DIR    = Split-Path -Parent $SCRIPTS_ROOT

  "agendia-ms-auth",
  "agendia-ms-agenda",
  "agendia-ms-clients",
  "agendia-ms-notifications",
  "agendia-ms-organization",
  "agendia-ms-platform",
  "agendia-ms-sales"
)

$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".ms-pids"
$LOGS_ROOT = Join-Path $SCRIPTS_ROOT "logs"
$LOGS_DIR  = Join-Path $LOGS_ROOT "ms"
$STARTED = 0
$SKIPPED = 0
$FAILED  = 0

# Asegurar que el server de sbt NO se autoinicie (evita problemas de locks en Windows)
$env:SBT_OPTS = "-Dsbt.server.autostart=false -Dsbt.server=false"

# Función para limpiar procesos de sbt/java que puedan estar bloqueando
function Clear-SbtProcesses {
  try {
    # Intentar matar procesos java que puedan estar relacionados con sbt
    # Usar WMI para obtener command line (compatible con PowerShell 5+)
    $javaProcesses = Get-WmiObject Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue | Where-Object {
      $_.CommandLine -like "*sbt*" -or $_.CommandLine -like "*agendia-template-ms*"
    }
    
    if ($javaProcesses) {
      Write-Host "   🔧 Limpiando procesos de sbt anteriores..." -ForegroundColor Gray
      foreach ($proc in $javaProcesses) {
        try {
          Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        } catch {
          # Ignorar errores al detener procesos
        }
      }
      Start-Sleep -Milliseconds 1000
    }
  } catch {
    # Ignorar errores (puede fallar si no hay permisos o no hay procesos)
  }
}

# Limpiar archivo de PIDs anterior
if (Test-Path $PIDS_FILE) {
  Remove-Item $PIDS_FILE -Force
}

# Crear directorio de logs si no existe
if (-not (Test-Path $LOGS_DIR)) {
  New-Item -ItemType Directory -Path $LOGS_DIR -Force | Out-Null
}

# Localizar sbt y npm si están instalados (compatible con PowerShell 5+)
$sbtCmd = Get-Command sbt.bat -ErrorAction SilentlyContinue
if (-not $sbtCmd) {
  $sbtCmd = Get-Command sbt -ErrorAction SilentlyContinue
}
$sbtPath = $null
if ($sbtCmd) {
  $sbtPath = $sbtCmd.Source
}

$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) {
  $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
}
$npmPath = $null
if ($npmCmd) {
  $npmPath = $npmCmd.Source
}

# Función para limpiar códigos ANSI de los logs (colores, etc.)
function Remove-AnsiCodes {
  param(
    [string]$Text
  )
  
  if (-not $Text) { return $Text }
  
  # Secuencias ANSI comunes de color/formato
  $ansiRegex = '\x1b\[[0-9;]*[a-zA-Z]|\x1b\][0-9;]*\x07'
  return ($Text -replace $ansiRegex, '')
}

# Espera a que el microservicio esté realmente levantado (build + server online)
function Wait-ForServiceReady {
  param(
    [string]$LogFile,
    [System.Diagnostics.Process]$Process,
    [int]$TimeoutSeconds = 180
  )

  $startTime = Get-Date

  # Patrones genéricos basados en los logs de Main.scala
  $readyPatterns = @(
    "online at http://",
    "Swagger UI available at http://"
  )

  while ($true) {
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -gt $TimeoutSeconds) {
      return $false
    }

    # Si el proceso ya murió, no sigas esperando: algo falló
    if ($Process -and $Process.HasExited) {
      return $false
    }

    if (Test-Path $LogFile) {
      try {
        $content = Get-Content -Path $LogFile -Raw -ErrorAction SilentlyContinue
        if ($content) {
          $cleanContent = Remove-AnsiCodes -Text $content

          foreach ($pattern in $readyPatterns) {
            if ($cleanContent -match [regex]::Escape($pattern)) {
              return $true
            }
          }
        }
      } catch {
        # Ignorar errores de lectura y seguir esperando
      }
    }

    Start-Sleep -Milliseconds 500
  }

  return $false
}

foreach ($dirName in $MS_DIRS) {
  $dirPath         = Join-Path $ROOT_DIR $dirName
  $sbtBuildPath    = Join-Path $dirPath "build.sbt"
  $packageJsonPath = Join-Path $dirPath "package.json"

  if ((Test-Path $dirPath) -and ((Test-Path $sbtBuildPath) -or (Test-Path $packageJsonPath))) {
    Write-Host "🚀 Iniciando $dirName..." -ForegroundColor Yellow

    Push-Location $dirPath

    $logFile     = Join-Path $LOGS_DIR  "${dirName}.log"
    $errorLogFile = Join-Path $LOGS_DIR "${dirName}.error.log"

    # Intentar limpiar logs anteriores, pero sin fallar si algún proceso aún los tiene abiertos
    if (Test-Path $logFile) {
      try {
        Remove-Item $logFile -Force -ErrorAction Stop
      } catch {
        # Si está en uso por otro proceso, lo dejamos y seguimos
      }
    }
    if (Test-Path $errorLogFile) {
      try {
        Remove-Item $errorLogFile -Force -ErrorAction Stop
      } catch {
        # Si está en uso por otro proceso, lo dejamos y seguimos
      }
    }

    $process = $null

    if ((Test-Path $sbtBuildPath) -and $sbtPath) {
      # Limpiar procesos de sbt anteriores que puedan estar bloqueando
      Clear-SbtProcesses
      
      # Scala / Akka HTTP con sbt (usar batch mode para evitar problemas de server en Windows)
      $process = Start-Process -FilePath $sbtPath -ArgumentList "-batch","run" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    } elseif (Test-Path $packageJsonPath -and $npmPath) {
      # Fallback para servicios Node/Nest u otros basados en npm
      $process = Start-Process -FilePath $npmPath -ArgumentList "run","dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    }

    if ($process) {
      "$($process.Id):$dirName" | Add-Content -Path $PIDS_FILE

      # Esperar a que el servicio esté listo (build terminado y servidor online)
      Write-Host "   ⏳ Esperando a que termine el build y levante el servidor..." -ForegroundColor Yellow -NoNewline
      $isReady = Wait-ForServiceReady -LogFile $logFile -Process $process -TimeoutSeconds 300

      if ($isReady -and -not $process.HasExited) {
        Write-Host "`r   ✅ $dirName iniciado y listo (PID: $($process.Id))" -ForegroundColor Green
        $STARTED++
      } elseif (-not $process.HasExited) {
        Write-Host "`r   ⚠️  $dirName iniciado pero no se detectó 'online' en el timeout (PID: $($process.Id))" -ForegroundColor Yellow
        $STARTED++
      } else {
        Write-Host "`r   ❌ Error iniciando $dirName" -ForegroundColor Red
        # Mostrar información del error si está disponible
        if (Test-Path $errorLogFile) {
          try {
            $errorContent = Get-Content -Path $errorLogFile -Raw -ErrorAction SilentlyContinue
            if ($errorContent -and $errorContent.Length -gt 0) {
              $firstError = ($errorContent -split "`n")[0..2] -join " "
              if ($firstError -match "ServerAlreadyBootingException") {
                Write-Host "      💡 Sugerencia: Cierra cualquier ventana de sbt abierta y vuelve a intentar" -ForegroundColor Gray
              }
            }
          } catch {
            # Ignorar errores al leer el log
          }
        }
        $FAILED++
      }
    } else {
      Write-Host "   ❌ No se pudo determinar comando para $dirName (sbt/npm no encontrados)" -ForegroundColor Red
      $FAILED++
    }

    Pop-Location
  } else {
    Write-Host "   ⏭️  Saltando $dirName (no existe o no tiene build.sbt / package.json)" -ForegroundColor Gray
    $SKIPPED++
  }
}

Write-Host "" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Iniciados: $STARTED" -ForegroundColor Green
Write-Host "   ⏭️  Saltados: $SKIPPED" -ForegroundColor Gray
Write-Host "   ❌ Fallidos: $FAILED" -ForegroundColor Red
Write-Host "" 
Write-Host "📝 Logs guardados en: $LOGS_DIR" -ForegroundColor Cyan
Write-Host "🛑 Para detener todos: ./microservices/stop-all-ms.ps1" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STARTED -gt 0) {
  Write-Host "" 
  Write-Host "💡 Los microservicios están corriendo en background." -ForegroundColor Cyan
  Write-Host "   Revisa los logs en logs/ms/ para ver el output de cada uno." -ForegroundColor Cyan
}
