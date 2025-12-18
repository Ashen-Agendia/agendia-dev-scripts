#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "❌ Error: Nombre del microservicio requerido"
  echo ""
  echo "Usage: ./create-ms.sh <ms-name>"
  echo "Example: ./create-ms.sh agenda"
  echo ""
  exit 1
fi

MS_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"
TEMPLATE_DIR="$ROOT_DIR/agendia-template-ms"
MS_DIR="$ROOT_DIR/agendia-ms-${MS_NAME}"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: Template directory not found at $TEMPLATE_DIR"
  exit 1
fi

EXISTING_DIR=false
if [ -d "$MS_DIR" ]; then
  echo "⚠️  El directorio ${MS_DIR} ya existe"
  echo "   Actualizando solo archivos de configuración..."
  EXISTING_DIR=true
else
  echo "🚀 Creando microservicio: ${MS_NAME}"
fi

find_available_port() {
  local start_port=4001
  local port=$start_port
  
  while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
    port=$((port + 1))
    if [ $port -gt 4100 ]; then
      echo "❌ Error: No se encontró un puerto disponible entre 4001-4100"
      exit 1
    fi
  done
  
  echo $port
}

PORT=$(find_available_port)
MS_NAME_DASH="agendia-ms-${MS_NAME}"

echo "📋 Configuración:"
echo "   - Nombre: ${MS_NAME_DASH}"
echo "   - Puerto: ${PORT}"
echo ""

if [ "$EXISTING_DIR" = false ]; then
  echo "📁 Copiando template..."
  cp -r "$TEMPLATE_DIR" "$MS_DIR"
fi

cd "$MS_DIR"

APP_CONF="src/main/resources/application.conf"
OPENAPI_SPEC="src/main/resources/openapi.yaml"
README_FILE="README.md"

if [ -f "$APP_CONF" ]; then
  echo "🔧 Actualizando application.conf..."
  sed -i.bak "s/agendia-template-ms/${MS_NAME_DASH}/g" "$APP_CONF"
  sed -i.bak "s/port      = .*/port      = ${PORT}/g" "$APP_CONF"
  rm "$APP_CONF.bak"
fi

if [ -f "$OPENAPI_SPEC" ]; then
  echo "🔧 Actualizando openapi.yaml..."
  sed -i.bak "s/Agendia Template Microservice/Agendia ${MS_NAME^} Microservice/g" "$OPENAPI_SPEC" || true
  sed -i.bak "s#url: http://localhost:[0-9]\+#url: http://localhost:${PORT}#g" "$OPENAPI_SPEC"
  rm "$OPENAPI_SPEC.bak" 2>/dev/null || true
fi

if [ -f "$README_FILE" ]; then
  echo "🔧 Actualizando README.md..."
  sed -i.bak "s/agendia-template-ms/${MS_NAME_DASH}/g" "$README_FILE"
  sed -i.bak "s/localhost:8080/localhost:${PORT}/g" "$README_FILE"
  rm "$README_FILE.bak"
fi

if [ "$EXISTING_DIR" = false ]; then
  echo "🧹 Limpiando archivos temporales de template (si aplica)..."
  rm -rf .git
fi

echo ""
echo "✅ Microservicio ${MS_NAME_DASH} creado/actualizado exitosamente!"
echo "📁 Ubicación: ${MS_DIR}"
echo ""
echo "🚀 Próximos pasos:"
echo "   1. cd ${MS_DIR}"
echo "   2. sbt compile"
echo "   3. sbt run"
echo ""