#!/bin/bash

echo "🔄 Reiniciando microservicios activos..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"
PIDS_FILE="$SCRIPTS_ROOT/.ms-pids"
LOGS_DIR="$SCRIPTS_ROOT/logs/ms"

RESTARTED=0
NOT_FOUND=0
FAILED=0

if [ ! -f "$PIDS_FILE" ]; then
  echo "⚠️  No se encontró archivo de PIDs (.ms-pids)"
  echo "   No hay microservicios corriendo para reiniciar."
  echo "   Usa ./start-all-ms.sh para iniciarlos."
  exit 0
fi

echo "📋 Leyendo PIDs desde $PIDS_FILE..."
echo ""

declare -A runningMs

while IFS=':' read -r PID DIR; do
  if [ -z "$PID" ] || [ -z "$DIR" ]; then
    continue
  fi

  if kill -0 "$PID" 2>/dev/null; then
    echo "   🛑 Deteniendo $DIR (PID: $PID)..."
    kill "$PID" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "      ✅ $DIR detenido"
      runningMs["$DIR"]=1
    else
      echo "      ⚠️  Error deteniendo $DIR"
      ((NOT_FOUND++))
    fi
  else
    echo "   ⚠️  $DIR (PID: $PID) ya no está corriendo"
    ((NOT_FOUND++))
  fi
done < "$PIDS_FILE"

rm "$PIDS_FILE"

if [ ${#runningMs[@]} -eq 0 ]; then
  echo ""
  echo "ℹ️  No hay microservicios corriendo para reiniciar"
  exit 0
fi

echo ""
echo "🚀 Reiniciando microservicios..."
echo ""

mkdir -p "$LOGS_DIR"

for DIR in "${!runningMs[@]}"; do
  dirPath="$ROOT_DIR/$DIR"
  sbtBuildPath="$dirPath/build.sbt"
  packageJsonPath="$dirPath/package.json"

  if [ -d "$dirPath" ] && { [ -f "$sbtBuildPath" ] || [ -f "$packageJsonPath" ]; }; then
    echo "🚀 Reiniciando $DIR..."

    cd "$dirPath" || continue

    LOG_OUT="$LOGS_DIR/${DIR}.log"
    LOG_ERR="$LOGS_DIR/${DIR}.error.log"

    if [ -f "$sbtBuildPath" ]; then
      sbt run > "$LOG_OUT" 2> "$LOG_ERR" &
    else
      npm run dev > "$LOG_OUT" 2> "$LOG_ERR" &
    fi

    PID=$!
    echo "$PID:$DIR" >> "$PIDS_FILE"

    cd "$ROOT_DIR" || continue

    if kill -0 $PID 2>/dev/null; then
      echo "   ✅ $DIR reiniciado (PID: $PID)"
      ((RESTARTED++))
      sleep 1
    else
      echo "   ❌ Error reiniciando $DIR"
      ((FAILED++))
    fi
  else
    echo "   ⚠️  Saltando $DIR (no existe o no tiene build.sbt / package.json)"
    ((FAILED++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Reiniciados: $RESTARTED"
if [ $NOT_FOUND -gt 0 ]; then
  echo "   ⚠️  No encontrados: $NOT_FOUND"
fi
if [ $FAILED -gt 0 ]; then
  echo "   ❌ Fallidos: $FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $RESTARTED -gt 0 ]; then
  echo ""
  echo "💡 Los microservicios han sido reiniciados."
  echo "   Revisa los logs en logs/ms/ para ver el output de cada uno."
fi
