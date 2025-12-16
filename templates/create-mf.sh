#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "❌ Error: Nombre del microfrontend requerido"
  echo ""
  echo "Usage: ./create-mf.sh <mf-name>"
  echo "Example: ./create-mf.sh agenda"
  echo ""
  exit 1
fi

MF_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"
TEMPLATE_DIR="$ROOT_DIR/agendia-template-mf"
MF_DIR="$ROOT_DIR/agendia-mf-${MF_NAME}"
SHELL_DIR="$ROOT_DIR/agendia-mf-shell"
SHELL_ROUTES="$SHELL_DIR/src/config/routes.config.ts"
SHELL_ENV="$SHELL_DIR/.env.dev"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: Template directory not found at $TEMPLATE_DIR"
  exit 1
fi

EXISTING_DIR=false
if [ -d "$MF_DIR" ]; then
  echo "⚠️  El directorio ${MF_DIR} ya existe"
  echo "   Actualizando solo archivos de configuración..."
  EXISTING_DIR=true
else
  echo "🚀 Creando microfrontend: ${MF_NAME}"
fi

find_available_port() {
  local start_port=3001
  local port=$start_port
  
  while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
    port=$((port + 1))
    if [ $port -gt 3100 ]; then
      echo "❌ Error: No se encontró un puerto disponible"
      exit 1
    fi
  done
  
  echo $port
}

PORT=$(find_available_port)
MF_NAME_UNDERSCORE=$(echo "$MF_NAME" | tr '-' '_')
MF_NAME_CAMEL=$(echo "$MF_NAME" | sed 's/-\([a-z]\)/\U\1/g' | sed 's/^./\U&/')
MF_DISPLAY_NAME=$(echo "$MF_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

echo "📋 Configuración:"
echo "   - Nombre: ${MF_NAME}"
echo "   - Puerto: ${PORT}"
echo "   - Ruta: /${MF_NAME}"
echo ""

if [ "$EXISTING_DIR" = false ]; then
  echo "📁 Copiando template..."
  cp -r "$TEMPLATE_DIR" "$MF_DIR"
fi

cd "$MF_DIR"

echo "🔧 Actualizando package.json..."
sed -i.bak "s/@agendia\/mf-template/@agendia\/mf-${MF_NAME}/g" package.json
sed -i.bak "s/Template base para crear nuevos microfrontends/Microfrontend ${MF_DISPLAY_NAME}/g" package.json
rm package.json.bak

echo "🔧 Actualizando vite.config.ts..."
sed -i.bak "s/mf_template/mf_${MF_NAME_UNDERSCORE}/g" vite.config.ts
sed -i.bak "s/3001/${PORT}/g" vite.config.ts
rm vite.config.ts.bak

echo "🔧 Actualizando root.config.ts..."
sed -i.bak "s/mf_template/mf-${MF_NAME}/g" src/config/root.config.ts
sed -i.bak "s/\/template/\/${MF_NAME}/g" src/config/root.config.ts
sed -i.bak "s/Template/${MF_DISPLAY_NAME}/g" src/config/root.config.ts
rm src/config/root.config.ts.bak

echo "🔧 Creando .env.dev..."
cat > .env.dev << EOF
VITE_PORT=${PORT}
VITE_MF_NAME=mf-${MF_NAME}
VITE_MF_ROUTE_PREFIX=/${MF_NAME}
EOF

if [ "$EXISTING_DIR" = false ]; then
  echo "🧹 Limpiando archivos temporales..."
  rm -rf node_modules dist .git .env.example
fi

if [ -d "$SHELL_DIR" ]; then
  echo "🔧 Actualizando shell..."
  
  ENV_VAR_NAME="VITE_MF_$(echo "$MF_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_URL"
  ENV_LINE="${ENV_VAR_NAME}=http://localhost:${PORT}"
  
  if [ -f "$SHELL_ENV" ]; then
    if ! grep -q "^${ENV_VAR_NAME}=" "$SHELL_ENV"; then
      echo "" >> "$SHELL_ENV"
      echo "$ENV_LINE" >> "$SHELL_ENV"
      echo "✅ Agregado ${ENV_VAR_NAME} a .env.dev del shell"
    fi
  else
    echo "$ENV_LINE" > "$SHELL_ENV"
    echo "✅ Creado .env.dev en el shell"
  fi
  
  if [ -f "$SHELL_ROUTES" ]; then
    MF_CONFIG="  {
    name: 'mf_${MF_NAME_UNDERSCORE}',
    url: normalizeMFUrl(import.meta.env.${ENV_VAR_NAME}),
    routePrefix: '/${MF_NAME}',
    requiresAuth: false,
    displayName: '${MF_DISPLAY_NAME}',
    icon: '${MF_NAME}',
    order: 999,
  },"
    
    if ! grep -q "mf_${MF_NAME_UNDERSCORE}" "$SHELL_ROUTES"; then
      sed -i.bak "/export const MICROFRONTENDS: MFConfig\[\] = \[/a\\
${MF_CONFIG}" "$SHELL_ROUTES"
      rm "$SHELL_ROUTES.bak"
      echo "✅ Agregado mf_${MF_NAME_UNDERSCORE} a routes.config.ts"
    fi
  fi
fi

echo ""
echo "✅ Microfrontend ${MF_NAME} creado exitosamente!"
echo "📁 Ubicación: ${MF_DIR}"
echo ""
echo "🚀 Próximos pasos:"
echo "   1. cd ${MF_DIR}"
echo "   2. npm install"
echo "   3. npm run dev"
echo ""
if [ -d "$SHELL_DIR" ]; then
  echo "💡 El microfrontend ya está registrado en el shell"
  echo "   Solo necesitas reiniciar el shell para que lo detecte"
fi
