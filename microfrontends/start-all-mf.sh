#!/bin/bash

echo "🚀 Iniciando todos los microfrontends en desarrollo..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

MF_DIRS=(
  "agendia-template-mf"
  "agendia-mf-shell"
  "agendia-mf-auth"
  "agendia-mf-agenda"
  "agendia-mf-sales"
  "agendia-mf-clients"
  "agendia-mf-dashboard"
  "agendia-mf-organization"
  "agendia-mf-platform"
  "agendia-mf-landing"
  "agendia-mf-public-booking"
)

PIDS_FILE="$SCRIPTS_ROOT/.mf-pids"
LOGS_DIR="$SCRIPTS_ROOT/logs"
STARTED=0
SKIPPED=0
FAILED=0

# Limpiar archivo de PIDs anterior
if [ -f "$PIDS_FILE" ]; then
  rm "$PIDS_FILE"
fi

# Crear directorio de logs si no existe
mkdir -p "$LOGS_DIR"

for dirName in "${MF_DIRS[@]}"; do
  dirPath="$ROOT_DIR/$dirName"
  packageJsonPath="$dirPath/package.json"
  
  if [ -d "$dirPath" ] && [ -f "$packageJsonPath" ]; then
    echo "🚀 Iniciando $dirName..."
    
    cd "$dirPath" || continue
    
    # Iniciar en background y guardar el PID
    npm run dev > "$LOGS_DIR/${dirName}.log" 2> "$LOGS_DIR/${dirName}.error.log" &
    PID=$!
    echo "$PID:$dirName" >> "$PIDS_FILE"
    
    cd "$ROOT_DIR" || continue
    
    if kill -0 $PID 2>/dev/null; then
      echo "   ✅ $dirName iniciado (PID: $PID)"
      ((STARTED++))
      sleep 1
    else
      echo "   ❌ Error iniciando $dirName"
      ((FAILED++))
    fi
  else
    echo "   ⏭️  Saltando $dirName (no existe o no tiene package.json)"
    ((SKIPPED++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Iniciados: $STARTED"
echo "   ⏭️  Saltados: $SKIPPED"
echo "   ❌ Fallidos: $FAILED"
echo ""
echo "📝 Logs guardados en: $LOGS_DIR"
echo "🛑 Para detener todos: ./stop-all-mf.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STARTED -gt 0 ]; then
  echo ""
  echo "💡 Los microfrontends están corriendo en background."
  echo "   Revisa los logs en logs/ para ver el output de cada uno."
fi

