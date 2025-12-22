#!/bin/bash
# ============================================================================
# Script de Instalación Automática de PostgreSQL en Linux
# ============================================================================
# Este script instala y configura PostgreSQL usando Docker Compose
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
POSTGRES_DIR="/opt/postgres"
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
    exit 1
fi

info "🚀 Iniciando instalación de PostgreSQL..."
info "   Directorio: $POSTGRES_DIR"
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
# Paso 4: Crear directorio y copiar archivos
# ============================================================================
info "📁 Paso 4: Configurando directorio de PostgreSQL..."

# Crear directorio (específico por entorno si no es local)
if [ "$ENVIRONMENT" = "local" ]; then
    POSTGRES_DIR="/opt/postgres"
else
    POSTGRES_DIR="/opt/postgres-$ENVIRONMENT"
fi

mkdir -p "$POSTGRES_DIR"
cd "$POSTGRES_DIR"

# Crear subdirectorios
mkdir -p data/postgres scripts backups

# Obtener ruta del script actual y buscar archivos de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Buscar archivos de configuración en agendia-infra/setup/postgres
POSTGRES_CONFIG_DIR=""
if [ -f "$SCRIPT_DIR/../../agendia-infra/setup/postgres/docker-compose.dev.yml" ] || [ -f "$SCRIPT_DIR/../../agendia-infra/setup/postgres/docker-compose.yml" ]; then
    POSTGRES_CONFIG_DIR="$SCRIPT_DIR/../../agendia-infra/setup/postgres"
elif [ -f "$(pwd)/agendia-infra/setup/postgres/docker-compose.dev.yml" ] || [ -f "$(pwd)/agendia-infra/setup/postgres/docker-compose.yml" ]; then
    POSTGRES_CONFIG_DIR="$(pwd)/agendia-infra/setup/postgres"
elif [ -f "/opt/agendia/agendia-infra/setup/postgres/docker-compose.dev.yml" ] || [ -f "/opt/agendia/agendia-infra/setup/postgres/docker-compose.yml" ]; then
    POSTGRES_CONFIG_DIR="/opt/agendia/agendia-infra/setup/postgres"
else
    error "No se encontró agendia-infra/setup/postgres/docker-compose.dev.yml ni docker-compose.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
fi

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

# Verificar si existe el archivo, si no usar docker-compose.dev.yml como fallback
if [ ! -f "$POSTGRES_CONFIG_DIR/$COMPOSE_FILE" ]; then
    warning "No se encontró $COMPOSE_FILE, usando docker-compose.dev.yml como fallback"
    COMPOSE_FILE="docker-compose.dev.yml"
    if [ ! -f "$POSTGRES_CONFIG_DIR/$COMPOSE_FILE" ] && [ ! -f "$POSTGRES_CONFIG_DIR/docker-compose.yml" ]; then
        error "No se encontró ningún archivo docker-compose válido en $POSTGRES_CONFIG_DIR"
        exit 1
    fi
fi

# Copiar archivos de configuración
info "Copiando archivos de configuración desde $POSTGRES_CONFIG_DIR..."
info "Usando archivo docker-compose: $COMPOSE_FILE"

if [ -f "$POSTGRES_CONFIG_DIR/$COMPOSE_FILE" ]; then
    cp "$POSTGRES_CONFIG_DIR/$COMPOSE_FILE" "$POSTGRES_DIR/docker-compose.dev.yml"
    success "$COMPOSE_FILE copiado como docker-compose.dev.yml"
elif [ -f "$POSTGRES_CONFIG_DIR/docker-compose.yml" ]; then
    cp "$POSTGRES_CONFIG_DIR/docker-compose.yml" "$POSTGRES_DIR/docker-compose.dev.yml"
    success "docker-compose.yml copiado como docker-compose.dev.yml"
else
    error "No se encontró archivo docker-compose en $POSTGRES_CONFIG_DIR"
    exit 1
fi

# Verificar archivo .env según entorno
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi

if [ -f "$POSTGRES_DIR/$ENV_FILE" ]; then
    info "Archivo $ENV_FILE encontrado"
else
    warning "Archivo $ENV_FILE no encontrado. Usando valores por defecto del docker-compose.yml"
fi

# Copiar scripts SQL
if [ -d "$POSTGRES_CONFIG_DIR/../db/scripts" ]; then
    cp "$POSTGRES_CONFIG_DIR/../db/scripts/"*.sql "$POSTGRES_DIR/scripts/" 2>/dev/null || true
    if [ -n "$(ls -A $POSTGRES_DIR/scripts/*.sql 2>/dev/null)" ]; then
        success "Scripts SQL copiados"
    fi
fi

