#!/bin/bash

# Script para instalar todas las dependencias del sistema necesarias para Agendia
# Verifica e instala: Node.js, npm, Java, sbt, gh, jq, Docker, Docker Compose

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar versión mínima
check_version() {
    local cmd=$1
    local min_version=$2
    local current_version=$3
    
    if [ -z "$current_version" ]; then
        return 1
    fi
    
    # Comparación simple de versiones (mayor o igual)
    printf '%s\n%s\n' "$min_version" "$current_version" | sort -V -C
}

# Función para detectar gestor de paquetes
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Función para instalar Node.js y npm
install_nodejs() {
    local pm=$1
    
    echo -e "${BLUE}📦 Instalando Node.js y npm...${NC}"
    
    if [ "$pm" = "apt" ]; then
        # Ubuntu/Debian - usar NodeSource para versión más reciente
        if ! command_exists node; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    elif [ "$pm" = "dnf" ]; then
        # Fedora
        sudo dnf install -y nodejs npm
    elif [ "$pm" = "yum" ]; then
        # CentOS/RHEL
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    elif [ "$pm" = "brew" ]; then
        # macOS
        brew install node
    else
        echo -e "${YELLOW}⚠️  Instala Node.js manualmente desde: https://nodejs.org/${NC}"
        return 1
    fi
    
    # Verificar instalación
    if command_exists node && command_exists npm; then
        local node_version=$(node --version | sed 's/v//')
        local npm_version=$(npm --version)
        echo -e "${GREEN}✅ Node.js ${node_version} y npm ${npm_version} instalados${NC}"
        return 0
    else
        echo -e "${RED}❌ Error instalando Node.js/npm${NC}"
        return 1
    fi
}

# Función para instalar Java
install_java() {
    local pm=$1
    
    echo -e "${BLUE}☕ Instalando Java (OpenJDK 11+)...${NC}"
    
    if [ "$pm" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y openjdk-11-jdk
    elif [ "$pm" = "dnf" ]; then
        sudo dnf install -y java-11-openjdk-devel
    elif [ "$pm" = "yum" ]; then
        sudo yum install -y java-11-openjdk-devel
    elif [ "$pm" = "brew" ]; then
        brew install openjdk@11
    else
        echo -e "${YELLOW}⚠️  Instala Java 11+ manualmente${NC}"
        return 1
    fi
    
    # Verificar instalación
    if command_exists java; then
        local java_version=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d'.' -f1)
        if [ "$java_version" -ge 11 ]; then
            echo -e "${GREEN}✅ Java ${java_version}+ instalado${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ Error instalando Java${NC}"
    return 1
}

