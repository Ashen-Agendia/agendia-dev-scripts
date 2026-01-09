# ============================================================================
# Script de Instalación de PostgreSQL para Windows
# ============================================================================
# Este script configura PostgreSQL usando Docker Compose en Windows
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
Script de Instalación de PostgreSQL para Windows

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
$LOGS_DIR = Join-Path $SCRIPTS_ROOT "logs\setup\postgres"
if (-not (Test-Path $LOGS_DIR)) {
    New-Item -ItemType Directory -Path $LOGS_DIR -Force | Out-Null
}
$LOG_FILE = Join-Path $LOGS_DIR "install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Buscar directorio de configuración
$POSTGRES_CONFIG_DIR = $null

# Calcular ruta a la raíz del proyecto (subir desde setup/postgres hasta la raíz)
$ROOT_DIR = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR))

$searchPaths = @(
    "$ROOT_DIR\agendia-infra\setup\postgres",
    "$PWD\..\..\..\agendia-infra\setup\postgres",
    "$PWD\agendia-infra\setup\postgres",
    "agendia-infra\setup\postgres"
)

foreach ($path in $searchPaths) {
    # Buscar primero docker-compose.dev.yml, luego docker-compose.yml
    $devConfigPath = Join-Path $path "docker-compose.dev.yml"
    $configPath = Join-Path $path "docker-compose.yml"
    if ((Test-Path $devConfigPath) -or (Test-Path $configPath)) {
        $POSTGRES_CONFIG_DIR = (Resolve-Path $path).Path
        break
    }
}

if (-not $POSTGRES_CONFIG_DIR) {
    Write-Error "No se encontró agendia-infra/setup/postgres/docker-compose.dev.yml ni docker-compose.yml"
    Write-Error "Asegúrate de que el repositorio agendia-infra esté disponible"
    Write-Info "Log guardado en: $LOG_FILE"
    exit 1
}

Write-Info "📝 Logs guardados en: $LOG_FILE"
Write-Info "🚀 Iniciando instalación de PostgreSQL..."
Write-Info "   Directorio de trabajo: $POSTGRES_CONFIG_DIR"
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
Set-Location $POSTGRES_CONFIG_DIR
Write-Success "Trabajando desde: $POSTGRES_CONFIG_DIR"
Write-Host ""

# Crear subdirectorios necesarios si no existen
Write-Info "📁 Verificando subdirectorios necesarios..."
@("data/postgres", "backups") | ForEach-Object {
    $dirPath = Join-Path $POSTGRES_CONFIG_DIR $_
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Success "Directorio creado: $_"
    }
}

# Verificar que los scripts SQL existan en db-scripts
Write-Info "📋 Verificando scripts SQL de inicialización..."
$dbScriptsPath = Join-Path (Split-Path -Parent (Split-Path -Parent $POSTGRES_CONFIG_DIR)) "db-scripts"
if (Test-Path $dbScriptsPath) {
    $sqlFiles = Get-ChildItem "$dbScriptsPath\*.sql" -ErrorAction SilentlyContinue
    if ($sqlFiles) {
        Write-Success "Scripts SQL encontrados en db-scripts/ ($($sqlFiles.Count) archivos)"
        Write-Info "   Los scripts se ejecutarán automáticamente al inicializar PostgreSQL"
    } else {
        Write-Warning "No se encontraron archivos .sql en db-scripts/"
    }
} else {
    Write-Warning "Directorio db-scripts/ no encontrado en $dbScriptsPath"
}

# Determinar archivo docker-compose según entorno
$COMPOSE_FILE = switch ($Environment) {
    "local" { "docker-compose.dev.yml" }  # Por ahora local usa dev también
    "dev" { "docker-compose.dev.yml" }
    "staging" { "docker-compose.staging.yml" }
    "prod" { "docker-compose.prod.yml" }
    default { "docker-compose.dev.yml" }  # Default: dev
}

$COMPOSE_FILE_PATH = Join-Path $POSTGRES_CONFIG_DIR $COMPOSE_FILE
if (-not (Test-Path $COMPOSE_FILE_PATH)) {
    Write-Warning "No se encontró $COMPOSE_FILE, usando docker-compose.dev.yml como fallback"
    $COMPOSE_FILE = "docker-compose.dev.yml"
    $COMPOSE_FILE_PATH = Join-Path $POSTGRES_CONFIG_DIR $COMPOSE_FILE
    if (-not (Test-Path $COMPOSE_FILE_PATH)) {
        Write-Error "No se encontró ningún archivo docker-compose válido en $POSTGRES_CONFIG_DIR"
        exit 1
    }
}

