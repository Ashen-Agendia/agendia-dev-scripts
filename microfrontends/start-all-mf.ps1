# Script PowerShell para iniciar todos los microfrontends en Windows

Write-Host "🚀 Iniciando todos los microfrontends en desarrollo..." -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$ROOT_DIR = Split-Path -Parent $SCRIPTS_ROOT

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

$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".mf-pids"
$LOGS_DIR = Join-Path $SCRIPTS_ROOT "logs"
$STARTED = 0
$SKIPPED = 0
$FAILED = 0

# Limpiar archivo de PIDs anterior
if (Test-Path $PIDS_FILE) {
  Remove-Item $PIDS_FILE
}

# Crear directorio de logs si no existe
if (-not (Test-Path $LOGS_DIR)) {
  New-Item -ItemType Directory -Path $LOGS_DIR | Out-Null
}

$npmPath = (Get-Command npm.cmd -ErrorAction SilentlyContinue)?.Source
if (-not $npmPath) {
  Write-Host "❌ No se encontró npm en el PATH. Instala Node.js o abre la terminal de Node." -ForegroundColor Red
  exit 1
}

# Función para esperar a que el servidor esté listo
function Wait-ForServerReady {
  param(
    [string]$LogFile,
    [int]$TimeoutSeconds = 120
  )
  
  $startTime = Get-Date
  $readyPatterns = @("ready in", "Local:", "Network:")
  
  while ($true) {
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -gt $TimeoutSeconds) {
      return $false
    }
    
    if (Test-Path $LogFile) {
      try {
        # Leer el archivo con codificación UTF-8
        $content = Get-Content -Path $LogFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content) {
          foreach ($pattern in $readyPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
              return $true
            }
          }
        }
      } catch {
        # Si hay error leyendo, continuar esperando
      }
    }
    
    Start-Sleep -Milliseconds 500
  }
  
  return $false
}

# Función para limpiar códigos ANSI de los logs
function Remove-AnsiCodes {
  param([string]$Text)
  
  if (-not $Text) { return $Text }
  
  # Remover códigos ANSI (secuencias que empiezan con ESC [ o ESC])
  # Incluye códigos de color, formato, cursor, etc.
  # Preservamos saltos de línea (\n = 0x0A, \r = 0x0D) y tabuladores (\t = 0x09)
  $ansiRegex = '\x1b\[[0-9;]*[a-zA-Z]|\x1b\][0-9;]*\x07'
  $cleaned = $Text -replace $ansiRegex, ''
  
  return $cleaned
}

