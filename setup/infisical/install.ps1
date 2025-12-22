# ============================================================================
# Script de Instalación de Infisical para Windows
# ============================================================================
# Este script configura Infisical usando Docker Compose en Windows
# 
# Uso:
#   .\install.ps1 [-Environment ENTORNO]
#
# Parámetros:
#   -Environment      Entorno: local, dev, staging, prod (default: dev)
#   -Help             Mostrar ayuda
# 
# Nota: Las dependencias del sistema (Docker, Docker Compose, etc.) deben
#       instalarse previamente ejecutando: install-system-deps.sh
# ============================================================================

param(
    [string]$Environment = "dev",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Colores (también escriben a log)
function Write-Info { 
    $msg = "ℹ️  $args"
    Write-Host $msg -ForegroundColor Cyan
    $msg | Add-Content -Path $LOG_FILE -Encoding UTF8
}
function Write-Success { 
    $msg = "✅ $args"
    Write-Host $msg -ForegroundColor Green
    $msg | Add-Content -Path $LOG_FILE -Encoding UTF8
}
function Write-Warning { 
    $msg = "⚠️  $args"
    Write-Host $msg -ForegroundColor Yellow
    $msg | Add-Content -Path $LOG_FILE -Encoding UTF8
}
function Write-Error { 
    $msg = "❌ $args"
    Write-Host $msg -ForegroundColor Red
    $msg | Add-Content -Path $LOG_FILE -Encoding UTF8
}

if ($Help) {
    Write-Host @"
Script de Instalación de Infisical para Windows

Uso: .\install.ps1 [-Environment ENTORNO]

Parámetros:
  -Environment      Entorno: local, dev, staging, prod (default: dev)

Nota: Las dependencias del sistema (Docker, Docker Compose, etc.) deben
      instalarse previamente ejecutando: install-system-deps.sh

Ejemplos:
  .\install.ps1                    # Dev (default)
  .\install.ps1 -Environment prod  # Producción
"@
    exit 0
}

# Validar entorno
if ($Environment -notmatch "^(local|dev|staging|prod)$") {
    Write-Error "Entorno inválido: $Environment. Debe ser: local, dev, staging, o prod"
    exit 1
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

# Configurar directorio de logs
$LOGS_DIR = Join-Path $SCRIPTS_ROOT "logs\setup\infisical"
if (-not (Test-Path $LOGS_DIR)) {
    New-Item -ItemType Directory -Path $LOGS_DIR -Force | Out-Null
}
$LOG_FILE = Join-Path $LOGS_DIR "install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Buscar directorio de configuración
$INFISICAL_CONFIG_DIR = $null

# Calcular ruta a la raíz del proyecto (subir desde setup/infisical hasta la raíz)
$ROOT_DIR = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR))

$searchPaths = @(
    "$ROOT_DIR\agendia-infra\setup\infisical",
    "$PWD\..\..\..\agendia-infra\setup\infisical",
    "$PWD\agendia-infra\setup\infisical",
    "agendia-infra\setup\infisical"
)

foreach ($path in $searchPaths) {
    # Buscar cualquier archivo docker-compose*.yml
    $composeFiles = @("docker-compose.dev.yml", "docker-compose.yml")
    foreach ($composeFile in $composeFiles) {
        $configPath = Join-Path $path $composeFile
        if (Test-Path $configPath) {
            $INFISICAL_CONFIG_DIR = (Resolve-Path $path).Path
            break
        }
    }
    if ($INFISICAL_CONFIG_DIR) {
        break
    }
}

if (-not $INFISICAL_CONFIG_DIR) {
    Write-Error "No se encontró agendia-infra/setup/infisical/docker-compose*.yml"
    Write-Error "Asegúrate de que el repositorio agendia-infra esté disponible"
    Write-Info "Log guardado en: $LOG_FILE"
    exit 1
}

Write-Info "📝 Logs guardados en: $LOG_FILE"
Write-Info "🚀 Iniciando instalación de Infisical..."
Write-Info "   Directorio de trabajo: $INFISICAL_CONFIG_DIR"
Write-Info "   Entorno: $Environment"
Write-Host ""

# Verificar Docker
Write-Info "🐳 Verificando Docker..."
try {
    $dockerVersion = docker --version
    Write-Success "Docker encontrado: $dockerVersion"
} catch {
    Write-Error "Docker no está instalado o no está en el PATH"
    Write-Error "Instala Docker Desktop para Windows: https://www.docker.com/products/docker-desktop"
    Write-Info "   Nota: Las dependencias del sistema deben instalarse con install-system-deps.sh"
    exit 1
}

