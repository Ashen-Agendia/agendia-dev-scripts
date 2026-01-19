#!/bin/bash

echo "🚀 Iniciando todos los microservicios en desarrollo..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

MS_DIRS=(
  "agendia-template-ms"
  "agendia-ms-auth"
  "agendia-ms-agenda"
  "agendia-ms-clients"
  "agendia-ms-notifications"
  "agendia-ms-organization"
  "agendia-ms-platform"
  "agendia-ms-sales"
)

PIDS_FILE="$SCRIPTS_ROOT/.ms-pids"
LOGS_DIR="$SCRIPTS_ROOT/logs/ms"
STARTED=0
SKIPPED=0
FAILED=0

# Limpiar archivo de PIDs anterior
if [ -f "$PIDS_FILE" ]; then
  rm "$PIDS_FILE"
fi

# Crear directorio de logs si no existe
mkdir -p "$LOGS_DIR"

for dirName in "${MS_DIRS[@]}"; do
  dirPath="$ROOT_DIR/$dirName"
  sbtBuildPath="$dirPath/build.sbt"
  packageJsonPath="$dirPath/package.json"

  if [ -d "$dirPath" ] && { [ -f "$sbtBuildPath" ] || [ -f "$packageJsonPath" ]; }; then
    echo "🚀 Iniciando $dirName..."

    cd "$dirPath" || continue

    LOG_OUT="$LOGS_DIR/${dirName}.log"
    LOG_ERR="$LOGS_DIR/${dirName}.error.log"

    if [ -f "$sbtBuildPath" ]; then
      # Scala / Akka HTTP (sbt)
      sbt run > "$LOG_OUT" 2> "$LOG_ERR" &
    else
      # Fallback Node/Nest u otros basados en npm
      npm run dev > "$LOG_OUT" 2> "$LOG_ERR" &
    fi

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
    echo "   ⏭️  Saltando $dirName (no existe o no tiene build.sbt / package.json)"
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
echo "🛑 Para detener todos (pending): crear script stop-all-ms.sh usando .ms-pids"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STARTED -gt 0 ]; then
  echo ""
  echo "💡 Los microservicios están corriendo en background."
  echo "   Revisa los logs en logs/ms/ para ver el output de cada uno."
fi
