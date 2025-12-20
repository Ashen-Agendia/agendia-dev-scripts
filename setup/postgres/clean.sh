#!/bin/bash
# ============================================================================
# Script de Limpieza para PostgreSQL (Linux)
# ============================================================================
# Este script limpia completamente PostgreSQL: contenedores, volúmenes, redes, datos
# 
# Uso:
#   ./clean.sh [--env ENTORNO] [--remove-images] [--keep-data] [--help]
#
# Opciones:
#   --env ENTORNO        Entorno: local, dev, staging, prod (default: dev)
#   --remove-images      También eliminar las imágenes de Docker (default: false)
#   --keep-data          No eliminar directorios de datos (data/, logs/, backups/) (default: false)
#   --help               Mostrar ayuda
# ============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones para mensajes
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Variables por defecto
ENVIRONMENT="dev"
REMOVE_IMAGES=false
REMOVE_DATA=true

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --remove-images)
            REMOVE_IMAGES=true
            shift
            ;;
        --keep-data)
            REMOVE_DATA=false
            shift
            ;;
        --help|-h)
            cat << EOF
Script de Limpieza para PostgreSQL (Linux)

Uso: $0 [opciones]

Opciones:
  --env ENTORNO          Entorno: local, dev, staging, prod (default: dev)
  --remove-images        También eliminar las imágenes de Docker (default: false)
  --keep-data            No eliminar directorios de datos (data/, logs/, backups/) (default: false)
  --help, -h             Mostrar esta ayuda

Ejemplos:
  $0                              # Limpiar entorno dev (mantiene imágenes)
  $0 --env prod                   # Limpiar entorno prod
  $0 --remove-images             # También eliminar imágenes de Docker
  $0 --keep-data                 # No eliminar datos locales
EOF
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            echo "Usa --help para ver la ayuda"
            exit 1
            ;;
    esac
done

# Validar entorno
if [[ ! "$ENVIRONMENT" =~ ^(local|dev|staging|prod)$ ]]; then
    error "Entorno inválido: $ENVIRONMENT. Debe ser: local, dev, staging, o prod"
    exit 1
fi

# Buscar directorio de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

POSTGRES_CONFIG_DIR=""

# Buscar docker-compose.yml
search_paths=(
    "$ROOT_DIR/agendia-infra/setup/postgres"
    "$PWD/../../../agendia-infra/setup/postgres"
    "$PWD/agendia-infra/setup/postgres"
    "agendia-infra/setup/postgres"
)

for path in "${search_paths[@]}"; do
    # Buscar cualquier archivo docker-compose*.yml
    if [ -f "$path/docker-compose.dev.yml" ] || [ -f "$path/docker-compose.yml" ]; then
        POSTGRES_CONFIG_DIR="$(cd "$path" && pwd)"
        break
    fi
done

if [ -z "$POSTGRES_CONFIG_DIR" ]; then
    error "No se encontró agendia-infra/setup/postgres/docker-compose*.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
fi

echo ""
warning "⚠️  ADVERTENCIA: Este script eliminará TODOS los contenedores, volúmenes y datos de PostgreSQL"
warning "   Entorno: $ENVIRONMENT"
warning "   Directorio: $POSTGRES_CONFIG_DIR"
echo ""

read -p "¿Estás seguro de que deseas continuar? (escribe 'si' para confirmar): " confirmation

if [ "$confirmation" != "si" ]; then
    info "Operación cancelada."
    exit 0
fi

echo ""
info "🧹 Iniciando limpieza de PostgreSQL..."
info "   Directorio de trabajo: $POSTGRES_CONFIG_DIR"
info "   Entorno: $ENVIRONMENT"
echo ""

# Cambiar al directorio de configuración
cd "$POSTGRES_CONFIG_DIR"

# Determinar archivo docker-compose según entorno
case "$ENVIRONMENT" in
    "local")
        COMPOSE_FILE="docker-compose.dev.yml"  # Por ahora local usa dev también
        ;;
    "dev")
        COMPOSE_FILE="docker-compose.dev.yml"
        ;;
    "staging")
        COMPOSE_FILE="docker-compose.staging.yml"
        ;;
    "prod")
        COMPOSE_FILE="docker-compose.prod.yml"
        ;;
    *)
        COMPOSE_FILE="docker-compose.dev.yml"  # Default: dev
        ;;
