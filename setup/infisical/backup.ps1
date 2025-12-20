# ============================================================================
# Script de Backup para Infisical (Windows)
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

$DATE = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "💾 Iniciando backup de Infisical (entorno: $Environment)..." -ForegroundColor Cyan

# Crear directorio de backups
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

# Backup de base de datos
Write-Info "📦 Haciendo backup de base de datos..."
$backupFile = Join-Path $BackupDir "db_$DATE.sql"
docker exec agendia-infisical-db pg_dump -U infisical infisical | Out-File -FilePath $backupFile -Encoding utf8

# Backup de .env
Write-Info "🔐 Haciendo backup de .env..."
if (Test-Path $ENV_FILE) {
    Copy-Item $ENV_FILE -Destination (Join-Path $BackupDir "env_$DATE.backup")
    Write-Success "Backup de $ENV_FILE completado"
} else {
    Write-Warning "Archivo $ENV_FILE no encontrado"
    if (Test-Path ".env" -and $ENV_FILE -ne ".env") {
        Copy-Item ".env" -Destination (Join-Path $BackupDir "env_$DATE.backup")
        Write-Success "Backup de .env completado (fallback)"
    }
}

Write-Host ""
Write-Success "Backup completado: $DATE"
Write-Info "📁 Ubicación: $BackupDir"
Write-Host ""
Write-Host "Archivos creados:"
Get-ChildItem $BackupDir | Where-Object { $_.Name -like "*$DATE*" } | Format-Table Name, Length, LastWriteTime
