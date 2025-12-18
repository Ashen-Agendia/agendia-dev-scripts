#!/bin/bash

echo "🔄 Reiniciando microfrontends activos..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"
PIDS_FILE="$SCRIPTS_ROOT/.mf-pids"
LOGS_ROOT="$SCRIPTS_ROOT/logs"
LOGS_DIR="$LOGS_ROOT/mf"

RESTARTED=0
NOT_FOUND=0
FAILED=0

if [ ! -f "$PIDS_FILE" ]; then
  echo "⚠️  No se encontró archivo de PIDs (.mf-pids)"
  echo "   No hay microfrontends corriendo para reiniciar."
  echo "   Usa ./start-all-mf.sh para iniciarlos."
  exit 0
fi

echo "📋 Leyendo PIDs desde $PIDS_FILE..."
echo ""

declare -A runningMfs

while IFS=':' read -r pid dirName; do
  if [ -z "$pid" ] || [ -z "$dirName" ]; then
    continue
  fi
  
  if kill -0 "$pid" 2>/dev/null; then
    echo "   🛑 Deteniendo $dirName (PID: $pid)..."
    kill "$pid" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "      ✅ $dirName detenido"
      runningMfs["$dirName"]=1
    else
      echo "      ⚠️  Error deteniendo $dirName"
      ((NOT_FOUND++))
    fi
  else
    echo "   ⚠️  $dirName (PID: $pid) ya no está corriendo"
    ((NOT_FOUND++))
  fi
done < "$PIDS_FILE"

if [ ${#runningMfs[@]} -eq 0 ]; then
  echo ""
  echo "ℹ️  No hay microfrontends corriendo para reiniciar"
  exit 0
fi

echo ""
echo "🚀 Reiniciando microfrontends..."
echo ""

# Limpiar archivo de PIDs para agregar los nuevos
if [ -f "$PIDS_FILE" ]; then
  rm "$PIDS_FILE"
fi

sleep 1

for dirName in "${!runningMfs[@]}"; do
  dirPath="$ROOT_DIR/$dirName"
  packageJsonPath="$dirPath/package.json"
  
  if [ -d "$dirPath" ] && [ -f "$packageJsonPath" ]; then
    echo "🚀 Reiniciando $dirName..."
    
    cd "$dirPath" || continue
    
    npm run dev > "$LOGS_DIR/${dirName}.log" 2> "$LOGS_DIR/${dirName}.error.log" &
    PID=$!
    echo "$PID:$dirName" >> "$PIDS_FILE"
    
    cd "$ROOT_DIR" || continue
    
    if kill -0 $PID 2>/dev/null; then
      echo "   ✅ $dirName reiniciado (PID: $PID)"
      ((RESTARTED++))
      sleep 1
    else
      echo "   ❌ Error reiniciando $dirName"
      ((FAILED++))
    fi
  else
    echo "   ⚠️  Saltando $dirName (no existe o no tiene package.json)"
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
echo ""
echo "📝 Logs guardados en: $LOGS_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $RESTARTED -gt 0 ]; then
  echo ""
  echo "💡 Los microfrontends han sido reiniciados."
  echo "   Revisa los logs en logs/mf/ para ver el output de cada uno."
fi

