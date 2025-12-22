#!/bin/bash
# ============================================================================
# Script de Instalación Automática de PostgreSQL en Linux
# ============================================================================
# Este script instala y configura PostgreSQL trabajando directamente
# desde agendia-infra/setup/postgres
# 
# Uso:
#   ./install.sh [opciones]
#
# Opciones:
#   --env ENTORNO          Entorno de instalación: local, dev, staging, prod (default: dev)
#   --help                 Mostrar esta ayuda
# 
# Nota: Las dependencias del sistema (Docker, Docker Compose, etc.) deben
#       instalarse previamente ejecutando: install-system-deps.sh
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
ENVIRONMENT="dev"  # local, dev, staging, prod

# Función para mostrar mensajes
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

# Función para mostrar ayuda
show_help() {
    cat << EOF
Script de Instalación Automática de PostgreSQL

Uso: $0 [opciones]

Opciones:
  --env ENTORNO          Entorno: local, dev, staging, prod (default: dev)
  --help                 Mostrar esta ayuda

Nota: Las dependencias del sistema (Docker, Docker Compose, etc.) deben
      instalarse previamente ejecutando: install-system-deps.sh

Ejemplos:
  # Instalación básica (desarrollo)
  $0

  # Para entorno local
  $0 --env local

  # Para producción
  $0 --env prod

EOF
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validar entorno
if [[ ! "$ENVIRONMENT" =~ ^(local|dev|staging|prod)$ ]]; then
    error "Entorno inválido: $ENVIRONMENT. Debe ser: local, dev, staging, o prod"
    exit 1
fi

# Verificar que se ejecuta como root o con sudo
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root o con sudo"
    error ""
    error "Ejecuta el script con uno de estos comandos:"
    error "  sudo ./install.sh"
    error "  sudo bash install.sh"
    error ""
    error "NOTA: No uses 'sudo install.sh' (sin ./) porque no encontrará el script"
    exit 1
fi

info "🚀 Iniciando instalación de PostgreSQL..."
info "   Entorno: $ENVIRONMENT"
echo ""

# ============================================================================
# Paso 1: Verificar dependencias del sistema
# ============================================================================
info "📦 Paso 1: Verificando dependencias del sistema..."
info "   Nota: Las dependencias del sistema deben instalarse con install-system-deps.sh"
echo ""

# ============================================================================
# Paso 2: Verificar Docker
# ============================================================================
info "🐳 Paso 2: Verificando Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker no está instalado."
    error "Instala Docker ejecutando: install-system-deps.sh"
    error "O instala Docker manualmente desde: https://docs.docker.com/get-docker/"
    exit 1
fi
success "Docker encontrado: $(docker --version)"

# Verificar que el usuario esté en el grupo docker (solo advertencia, no crítico)
if [ -n "$SUDO_USER" ]; then
    if groups "$SUDO_USER" | grep -q docker; then
        success "Usuario $SUDO_USER está en el grupo docker"
    else
        warning "Usuario $SUDO_USER no está en el grupo docker"
        warning "Ejecuta: sudo usermod -aG docker $SUDO_USER y luego cierra sesión y vuelve a iniciar sesión"
    fi
fi
echo ""

# ============================================================================
# Paso 3: Verificar Docker Compose
# ============================================================================
info "📦 Paso 3: Verificando Docker Compose..."

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose no está instalado."
    error "Instala Docker Compose ejecutando: install-system-deps.sh"
    error "O instala Docker Compose manualmente desde: https://docs.docker.com/compose/install/"
    exit 1
fi
success "Docker Compose encontrado: $(docker-compose --version)"
echo ""

# ============================================================================
# Paso 4: Buscar y cambiar al directorio de agendia-infra
# ============================================================================
info "📁 Buscando directorio de configuración..."

# Obtener ruta del script actual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_PWD="$(pwd)"

# Calcular posibles rutas a la raíz del proyecto
# Desde agendia-dev-scripts/setup/postgres, subir 3 niveles para llegar a la raíz
PROJECT_ROOT=""
if [ -d "$SCRIPT_DIR/../../.." ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Buscar directorio agendia-infra/setup/postgres
POSTGRES_CONFIG_DIR=""
SEARCH_PATHS=()

# 1. Desde la raíz del proyecto (si se calculó)
if [ -n "$PROJECT_ROOT" ]; then
    SEARCH_PATHS+=("$PROJECT_ROOT/agendia-infra/setup/postgres")
fi

# 2. Desde el directorio del script (relativo)
SEARCH_PATHS+=("$SCRIPT_DIR/../../agendia-infra/setup/postgres")

# 3. Desde el directorio original de trabajo
SEARCH_PATHS+=("$ORIGINAL_PWD/agendia-infra/setup/postgres")
SEARCH_PATHS+=("$ORIGINAL_PWD/../agendia-infra/setup/postgres")
SEARCH_PATHS+=("$ORIGINAL_PWD/../../agendia-infra/setup/postgres")

# 4. Ubicación estándar
SEARCH_PATHS+=("/opt/agendia/agendia-infra/setup/postgres")

# Buscar en todas las rutas
for search_path in "${SEARCH_PATHS[@]}"; do
    if [ -f "$search_path/docker-compose.dev.yml" ] || [ -f "$search_path/docker-compose.yml" ]; then
        POSTGRES_CONFIG_DIR="$(cd "$search_path" && pwd)"
        break
    fi
done

if [ -z "$POSTGRES_CONFIG_DIR" ]; then
    error "No se encontró agendia-infra/setup/postgres/docker-compose.dev.yml ni docker-compose.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    error "Buscado en:"
    for search_path in "${SEARCH_PATHS[@]}"; do
        error "  - $search_path"
    done
    exit 1
fi

# Cambiar al directorio de configuración
cd "$POSTGRES_CONFIG_DIR"
success "Trabajando desde: $POSTGRES_CONFIG_DIR"
echo ""

# Crear subdirectorios necesarios si no existen
info "📁 Verificando subdirectorios necesarios..."
mkdir -p data/postgres scripts backups
success "Subdirectorios verificados"

# ============================================================================
# Verificar archivos de configuración
# ============================================================================
info "📋 Verificando archivos de configuración..."

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

# Verificar archivo docker-compose
if [ ! -f "$COMPOSE_FILE" ] && [ ! -f "docker-compose.yml" ]; then
    error "No se encontró archivo docker-compose en $POSTGRES_CONFIG_DIR"
    error "Asegúrate de que existe $COMPOSE_FILE o docker-compose.yml"
    exit 1
fi

# Usar docker-compose.yml como fallback si no existe el específico
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="docker-compose.yml"
    warning "Usando docker-compose.yml como fallback"
fi

success "Archivo docker-compose encontrado: $COMPOSE_FILE"

# Verificar archivo .env según entorno
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi

if [ -f "$ENV_FILE" ]; then
    success "Archivo $ENV_FILE encontrado"
else
    warning "Archivo $ENV_FILE no encontrado. Usando valores por defecto del docker-compose.yml"
    warning "Puedes crear el archivo manualmente en: $POSTGRES_CONFIG_DIR/$ENV_FILE"
fi

# Copiar scripts SQL desde db-scripts si existen
if [ -d "$POSTGRES_CONFIG_DIR/../../db-scripts" ]; then
    cp "$POSTGRES_CONFIG_DIR/../../db-scripts/"*.sql "$POSTGRES_CONFIG_DIR/scripts/" 2>/dev/null || true
    if [ -n "$(ls -A $POSTGRES_CONFIG_DIR/scripts/*.sql 2>/dev/null)" ]; then
        success "Scripts SQL copiados a scripts/"
    fi
fi
echo ""

# ============================================================================
# Paso 6: Iniciar PostgreSQL
# ============================================================================
info "🚀 Paso 6: Iniciando PostgreSQL..."

# Determinar argumentos de docker-compose
COMPOSE_ARGS="-f $COMPOSE_FILE"
ENV_FILE_ARG=""
if [ -f "$ENV_FILE" ]; then
    ENV_FILE_ARG="--env-file $ENV_FILE"
    COMPOSE_ARGS="$COMPOSE_ARGS $ENV_FILE_ARG"
fi

info "Usando archivo docker-compose: $COMPOSE_FILE"
if [ -n "$ENV_FILE_ARG" ]; then
    info "Usando archivo .env: $ENV_FILE"
fi

# Cambiar a usuario no-root si es posible
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS pull -q
    sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS up -d
else
    docker-compose $COMPOSE_ARGS pull -q
    docker-compose $COMPOSE_ARGS up -d
fi

# Esperar a que el servicio inicie
info "Esperando a que PostgreSQL inicie..."
sleep 10

# Verificar estado
if docker-compose $COMPOSE_ARGS ps | grep -q "Up"; then
    success "PostgreSQL iniciado correctamente"
else
    error "Error al iniciar PostgreSQL. Revisa los logs:"
    docker-compose $COMPOSE_ARGS logs --tail=50
    exit 1
fi
echo ""

# ============================================================================
# Configurar firewall
# ============================================================================
info "🔒 Configurando firewall..."

# Verificar UFW
if ! command -v ufw &> /dev/null; then
    warning "UFW no está instalado. Considera instalarlo para mayor seguridad."
    warning "Instala UFW: sudo apt install ufw"
else
    # Permitir SSH (importante hacerlo primero)
    ufw allow 22/tcp > /dev/null 2>&1 || true

    # Permitir PostgreSQL (solo si no es local)
    if [ "$ENVIRONMENT" != "local" ]; then
        ufw allow 5003/tcp > /dev/null 2>&1 || true
    fi

    # Habilitar firewall si no está habilitado
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable > /dev/null 2>&1 || true
    fi

    success "Firewall configurado"
fi
echo ""

# ============================================================================
# Configurar backup automático
# ============================================================================
info "💾 Configurando backup automático..."

if [ -f "backup.sh" ]; then
    chmod +x backup.sh
    # Agregar a crontab para backup diario a las 2 AM
    CRON_JOB="0 2 * * * cd $POSTGRES_CONFIG_DIR && ./backup.sh --env $ENVIRONMENT >> $POSTGRES_CONFIG_DIR/backup.log 2>&1"
    
    if [ -n "$SUDO_USER" ]; then
        (crontab -u "$SUDO_USER" -l 2>/dev/null | grep -v "backup.sh"; echo "$CRON_JOB") | crontab -u "$SUDO_USER" -
    else
        (crontab -l 2>/dev/null | grep -v "backup.sh"; echo "$CRON_JOB") | crontab -
    fi
    
    success "Backup automático configurado (diario a las 2 AM)"
else
    warning "Script backup.sh no encontrado. Backups automáticos no configurados."
fi
echo ""

# ============================================================================
# Verificación final
# ============================================================================
info "✅ Verificando instalación..."

# Verificar contenedores
if docker-compose $COMPOSE_ARGS ps | grep -q "Up"; then
    success "Contenedores corriendo"
    docker-compose $COMPOSE_ARGS ps
else
    error "Algunos contenedores no están corriendo"
    docker-compose $COMPOSE_ARGS ps
    exit 1
fi

# Verificar conectividad
info "Verificando conectividad..."
sleep 5

if docker exec agendia-postgres pg_isready -U postgres > /dev/null 2>&1; then
    success "PostgreSQL responde correctamente"
else
    warning "PostgreSQL no responde. Revisa los logs: docker-compose -f $COMPOSE_FILE logs postgres"
fi

echo ""

# ============================================================================
# Resumen final
# ============================================================================
success "🎉 Instalación de PostgreSQL completada!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "📋 Información de Acceso:"
echo "   🐘 PostgreSQL: localhost:5003"
echo "   📊 Base de datos: agendia_dev"
echo "   👤 Usuario: postgres"
echo ""
info "📝 Próximos pasos:"
echo "   1. Los scripts SQL en scripts/ se ejecutarán automáticamente al iniciar"
echo "   2. Verifica que los esquemas se hayan creado:"
echo "      docker exec -it agendia-postgres psql -U postgres -d agendia_dev -c '\\dn'"
echo "   3. Configura las contraseñas de los usuarios en Infisical"
echo "   4. Los secretos de base de datos se gestionan desde Infisical"
echo ""
info "🔧 Configuración:"
echo "   - Entorno actual: $ENVIRONMENT"
echo "   - Cada entorno debe tener sus propios secretos en Infisical"
echo "   - Ver: agendia-docs/docs/desarrollo/gestion-secretos.md"
echo ""
info "🔐 Archivos importantes:"
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi
echo "   - Directorio de trabajo: $POSTGRES_CONFIG_DIR"
echo "   - Archivo .env: $POSTGRES_CONFIG_DIR/$ENV_FILE"
echo "   - Logs: docker-compose -f $COMPOSE_FILE logs postgres"
echo "   - Scripts SQL: $POSTGRES_CONFIG_DIR/scripts/"
echo "   - Backups: $POSTGRES_CONFIG_DIR/backups/"
echo ""
info "📚 Comandos útiles:"
echo "   - Ver logs: cd $POSTGRES_CONFIG_DIR && docker-compose -f $COMPOSE_FILE logs -f"
echo "   - Reiniciar: cd $POSTGRES_CONFIG_DIR && docker-compose -f $COMPOSE_FILE restart"
echo "   - Detener: cd $POSTGRES_CONFIG_DIR && docker-compose -f $COMPOSE_FILE down"
echo "   - Backup manual: cd $POSTGRES_CONFIG_DIR && ./backup.sh"
echo ""
info "📖 Documentación:"
echo "   - Ver: agendia-docs/docs/setup/postgres-linux.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