Write-Info "📦 Verificando Docker Compose..."
try {
    $composeVersion = docker-compose --version
    Write-Success "Docker Compose encontrado: $composeVersion"
} catch {
    Write-Error "Docker Compose no está instalado o no está en el PATH"
    Write-Info "   Nota: Las dependencias del sistema deben instalarse con install-system-deps.sh"
    exit 1
}
Write-Host ""

# Cambiar al directorio de configuración
Set-Location $INFISICAL_CONFIG_DIR
Write-Success "Trabajando desde: $INFISICAL_CONFIG_DIR"
Write-Host ""

# Crear subdirectorios necesarios si no existen
Write-Info "📁 Verificando subdirectorios necesarios..."
@("data\postgres", "data\redis", "logs", "backups") | ForEach-Object {
    $dirPath = Join-Path $INFISICAL_CONFIG_DIR $_
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Success "Directorio creado: $_"
    }
}

# Determinar archivo docker-compose según entorno
# Lógica escalable: cuando se agreguen otros entornos, se usarán automáticamente
$COMPOSE_FILE = switch ($Environment) {
    "local" { "docker-compose.dev.yml" }  # Por ahora local usa dev también
    "dev" { "docker-compose.dev.yml" }
    "staging" { "docker-compose.staging.yml" }
    "prod" { "docker-compose.prod.yml" }
    default { "docker-compose.dev.yml" }  # Default: dev
}

if (-not (Test-Path (Join-Path $INFISICAL_CONFIG_DIR $COMPOSE_FILE))) {
    Write-Error "Archivo docker-compose no encontrado: $COMPOSE_FILE"
    Write-Error "Asegúrate de que el archivo existe en $INFISICAL_CONFIG_DIR"
    exit 1
}

Write-Info "📋 Verificando archivos de configuración..."
Write-Success "Archivo docker-compose encontrado: $COMPOSE_FILE"

# Verificar archivo .env
$ENV_FILE = if ($Environment -eq "local") { ".env" } else { ".env.$Environment" }
if (Test-Path $ENV_FILE) {
    Write-Info "Archivo $ENV_FILE encontrado"
    
    # Validar ENCRYPTION_KEY si existe en el archivo
    try {
        $envContent = Get-Content $ENV_FILE -ErrorAction SilentlyContinue | Where-Object { $_ -match "^INFISICAL_ENCRYPTION_KEY=" }
        if ($envContent) {
            $encryptionKey = ($envContent -split "=", 2)[1].Trim()
            if ($encryptionKey) {
                $keyLength = $encryptionKey.Length
                # Verificar que sea hexadecimal válido
                $isHex = $encryptionKey -match '^[0-9a-fA-F]+$'
                
                # Nota: Infisical requiere 16 bytes = 32 caracteres hexadecimales (según documentación oficial)
                # openssl rand -hex 16 genera 32 caracteres (16 bytes * 2)
                if ($keyLength -ne 32) {
                    Write-Warning ""
                    Write-Warning "⚠️  ADVERTENCIA: INFISICAL_ENCRYPTION_KEY tiene longitud incorrecta"
                    Write-Warning "   Longitud actual: $keyLength caracteres"
                    Write-Warning "   Longitud requerida: 32 caracteres hexadecimales (16 bytes)"
                    Write-Warning "   Esto causará errores de 'Invalid key length' durante las migraciones."
                } elseif (-not $isHex) {
                    Write-Warning ""
                    Write-Warning "⚠️  ADVERTENCIA: INFISICAL_ENCRYPTION_KEY contiene caracteres no hexadecimales válidos"
                    Write-Warning "   La clave debe contener SOLO caracteres hexadecimales (0-9, a-f, A-F)"
                    Write-Warning "   Longitud: $keyLength caracteres"
                    Write-Warning "   Esto causará errores de 'Invalid key length' durante las migraciones."
                } else {
                    Write-Success "INFISICAL_ENCRYPTION_KEY tiene formato válido (32 caracteres hexadecimales)"
                }
                
                if ($keyLength -ne 32 -or -not $isHex) {
                    Write-Warning ""
                    Write-Warning "   Para generar un nuevo ENCRYPTION_KEY válido en PowerShell:"
                    Write-Warning "   [Convert]::ToHexString((1..16 | ForEach-Object { Get-Random -Maximum 256 }))"
                    Write-Warning ""
                    Write-Warning "   O con OpenSSL:"
                    Write-Warning "   openssl rand -hex 16"
                    Write-Warning ""
                    Write-Warning "   Luego actualiza INFISICAL_ENCRYPTION_KEY en $ENV_FILE"
                    Write-Warning "   Y ejecuta: .\clean.ps1 -Environment $Environment para limpiar todo"
                    Write-Warning "   Luego vuelve a ejecutar este script de instalación"
                    Write-Warning ""
                }
            }
        }
    } catch {
        # Ignorar errores al leer el archivo .env
    }
} else {
    Write-Warning "Archivo $ENV_FILE no encontrado. Usando valores por defecto del docker-compose.yml"
    Write-Warning "Puedes crear el archivo manualmente en: $INFISICAL_CONFIG_DIR\$ENV_FILE"
}

