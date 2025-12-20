#!/bin/bash
# ============================================================================
# Script de Instalación Automática de Infisical en Linux
# ============================================================================
# Este script instala y configura Infisical self-hosted en un servidor Linux
# 
# Uso:
#   ./install.sh [opciones]
#
# Opciones:
#   --url URL              URL del servidor Infisical (default: http://localhost:5002)
#   --domain DOMINIO       Dominio para producción (opcional)
#   --env ENTORNO          Entorno de instalación: local, dev, staging, prod (default: dev)
#   --skip-docker          Omitir instalación de Docker (si ya está instalado)
#   --skip-nginx           Omitir instalación de Nginx (si ya está instalado)
#   --help                 Mostrar esta ayuda
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INFISICAL_DIR="/opt/infisical"
INFISICAL_URL="http://localhost:5002"
DOMAIN=""
ENVIRONMENT="dev"  # local, dev, staging, prod
SKIP_DOCKER=false
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
  --skip-docker          Omitir instalación de Docker (si ya está instalado)
  --skip-nginx           Omitir instalación de Nginx (si ya está instalado)
  --help                 Mostrar esta ayuda

Ejemplos:
  # Instalación básica (desarrollo)
  $0

  # Para entorno local
  $0 --env local

  # Para producción con dominio
  $0 --env prod --domain infisical.tu-dominio.com

  # Omitir instalación de Docker
  $0 --skip-docker

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
        --skip-docker)
            SKIP_DOCKER=true
            shift
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
    exit 1
fi

info "🚀 Iniciando instalación de Infisical..."
info "   Directorio: $INFISICAL_DIR"
info "   URL: $INFISICAL_URL"
info "   Entorno: $ENVIRONMENT"
if [ -n "$DOMAIN" ]; then
    info "   Dominio: $DOMAIN"
fi
echo ""

# ============================================================================
# Paso 1: Actualizar sistema
# ============================================================================
info "📦 Paso 1: Actualizando sistema..."
apt update -qq
apt upgrade -y -qq
success "Sistema actualizado"
echo ""

# ============================================================================
# Paso 2: Instalar Docker
# ============================================================================
if [ "$SKIP_DOCKER" = false ]; then
    info "🐳 Paso 2: Instalando Docker..."
    
    if command -v docker &> /dev/null; then
        warning "Docker ya está instalado: $(docker --version)"
    else
        info "Descargando e instalando Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
        success "Docker instalado: $(docker --version)"
    fi
    
    # Agregar usuario actual al grupo docker
    if [ -n "$SUDO_USER" ]; then
        info "Agregando usuario $SUDO_USER al grupo docker..."
        usermod -aG docker "$SUDO_USER"
        success "Usuario agregado al grupo docker"
    fi
else
    info "🐳 Paso 2: Omitiendo instalación de Docker (--skip-docker)"
    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado. Ejecuta sin --skip-docker o instala Docker manualmente."
        exit 1
    fi
fi
echo ""

# ============================================================================
# Paso 3: Instalar Docker Compose
# ============================================================================
info "📦 Paso 3: Instalando Docker Compose..."

if command -v docker-compose &> /dev/null; then
    warning "Docker Compose ya está instalado: $(docker-compose --version)"
else
    info "Descargando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    success "Docker Compose instalado: $(docker-compose --version)"
fi
echo ""

# ============================================================================
# Paso 4: Crear directorio y copiar archivos
# ============================================================================
info "📁 Paso 4: Configurando directorio de Infisical..."

# Crear directorio (específico por entorno si no es local)
# Para local, usar /opt/infisical
# Para otros entornos, usar /opt/infisical-{entorno}
if [ "$ENVIRONMENT" = "local" ]; then
    INFISICAL_DIR="/opt/infisical"
else
    INFISICAL_DIR="/opt/infisical-$ENVIRONMENT"
fi

mkdir -p "$INFISICAL_DIR"
cd "$INFISICAL_DIR"

# Crear subdirectorios
mkdir -p data/postgres logs backups

# Obtener ruta del script actual y buscar archivos de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Buscar archivos de configuración en agendia-infra/setup/infisical
# Primero intentar desde el directorio del script (si está en agendia-infra)
# Luego intentar desde la raíz del proyecto
INFISICAL_CONFIG_DIR=""
# Buscar cualquier archivo docker-compose*.yml
if [ -f "$SCRIPT_DIR/../../agendia-infra/setup/infisical/docker-compose.dev.yml" ] || [ -f "$SCRIPT_DIR/../../agendia-infra/setup/infisical/docker-compose.yml" ]; then
    INFISICAL_CONFIG_DIR="$SCRIPT_DIR/../../agendia-infra/setup/infisical"
