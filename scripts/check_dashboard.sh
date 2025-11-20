#!/bin/bash
# Script de diagnóstico do Dashboard

echo "=========================================="
echo "Diagnóstico do Dashboard Lo-Fi"
echo "=========================================="
echo ""

echo "1. Verificando containers Docker..."
if command -v docker-compose &> /dev/null; then
    docker-compose ps
else
    echo "❌ docker-compose não encontrado"
    exit 1
fi

echo ""
echo "2. Verificando logs do dashboard (últimas 30 linhas)..."
docker-compose logs --tail=30 dashboard 2>&1 | tail -30

echo ""
echo "3. Verificando se o dashboard está respondendo internamente..."
if docker-compose exec -T dashboard curl -s http://localhost:5000 > /dev/null 2>&1; then
    echo "✅ Dashboard responde internamente"
    HTTP_CODE=$(docker-compose exec -T dashboard curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
    echo "   Código HTTP: $HTTP_CODE"
else
    echo "❌ Dashboard NÃO responde internamente"
fi

echo ""
echo "4. Verificando arquivos no container..."
echo "   Arquivos Python:"
docker-compose exec -T dashboard ls -1 /app/*.py 2>/dev/null | wc -l | xargs -I {} echo "   Encontrados: {} arquivos .py"

echo "   Diretório templates:"
if docker-compose exec -T dashboard test -d /app/templates; then
    echo "   ✅ templates/ existe"
    docker-compose exec -T dashboard ls -1 /app/templates/ 2>/dev/null | wc -l | xargs -I {} echo "   Arquivos: {}"
else
    echo "   ❌ templates/ NÃO existe"
fi

echo "   Diretório static:"
if docker-compose exec -T dashboard test -d /app/static; then
    echo "   ✅ static/ existe"
    docker-compose exec -T dashboard ls -1 /app/static/ 2>/dev/null | wc -l | xargs -I {} echo "   Arquivos: {}"
else
    echo "   ❌ static/ NÃO existe"
fi

echo ""
echo "5. Verificando porta 5000..."
if command -v netstat &> /dev/null; then
    PORT_CHECK=$(sudo netstat -tuln 2>/dev/null | grep ":5000 " || echo "")
    if [ -n "$PORT_CHECK" ]; then
        echo "   ✅ Porta 5000 está em uso:"
        echo "$PORT_CHECK" | sed 's/^/   /'
    else
        echo "   ⚠️  Porta 5000 não está escutando (pode ser normal se usar Docker)"
    fi
fi

echo ""
echo "6. Verificando dependências Python..."
if docker-compose exec -T dashboard python3 -c "import flask, flask_socketio" 2>/dev/null; then
    echo "   ✅ Flask e Flask-SocketIO instalados"
else
    echo "   ❌ Dependências Python NÃO instaladas"
    echo "   Execute: docker-compose exec dashboard pip install -r /app/requirements.txt"
fi

echo ""
echo "7. Verificando processo Python do dashboard..."
DASHBOARD_PID=$(docker-compose exec -T dashboard pgrep -f "dashboard.py" 2>/dev/null | head -1)
if [ -n "$DASHBOARD_PID" ]; then
    echo "   ✅ Processo dashboard.py rodando (PID: $DASHBOARD_PID)"
else
    echo "   ❌ Processo dashboard.py NÃO está rodando"
fi

echo ""
echo "=========================================="
echo "Resumo:"
echo "=========================================="

# Verificar status geral
CONTAINER_STATUS=$(docker-compose ps dashboard 2>/dev/null | grep -c "Up" || echo "0")
if [ "$CONTAINER_STATUS" -gt 0 ]; then
    echo "✅ Container dashboard está rodando"
else
    echo "❌ Container dashboard NÃO está rodando"
    echo "   Execute: docker-compose up -d dashboard"
fi

if docker-compose exec -T dashboard curl -s http://localhost:5000 > /dev/null 2>&1; then
    echo "✅ Dashboard responde internamente"
else
    echo "❌ Dashboard NÃO responde"
    echo "   Verifique os logs: docker-compose logs dashboard"
fi

echo ""
echo "Para ver logs em tempo real:"
echo "  docker-compose logs -f dashboard"
echo ""
echo "Para reiniciar o dashboard:"
echo "  docker-compose restart dashboard"
echo ""