# Función para instalar sbt
install_sbt() {
    local pm=$1
    
    echo -e "${BLUE}🔧 Instalando sbt (Scala Build Tool)...${NC}"
    
    if [ "$pm" = "apt" ]; then
        # Método 1: Intentar con repositorio oficial
        echo -e "${YELLOW}   Intentando método 1: Repositorio oficial...${NC}"
        
        # Instalar dependencias necesarias
        sudo apt-get update
        sudo apt-get install -y curl gnupg2
        
        # Agregar clave GPG primero
        if ! curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo gpg --dearmor -o /usr/share/keyrings/sbt-archive-keyring.gpg 2>/dev/null; then
            echo -e "${YELLOW}   ⚠️  No se pudo agregar la clave GPG desde keyserver.ubuntu.com${NC}"
            echo -e "${YELLOW}   Intentando método alternativo...${NC}"
            
            # Método alternativo: descargar clave directamente
            if ! curl -fsSL https://repo.scala-sbt.org/scalasbt/debian/sbt-archive-keyring.gpg | sudo tee /usr/share/keyrings/sbt-archive-keyring.gpg > /dev/null 2>&1; then
                echo -e "${YELLOW}   ⚠️  Método alternativo falló, intentando instalación manual...${NC}"
            fi
        fi
        
        if [ -f /usr/share/keyrings/sbt-archive-keyring.gpg ]; then
            sudo chmod go+r /usr/share/keyrings/sbt-archive-keyring.gpg
            
            # Agregar repositorio
            echo "deb [signed-by=/usr/share/keyrings/sbt-archive-keyring.gpg] https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list > /dev/null
            
            sudo apt-get update
            
            if sudo apt-get install -y sbt 2>/dev/null; then
                return 0
            fi
        fi
        
        # Método 2: Intentar con apt-key (deprecated pero funciona en Debian antiguo)
        echo -e "${YELLOW}   Intentando método 2: Usando apt-key (compatible con Debian antiguo)...${NC}"
        
        # Limpiar intentos anteriores
        sudo rm -f /etc/apt/sources.list.d/sbt*.list /usr/share/keyrings/sbt-archive-keyring.gpg 2>/dev/null
        
        if curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add - 2>/dev/null; then
            echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list > /dev/null
            sudo apt-get update
            
            if sudo apt-get install -y sbt 2>/dev/null; then
                return 0
            fi
        fi
        
        # Método 3: Instalación manual desde binario
        echo -e "${YELLOW}   Intentando método 3: Instalación manual desde binario...${NC}"
        
        local sbt_version="1.10.2"
        local temp_dir=$(mktemp -d)
        
        cd "$temp_dir" || return 1
        
        # Descargar sbt como zip (más común)
        if curl -fsSL "https://github.com/sbt/sbt/releases/download/v${sbt_version}/sbt-${sbt_version}.zip" -o sbt.zip; then
            if command_exists unzip; then
                unzip -q sbt.zip
                if [ -d "sbt" ]; then
                    sudo mv sbt /usr/local/
                    sudo ln -sf /usr/local/sbt/bin/sbt /usr/local/bin/sbt
                    sudo chmod +x /usr/local/bin/sbt
                    
                    cd - > /dev/null
                    rm -rf "$temp_dir"
                    
                    if command_exists sbt; then
                        return 0
                    fi
                fi
            fi
        fi
        
        cd - > /dev/null
        rm -rf "$temp_dir"
        
        # Método 4: Usar SDKMAN o sugerir instalación manual
        echo -e "${YELLOW}   ⚠️  Los métodos automáticos fallaron.${NC}"
        echo ""
        echo -e "${YELLOW}   Opciones alternativas:${NC}"
        echo ""
        echo "   1. Instalar usando SDKMAN (recomendado):"
        echo "      curl -s \"https://get.sdkman.io\" | bash"
        echo "      source \"\$HOME/.sdkman/bin/sdkman-init.sh\""
        echo "      sdk install sbt"
        echo ""
        echo "   2. Descargar manualmente desde:"
        echo "      https://www.scala-sbt.org/download.html"
        echo ""
        return 1
    elif [ "$pm" = "dnf" ]; then
        # Fedora - sbt puede estar en repositorios
        if ! sudo dnf install -y sbt 2>/dev/null; then
            echo -e "${YELLOW}⚠️  sbt no está en repositorios estándar. Instalación manual requerida.${NC}"
            echo "   Ver: https://www.scala-sbt.org/download.html"
            return 1
        fi
    elif [ "$pm" = "yum" ]; then
        # CentOS/RHEL
        if ! sudo yum install -y sbt 2>/dev/null; then
            echo -e "${YELLOW}⚠️  sbt no está en repositorios estándar. Instalación manual requerida.${NC}"
            echo "   Ver: https://www.scala-sbt.org/download.html"
            return 1
        fi
    elif [ "$pm" = "brew" ]; then
        brew install sbt
    else
        echo -e "${YELLOW}⚠️  Instala sbt manualmente desde: https://www.scala-sbt.org/download.html${NC}"
        return 1
    fi
    
    # Verificar instalación
    if command_exists sbt; then
        local sbt_version=$(sbt --version 2>&1 | head -n 1 | awk '{print $NF}')
        echo -e "${GREEN}✅ sbt ${sbt_version} instalado${NC}"
        return 0
    else
        echo -e "${RED}❌ Error instalando sbt${NC}"
        return 1
    fi
}