Write-Info "📋 Verificando archivos de configuración..."
Write-Success "Archivo docker-compose encontrado: $COMPOSE_FILE"

# Verificar archivo .env
$ENV_FILE = if ($Environment -eq "local") { ".env" } else { ".env.$Environment" }
if (Test-Path $ENV_FILE) {
    Write-Success "Archivo $ENV_FILE encontrado"
} else {
    Write-Warning "Archivo $ENV_FILE no encontrado. Usando valores por defecto del docker-compose.yml"
    Write-Warning "Puedes crear el archivo manualmente en: $POSTGRES_CONFIG_DIR\$ENV_FILE"
}

Write-Host ""

# Iniciar PostgreSQL
Write-Info "🚀 Paso 6: Iniciando PostgreSQL..."
Write-Info "Usando archivo docker-compose: $COMPOSE_FILE"
if (Test-Path $ENV_FILE) {
    Write-Info "Usando archivo .env: $ENV_FILE"
}
Write-Info "📥 Descargando imágenes de Docker (esto puede tardar varios minutos)..."
try {
    $pullOutput = docker-compose -f $COMPOSE_FILE pull -q 2>&1
    $pullOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Imágenes descargadas correctamente"
    } else {
        Write-Warning "Advertencia durante descarga de imágenes (puede ser normal si ya existen)"
    }
    
    Write-Host ""
    Write-Info "🐳 Iniciando contenedores..."
    
    $upOutput = docker-compose -f $COMPOSE_FILE up -d 2>&1
    $upOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
    $upOutput | ForEach-Object { Write-Host $_ }
    
    
    Write-Host ""
    Write-Info "⏳ Esperando a que los servicios inicien (10 segundos)..."
    $progressChars = @("⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷")
    for ($i = 0; $i -lt 10; $i++) {
        $char = $progressChars[$i % $progressChars.Length]
        Write-Host -NoNewline "`r   $char Esperando... ($($i + 1)/10)"
        Start-Sleep -Seconds 1
    }
    Write-Host "`r   ✅ Esperando... completado"
    
    # Verificar estado
    Write-Info "🔍 Verificando estado de contenedores..."
    $status = docker-compose -f $COMPOSE_FILE ps 2>&1
    $status | Add-Content -Path $LOG_FILE -Encoding UTF8
    
    if ($status -match "Up") {
        Write-Success "PostgreSQL iniciado correctamente"
        $statusLines = $status -split "`n" | Where-Object { $_ -match "agendia-postgres" }
        foreach ($line in $statusLines) {
            if ($line -match "Up") {
                Write-Success "   ✅ Contenedor corriendo: agendia-postgres"
            }
        }
    } else {
        Write-Error "Error al iniciar PostgreSQL"
        $logsOutput = docker-compose -f $COMPOSE_FILE logs --tail=50 2>&1
        $logsOutput | Add-Content -Path $LOG_FILE -Encoding UTF8
        Write-Host $logsOutput
        exit 1
    }
} catch {
    $errorMsg = "Error al iniciar PostgreSQL: $_"
    Write-Error $errorMsg
    $errorMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
    exit 1
}

Write-Host ""

# Verificación final
Write-Info "✅ Verificando instalación..."
Start-Sleep -Seconds 5

try {
    $healthCheck = docker exec agendia-postgres pg_isready -U postgres 2>&1
    $healthCheck | Add-Content -Path $LOG_FILE -Encoding UTF8
    if ($LASTEXITCODE -eq 0) {
        Write-Success "PostgreSQL responde correctamente"
    } else {
        throw "pg_isready failed"
    }
} catch {
    $warningMsg = "PostgreSQL no responde. Revisa los logs: docker-compose logs postgres"
    Write-Warning $warningMsg
    $warningMsg | Add-Content -Path $LOG_FILE -Encoding UTF8
}

Write-Host ""
Write-Success "🎉 Instalación de PostgreSQL completada!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Info "📋 Información de Acceso:"
Write-Host "   🐘 PostgreSQL: localhost:5003"
Write-Host "   📊 Base de datos: agendia_dev"
Write-Host "   👤 Usuario: postgres"
Write-Host ""
Write-Info "📝 Comandos útiles (ejecutar desde $POSTGRES_CONFIG_DIR):"
Write-Host "   - Ver logs: docker-compose -f $COMPOSE_FILE logs -f"
Write-Host "   - Reiniciar: docker-compose -f $COMPOSE_FILE restart"
Write-Host "   - Detener: docker-compose -f $COMPOSE_FILE down"
Write-Host "   - Backup manual: .\..\..\agendia-dev-scripts\setup\postgres\backup.ps1 -Environment $Environment"
Write-Host ""
Write-Info "📄 Log de instalación: $LOG_FILE"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
