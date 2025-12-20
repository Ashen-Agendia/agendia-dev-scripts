#!/bin/bash
# ============================================================================
# Script de Backup para PostgreSQL
# ============================================================================
# Uso: ./backup.sh [--env ENTORNO] [directorio_destino]
# Si no se especifica directorio, usa ./backups/
# Si no se especifica entorno, intenta detectarlo o usa 'dev'
# ============================================================================

set -e

ENVIRONMENT="dev"
BACKUP_DIR="./backups"

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        *)
            if [[ "$1" != --* ]]; then
                BACKUP_DIR="$1"
            fi
            shift
            ;;
    esac
done

# Determinar archivo .env
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi

DATE=$(date +%Y%m%d_%H%M%S)

echo "💾 Iniciando backup de PostgreSQL (entorno: $ENVIRONMENT)..."

# Cargar variables de entorno si existe el archivo
if [ -f "$ENV_FILE" ]; then
    echo "📄 Cargando variables desde $ENV_FILE..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Valores por defecto si no están en .env
POSTGRES_DB="${POSTGRES_DB:-agendia_dev}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
CONTAINER_NAME="${CONTAINER_NAME:-agendia-postgres}"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Backup de base de datos
echo "📦 Haciendo backup de base de datos ($POSTGRES_DB)..."
docker exec "$CONTAINER_NAME" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_DIR/db_$DATE.sql"

# Backup de .env (importante!)
echo "🔐 Haciendo backup de .env..."
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$BACKUP_DIR/env_$DATE.backup"
    echo "✅ Backup de $ENV_FILE completado"
else
    echo "⚠️  ADVERTENCIA: Archivo $ENV_FILE no encontrado"
fi

# Comprimir backups antiguos (más de 7 días)
echo "🗜️  Comprimiendo backups antiguos..."
find "$BACKUP_DIR" -name "*.sql" -mtime +7 -exec gzip {} \;
find "$BACKUP_DIR" -name "*.backup" -mtime +7 -exec gzip {} \;

# Eliminar backups muy antiguos (más de 30 días)
echo "🗑️  Eliminando backups muy antiguos..."
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo "✅ Backup completado: $DATE"
echo "📁 Ubicación: $BACKUP_DIR"
echo ""
echo "Archivos creados:"
ls -lh "$BACKUP_DIR" | grep "$DATE"

