#!/bin/bash
# Script de diagnóstico do Dashboard
# Suporta Docker Compose e Docker Swarm

echo "=========================================="
echo "Diagnóstico do Dashboard Lo-Fi"
echo "=========================================="
echo ""

# Detectar ambiente: Docker Compose ou Docker Swarm
DOCKER_MODE=""
STACK_NAME="lofi"
SWARM_SERVICE="lofi_dashboard"
COMPOSE_SERVICE="dashboard"

# Verificar se está em Docker Swarm
# Primeiro verifica se o serviço específico existe (mais confiável)
if docker service inspect "${SWARM_SERVICE}" >/dev/null 2>&1; then
    DOCKER_MODE="swarm"
    echo "🔍 Modo detectado: Docker Swarm (stack: ${STACK_NAME}, serviço: ${SWARM_SERVICE})"
elif docker service ls >/dev/null 2>&1; then
    # Swarm está inicializado, verificar se nosso stack existe
    if docker service ls --format "{{.Name}}" 2>/dev/null | grep -q "^${STACK_NAME}_"; then
        DOCKER_MODE="swarm"
        # Tenta encontrar o serviço do dashboard se o nome padrão não funcionar
        DASHBOARD_SERVICE=$(docker service ls --format "{{.Name}}" 2>/dev/null | grep -i dashboard | head -1)
        if [ -n "$DASHBOARD_SERVICE" ]; then
            SWARM_SERVICE="$DASHBOARD_SERVICE"
            echo "🔍 Modo detectado: Docker Swarm (stack: ${STACK_NAME}, serviço: ${SWARM_SERVICE})"
        else
            echo "🔍 Modo detectado: Docker Swarm (stack: ${STACK_NAME}, usando: ${SWARM_SERVICE})"
        fi
    else
        # Swarm ativo mas stack não encontrado - ainda usa Swarm mode para comandos
        DOCKER_MODE="swarm"
        echo "⚠️  Docker Swarm ativo, mas stack ${STACK_NAME} não encontrado (usando: ${SWARM_SERVICE})"
    fi
else
    # Swarm não está inicializado, usar Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version >/dev/null 2>&1; then
        DOCKER_MODE="compose"
        echo "🔍 Modo detectado: Docker Compose"
    else
        echo "❌ Docker não encontrado ou modo não suportado"
        echo "   Certifique-se de que Docker está instalado e rodando"
        exit 1
    fi
fi

echo ""

# Função para obter container ID do dashboard (Swarm)
get_swarm_container() {
    # Tenta primeiro pegar pelo nome do serviço
    local container_id=$(docker ps --filter "name=${SWARM_SERVICE}" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -n "$container_id" ]; then
        echo "$container_id"
        return 0
    fi
    
    # Fallback: pega pela task do serviço
    local task_id=$(docker service ps ${SWARM_SERVICE} --format "{{.ID}}" --filter "desired-state=running" 2>/dev/null | head -1)
    if [ -z "$task_id" ]; then
        return 1
    fi
    
    # Tenta obter o container ID da task
    container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' $task_id 2>/dev/null)
    if [ -z "$container_id" ] || [ "$container_id" = "<no value>" ]; then
        # Última tentativa: pega qualquer container do serviço
        container_id=$(docker ps --filter "label=com.docker.swarm.service.name=${SWARM_SERVICE}" --format "{{.ID}}" 2>/dev/null | head -1)
        if [ -z "$container_id" ]; then
            return 1
        fi
    fi
    echo "$container_id"
}

# Função para executar comando no container (Swarm)
swarm_exec() {
    local container=$(get_swarm_container)
    if [ -z "$container" ]; then
        return 1
    fi
    docker exec "$container" "$@" 2>/dev/null
}

# Função para executar comando no container (Compose)
compose_exec() {
    if command -v docker-compose &> /dev/null; then
        docker-compose exec -T ${COMPOSE_SERVICE} "$@" 2>/dev/null
    else
        docker compose exec -T ${COMPOSE_SERVICE} "$@" 2>/dev/null
    fi
}

echo "1. Verificando containers Docker..."
if [ "$DOCKER_MODE" = "swarm" ]; then
    echo "   Serviços do stack ${STACK_NAME}:"
    docker service ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}" 2>/dev/null || echo "   ⚠️  Não foi possível listar serviços"
    echo ""
    echo "   Tarefas do serviço ${SWARM_SERVICE}:"
    docker service ps ${SWARM_SERVICE} --no-trunc 2>/dev/null || echo "   ❌ Serviço ${SWARM_SERVICE} não encontrado"