Write-Host ""

# Determinar argumentos de docker-compose
$COMPOSE_ARGS = @("-f", $COMPOSE_FILE)
$ENV_FILE_ARG = ""
if (Test-Path $ENV_FILE) {
    $ENV_FILE_ARG = "--env-file"
    $COMPOSE_ARGS += $ENV_FILE_ARG, $ENV_FILE
}

# Iniciar Infisical
Write-Info "🚀 Paso 6: Iniciando Infisical..."
Write-Info "Usando archivo docker-compose: $COMPOSE_FILE"
if ($ENV_FILE_ARG) {
    Write-Info "Usando archivo .env: $ENV_FILE"
}
try {
    # Descargar imágenes
    Write-Info "📥 Descargando imágenes de Docker (esto puede tardar varios minutos)..."
    "=== INICIO: docker-compose pull ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    $pullStartTime = Get-Date
    $pullOutput = docker-compose $COMPOSE_ARGS pull 2>&1
    $pullOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
    $pullEndTime = Get-Date
    $pullDuration = ($pullEndTime - $pullStartTime).TotalSeconds
    "=== FIN: docker-compose pull (duración: $([math]::Round($pullDuration, 2)) segundos, exit code: $LASTEXITCODE) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Imágenes descargadas correctamente"
    } else {
        Write-Warning "Posibles advertencias durante la descarga (ver logs para detalles)"
    }
    
    Write-Host ""
    
    # Iniciar contenedores
    Write-Info "🐳 Iniciando contenedores..."
    "=== INICIO: docker-compose up -d ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    $upStartTime = Get-Date
    $upOutput = docker-compose $COMPOSE_ARGS up -d 2>&1
    $upOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
    $upEndTime = Get-Date
    $upDuration = ($upEndTime - $upStartTime).TotalSeconds
    "=== FIN: docker-compose up -d (duración: $([math]::Round($upDuration, 2)) segundos, exit code: $LASTEXITCODE) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    Write-Host ""
    Write-Info "⏳ Esperando a que los servicios inicien (15 segundos)..."
    for ($i = 15; $i -gt 0; $i--) {
        Write-Host "   Esperando... $i segundos restantes" -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "`r" -NoNewline
    }
    Write-Host "   Esperando... completado                 " # Espacios para limpiar la línea
    
    # Verificar estado - buscar contenedores realmente corriendo
    Write-Info "🔍 Verificando estado de contenedores..."
    "=== INICIO: docker-compose ps ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    $statusText = docker-compose $COMPOSE_ARGS ps 2>&1
    $statusText | Add-Content -Path $LOG_FILE -Encoding UTF8
    "=== FIN: docker-compose ps ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    # Verificar si hay contenedores corriendo usando docker ps directamente
    "=== INICIO: docker ps (filtro: agendia-infisical) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    $runningContainers = docker ps --filter "name=agendia-infisical" --format "{{.Names}}" 2>&1
    $runningContainers | Add-Content -Path $LOG_FILE -Encoding UTF8
    "=== FIN: docker ps ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    if ($runningContainers -and ($runningContainers -match "agendia-infisical")) {
        Write-Success "Infisical iniciado correctamente"
        $runningContainers -split "`n" | Where-Object { $_ -match "agendia-infisical" } | ForEach-Object {
            Write-Success "  ✅ Contenedor corriendo: $_"
        }
    } else {
        Write-Error "Error al iniciar Infisical - No hay contenedores corriendo"
        Write-Error "Salida de docker-compose ps:"
        Write-Host $statusText
        $logsOutput = docker-compose $COMPOSE_ARGS logs --tail=50 2>&1
        $logsOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
        Write-Host $logsOutput
        Write-Error ""
        Write-Error "Revisa los errores anteriores. Posibles causas:"
        Write-Error "  - Imagen de Docker no disponible o requiere autenticación (ej: infisical/api)"
        Write-Error "  - Error en el docker-compose.yml"
        Write-Error "  - Problemas de red o permisos"
        exit 1
    }
} catch {
    $errorMsg = "Error al iniciar Infisical: $_"
    Write-Error $errorMsg
    $errorMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
    exit 1
}

