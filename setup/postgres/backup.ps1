# ============================================================================
# Script de Backup para PostgreSQL (Windows)
# ============================================================================
# Uso: .\backup.ps1 [-Environment ENTORNO] [DirectorioDestino]
# ============================================================================

param(
    [string]$Environment = "dev",
    [string]$BackupDir = ".\backups"
)

$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠️  $args" -ForegroundColor Yellow }

# Validar entorno
if ($Environment -notmatch "^(local|dev|staging|prod)$") {
    Write-Host "❌ Entorno inválido: $Environment" -ForegroundColor Red
    exit 1
}

# Determinar archivo .env
$ENV_FILE = if ($Environment -eq "local") { ".env" } else { ".env.$Environment" }

# Cargar variables de entorno si existe el archivo
if (Test-Path $ENV_FILE) {
    Write-Info "📄 Cargando variables desde $ENV_FILE..."
    Get-Content $ENV_FILE | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), 'Process')
    }
}

# Valores por defecto
$POSTGRES_DB = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "agendia_dev" }
$POSTGRES_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "postgres" }
$CONTAINER_NAME = "agendia-postgres"

$DATE = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "💾 Iniciando backup de PostgreSQL (entorno: $Environment)..." -ForegroundColor Cyan

# Crear directorio de backups
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

# Backup de base de datos
Write-Info "📦 Haciendo backup de base de datos ($POSTGRES_DB)..."
$backupFile = Join-Path $BackupDir "db_$DATE.sql"
docker exec $CONTAINER_NAME pg_dump -U $POSTGRES_USER $POSTGRES_DB | Out-File -FilePath $backupFile -Encoding utf8

# Backup de .env
Write-Info "🔐 Haciendo backup de .env..."
if (Test-Path $ENV_FILE) {
    Copy-Item $ENV_FILE -Destination (Join-Path $BackupDir "env_$DATE.backup")
    Write-Success "Backup de $ENV_FILE completado"
} else {
    Write-Warning "Archivo $ENV_FILE no encontrado"
}

Write-Host ""
Write-Success "Backup completado: $DATE"
Write-Info "📁 Ubicación: $BackupDir"
Write-Host ""
Write-Host "Archivos creados:"
Get-ChildItem $BackupDir | Where-Object { $_.Name -like "*$DATE*" } | Format-Table Name, Length, LastWriteTime