foreach ($dirName in $MF_DIRS) {
  $dirPath = Join-Path $ROOT_DIR $dirName
  $packageJsonPath = Join-Path $dirPath "package.json"
  
  if ((Test-Path $dirPath) -and (Test-Path $packageJsonPath)) {
    Write-Host "🚀 Iniciando $dirName..." -ForegroundColor Yellow
    
    Push-Location $dirPath
    
    # Iniciar proceso en background
    $logFile = Join-Path $LOGS_DIR "${dirName}.log"
    $errorLogFile = Join-Path $LOGS_DIR "${dirName}.error.log"
    
    # Limpiar logs anteriores
    if (Test-Path $logFile) {
      Remove-Item $logFile -Force
    }
    if (Test-Path $errorLogFile) {
      Remove-Item $errorLogFile -Force
    }
    
    # Iniciar proceso con redirección a archivos
    # Nota: Start-Process puede tener problemas con UTF-8, así que limpiaremos los códigos ANSI después
    $process = Start-Process -FilePath $npmPath -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
    
    # Guardar PID y directorio
    "$($process.Id):$dirName" | Add-Content -Path $PIDS_FILE
    
    Pop-Location
    
    # Esperar a que el servidor esté listo
    Write-Host "   ⏳ Esperando a que termine el build..." -ForegroundColor Yellow -NoNewline
    $isReady = $false
    $startTime = Get-Date
    $timeoutSeconds = 120
    $lastSize = 0
    
    while (-not $isReady) {
      $elapsed = (Get-Date) - $startTime
      if ($elapsed.TotalSeconds -gt $timeoutSeconds) {
        break
      }
      
      # Verificar si el proceso sigue corriendo
      if ($process.HasExited) {
        break
      }
      
      # Leer logs de forma no bloqueante
      if (Test-Path $logFile) {
        try {
          # Leer solo si el archivo ha crecido (evita leer constantemente)
          $currentSize = (Get-Item $logFile -ErrorAction SilentlyContinue).Length
          if ($currentSize -gt $lastSize -or $lastSize -eq 0) {
            $lastSize = $currentSize
            
            # Leer con manejo de errores para archivos bloqueados
            $content = $null
            try {
              # Intentar leer con FileStream para evitar bloqueos
              $stream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
              $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
              $content = $reader.ReadToEnd()
              $reader.Close()
              $stream.Close()
            } catch {
              # Si falla, intentar método alternativo
              try {
                $content = Get-Content -Path $logFile -Raw -ErrorAction Stop -Encoding UTF8
              } catch {
                # Si también falla, intentar sin especificar encoding
                try {
                  $bytes = [System.IO.File]::ReadAllBytes($logFile)
                  $content = [System.Text.Encoding]::UTF8.GetString($bytes)
                } catch {
                  # Continuar si todo falla
                }
              }
            }
            
            if ($content) {
              # Buscar patrones - usar expresiones regulares más flexibles
              # Los patrones deben funcionar incluso con códigos ANSI y prefijos como [0], [1]
              $readyPatterns = @(
                "ready\s+in\s+\d+",              # "ready in 390 ms" con número
                "ready\s+in",                    # "ready in" con espacios flexibles
                "Local:\s*http",                 # "Local:" seguido de URL
                "Local:.*localhost",             # "Local:" con localhost
                "Network:",                      # Network message
                "VITE.*ready",                   # Vite ready message
                "http://localhost:\d+",          # URL del servidor local con puerto
                "\[[0-9]+\].*ready\s+in",        # Con prefijo de concurrently [0], [1], etc.
                "\[[0-9]+\].*Local:"             # Local con prefijo de concurrently
              )
              
              # Primero limpiar códigos ANSI para búsqueda más confiable
              $cleanContent = Remove-AnsiCodes -Text $content
              
              foreach ($pattern in $readyPatterns) {
                # Buscar en contenido limpio (más confiable)
                if ($cleanContent -match $pattern) {
                  $isReady = $true
                  break
                }
                
                # También buscar en contenido original por si el patrón incluye códigos ANSI
                if ($content -match $pattern) {
                  $isReady = $true
                  break
                }
              }
            }
          }
        } catch {
          # Continuar esperando si hay error (archivo puede estar bloqueado)
        }
      }
      
      Start-Sleep -Milliseconds 300
    }
    
    # Limpiar códigos ANSI al final (después de un pequeño delay para asegurar que el proceso terminó de escribir)
    Start-Sleep -Milliseconds 500
    
    # Función helper para limpiar un archivo de códigos ANSI
    function Clean-LogFile {
      param([string]$FilePath)
      
      if (-not (Test-Path $FilePath)) { return }
      
      $maxRetries = 3
      $retry = 0
      
      while ($retry -lt $maxRetries) {
        try {
          # Intentar leer con FileShare para no bloquear
          $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
          $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
          $content = $reader.ReadToEnd()
          $reader.Close()
          
          if ($content) {
            $cleanContent = Remove-AnsiCodes -Text $content
            if ($cleanContent -ne $content) {
              $stream.SetLength(0)
              $stream.Position = 0
              $writer = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::UTF8)
              $writer.Write($cleanContent)
              $writer.Flush()
              $writer.Close()
            }
          }
          
          $stream.Close()
          break
        } catch {
          $retry++
          if ($retry -lt $maxRetries) {
            Start-Sleep -Milliseconds 200
          }
        }
      }
    }
    
    # Limpiar ambos archivos de log
    Clean-LogFile -FilePath $logFile
    Clean-LogFile -FilePath $errorLogFile
    
    if ($isReady) {
      Write-Host "`r   ✅ $dirName iniciado y listo (PID: $($process.Id))" -ForegroundColor Green
      $STARTED++
    } elseif ($process -and -not $process.HasExited) {
      Write-Host "`r   ⚠️  $dirName iniciado pero no se detectó 'ready' en el timeout (PID: $($process.Id))" -ForegroundColor Yellow
      $STARTED++
    } else {
      Write-Host "`r   ❌ Error iniciando $dirName" -ForegroundColor Red
      $FAILED++
    }
  } else {
    Write-Host "   ⏭️  Saltando $dirName (no existe o no tiene package.json)" -ForegroundColor Gray
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
Write-Host "🛑 Para detener todos: ./stop-all-mf.ps1" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STARTED -gt 0) {
  Write-Host ""
  Write-Host "💡 Los microfrontends están corriendo en background." -ForegroundColor Cyan
  Write-Host "   Revisa los logs en logs/ para ver el output de cada uno." -ForegroundColor Cyan
}

