#!/bin/bash
# ============================================================================
# Script de Instalación Automática de Infisical en Linux
# ============================================================================
# Este script instala y configura Infisical self-hosted trabajando directamente
# desde agendia-infra/setup/infisical
# 
# Uso:
#   ./install.sh [opciones]
#
# Opciones:
#   --url URL              URL del servidor Infisical (default: http://localhost:5002)
#   --domain DOMINIO       Dominio para producción (opcional)
#   --env ENTORNO          Entorno de instalación: local, dev, staging, prod (default: dev)
#   --skip-nginx           Omitir verificación de Nginx (si ya está instalado)
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
INFISICAL_URL="http://localhost:5002"
DOMAIN=""
ENVIRONMENT="dev"  # local, dev, staging, prod
SKIP_NGINX=false

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
Script de Instalación Automática de Infisical

Uso: $0 [opciones]

Opciones:
  --url URL              URL del servidor Infisical (default: http://localhost:5002)
  --domain DOMINIO       Dominio para producción (ej: infisical.tu-dominio.com)
  --env ENTORNO          Entorno: local, dev, staging, prod (default: dev)
  --skip-nginx           Omitir verificación de Nginx (si ya está instalado)
  --help                 Mostrar esta ayuda

Nota: Las dependencias del sistema (Docker, Docker Compose, etc.) deben
      instalarse previamente ejecutando: install-system-deps.sh

Ejemplos:
  # Instalación básica (desarrollo)
  $0

  # Para entorno local
  $0 --env local

  # Para producción con dominio
  $0 --env prod --domain infisical.tu-dominio.com

EOF
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            INFISICAL_URL="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            shift
            ;;
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

info "🚀 Iniciando instalación de Infisical..."
info "   Entorno: $ENVIRONMENT"
if [ -n "$DOMAIN" ]; then
    info "   Dominio: $DOMAIN"
fi
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

# Verificar Docker Compose v2 (plugin) o v1 (standalone)
DOCKER_COMPOSE_CMD=""
DOCKER_COMPOSE_VERSION=""

# Verificar si docker compose (plugin v2) está disponible
# El plugin v2 se ejecuta como "docker compose" (con espacio)
# Verificamos primero si docker está disponible (ya verificado antes)
if command -v docker &> /dev/null 2>&1; then
    # Verificar Docker Compose v2 (plugin) - múltiples métodos
    COMPOSE_V2_AVAILABLE=false
    
    # Método 1: Intentar ejecutar el comando directamente
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_V2_AVAILABLE=true
    # Método 2: Verificar si el plugin está listado en los plugins de Docker
    elif docker info 2>/dev/null | grep -q "compose"; then
        COMPOSE_V2_AVAILABLE=true
    # Método 3: Verificar si el paquete docker-compose-plugin está instalado (Ubuntu/Debian)
    elif dpkg -l 2>/dev/null | grep -q "docker-compose-plugin"; then
        COMPOSE_V2_AVAILABLE=true
    # Método 4: Verificar si existe el binario del plugin
    elif [ -f "/usr/libexec/docker/cli-plugins/docker-compose" ] || [ -f "/usr/local/lib/docker/cli-plugins/docker-compose" ] || [ -f "$HOME/.docker/cli-plugins/docker-compose" ]; then
        COMPOSE_V2_AVAILABLE=true
    fi
    
    if [ "$COMPOSE_V2_AVAILABLE" = true ]; then
        # Docker Compose v2 (plugin)
        DOCKER_COMPOSE_CMD="docker compose"
        # Intentar obtener la versión, si falla usar un valor por defecto
        DOCKER_COMPOSE_VERSION=$(docker compose version 2>/dev/null | awk '{print $4}' 2>/dev/null || echo "v2")
        success "Docker Compose encontrado: ${DOCKER_COMPOSE_VERSION} (plugin v2)"
    elif command -v docker-compose &> /dev/null 2>&1; then
        # Docker Compose v1 (standalone)
        DOCKER_COMPOSE_CMD="docker-compose"
        DOCKER_COMPOSE_VERSION=$(docker-compose --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "v1")
        success "Docker Compose encontrado: ${DOCKER_COMPOSE_VERSION} (standalone v1)"
    else
        error "Docker Compose no está instalado."
        error "Instala Docker Compose ejecutando: install-system-deps.sh"
        error "O instala Docker Compose manualmente desde: https://docs.docker.com/compose/install/"
        exit 1
    fi
else
    error "Docker no está disponible. Esto no debería pasar ya que se verificó anteriormente."
    exit 1
fi
echo ""

# ============================================================================
# Paso 4: Buscar y cambiar al directorio de agendia-infra
# ============================================================================
info "📁 Buscando directorio de configuración..."

# Obtener ruta del script actual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_PWD="$(pwd)"

# Calcular posibles rutas a la raíz del proyecto
# Desde agendia-dev-scripts/setup/infisical, subir 3 niveles para llegar a la raíz
PROJECT_ROOT=""
if [ -d "$SCRIPT_DIR/../../.." ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Buscar directorio agendia-infra/setup/infisical
INFISICAL_CONFIG_DIR=""
SEARCH_PATHS=()

# 1. Desde la raíz del proyecto (si se calculó)
if [ -n "$PROJECT_ROOT" ]; then
    SEARCH_PATHS+=("$PROJECT_ROOT/agendia-infra/setup/infisical")
fi

# 2. Desde el directorio del script (relativo)
SEARCH_PATHS+=("$SCRIPT_DIR/../../agendia-infra/setup/infisical")

# 3. Desde el directorio original de trabajo
SEARCH_PATHS+=("$ORIGINAL_PWD/agendia-infra/setup/infisical")
SEARCH_PATHS+=("$ORIGINAL_PWD/../agendia-infra/setup/infisical")
SEARCH_PATHS+=("$ORIGINAL_PWD/../../agendia-infra/setup/infisical")

# 4. Ubicación estándar
SEARCH_PATHS+=("/opt/agendia/agendia-infra/setup/infisical")

# Buscar en todas las rutas
for search_path in "${SEARCH_PATHS[@]}"; do
    if [ -f "$search_path/docker-compose.dev.yml" ] || [ -f "$search_path/docker-compose.yml" ]; then
        INFISICAL_CONFIG_DIR="$(cd "$search_path" && pwd)"
        break
    fi
done

if [ -z "$INFISICAL_CONFIG_DIR" ]; then
    error "No se encontró agendia-infra/setup/infisical/docker-compose*.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    error "Buscado en:"
    for search_path in "${SEARCH_PATHS[@]}"; do
        error "  - $search_path"
    done
    exit 1
fi

# Cambiar al directorio de configuración
cd "$INFISICAL_CONFIG_DIR"
success "Trabajando desde: $INFISICAL_CONFIG_DIR"
echo ""

# Crear subdirectorios necesarios si no existen
info "📁 Verificando subdirectorios necesarios..."
mkdir -p data/postgres logs backups
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
    error "No se encontró archivo docker-compose en $INFISICAL_CONFIG_DIR"
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
    warning "Puedes crear el archivo manualmente en: $INFISICAL_CONFIG_DIR/$ENV_FILE"
fi
echo ""

# ============================================================================
# Paso 6: Iniciar Infisical
# ============================================================================
info "🚀 Paso 6: Iniciando Infisical..."

# Determinar argumentos de docker-compose
COMPOSE_ARGS="-f $COMPOSE_FILE"
ENV_FILE_ARG=""
if [ -f "$ENV_FILE" ]; then
    # Usar ruta absoluta para el archivo .env (necesario cuando se usa sudo -u)
    ENV_FILE_ABS="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
    ENV_FILE_ARG="--env-file $ENV_FILE_ABS"
    COMPOSE_ARGS="$COMPOSE_ARGS $ENV_FILE_ARG"
fi

info "Usando archivo docker-compose: $COMPOSE_FILE"
if [ -n "$ENV_FILE_ARG" ]; then
    info "Usando archivo .env: $ENV_FILE"
fi

# Cambiar a usuario no-root si es posible
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" $DOCKER_COMPOSE_CMD $COMPOSE_ARGS pull -q
    sudo -u "$SUDO_USER" $DOCKER_COMPOSE_CMD $COMPOSE_ARGS up -d
else
    $DOCKER_COMPOSE_CMD $COMPOSE_ARGS pull -q
    $DOCKER_COMPOSE_CMD $COMPOSE_ARGS up -d
fi

# Esperar a que los servicios inicien
info "Esperando a que los servicios inicien..."
sleep 10

# Verificar estado
if $DOCKER_COMPOSE_CMD $COMPOSE_ARGS ps | grep -q "Up"; then
    success "Infisical iniciado correctamente"
else
    error "Error al iniciar Infisical. Revisa los logs:"
    $DOCKER_COMPOSE_CMD $COMPOSE_ARGS logs --tail=50
    exit 1
fi
echo ""

# ============================================================================
# Configurar Nginx (si se proporcionó dominio)
# ============================================================================
if [ -n "$DOMAIN" ] && [ "$SKIP_NGINX" = false ]; then
    info "🌐 Configurando Nginx para dominio: $DOMAIN"
    
    # Verificar Nginx
    if ! command -v nginx &> /dev/null; then
        error "Nginx no está instalado."
        error "Instala Nginx ejecutando: install-system-deps.sh"
        error "O instala Nginx manualmente: sudo apt install nginx"
        exit 1
    fi
    success "Nginx encontrado: $(nginx -v 2>&1)"
    
    # Crear configuración de Nginx
    cat > "/etc/nginx/sites-available/infisical" << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Habilitar sitio
    ln -sf /etc/nginx/sites-available/infisical /etc/nginx/sites-enabled/
    
    # Verificar configuración
    if nginx -t; then
        systemctl reload nginx
        success "Nginx configurado para $DOMAIN"
        
        # Verificar Certbot y configurar SSL
        info "Configurando SSL con Let's Encrypt..."
        if ! command -v certbot &> /dev/null; then
            error "Certbot no está instalado."
            error "Instala Certbot: sudo apt install certbot python3-certbot-nginx"
            exit 1
        fi
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN --redirect
        
        # Actualizar URLs en .env para usar HTTPS
        if [ -f "$ENV_FILE" ]; then
            sed -i "s|INFISICAL_SERVER_URL=.*|INFISICAL_SERVER_URL=https://$DOMAIN|g" "$ENV_FILE"
            sed -i "s|INFISICAL_SITE_URL=.*|INFISICAL_SITE_URL=https://$DOMAIN|g" "$ENV_FILE"
            
            # Reiniciar Infisical con nuevas URLs
            if [ -n "$SUDO_USER" ]; then
                sudo -u "$SUDO_USER" $DOCKER_COMPOSE_CMD $COMPOSE_ARGS down
                sudo -u "$SUDO_USER" $DOCKER_COMPOSE_CMD $COMPOSE_ARGS up -d
            else
                $DOCKER_COMPOSE_CMD $COMPOSE_ARGS down
                $DOCKER_COMPOSE_CMD $COMPOSE_ARGS up -d
            fi
        fi
        
        success "SSL configurado para $DOMAIN"
    else
        error "Error en configuración de Nginx"
        exit 1
    fi
    echo ""
fi

# ============================================================================
# Configurar firewall
# ============================================================================
info "🔒 Configurando firewall..."

if command -v ufw &> /dev/null; then
    # Permitir SSH (importante hacerlo primero)
    ufw allow 22/tcp > /dev/null 2>&1 || true
    
    if [ -n "$DOMAIN" ]; then
        # Si hay dominio, permitir HTTP y HTTPS
        ufw allow 80/tcp > /dev/null 2>&1 || true
        ufw allow 443/tcp > /dev/null 2>&1 || true
    else
        # Si no hay dominio, permitir puertos directos
        ufw allow 5002/tcp > /dev/null 2>&1 || true
    fi
    
    # Habilitar firewall si no está habilitado
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable > /dev/null 2>&1 || true
    fi
    
    success "Firewall configurado"
else
    warning "UFW no está instalado. Considera instalarlo para mayor seguridad."
    warning "Instala UFW: sudo apt install ufw"
fi
echo ""

# ============================================================================
# Configurar backup automático
# ============================================================================
info "💾 Configurando backup automático..."

if [ -f "backup.sh" ]; then
    chmod +x backup.sh
    # Agregar a crontab para backup diario a las 2 AM
    CRON_JOB="0 2 * * * cd $INFISICAL_CONFIG_DIR && ./backup.sh --env $ENVIRONMENT >> $INFISICAL_CONFIG_DIR/backup.log 2>&1"
    
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
if $DOCKER_COMPOSE_CMD $COMPOSE_ARGS ps | grep -q "Up"; then
    success "Contenedores corriendo"
    $DOCKER_COMPOSE_CMD $COMPOSE_ARGS ps
else
    error "Algunos contenedores no están corriendo"
    $DOCKER_COMPOSE_CMD $COMPOSE_ARGS ps
    exit 1
fi

# Verificar conectividad
info "Verificando conectividad..."
sleep 5

if curl -s -f "$INFISICAL_URL" > /dev/null 2>&1; then
    success "Infisical responde correctamente en $INFISICAL_URL"
else
    warning "Infisical no responde. Revisa los logs: $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE logs infisical"
fi

echo ""

# ============================================================================
# Resumen final
# ============================================================================
success "🎉 Instalación de Infisical completada!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "📋 Información de Acceso:"
if [ -n "$DOMAIN" ]; then
    echo "   🌐 URL: https://$DOMAIN"
else
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "   🌐 URL: http://$SERVER_IP:5002"
    echo "   🌐 URL (localhost): http://localhost:5002"
fi
echo ""
info "📝 Próximos pasos:"
echo "   1. Accede a la URL de Infisical en tu navegador"
echo "   2. Crea tu cuenta de administrador"
echo "   3. Crea el proyecto 'Agendia'"
echo "   4. Crea los entornos necesarios:"
if [ "$ENVIRONMENT" = "local" ]; then
    echo "      - local (este entorno - desarrollo local)"
    echo "      - dev (opcional - desarrollo compartido)"
elif [ "$ENVIRONMENT" = "dev" ]; then
    echo "      - local (opcional - desarrollo local)"
    echo "      - dev (este entorno - desarrollo compartido)"
    echo "      - staging (opcional - para pruebas)"
    echo "      - prod (opcional - para producción)"
elif [ "$ENVIRONMENT" = "staging" ]; then
    echo "      - dev (opcional - desarrollo)"
    echo "      - staging (este entorno - pruebas)"
    echo "      - prod (opcional - producción)"
else
    echo "      - dev (opcional - desarrollo)"
    echo "      - staging (opcional - pruebas)"
    echo "      - prod (este entorno - producción)"
fi
echo "   5. Configura los secretos de base de datos para cada entorno"
echo "   6. Genera Access Tokens o Service Tokens por entorno"
echo ""
info "🔧 Configuración de Entornos en Infisical:"
echo "   - Entorno actual: $ENVIRONMENT"
echo "   - Cada entorno (local, dev, staging, prod) debe tener sus propios secretos"
echo "   - Usa diferentes tokens para cada entorno en los microservicios"
echo "   - Ver: agendia-docs/docs/desarrollo/gestion-secretos.md"
echo ""
info "🔐 Archivos importantes:"
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi
echo "   - Directorio de trabajo: $INFISICAL_CONFIG_DIR"
echo "   - Archivo .env: $INFISICAL_CONFIG_DIR/$ENV_FILE"
echo "   - Logs: $INFISICAL_CONFIG_DIR/logs/"
echo "   - Backups: $INFISICAL_CONFIG_DIR/backups/"
echo ""
info "📝 Nota sobre configuración:"
echo "   - Infisical puede funcionar sin .env (usa valores por defecto)"
echo "   - Para producción, crea un .env con secretos seguros"
echo "   - Los secretos de tu aplicación se gestionan desde la UI de Infisical"
echo ""
info "📚 Comandos útiles:"
echo "   - Ver logs: cd $INFISICAL_CONFIG_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo "   - Reiniciar: cd $INFISICAL_CONFIG_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE restart"
echo "   - Detener: cd $INFISICAL_CONFIG_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down"
echo "   - Backup manual: cd $INFISICAL_CONFIG_DIR && ./backup.sh"
echo ""
info "📖 Documentación:"
echo "   - Ver: agendia-docs/docs/setup/infisical-linux.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