# Copiar script de backup si existe
if [ -f "$SCRIPT_DIR/backup.sh" ]; then
    cp "$SCRIPT_DIR/backup.sh" "$POSTGRES_DIR/"
    chmod +x "$POSTGRES_DIR/backup.sh"
    success "backup.sh copiado"
fi

# Cambiar propietario si hay un usuario sudo
if [ -n "$SUDO_USER" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$POSTGRES_DIR"
    success "Permisos configurados para usuario $SUDO_USER"
fi

success "Directorio configurado: $POSTGRES_DIR"
echo ""

# ============================================================================
# Paso 5: Configuración completada
# ============================================================================
success "Configuración de directorios completada"
echo ""

# ============================================================================
# Paso 6: Iniciar PostgreSQL
# ============================================================================
info "🚀 Paso 6: Iniciando PostgreSQL..."

cd "$POSTGRES_DIR"

# Cambiar a usuario no-root si es posible
ENV_FILE_ARG=""
if [ "$ENVIRONMENT" = "local" ]; then
    if [ -f ".env" ]; then
        ENV_FILE_ARG="--env-file .env"
    fi
else
    if [ -f ".env.$ENVIRONMENT" ]; then
        ENV_FILE_ARG="--env-file .env.$ENVIRONMENT"
    fi
fi

if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" docker-compose -f docker-compose.dev.yml pull -q
    sudo -u "$SUDO_USER" docker-compose -f docker-compose.dev.yml up -d
else
    docker-compose -f docker-compose.dev.yml pull -q
    docker-compose -f docker-compose.dev.yml up -d
fi

# Esperar a que el servicio inicie
info "Esperando a que PostgreSQL inicie..."
sleep 10

# Verificar estado
if docker-compose -f docker-compose.dev.yml ps | grep -q "Up"; then
    success "PostgreSQL iniciado correctamente"
else
    error "Error al iniciar PostgreSQL. Revisa los logs:"
    docker-compose -f docker-compose.dev.yml logs --tail=50
    exit 1
fi
echo ""

# ============================================================================
# Paso 7: Configurar firewall
# ============================================================================
info "🔒 Paso 7: Configurando firewall..."

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
# Paso 8: Configurar backup automático
# ============================================================================
info "💾 Paso 8: Configurando backup automático..."

if [ -f "$POSTGRES_DIR/backup.sh" ]; then
    # Agregar a crontab para backup diario a las 2 AM
    CRON_JOB="0 2 * * * cd $POSTGRES_DIR && ./backup.sh --env $ENVIRONMENT >> $POSTGRES_DIR/backup.log 2>&1"
    
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
# Paso 9: Verificación final
# ============================================================================
info "✅ Paso 9: Verificando instalación..."

cd "$POSTGRES_DIR"

# Verificar contenedores
ENV_FILE_ARG=""
if [ "$ENVIRONMENT" = "local" ]; then
    if [ -f ".env" ]; then
        ENV_FILE_ARG="--env-file .env"
    fi
else
    if [ -f ".env.$ENVIRONMENT" ]; then
        ENV_FILE_ARG="--env-file .env.$ENVIRONMENT"
    fi
fi

if docker-compose -f docker-compose.dev.yml ps | grep -q "Up"; then
    success "Contenedores corriendo"
    docker-compose -f docker-compose.dev.yml ps
else
    error "Algunos contenedores no están corriendo"
    docker-compose -f docker-compose.dev.yml ps
    exit 1
fi

# Verificar conectividad
info "Verificando conectividad..."
sleep 5

if docker exec agendia-postgres pg_isready -U postgres > /dev/null 2>&1; then
    success "PostgreSQL responde correctamente"
else
    warning "PostgreSQL no responde. Revisa los logs: docker-compose -f docker-compose.dev.yml logs postgres"
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
echo "   - Archivo .env: $POSTGRES_DIR/$ENV_FILE"
echo "   - Logs: docker-compose -f docker-compose.dev.yml logs postgres"
echo "   - Scripts SQL: $POSTGRES_DIR/scripts/"
echo "   - Backups: $POSTGRES_DIR/backups/"
echo ""
info "📚 Comandos útiles:"
echo "   - Ver logs: cd $POSTGRES_DIR && docker-compose -f docker-compose.dev.yml logs -f"
echo "   - Reiniciar: cd $POSTGRES_DIR && docker-compose -f docker-compose.dev.yml restart"
echo "   - Detener: cd $POSTGRES_DIR && docker-compose -f docker-compose.dev.yml down"
echo "   - Backup manual: cd $POSTGRES_DIR && ./backup.sh"
echo ""
info "📖 Documentación:"
echo "   - Ver: agendia-docs/docs/setup/postgres-linux.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

