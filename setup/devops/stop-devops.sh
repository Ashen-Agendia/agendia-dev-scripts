#!/bin/bash

echo "🛑 Deteniendo DevOps Dashboard..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PIDS_FILE="$SCRIPTS_ROOT/.devops-pids"

STOPPED=0
NOT_FOUND=0

if [ ! -f "$PIDS_FILE" ]; then
    echo "⚠️  No se encontró archivo de PIDs (.devops-pids)"
    echo "   Intentando detener procesos en los puertos comunes (5000, 3010)..."
    echo ""
    
    for port in 5000 3010; do
        pid=$(lsof -ti:$port 2>/dev/null)
        if [ -n "$pid" ]; then
            echo "   🛑 Deteniendo proceso en puerto $port (PID: $pid)..."
            kill "$pid" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "      ✅ Proceso detenido"
                ((STOPPED++))
            fi
        fi
    done
    
    if [ $STOPPED -eq 0 ]; then
        echo "   ℹ️  No se encontraron procesos corriendo en los puertos comunes"
    fi
else
    echo "📋 Leyendo PIDs desde $PIDS_FILE..."
    echo ""
    
    while IFS=':' read -r PID SERVICE; do
        if [ -z "$PID" ] || [ -z "$SERVICE" ]; then
            continue
        fi
        
        if kill -0 "$PID" 2>/dev/null; then
            echo "   🛑 Deteniendo $SERVICE (PID: $PID)..."
            kill "$PID" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "      ✅ $SERVICE detenido"
                ((STOPPED++))
            else
                echo "      ❌ Error deteniendo $SERVICE"
            fi
        else
            echo "   ⚠️  $SERVICE (PID: $PID) ya no está corriendo"
            ((NOT_FOUND++))
        fi
    done < "$PIDS_FILE"
    
    rm "$PIDS_FILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   🛑 Detenidos: $STOPPED"
if [ $NOT_FOUND -gt 0 ]; then
    echo "   ⚠️  No encontrados: $NOT_FOUND"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STOPPED -gt 0 ]; then
    echo "✅ DevOps Dashboard detenido"
else
    echo "ℹ️  No se encontraron procesos para detener"
fi

