#!/bin/bash
# Script de diagnóstico rápido para Docker Swarm
# Execute no servidor para diagnosticar problemas

echo "=== Diagnóstico Docker Swarm ==="
echo ""

echo "1. Status dos serviços:"
docker stack services lofi
echo ""

echo "2. Tasks de cada serviço:"
for service in lofi_dashboard lofi_cozy lofi_dracco; do
    echo ""
    echo "--- $service ---"
    docker service ps $service --no-trunc
done
echo ""

echo "3. Logs recentes do dashboard:"
docker service logs lofi_dashboard --tail 50 2>&1 | tail -20
echo ""

echo "4. Logs recentes do cozy:"
docker service logs lofi_cozy --tail 30 2>&1 | tail -15
echo ""

echo "5. Logs recentes do dracco:"
docker service logs lofi_dracco --tail 30 2>&1 | tail -15
echo ""

echo "6. Status de atualização dos serviços:"
for service in lofi_dashboard lofi_cozy lofi_dracco; do
    if docker service ls --format "{{.Name}}" 2>/dev/null | grep -q "^${service}$"; then
        update_status=$(docker service inspect "$service" --format '{{.UpdateStatus.State}}' 2>/dev/null || echo "N/A")
        echo "   $service: $update_status"
    fi
done
echo ""

echo "7. Imagens disponíveis:"
docker images melodanilo/dracco-lofi --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}"
echo ""

echo "8. Containers rodando:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "NAMES|lofi"
echo ""

echo "9. Uso de recursos:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "NAME|lofi" || echo "Nenhum container rodando"
echo ""

echo "=== Comandos úteis ==="
echo ""
echo "Para forçar atualização de um serviço:"
echo "  docker service update --force lofi_cozy"
echo "  docker service update --force lofi_dracco"
echo ""
echo "Para ver logs em tempo real:"
echo "  docker service logs -f lofi_cozy"
echo "  docker service logs -f lofi_dracco"
echo ""
echo "Para remover e recriar um serviço:"
echo "  docker service rm lofi_cozy"
echo "  docker stack deploy -c docker-stack.yml lofi"
echo ""
echo "Para ver detalhes de um serviço:"
echo "  docker service inspect lofi_cozy --pretty"
echo ""