elif [ -f "$(pwd)/agendia-infra/setup/infisical/docker-compose.dev.yml" ] || [ -f "$(pwd)/agendia-infra/setup/infisical/docker-compose.yml" ]; then
    INFISICAL_CONFIG_DIR="$(pwd)/agendia-infra/setup/infisical"
elif [ -f "/opt/agendia/agendia-infra/setup/infisical/docker-compose.dev.yml" ] || [ -f "/opt/agendia/agendia-infra/setup/infisical/docker-compose.yml" ]; then
    INFISICAL_CONFIG_DIR="/opt/agendia/agendia-infra/setup/infisical"
else
    error "No se encontró agendia-infra/setup/infisical/docker-compose*.yml"
    error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
fi

# Copiar archivos de configuración
info "Copiando archivos de configuración desde $INFISICAL_CONFIG_DIR..."
# Intentar copiar docker-compose.dev.yml primero, luego docker-compose.yml
if [ -f "$INFISICAL_CONFIG_DIR/docker-compose.dev.yml" ]; then
    cp "$INFISICAL_CONFIG_DIR/docker-compose.dev.yml" "$INFISICAL_DIR/"
    success "docker-compose.dev.yml copiado"
elif [ -f "$INFISICAL_CONFIG_DIR/docker-compose.yml" ]; then
    cp "$INFISICAL_CONFIG_DIR/docker-compose.yml" "$INFISICAL_DIR/"
    success "docker-compose.yml copiado"
else
    error "No se encontró docker-compose*.yml en $INFISICAL_CONFIG_DIR"
    exit 1
fi

# Verificar archivo .env según entorno
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi

if [ -f "$INFISICAL_DIR/$ENV_FILE" ]; then
    info "Archivo $ENV_FILE encontrado"
else
    info "Archivo $ENV_FILE no encontrado. Usando valores por defecto del docker-compose.yml"
fi

# Copiar scripts auxiliares (si están en el directorio de configuración)
if [ -f "$INFISICAL_CONFIG_DIR/backup.sh" ]; then
    cp "$INFISICAL_CONFIG_DIR/backup.sh" "$INFISICAL_DIR/"
    chmod +x "$INFISICAL_DIR/backup.sh"
    success "backup.sh copiado"
elif [ -f "$SCRIPT_DIR/backup.sh" ]; then
    cp "$SCRIPT_DIR/backup.sh" "$INFISICAL_DIR/"
    chmod +x "$INFISICAL_DIR/backup.sh"
    success "backup.sh copiado"
fi