Write-Host ""

# Verificar logs del contenedor antes de ejecutar migraciones
Write-Info "📋 Revisando logs del contenedor para asegurar que esté listo..."
"=== INICIO: Logs del contenedor (antes de migraciones) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
$migrationShouldRun = $true
try {
    $containerLogs = docker logs agendia-infisical-backend --tail 50 2>&1
    $containerLogs | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    # Verificar si hay errores críticos en los logs
    if ($containerLogs -match "Invalid key length" -or ($containerLogs -match "Boot up migration failed" -and $containerLogs -match "Invalid key length")) {
        Write-Warning ""
        Write-Warning "   ⚠️  ERROR CRÍTICO DETECTADO EN LOGS: 'Invalid key length'"
        Write-Warning "   El ENCRYPTION_KEY en tu .env.$Environment es INVÁLIDO."
        Write-Warning "   Aunque parece tener 32 caracteres, contiene caracteres inválidos o no es hexadecimal válido."
        Write-Warning "   El contenedor NO puede completar las migraciones y quedará bloqueado."
        Write-Warning ""
        Write-Warning "   SOLUCIÓN REQUERIDA:"
        Write-Warning "   1. Detén y limpia todo: .\clean.ps1 -Environment $Environment"
        Write-Warning "   2. Genera un NUEVO ENCRYPTION_KEY válido:"
        Write-Warning "      PowerShell: [Convert]::ToHexString((1..16 | ForEach-Object { Get-Random -Maximum 256 }))"
        Write-Warning "      O con OpenSSL: openssl rand -hex 32"
        Write-Warning "   3. Asegúrate de copiar EXACTAMENTE el resultado (sin espacios, sin comillas)"
        Write-Warning "   4. Actualiza INFISICAL_ENCRYPTION_KEY en tu archivo .env.$Environment"
        Write-Warning "   5. Vuelve a ejecutar este script de instalación"
        Write-Warning ""
        Write-Warning "   NO se ejecutarán migraciones manuales hasta que se corrija el ENCRYPTION_KEY."
        $migrationShouldRun = $false
    }
    
    "=== FIN: Logs del contenedor (antes de migraciones) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
} catch {
    $warningMsg = "No se pudieron obtener logs del contenedor: $_"
    Write-Warning $warningMsg
    $warningMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
}

Write-Host ""
Write-Info "⏳ Esperando 10 segundos para asegurar que el contenedor esté completamente listo..."
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "   Esperando... $i segundos restantes" -NoNewline
    Start-Sleep -Seconds 1
    Write-Host "`r" -NoNewline
}
Write-Host "   Esperando... completado                 "

# Verificar que el contenedor esté realmente corriendo antes de ejecutar migraciones
Write-Info "🔍 Verificando estado del contenedor antes de migraciones..."
"=== INICIO: Verificación de estado del contenedor (antes de migraciones) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
$containerStatus = docker inspect agendia-infisical-backend --format='{{.State.Status}}' 2>&1
$containerStatus | Add-Content -Path $LOG_FILE -Encoding UTF8
"Estado del contenedor: $containerStatus" | Add-Content -Path $LOG_FILE -Encoding UTF8
"=== FIN: Verificación de estado del contenedor ===" | Add-Content -Path $LOG_FILE -Encoding UTF8