# Función para instalar GitHub CLI
install_gh() {
    local pm=$1
    
    echo -e "${BLUE}🐙 Instalando GitHub CLI (gh)...${NC}"
    
    if [ "$pm" = "apt" ]; then
        if ! sudo apt-get install -y gh 2>/dev/null; then
            # Agregar repositorio oficial
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y gh
        fi
    elif [ "$pm" = "dnf" ]; then
        if ! sudo dnf install -y gh 2>/dev/null; then
            sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo dnf install -y gh
        fi
    elif [ "$pm" = "yum" ]; then
        if ! sudo yum install -y gh 2>/dev/null; then
            sudo yum config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo yum install -y gh
        fi
    elif [ "$pm" = "brew" ]; then
        brew install gh
    else
        echo -e "${YELLOW}⚠️  Instala gh manualmente desde: https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
        return 1
    fi
    
    # Verificar instalación
    if command_exists gh; then
        local gh_version=$(gh --version | head -n 1 | awk '{print $3}')
        echo -e "${GREEN}✅ GitHub CLI ${gh_version} instalado${NC}"
        return 0
    else
        echo -e "${RED}❌ Error instalando GitHub CLI${NC}"
        return 1
    fi
}

# Función para instalar jq
install_jq() {
    local pm=$1
    
    echo -e "${BLUE}🔍 Instalando jq...${NC}"
    
    if [ "$pm" = "apt" ]; then
        sudo apt-get install -y jq
    elif [ "$pm" = "dnf" ]; then
        sudo dnf install -y jq
    elif [ "$pm" = "yum" ]; then
        sudo yum install -y jq
    elif [ "$pm" = "brew" ]; then
        brew install jq
    else
        echo -e "${YELLOW}⚠️  Instala jq manualmente desde: https://stedolan.github.io/jq/download/${NC}"
        return 1
    fi
    
    # Verificar instalación
    if command_exists jq; then
        local jq_version=$(jq --version | sed 's/jq-//')
        echo -e "${GREEN}✅ jq ${jq_version} instalado${NC}"
        return 0
    else
        echo -e "${RED}❌ Error instalando jq${NC}"
        return 1
    fi
}

# Función para instalar Docker
install_docker() {
    local pm=$1
    
    echo -e "${BLUE}🐳 Instalando Docker...${NC}"
    
    if [ "$pm" = "apt" ]; then
        # Ubuntu/Debian - usar script oficial de Docker
        if ! command_exists docker; then
            # Instalar dependencias previas
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            
            # Agregar clave GPG oficial de Docker
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Agregar repositorio de Docker
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Instalar Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
    elif [ "$pm" = "dnf" ]; then
        # Fedora
        if ! command_exists docker; then
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
    elif [ "$pm" = "yum" ]; then
        # CentOS/RHEL
        if ! command_exists docker; then
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
    elif [ "$pm" = "brew" ]; then
        # macOS - Docker Desktop
        if ! command_exists docker; then
            echo -e "${YELLOW}⚠️  En macOS, instala Docker Desktop manualmente desde: https://www.docker.com/products/docker-desktop${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Instala Docker manualmente desde: https://docs.docker.com/get-docker/${NC}"
        return 1
    fi
    
    # Iniciar y habilitar servicio Docker (solo en Linux)
    if [ "$pm" != "brew" ]; then
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # Verificar instalación
    if command_exists docker; then
        local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        echo -e "${GREEN}✅ Docker ${docker_version} instalado${NC}"
        
        # Agregar usuario actual al grupo docker (si no es root)
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            if ! groups "$SUDO_USER" | grep -q docker; then
                sudo usermod -aG docker "$SUDO_USER"
                echo -e "${YELLOW}⚠️  Usuario $SUDO_USER agregado al grupo docker${NC}"
                echo -e "${YELLOW}   Cierra sesión y vuelve a iniciar sesión para aplicar los cambios${NC}"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}❌ Error instalando Docker${NC}"
        return 1
    fi
}

