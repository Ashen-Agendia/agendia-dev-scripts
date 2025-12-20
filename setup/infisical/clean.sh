#!/bin/bash
# ============================================================================
# Script de Limpieza para Infisical (Linux)
# ============================================================================
# Este script limpia completamente Infisical: contenedores, volúmenes, redes, datos
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
Script de Limpieza para Infisical (Linux)

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

INFISICAL_CONFIG_DIR=""

# Buscar docker-compose.yml
search_paths=(
    "$ROOT_DIR/agendia-infra/setup/infisical"
    "$PWD/../../../agendia-infra/setup/infisical"
    "$PWD/agendia-infra/setup/infisical"
    "agendia-infra/setup/infisical"
)

for path in "${search_paths[@]}"; do
    # Buscar cualquier archivo docker-compose*.yml
    if [ -f "$path/docker-compose.dev.yml" ] || [ -f "$path/docker-compose.yml" ]; then
        INFISICAL_CONFIG_DIR="$(cd "$path" && pwd)"
        break
    fi
done

if [ -z "$INFISICAL_CONFIG_DIR" ]; then
    error "No se encontró agendia-infra/setup/infisical/docker-compose*.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
fi

echo ""
warning "⚠️  ADVERTENCIA: Este script eliminará TODOS los contenedores, volúmenes y datos de Infisical"
warning "   Entorno: $ENVIRONMENT"
warning "   Directorio: $INFISICAL_CONFIG_DIR"
echo ""

read -p "¿Estás seguro de que deseas continuar? (escribe 'si' para confirmar): " confirmation

if [ "$confirmation" != "si" ]; then
    info "Operación cancelada."
    exit 0
fi

echo ""
info "🧹 Iniciando limpieza de Infisical..."
info "   Directorio de trabajo: $INFISICAL_CONFIG_DIR"
info "   Entorno: $ENVIRONMENT"
echo ""

# Cambiar al directorio de configuración
cd "$INFISICAL_CONFIG_DIR"

# Determinar archivo docker-compose según entorno
# Lógica escalable: cuando se agreguen otros entornos, se usarán automáticamente
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

# Determinar archivo .env (opcional, para referencias)
ENV_FILE=""
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
else
    ENV_FILE=".env.$ENVIRONMENT"
fi

# 1. Detener y eliminar contenedores
info "🛑 Paso 1: Deteniendo y eliminando contenedores..."
docker-compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
success "Contenedores detenidos y eliminados"

echo ""

# 2. Eliminar contenedores por nombre (por si acaso)
info "🗑️  Paso 2: Eliminando contenedores por nombre..."
containers=(
    "agendia-infisical-backend"
    "agendia-infisical-db"
    "agendia-infisical-redis"
)

for container in "${containers[@]}"; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        docker rm -f "$container" > /dev/null 2>&1 && success "  Eliminado: $container" || true
    fi
done

echo ""

# 3. Eliminar volúmenes relacionados
info "🗑️  Paso 3: Eliminando volúmenes de Docker..."
volumes=$(docker volume ls --filter "name=infisical" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$volumes" ]; then
    echo "$volumes" | while read -r volume; do
        if [ -n "$volume" ]; then
            if docker volume rm "$volume" > /dev/null 2>&1; then
                success "  Volumen eliminado: $volume"
            else
                warning "  No se pudo eliminar volumen: $volume (puede estar en uso)"
            fi
        fi
    done
else
    info "  No se encontraron volúmenes con nombre 'infisical'"
fi

echo ""

# 4. Eliminar redes
info "🌐 Paso 4: Eliminando redes de Docker..."
networks=$(docker network ls --filter "name=infisical" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$networks" ]; then
    echo "$networks" | while read -r network; do
        if [ -n "$network" ] && [ "$network" != "NETWORK" ]; then
            if docker network rm "$network" > /dev/null 2>&1; then
                success "  Red eliminada: $network"
            else
                warning "  No se pudo eliminar red: $network (puede estar en uso)"
            fi
        fi
    done
else
    info "  No se encontraron redes con nombre 'infisical'"
fi

echo ""

# 5. Eliminar imágenes (opcional)
if [ "$REMOVE_IMAGES" = true ]; then
    info "🖼️  Paso 5: Eliminando imágenes de Docker..."
    images=(
        "infisical/infisical:latest-postgres"
        "postgres:15-alpine"
        "redis:7-alpine"
    )
    
    for image in "${images[@]}"; do
        if docker images "$image" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^${image}$"; then
            if docker rmi -f "$image" > /dev/null 2>&1; then
                success "  Imagen eliminada: $image"
            else
                warning "  No se pudo eliminar imagen: $image"
            fi
        fi
    done
    echo ""
else
    info "⏭️  Paso 5: Omitido (manteniendo imágenes). Usa --remove-images para eliminarlas."
    echo ""
fi

# 6. Eliminar directorios de datos (opcional)
if [ "$REMOVE_DATA" = true ]; then
    info "📁 Paso 6: Eliminando directorios de datos locales..."
    
    data_dirs=("data" "logs" "backups")
    
    for dir in "${data_dirs[@]}"; do
        dir_path="$INFISICAL_CONFIG_DIR/$dir"
        if [ -d "$dir_path" ]; then
            if rm -rf "$dir_path" 2>/dev/null; then
                success "  Directorio eliminado: $dir"
            else
                warning "  No se pudo eliminar directorio: $dir (puede estar en uso)"
                warning "    Intenta eliminarlo manualmente: $dir_path"
            fi
        else
            info "  Directorio no existe: $dir"
        fi
    done
    echo ""
else
    info "⏭️  Paso 6: Omitido (manteniendo datos locales). Usa --keep-data para mantenerlos."
    echo ""
fi

echo ""
success "🎉 Limpieza completada!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "📋 Resumen:"
echo "   ✅ Contenedores eliminados"
echo "   ✅ Volúmenes eliminados"
echo "   ✅ Redes eliminadas"
if [ "$REMOVE_IMAGES" = true ]; then
    echo "   ✅ Imágenes eliminadas"
else
    echo "   ℹ️  Imágenes conservadas"
fi
if [ "$REMOVE_DATA" = true ]; then
    echo "   ✅ Datos locales eliminados"
else
    echo "   ℹ️  Datos locales conservados"
fi
echo ""
info "🚀 Próximos pasos:"
echo "   1. Verifica que tu .env.$ENVIRONMENT tenga el ENCRYPTION_KEY correcto (32 caracteres hexadecimales = 16 bytes)"
echo "   2. Ejecuta el script de instalación: ./install.sh --env $ENVIRONMENT"
echo "   3. El script usará automáticamente el archivo: $COMPOSE_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