else
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
fi

echo ""
echo "2. Verificando logs do dashboard (últimas 30 linhas)..."
if [ "$DOCKER_MODE" = "swarm" ]; then
    docker service logs --tail=30 ${SWARM_SERVICE} 2>&1 | tail -30 || echo "   ❌ Não foi possível obter logs"
else
    if command -v docker-compose &> /dev/null; then
        docker-compose logs --tail=30 ${COMPOSE_SERVICE} 2>&1 | tail -30
    else
        docker compose logs --tail=30 ${COMPOSE_SERVICE} 2>&1 | tail -30
    fi
fi

echo ""
echo "3. Verificando se o dashboard está respondendo internamente..."
if [ "$DOCKER_MODE" = "swarm" ]; then
    if swarm_exec curl -s http://localhost:5000 > /dev/null 2>&1; then
        echo "   ✅ Dashboard responde internamente"
        HTTP_CODE=$(swarm_exec curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
        echo "   Código HTTP: $HTTP_CODE"
    else
        echo "   ❌ Dashboard NÃO responde internamente"
    fi
else
    if compose_exec curl -s http://localhost:5000 > /dev/null 2>&1; then
        echo "   ✅ Dashboard responde internamente"
        HTTP_CODE=$(compose_exec curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
        echo "   Código HTTP: $HTTP_CODE"
    else
        echo "   ❌ Dashboard NÃO responde internamente"
    fi
fi

echo ""
echo "4. Verificando arquivos no container..."
if [ "$DOCKER_MODE" = "swarm" ]; then
    container=$(get_swarm_container)
    if [ -z "$container" ]; then
        echo "   ❌ Container do dashboard não encontrado"
    else
        echo "   Arquivos Python:"
        docker exec "$container" ls -1 /app/*.py 2>/dev/null | wc -l | xargs -I {} echo "   Encontrados: {} arquivos .py"
        
        echo "   Diretório templates:"
        if docker exec "$container" test -d /app/templates 2>/dev/null; then
            echo "   ✅ templates/ existe"
            docker exec "$container" ls -1 /app/templates/ 2>/dev/null | wc -l | xargs -I {} echo "   Arquivos: {}"
        else
            echo "   ❌ templates/ NÃO existe"
        fi
        
        echo "   Diretório static:"
        if docker exec "$container" test -d /app/static 2>/dev/null; then
            echo "   ✅ static/ existe"
            docker exec "$container" ls -1 /app/static/ 2>/dev/null | wc -l | xargs -I {} echo "   Arquivos: {}"
        else
            echo "   ❌ static/ NÃO existe"
        fi
    fi
else
    echo "   Arquivos Python:"
    compose_exec ls -1 /app/*.py | wc -l | xargs -I {} echo "   Encontrados: {} arquivos .py"
    
    echo "   Diretório templates:"
    if compose_exec test -d /app/templates; then
        echo "   ✅ templates/ existe"
        compose_exec ls -1 /app/templates/ | wc -l | xargs -I {} echo "   Arquivos: {}"
    else
        echo "   ❌ templates/ NÃO existe"
    fi
    
    echo "   Diretório static:"
    if compose_exec test -d /app/static; then
        echo "   ✅ static/ existe"
        compose_exec ls -1 /app/static/ | wc -l | xargs -I {} echo "   Arquivos: {}"
    else
        echo "   ❌ static/ NÃO existe"
    fi
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
if [ "$DOCKER_MODE" = "swarm" ]; then
    if swarm_exec python3 -c "import flask, flask_socketio" 2>/dev/null; then
        echo "   ✅ Flask e Flask-SocketIO instalados"
    else
        echo "   ❌ Dependências Python NÃO instaladas"
        echo "   Execute: docker service update --force ${SWARM_SERVICE}"
    fi
else
    if compose_exec python3 -c "import flask, flask_socketio" 2>/dev/null; then
        echo "   ✅ Flask e Flask-SocketIO instalados"
    else
        echo "   ❌ Dependências Python NÃO instaladas"
        if command -v docker-compose &> /dev/null; then
            echo "   Execute: docker-compose exec ${COMPOSE_SERVICE} pip install -r /app/requirements.txt"
        else
            echo "   Execute: docker compose exec ${COMPOSE_SERVICE} pip install -r /app/requirements.txt"
        fi
    fi
fi

echo ""
echo "7. Verificando processo Python do dashboard..."
if [ "$DOCKER_MODE" = "swarm" ]; then
    DASHBOARD_PID=$(swarm_exec pgrep -f "dashboard.py" | head -1)
    if [ -n "$DASHBOARD_PID" ]; then
        echo "   ✅ Processo dashboard.py rodando (PID: $DASHBOARD_PID)"
    else
        echo "   ❌ Processo dashboard.py NÃO está rodando"
    fi
else
    DASHBOARD_PID=$(compose_exec pgrep -f "dashboard.py" | head -1)
    if [ -n "$DASHBOARD_PID" ]; then
        echo "   ✅ Processo dashboard.py rodando (PID: $DASHBOARD_PID)"
    else
        echo "   ❌ Processo dashboard.py NÃO está rodando"
    fi
fi

echo ""
echo "=========================================="
echo "Resumo:"
echo "=========================================="

# Verificar status geral
if [ "$DOCKER_MODE" = "swarm" ]; then
    SERVICE_STATUS=$(docker service ls --format "{{.Replicas}}" --filter "name=${SWARM_SERVICE}" 2>/dev/null | grep -c "1/1" || echo "0")
    SERVICE_STATUS=$(echo "$SERVICE_STATUS" | tr -d '[:space:]')
    if [ -n "$SERVICE_STATUS" ] && [ "$SERVICE_STATUS" -gt 0 ] 2>/dev/null; then
        echo "✅ Serviço ${SWARM_SERVICE} está rodando"
    else
        echo "❌ Serviço ${SWARM_SERVICE} NÃO está rodando"
        echo "   Execute: docker stack deploy -c docker-stack.yml ${STACK_NAME}"
    fi
    
    if swarm_exec curl -s http://localhost:5000 > /dev/null 2>&1; then
        echo "✅ Dashboard responde internamente"
    else
        echo "❌ Dashboard NÃO responde"
        echo "   Verifique os logs: docker service logs ${SWARM_SERVICE}"
    fi
    
    echo ""
    echo "Para ver logs em tempo real:"
    echo "  docker service logs -f ${SWARM_SERVICE}"
    echo ""
    echo "Para reiniciar o dashboard:"
    echo "  docker service update --force ${SWARM_SERVICE}"
    echo ""
else
    if command -v docker-compose &> /dev/null; then
        CONTAINER_STATUS=$(docker-compose ps ${COMPOSE_SERVICE} 2>/dev/null | grep -c "Up" || echo "0")
    else
        CONTAINER_STATUS=$(docker compose ps ${COMPOSE_SERVICE} 2>/dev/null | grep -c "Up" || echo "0")
    fi
    if [ "$CONTAINER_STATUS" -gt 0 ]; then
        echo "✅ Container dashboard está rodando"
    else
        echo "❌ Container dashboard NÃO está rodando"
        if command -v docker-compose &> /dev/null; then
            echo "   Execute: docker-compose up -d ${COMPOSE_SERVICE}"
        else
            echo "   Execute: docker compose up -d ${COMPOSE_SERVICE}"
        fi
    fi
    
    if compose_exec curl -s http://localhost:5000 > /dev/null 2>&1; then
        echo "✅ Dashboard responde internamente"
    else
        echo "❌ Dashboard NÃO responde"
        if command -v docker-compose &> /dev/null; then
            echo "   Verifique os logs: docker-compose logs ${COMPOSE_SERVICE}"
        else
            echo "   Verifique os logs: docker compose logs ${COMPOSE_SERVICE}"
        fi
    fi
    
    echo ""
    echo "Para ver logs em tempo real:"
    if command -v docker-compose &> /dev/null; then
        echo "  docker-compose logs -f ${COMPOSE_SERVICE}"
    else
        echo "  docker compose logs -f ${COMPOSE_SERVICE}"
    fi
    echo ""
    echo "Para reiniciar o dashboard:"
    if command -v docker-compose &> /dev/null; then
        echo "  docker-compose restart ${COMPOSE_SERVICE}"
    else
        echo "  docker compose restart ${COMPOSE_SERVICE}"
    fi
    echo ""
fi