# Función para instalar Docker Compose
install_docker_compose() {
    local pm=$1
    
    echo -e "${BLUE}📦 Instalando Docker Compose...${NC}"
    
    # Verificar si docker-compose-plugin ya está instalado (Docker Compose v2)
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version | awk '{print $4}')
        echo -e "${GREEN}✅ Docker Compose ${compose_version} (plugin) ya está instalado${NC}"
        return 0
    fi
    
    # Verificar si docker-compose (standalone) ya está instalado
    if command_exists docker-compose; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        echo -e "${GREEN}✅ Docker Compose ${compose_version} (standalone) ya está instalado${NC}"
        return 0
    fi
    
    # Si docker-compose-plugin no está disponible, instalar standalone
    local compose_version="v2.24.0"
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # Mapear arquitectura
    case "$arch" in
        x86_64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            echo -e "${YELLOW}⚠️  Arquitectura no soportada: $arch${NC}"
            echo -e "${YELLOW}   Instala Docker Compose manualmente desde: https://docs.docker.com/compose/install/${NC}"
            return 1
            ;;
    esac
    
    # Descargar e instalar Docker Compose standalone
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-${os}-${arch}"
    local compose_path="/usr/local/bin/docker-compose"
    
    if sudo curl -L "$compose_url" -o "$compose_path"; then
        sudo chmod +x "$compose_path"
        
        if command_exists docker-compose; then
            local installed_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
            echo -e "${GREEN}✅ Docker Compose ${installed_version} instalado${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ Error instalando Docker Compose${NC}"
    echo -e "${YELLOW}   Instala Docker Compose manualmente desde: https://docs.docker.com/compose/install/${NC}"
    return 1
}

