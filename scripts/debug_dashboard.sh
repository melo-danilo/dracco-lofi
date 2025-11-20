#!/bin/bash
# Script de debug para investigar o problema do dashboard

echo "=== Debug do Dashboard ==="
echo ""

# Pegar o ID do container atual do serviço
echo "1. Verificando containers do serviço..."
TASK_ID=$(docker service ps lofi_dashboard --format "{{.ID}}" --no-trunc --filter "desired-state=running" 2>/dev/null | head -1)

if [ -z "$TASK_ID" ]; then
    echo "❌ Nenhum container rodando encontrado"
    echo "   Tentando pegar qualquer container do serviço..."
    TASK_ID=$(docker service ps lofi_dashboard --format "{{.ID}}" --no-trunc 2>/dev/null | head -1)
fi

if [ -n "$TASK_ID" ]; then
    echo "   Task ID: $TASK_ID"
    
    # Tentar pegar o container ID
    CONTAINER_ID=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' $TASK_ID 2>/dev/null)
    
    if [ -z "$CONTAINER_ID" ] || [ "$CONTAINER_ID" = "<no value>" ]; then
        echo "   ⚠️  Container ID não disponível ainda"
    else
        echo "   Container ID: $CONTAINER_ID"
        echo ""
        echo "2. Verificando arquivos no container do serviço..."
        docker exec $CONTAINER_ID ls -la /app/ 2>/dev/null || echo "   ❌ Não foi possível executar no container"
        
        echo ""
        echo "3. Verificando se dashboard.py existe no container..."
        docker exec $CONTAINER_ID test -f /app/dashboard.py 2>/dev/null && echo "   ✅ dashboard.py existe" || echo "   ❌ dashboard.py NÃO existe"
        
        echo ""
        echo "4. Verificando montagens de volumes..."
        docker inspect $CONTAINER_ID --format '{{json .Mounts}}' 2>/dev/null | python3 -m json.tool 2>/dev/null || docker inspect $CONTAINER_ID --format '{{json .Mounts}}' 2>/dev/null
    fi
else
    echo "❌ Nenhum task encontrado para o serviço"
fi

echo ""
echo "5. Verificando imagem Docker..."
docker run --rm melodanilo/dracco-lofi:latest ls -la /app/ | grep dashboard.py && echo "   ✅ dashboard.py está na imagem" || echo "   ❌ dashboard.py NÃO está na imagem"

echo ""
echo "6. Verificando SHA da imagem usada pelo serviço..."
docker service inspect lofi_dashboard --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null

echo ""
echo "7. Listando todas as imagens dracco-lofi..."
docker images melodanilo/dracco-lofi