if ($containerStatus -ne "running") {
    Write-Warning "El contenedor no está en estado 'running' (estado actual: $containerStatus)"
    Write-Warning "No se ejecutarán migraciones. Revisa los logs del contenedor."
    $containerLogs = docker logs agendia-infisical-backend --tail 100 2>&1
    $containerLogs | Add-Content -Path $LOG_FILE -Encoding UTF8
} elseif (-not $migrationShouldRun) {
    Write-Warning "No se ejecutarán migraciones manuales debido a errores detectados en los logs."
    Write-Warning "Corrige el ENCRYPTION_KEY y reinicia los contenedores."
        } else {
            # Ejecutar migraciones de base de datos
            Write-Info "🔄 Ejecutando migraciones de base de datos..."
            try {
                # Primero intentar desbloquear la tabla de migraciones si está bloqueada
                Write-Info "   Verificando si la tabla de migraciones está bloqueada..."
                $unlockOutput = docker exec agendia-infisical-backend npx knex --knexfile ./dist/db/knexfile.mjs migrate:unlock 2>&1
                $unlockOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
                
                # Esperar un momento después de desbloquear
                Start-Sleep -Seconds 2
                
                Write-Info "   Ejecutando: docker exec agendia-infisical-backend npm run migration:latest"
                "=== INICIO: Ejecución de migraciones ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
                $migrationStartTime = Get-Date
                $migrationOutput = docker exec agendia-infisical-backend npm run migration:latest 2>&1
                $migrationOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
                $migrationEndTime = Get-Date
                $migrationDuration = ($migrationEndTime - $migrationStartTime).TotalSeconds
                "=== FIN: Ejecución de migraciones (duración: $([math]::Round($migrationDuration, 2)) segundos, exit code: $LASTEXITCODE) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Migraciones ejecutadas correctamente"
        } else {
            Write-Warning "Las migraciones fallaron (código de salida: $LASTEXITCODE)."
            
            # Explicar código de salida
            if ($LASTEXITCODE -eq 137) {
                Write-Warning "   Código 137 indica que el proceso fue terminado por el sistema (SIGKILL)."
                Write-Warning "   Esto puede ser por falta de memoria, timeout, o un error crítico."
            }
            
            Write-Host "   Últimas líneas de salida:"
            if ($migrationOutput) {
                $migrationOutput -split "`n" | Select-Object -Last 10 | ForEach-Object { Write-Host "   $_" }
            } else {
                Write-Host "   (Sin salida disponible - el proceso fue terminado antes de generar salida)"
            }
            
            # Verificar si hay errores comunes en la salida
            if ($migrationOutput -match "Invalid key length") {
                Write-Warning ""
                Write-Warning "   ⚠️  ERROR DETECTADO: 'Invalid key length'"
                Write-Warning "   El ENCRYPTION_KEY en tu .env.$Environment es inválido."
                Write-Warning "   ENCRYPTION_KEY debe ser una cadena hexadecimal de exactamente 32 caracteres (16 bytes)."
                Write-Warning ""
                Write-Warning "   Solución:"
                Write-Warning "   1. Limpia todo: .\clean.ps1 -Environment $Environment"
                Write-Warning "   2. Genera un nuevo ENCRYPTION_KEY válido:"
                Write-Warning "      PowerShell: [Convert]::ToHexString((1..16 | ForEach-Object { Get-Random -Maximum 256 }))"
                Write-Warning "      O con OpenSSL: openssl rand -hex 32"
                Write-Warning "   3. Actualiza INFISICAL_ENCRYPTION_KEY en tu archivo .env.$Environment"
                Write-Warning "   4. Ejecuta este script de instalación nuevamente"
            }
            
            if ($migrationOutput -match "Migration table is already locked") {
                Write-Warning ""
                Write-Warning "   ⚠️  ERROR DETECTADO: 'Migration table is already locked'"
                Write-Warning "   Las migraciones automáticas del contenedor están corriendo o fallaron."
                Write-Warning "   Esto puede indicar que el ENCRYPTION_KEY es inválido y las migraciones automáticas fallaron."
                Write-Warning ""
                Write-Warning "   Solución:"
                Write-Warning "   1. Verifica los logs del contenedor: docker logs agendia-infisical-backend"
                Write-Warning "   2. Si ves 'Invalid key length', corrige el ENCRYPTION_KEY y limpia todo:"
                Write-Warning "      .\clean.ps1 -Environment $Environment"
                Write-Warning "   3. Si las migraciones están realmente corriendo, espera a que terminen."
            }
            
            if ($migrationOutput -match "KMS: Failed to encrypt ROOT Key") {
                Write-Warning ""
                Write-Warning "   ⚠️  ERROR DETECTADO: 'KMS: Failed to encrypt ROOT Key'"
                Write-Warning "   Esto generalmente está relacionado con ENCRYPTION_KEY inválido."
            }
        }
    } catch {
        $warningMsg = "No se pudo ejecutar migraciones: $_"
        Write-Warning $warningMsg
        $warningMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
        Write-Warning "Puedes ejecutarlas manualmente con: docker exec agendia-infisical-backend npm run migration:latest"
    }
}