esac

if [ ! -f "$COMPOSE_FILE" ]; then
    warning "Archivo docker-compose no encontrado: $COMPOSE_FILE. Intentando limpiar de todas formas..."
fi

# 1. Detener y eliminar contenedores
info "🛑 Paso 1: Deteniendo y eliminando contenedores..."
if docker-compose -f "$COMPOSE_FILE" down -v 2>/dev/null; then
    success "Contenedores detenidos y eliminados"
else
    warning "Algunos contenedores pueden no haber sido eliminados (puede que no existan)"
fi

echo ""

# 2. Eliminar contenedores por nombre (por si acaso)
info "🗑️  Paso 2: Eliminando contenedores por nombre..."
containers=(
    "agendia-postgres"
)

for container in "${containers[@]}"; do
    if docker rm -f "$container" 2>/dev/null; then
        success "   Contenedor eliminado: $container"
    fi
done

echo ""

# 3. Eliminar volúmenes de Docker
info "🗑️  Paso 3: Eliminando volúmenes de Docker..."
volumes=$(docker volume ls --filter "name=postgres" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$volumes" ]; then
    echo "$volumes" | while read -r volume; do
        if docker volume rm "$volume" 2>/dev/null; then
            success "   Volumen eliminado: $volume"
        fi
    done
else
    info "   No se encontraron volúmenes de PostgreSQL"
fi

echo ""

# 4. Eliminar redes
info "🗑️  Paso 4: Eliminando redes..."
networks=$(docker network ls --filter "name=agendia" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$networks" ]; then
    echo "$networks" | while read -r network; do
        if [[ "$network" =~ postgres|agendia-network ]]; then
            if docker network rm "$network" 2>/dev/null; then
                success "   Red eliminada: $network"
            fi
        fi
    done
else
    info "   No se encontraron redes de PostgreSQL"
fi

echo ""

# 5. Eliminar imágenes (opcional)
if [ "$REMOVE_IMAGES" = true ]; then
    info "🗑️  Paso 5: Eliminando imágenes de Docker..."
    images=$(docker images --filter "reference=postgres:15-alpine" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$images" ]; then
        echo "$images" | while read -r image; do
            if docker rmi -f "$image" 2>/dev/null; then
                success "   Imagen eliminada: $image"
            fi
        done
    else
        info "   No se encontraron imágenes de PostgreSQL"
    fi
    echo ""
else
    info "⏭️  Paso 5: Omitiendo eliminación de imágenes (usa --remove-images para eliminarlas)"
    echo ""
fi

# 6. Eliminar directorios de datos locales (opcional)
if [ "$REMOVE_DATA" = true ]; then
    info "🗑️  Paso 6: Eliminando directorios de datos locales..."
    data_dirs=(
        "data/postgres"
        "logs"
        "backups"
    )
    
    for dir in "${data_dirs[@]}"; do
        dir_path="$POSTGRES_CONFIG_DIR/$dir"
        if [ -d "$dir_path" ]; then
            if rm -rf "$dir_path" 2>/dev/null; then
                success "   Directorio eliminado: $dir"
            else
                warning "   No se pudo eliminar: $dir"
            fi
        else
            info "   Directorio no existe: $dir"
        fi
    done
    echo ""
else
    info "⏭️  Paso 6: Manteniendo directorios de datos locales (usa --keep-data para mantenerlos)"
    echo ""
fi

# Resumen final
echo ""
success "🎉 Limpieza de PostgreSQL completada!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "📋 Resumen:"
echo "   ✅ Contenedores eliminados"
echo "   ✅ Volúmenes de Docker eliminados"
echo "   ✅ Redes eliminadas"
if [ "$REMOVE_IMAGES" = true ]; then
    echo "   ✅ Imágenes eliminadas"
else
    echo "   ⏭️  Imágenes mantenidas"
fi
if [ "$REMOVE_DATA" = true ]; then
    echo "   ✅ Datos locales eliminados"
else
    echo "   ⏭️  Datos locales mantenidos"
fi
echo ""
info "💡 Próximos pasos:"
echo "   1. Verifica que tu .env.$ENVIRONMENT tenga las credenciales correctas"
echo "   2. Ejecuta el script de instalación nuevamente:"
echo "      ./install.sh --env $ENVIRONMENT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