# Cambiar propietario si hay un usuario sudo
if [ -n "$SUDO_USER" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$INFISICAL_DIR"
    success "Permisos configurados para usuario $SUDO_USER"
fi

success "Directorio configurado: $INFISICAL_DIR"
echo ""

# ============================================================================
# Paso 5: Configuración completada
# ============================================================================
success "Configuración de directorios completada"
echo ""

# ============================================================================
# Paso 6: Iniciar Infisical
# ============================================================================
info "🚀 Paso 6: Iniciando Infisical..."

cd "$INFISICAL_DIR"
    
# Determinar archivo .env
ENV_FILE=".env.$ENVIRONMENT"
    if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
    fi

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
    error "Archivo docker-compose no encontrado: $COMPOSE_FILE"
    error "Asegúrate de que el archivo existe en el directorio actual"
    exit 1
fi

info "Usando archivo docker-compose: $COMPOSE_FILE"
    
# Cambiar a usuario no-root si es posible
COMPOSE_ARGS="-f $COMPOSE_FILE"
ENV_FILE_ARG=""
if [ -f "$ENV_FILE" ]; then
    ENV_FILE_ARG="--env-file $ENV_FILE"
    COMPOSE_ARGS="$COMPOSE_ARGS $ENV_FILE_ARG"
fi

if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS pull -q
    sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS up -d
else
    docker-compose $COMPOSE_ARGS pull -q
    docker-compose $COMPOSE_ARGS up -d
fi

# Esperar a que los servicios inicien
info "Esperando a que los servicios inicien..."
sleep 10

# Verificar estado
if docker-compose $COMPOSE_ARGS ps | grep -q "Up"; then
    success "Infisical iniciado correctamente"
else
    error "Error al iniciar Infisical. Revisa los logs:"
    docker-compose $COMPOSE_ARGS logs --tail=50
    exit 1
fi
echo ""

# ============================================================================
# Paso 8: Configurar Nginx (si se proporcionó dominio)
# ============================================================================
if [ -n "$DOMAIN" ] && [ "$SKIP_NGINX" = false ]; then
    info "🌐 Paso 8: Configurando Nginx para dominio: $DOMAIN"
    
    # Instalar Nginx
    if ! command -v nginx &> /dev/null; then
        apt install -y nginx
        success "Nginx instalado"
    else
        warning "Nginx ya está instalado"
    fi
    
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
        
        # Instalar Certbot y configurar SSL
        info "Configurando SSL con Let's Encrypt..."
        apt install -y certbot python3-certbot-nginx
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN --redirect
        
        # Actualizar URLs en .env para usar HTTPS
        sed -i "s|INFISICAL_SERVER_URL=.*|INFISICAL_SERVER_URL=https://$DOMAIN|g" "$INFISICAL_DIR/.env"
        sed -i "s|INFISICAL_SITE_URL=.*|INFISICAL_SITE_URL=https://$DOMAIN|g" "$INFISICAL_DIR/.env"
        
        # Reiniciar Infisical con nuevas URLs
        cd "$INFISICAL_DIR"
        # COMPOSE_ARGS ya está definido arriba con el archivo correcto
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS down
            sudo -u "$SUDO_USER" docker-compose $COMPOSE_ARGS up -d
        else
            docker-compose $COMPOSE_ARGS down
            docker-compose $COMPOSE_ARGS up -d
        fi
        
        success "SSL configurado para $DOMAIN"
    else
        error "Error en configuración de Nginx"
        exit 1
    fi
    echo ""
fi

# ============================================================================
# Paso 8: Configurar firewall
# ============================================================================
info "🔒 Paso 9: Configurando firewall..."

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
fi
echo ""

# ============================================================================
# Paso 10: Configurar backup automático
# ============================================================================
info "💾 Paso 10: Configurando backup automático..."

if [ -f "$INFISICAL_DIR/backup.sh" ]; then
    # Agregar a crontab para backup diario a las 2 AM
    CRON_JOB="0 2 * * * cd $INFISICAL_DIR && ./backup.sh --env $ENVIRONMENT >> $INFISICAL_DIR/backup.log 2>&1"
    
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
# Paso 10: Verificación final
# ============================================================================
info "✅ Paso 11: Verificando instalación..."

cd "$INFISICAL_DIR"

# Determinar archivo .env para verificación
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi
ENV_FILE_ARG=""
if [ -f "$ENV_FILE" ]; then
    ENV_FILE_ARG="--env-file $ENV_FILE"
fi

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

if curl -s -f "http://localhost:5002" > /dev/null 2>&1; then
    success "Infisical responde correctamente en http://localhost:5002"
else
    warning "Infisical no responde. Revisa los logs: docker-compose -f $COMPOSE_FILE logs infisical"
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
echo "   - Ver: agendia-infra/setup/infisical/ENTORNOS.md"
echo "   - Ver: ../../../agendia-docs/docs/desarrollo/gestion-secretos.md"
echo ""
info "🔐 Archivos importantes:"
ENV_FILE=".env.$ENVIRONMENT"
if [ "$ENVIRONMENT" = "local" ]; then
    ENV_FILE=".env"
fi
echo "   - Archivo .env: $INFISICAL_DIR/$ENV_FILE"
echo "   - Logs: $INFISICAL_DIR/logs/"
echo "   - Backups: $INFISICAL_DIR/backups/"
echo ""
info "📝 Nota sobre configuración:"
echo "   - Infisical puede funcionar sin .env (usa valores por defecto)"
echo "   - Para producción, crea un .env con secretos seguros"
echo "   - Los secretos de tu aplicación se gestionan desde la UI de Infisical"
echo ""
info "📚 Comandos útiles:"
echo "   - Ver logs: cd $INFISICAL_DIR && docker-compose -f $COMPOSE_FILE logs -f"
echo "   - Reiniciar: cd $INFISICAL_DIR && docker-compose -f $COMPOSE_FILE restart"
echo "   - Detener: cd $INFISICAL_DIR && docker-compose -f $COMPOSE_FILE down"
echo "   - Backup manual: cd $INFISICAL_DIR && ./backup.sh"
echo ""
info "📖 Documentación:"
echo "   - Ver: ../../../agendia-docs/docs/setup/infisical-linux.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
