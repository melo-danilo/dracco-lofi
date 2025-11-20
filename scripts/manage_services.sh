#!/bin/bash
# Script para gerenciar serviços do Docker Swarm
# Uso: bash scripts/manage_services.sh [comando] [servico]

STACK_NAME="lofi"
SERVICES=("lofi_dashboard" "lofi_cozy" "lofi_dracco")

show_help() {
    echo "=== Gerenciamento de Serviços Docker Swarm ==="
    echo ""
    echo "Uso: bash scripts/manage_services.sh [comando] [servico]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  status          - Ver status de todos os serviços"
    echo "  logs [servico]  - Ver logs de um serviço (ou todos)"
    echo "  restart [servico] - Reiniciar um serviço"
    echo "  stop [servico]  - Parar um serviço"
    echo "  update [servico] - Forçar atualização de um serviço"
    echo "  remove [servico] - Remover um serviço (depois use 'deploy' para recriar)"
    echo "  deploy          - Fazer deploy do stack completo"
    echo ""
    echo "Serviços disponíveis:"
    for svc in "${SERVICES[@]}"; do
        echo "  - $svc"
    done
    echo ""
    echo "Exemplos:"
    echo "  bash scripts/manage_services.sh status"
    echo "  bash scripts/manage_services.sh logs lofi_cozy"
    echo "  bash scripts/manage_services.sh restart lofi_cozy"
    echo "  bash scripts/manage_services.sh update lofi_cozy"
}

show_status() {
    echo "=== Status dos Serviços ==="
    echo ""
    docker stack services $STACK_NAME
    echo ""
    echo "=== Tasks Detalhadas ==="
    for svc in "${SERVICES[@]}"; do
        echo ""
        echo "--- $svc ---"
        docker service ps $svc --no-trunc | head -3
    done
}

show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        echo "=== Logs de Todos os Serviços ==="
        for svc in "${SERVICES[@]}"; do
            echo ""
            echo "--- $svc (últimas 20 linhas) ---"
            docker service logs $svc --tail 20 2>&1 | tail -20
        done
    else
        echo "=== Logs de $service ==="
        docker service logs $service --tail 50 -f
    fi
}

restart_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo "❌ Especifique um serviço para reiniciar"
        echo "   Serviços disponíveis: ${SERVICES[*]}"
        exit 1
    fi
    
    echo "🔄 Reiniciando $service..."
    docker service update --force $service
    echo "✅ Comando de reinício enviado"
    echo ""
    echo "Acompanhe o status com:"
    echo "  docker service ps $service"
    echo "  docker service logs $service -f"
}

stop_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo "❌ Especifique um serviço para parar"
        echo "   Serviços disponíveis: ${SERVICES[*]}"
        exit 1
    fi
    
    echo "⏹️  Parando $service..."
    docker service scale $service=0
    echo "✅ Serviço parado"
    echo ""
    echo "Para iniciar novamente:"
    echo "  docker service scale $service=1"
}

start_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo "❌ Especifique um serviço para iniciar"
        echo "   Serviços disponíveis: ${SERVICES[*]}"
        exit 1
    fi
    
    echo "▶️  Iniciando $service..."
    docker service scale $service=1
    echo "✅ Comando de início enviado"
    echo ""
    echo "Acompanhe o status com:"
    echo "  docker service ps $service"
}

update_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo "❌ Especifique um serviço para atualizar"
        echo "   Serviços disponíveis: ${SERVICES[*]}"
        exit 1
    fi
    
    echo "🔄 Forçando atualização de $service..."
    docker service update --force $service
    echo "✅ Comando de atualização enviado"
    echo ""
    echo "Acompanhe o status com:"
    echo "  docker service ps $service"
    echo "  docker service logs $service -f"
}

remove_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo "❌ Especifique um serviço para remover"
        echo "   Serviços disponíveis: ${SERVICES[*]}"
        exit 1
    fi
    
    echo "⚠️  ATENÇÃO: Isso irá remover o serviço $service"
    read -p "Tem certeza? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo "Operação cancelada"
        exit 0
    fi
    
    echo "🗑️  Removendo $service..."
    docker service rm $service
    echo "✅ Serviço removido"
    echo ""
    echo "Para recriar, execute:"
    echo "  docker stack deploy -c docker-stack.yml $STACK_NAME"
}

deploy_stack() {
    echo "🚀 Fazendo deploy do stack $STACK_NAME..."
    docker stack deploy -c docker-stack.yml $STACK_NAME
    echo "✅ Deploy concluído"
    echo ""
    echo "Verifique o status com:"
    echo "  docker stack services $STACK_NAME"
}

# Main
COMMAND=$1
SERVICE=$2

case "$COMMAND" in
    status)
        show_status
        ;;
    logs)
        show_logs "$SERVICE"
        ;;
    restart)
        restart_service "$SERVICE"
        ;;
    stop)
        stop_service "$SERVICE"
        ;;
    start)
        start_service "$SERVICE"
        ;;
    update)
        update_service "$SERVICE"
        ;;
    remove)
        remove_service "$SERVICE"
        ;;
    deploy)
        deploy_stack
        ;;
    *)
        show_help
        ;;
esac