# Función principal de instalación
install_dependencies() {
    local missing_deps=()
    local pm=$(detect_package_manager)
    
    echo -e "${BLUE}🔍 Verificando dependencias del sistema...${NC}"
    echo ""
    
    # Verificar Node.js (versión 18+)
    if ! command_exists node; then
        missing_deps+=("nodejs")
    else
        local node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
        if [ "$node_version" -lt 18 ]; then
            echo -e "${YELLOW}⚠️  Node.js versión ${node_version} detectada, se requiere 18+${NC}"
            missing_deps+=("nodejs")
        else
            echo -e "${GREEN}✅ Node.js $(node --version)${NC}"
        fi
    fi
    
    # Verificar npm
    if ! command_exists npm; then
        missing_deps+=("npm")
    else
        echo -e "${GREEN}✅ npm $(npm --version)${NC}"
    fi
    
    # Verificar Java (versión 11+)
    if ! command_exists java; then
        missing_deps+=("java")
    else
        local java_version=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d'.' -f1)
        if [ -z "$java_version" ] || [ "$java_version" -lt 11 ]; then
            echo -e "${YELLOW}⚠️  Java versión antigua detectada, se requiere 11+${NC}"
            missing_deps+=("java")
        else
            echo -e "${GREEN}✅ Java $(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')${NC}"
        fi
    fi
    
    # Verificar sbt
    if ! command_exists sbt; then
        missing_deps+=("sbt")
    else
        echo -e "${GREEN}✅ sbt $(sbt --version 2>&1 | head -n 1 | awk '{print $NF}')${NC}"
    fi
    
    # Verificar gh (opcional pero recomendado)
    if ! command_exists gh; then
        missing_deps+=("gh")
    else
        echo -e "${GREEN}✅ GitHub CLI $(gh --version | head -n 1 | awk '{print $3}')${NC}"
    fi
    
    # Verificar jq (opcional pero recomendado)
    if ! command_exists jq; then
        missing_deps+=("jq")
    else
        echo -e "${GREEN}✅ jq $(jq --version | sed 's/jq-//')${NC}"
    fi
    
    # Verificar Docker
    if ! command_exists docker; then
        missing_deps+=("docker")
    else
        echo -e "${GREEN}✅ Docker $(docker --version | awk '{print $3}' | sed 's/,//')${NC}"
    fi
    
    # Verificar Docker Compose (plugin o standalone)
    if ! docker compose version &> /dev/null && ! command_exists docker-compose; then
        missing_deps+=("docker-compose")
    else
        if docker compose version &> /dev/null; then
            echo -e "${GREEN}✅ Docker Compose $(docker compose version | awk '{print $4}') (plugin)${NC}"
        else
            echo -e "${GREEN}✅ Docker Compose $(docker-compose --version | awk '{print $3}' | sed 's/,//') (standalone)${NC}"
        fi
    fi
    
    echo ""
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Todas las dependencias están instaladas${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  Faltan las siguientes dependencias: ${missing_deps[*]}${NC}"
    echo ""
    
    if [ "$pm" = "unknown" ]; then
        echo -e "${RED}❌ No se detectó un gestor de paquetes compatible.${NC}"
        echo ""
        echo "Por favor instala las dependencias manualmente:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                nodejs|npm)
                    echo "  - Node.js/npm: https://nodejs.org/"
                    ;;
                java)
                    echo "  - Java: https://adoptium.net/"
                    ;;
                sbt)
                    echo "  - sbt: https://www.scala-sbt.org/download.html"
                    ;;
                gh)
                    echo "  - GitHub CLI: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
                    ;;
                jq)
                    echo "  - jq: https://stedolan.github.io/jq/download/"
                    ;;
                docker)
                    echo "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                docker-compose)
                    echo "  - Docker Compose: https://docs.docker.com/compose/install/"
                    ;;
            esac
        done
        return 1
    fi
    
    echo -e "${BLUE}🚀 Instalando dependencias faltantes...${NC}"
    echo ""
    
    local failed=0
    
    for dep in "${missing_deps[@]}"; do
        case $dep in
            nodejs|npm)
                if ! install_nodejs "$pm"; then
                    ((failed++))
                fi
                ;;
            java)
                if ! install_java "$pm"; then
                    ((failed++))
                fi
                ;;
            sbt)
                if ! install_sbt "$pm"; then
                    ((failed++))
                fi
                ;;
            gh)
                if ! install_gh "$pm"; then
                    ((failed++))
                fi
                ;;
            jq)
                if ! install_jq "$pm"; then
                    ((failed++))
                fi
                ;;
            docker)
                if ! install_docker "$pm"; then
                    ((failed++))
                fi
                ;;
            docker-compose)
                if ! install_docker_compose "$pm"; then
                    ((failed++))
                fi
                ;;
        esac
        echo ""
    done
    
    if [ $failed -gt 0 ]; then
        echo -e "${RED}❌ Algunas dependencias no se pudieron instalar${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Todas las dependencias instaladas correctamente${NC}"
    return 0
}

# Ejecutar instalación
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Instalador de Dependencias del Sistema"
echo "   Agendia Development Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! install_dependencies; then
    echo ""
    echo -e "${RED}❌ Error: No se pudieron instalar todas las dependencias necesarias.${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 ¡Instalación completada!${NC}"
echo ""
echo "Próximos pasos:"
echo "  1. Ejecuta: ./repos/clone-all-repos.sh (si aún no has clonado los repos)"
echo "  2. Ejecuta: ./microfrontends/install-all-mf.sh (instalar dependencias de MFs)"
echo "  3. Ejecuta: ./microservices/install-all-ms.sh (instalar dependencias de MSs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