Write-Host ""

# Verificación final
Write-Host ""
Write-Info "✅ Verificando instalación..."
Write-Info "   Esperando 5 segundos antes de verificar conectividad..."
Start-Sleep -Seconds 5

# Verificar estado del contenedor antes de intentar HTTP
Write-Info "🔍 Verificando estado del contenedor..."
"=== INICIO: Verificación de estado del contenedor (antes de HTTP) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
$containerStatusFinal = docker inspect agendia-infisical-backend --format='{{.State.Status}}' 2>&1
$containerHealth = docker inspect agendia-infisical-backend --format='{{.State.Health.Status}}' 2>&1
"Estado del contenedor: $containerStatusFinal" | Add-Content -Path $LOG_FILE -Encoding UTF8
"Estado de health check: $containerHealth" | Add-Content -Path $LOG_FILE -Encoding UTF8
"=== FIN: Verificación de estado del contenedor ===" | Add-Content -Path $LOG_FILE -Encoding UTF8

if ($containerStatusFinal -ne "running") {
    Write-Warning "El contenedor no está corriendo (estado: $containerStatusFinal). Obteniendo logs recientes..."
    "=== INICIO: Logs del contenedor (contenedor no corriendo) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    $containerLogsFinal = docker logs agendia-infisical-backend --tail 100 2>&1
    $containerLogsFinal | Add-Content -Path $LOG_FILE -Encoding UTF8
    "=== FIN: Logs del contenedor ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    Write-Warning "   Revisa los logs del contenedor: docker logs agendia-infisical-backend"
} else {
    try {
        Write-Info "   Verificando conectividad HTTP en http://localhost:5002..."
        "=== INICIO: Verificación HTTP (http://localhost:5002) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
        $httpCheckStartTime = Get-Date
        $response = Invoke-WebRequest -Uri "http://localhost:5002" -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
        $httpCheckEndTime = Get-Date
        $httpCheckDuration = ($httpCheckEndTime - $httpCheckStartTime).TotalSeconds
        
        "Status Code: $($response.StatusCode)" | Add-Content -Path $LOG_FILE -Encoding UTF8
        "Status Description: $($response.StatusDescription)" | Add-Content -Path $LOG_FILE -Encoding UTF8
        "Duración: $([math]::Round($httpCheckDuration, 2)) segundos" | Add-Content -Path $LOG_FILE -Encoding UTF8
        "=== FIN: Verificación HTTP ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
        
        if ($response.StatusCode -eq 200) {
            Write-Success "Infisical responde correctamente en http://localhost:5002 (HTTP $($response.StatusCode))"
        } else {
            Write-Warning "Infisical respondió pero con código HTTP $($response.StatusCode). Revisa los logs."
        }
    } catch {
        $warningMsg = "Infisical no responde en http://localhost:5002: $_"
        Write-Warning $warningMsg
        $warningMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
        Write-Warning "   Obteniendo logs del contenedor para diagnóstico..."
        "=== INICIO: Logs del contenedor (HTTP falló) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
        $containerLogsHttp = docker logs agendia-infisical-backend --tail 100 2>&1
        $containerLogsHttp | Add-Content -Path $LOG_FILE -Encoding UTF8
        "=== FIN: Logs del contenedor ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
        Write-Warning "   Revisa los logs del contenedor: docker logs agendia-infisical-backend"
        "=== FIN: Verificación HTTP (falló) ===" | Add-Content -Path $LOG_FILE -Encoding UTF8
    }
}

Write-Host ""
Write-Success "🎉 Instalación de Infisical completada!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Info "📋 Información de Acceso:"
Write-Host "   🌐 Infisical: http://localhost:5002"
Write-Host ""
Write-Info "📝 Comandos útiles (ejecutar desde $INFISICAL_CONFIG_DIR):"
Write-Host "   - Ver logs: docker-compose -f $COMPOSE_FILE logs -f"
Write-Host "   - Reiniciar: docker-compose -f $COMPOSE_FILE restart"
Write-Host "   - Detener: docker-compose -f $COMPOSE_FILE down"
Write-Host "   - Backup manual: .\..\..\agendia-dev-scripts\setup\infisical\backup.ps1 -Environment $Environment"
Write-Host ""
Write-Info "📄 Log de instalación: $LOG_FILE"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
