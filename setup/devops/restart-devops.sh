#!/bin/bash

echo "🔄 Reiniciando DevOps Dashboard..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛑 Deteniendo servicios..."
"$SCRIPT_DIR/stop-devops.sh"

echo ""
echo "⏳ Esperando 2 segundos..."
sleep 2

echo ""
echo "🚀 Iniciando servicios..."
"$SCRIPT_DIR/start-devops.sh"

