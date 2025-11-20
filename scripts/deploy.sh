#!/bin/bash

set -e

# Evita o erro 'dubious ownership'
git config --global --add safe.directory /root/dracco-stack

# Verificar se arquivos necessários existem
echo "Verificando arquivos necessários..."
REQUIRED_FILES=("entrypoint.sh" "server.py" "dashboard.py" "requirements.txt" "Dockerfile")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ ERRO: Arquivo $file não encontrado!"
        exit 1
    fi
done

if [ ! -d "templates" ] || [ ! -d "static" ]; then
    echo "❌ ERRO: Diretórios templates/ ou static/ não encontrados!"
    exit 1
fi

echo "✅ Todos os arquivos necessários encontrados"

# Criar diretórios necessários para volumes (se não existirem)
echo "Criando diretórios necessários..."
mkdir -p logs control stats

# Remover imagem antiga para forçar rebuild completo
echo "Removendo imagem antiga (se existir)..."
docker rmi melodanilo/dracco-lofi:latest 2>/dev/null || true

# Criar tag única baseada em timestamp para garantir uso da nova imagem
TIMESTAMP_TAG=$(date +%Y%m%d%H%M%S)
echo "Tag única para esta build: $TIMESTAMP_TAG"

# Fazer build sem cache para garantir que todos os arquivos sejam incluídos
echo "Fazendo build da imagem Docker (sem cache)..."
docker build --no-cache -t melodanilo/dracco-lofi:latest -t melodanilo/dracco-lofi:$TIMESTAMP_TAG .

# Obter o SHA da imagem recém-construída
IMAGE_SHA=$(docker inspect melodanilo/dracco-lofi:latest --format '{{.Id}}')
echo "SHA da imagem: $IMAGE_SHA"

# Verificar se o arquivo dashboard.py está na imagem
echo "Verificando se dashboard.py está na imagem..."
if docker run --rm melodanilo/dracco-lofi:latest test -f /app/dashboard.py; then
    echo "✅ dashboard.py encontrado na imagem"
    echo "Listando arquivos em /app:"
    docker run --rm melodanilo/dracco-lofi:latest ls -la /app/ | head -20
else
    echo "❌ ERRO: dashboard.py NÃO está na imagem!"
    echo "Listando arquivos em /app:"
    docker run --rm melodanilo/dracco-lofi:latest ls -la /app/
    exit 1
fi

# Função para aguardar atualizações pendentes dos serviços
wait_for_pending_updates() {
    local max_wait=180  # Máximo de 3 minutos
    local waited=0
    
    echo "Verificando atualizações pendentes nos serviços..."
    
    while [ $waited -lt $max_wait ]; do
        local pending_updates=0
        
        # Verifica cada serviço do stack
        for service in lofi_dashboard lofi_cozy lofi_dracco; do
            if docker service ls --format "{{.Name}}" 2>/dev/null | grep -q "^${service}$"; then
                # Verifica se há atualizações pendentes
                local update_status=$(docker service inspect "$service" --format '{{.UpdateStatus.State}}' 2>/dev/null || echo "completed")
                
                # Verifica também tasks em estado de atualização
                local updating_tasks=$(docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" 2>/dev/null | grep -c "Preparing\|Starting\|Ready" || echo "0")
                
                # Garante que updating_tasks é um número válido (remove espaços e converte para número)
                updating_tasks=$(echo "$updating_tasks" | tr -d '[:space:]')
                updating_tasks=${updating_tasks:-0}  # Se vazio, usa 0
                updating_tasks=$((10#$updating_tasks))  # Converte para número base 10
                
                if [[ "$update_status" == "updating" ]] || [[ "$update_status" == "paused" ]] || [[ $updating_tasks -gt 0 ]]; then
                    echo "   ⏳ Serviço $service está em atualização (status: $update_status, tasks: $updating_tasks)..."
                    pending_updates=$((pending_updates + 1))
                fi
            fi
        done
        
        if [ $pending_updates -eq 0 ]; then
            echo "✅ Nenhuma atualização pendente"
            return 0
        fi
        
        if [ $((waited % 15)) -eq 0 ]; then
            echo "   Aguardando atualizações pendentes ($pending_updates serviço(s))... ($waited/$max_wait segundos)"
        fi
        sleep 5
        waited=$((waited + 5))
    done
    
    echo "⚠️  Timeout aguardando atualizações pendentes. Continuando mesmo assim..."
    return 1
}

# Aguardar atualizações pendentes antes de fazer deploy
wait_for_pending_updates

# Remover o serviço do dashboard se existir (para forçar uso da nova imagem)
if docker service ls --format "{{.Name}}" 2>/dev/null | grep -q "^lofi_dashboard$"; then
    echo "Removendo serviço dashboard antigo para forçar atualização..."
    docker service rm lofi_dashboard || true
    sleep 3
fi

# Tentar fazer push da imagem para o Docker Hub (tag única e latest)
echo "Tentando fazer push da imagem para o Docker Hub..."
PUSHED=false
if docker push melodanilo/dracco-lofi:$TIMESTAMP_TAG 2>&1 | grep -qE "(digest:|pushed)"; then
    echo "✅ Imagem com tag $TIMESTAMP_TAG enviada para o Docker Hub"
    PUSHED=true
    # Também fazer push da tag latest
    docker push melodanilo/dracco-lofi:latest 2>/dev/null && echo "✅ Tag latest também atualizada no Docker Hub" || true
else
    echo "⚠️  Não foi possível fazer push para o Docker Hub"
    echo "   (Isso é normal se as credenciais não estiverem configuradas)"
    echo "   Configure com: bash scripts/setup_dockerhub.sh"
    echo ""
    echo "   Continuando com deploy usando imagem local (tag: $TIMESTAMP_TAG)..."
fi

# Verificar novamente se dashboard.py está na imagem local
echo "Verificação final: dashboard.py na imagem local..."
if docker run --rm melodanilo/dracco-lofi:latest test -f /app/dashboard.py; then
    echo "✅ dashboard.py confirmado na imagem local"
else
    echo "❌ ERRO CRÍTICO: dashboard.py NÃO está na imagem local!"
    exit 1
fi

# Atualizar docker-stack.yml temporariamente para usar a tag única
echo "Atualizando docker-stack.yml para usar tag única..."
sed -i.bak "s|image: melodanilo/dracco-lofi:latest|image: melodanilo/dracco-lofi:$TIMESTAMP_TAG|g" docker-stack.yml

# Aguardar novamente antes do deploy final
echo "Aguardando um pouco mais antes do deploy final..."
sleep 3

# Verificar novamente se há atualizações pendentes
wait_for_pending_updates

# Fazer deploy do stack
echo "Fazendo deploy do stack..."
DEPLOY_OUTPUT=$(docker stack deploy -c docker-stack.yml lofi 2>&1)
DEPLOY_EXIT=$?

# Verifica se houve erro "update out of sequence"
if echo "$DEPLOY_OUTPUT" | grep -qi "update out of sequence"; then
    echo "⚠️  Erro 'update out of sequence' detectado"
    echo "   Aguardando mais tempo e tentando novamente..."
    
    # Aguarda mais tempo
    sleep 15
    wait_for_pending_updates
    
    # Tenta novamente
    echo "Tentando deploy novamente..."
    DEPLOY_OUTPUT2=$(docker stack deploy -c docker-stack.yml lofi 2>&1)
    DEPLOY_EXIT2=$?
    
    if echo "$DEPLOY_OUTPUT2" | grep -qi "update out of sequence"; then
        echo "❌ Erro 'update out of sequence' persiste"
        echo "   Isso geralmente significa que há uma atualização em andamento"
        echo "   Aguarde alguns minutos e tente novamente, ou execute:"
        echo "   docker service update --force lofi_dracco"
        echo "   docker service update --force lofi_cozy"
        exit 1
    elif [ $DEPLOY_EXIT2 -eq 0 ]; then
        echo "✅ Deploy bem-sucedido na segunda tentativa"
    else
        echo "⚠️  Deploy retornou código $DEPLOY_EXIT2"
        echo "   Output: $DEPLOY_OUTPUT2"
    fi
elif [ $DEPLOY_EXIT -eq 0 ]; then
    echo "✅ Deploy iniciado com sucesso"
else
    # Verifica se é apenas o aviso sobre --detach
    if echo "$DEPLOY_OUTPUT" | grep -qi "detach"; then
        echo "✅ Deploy iniciado (aviso sobre detach ignorado)"
    else
        echo "⚠️  Deploy retornou código $DEPLOY_EXIT"
        echo "   Output: $DEPLOY_OUTPUT"
    fi
fi

# Restaurar docker-stack.yml original
echo "Restaurando docker-stack.yml original..."
mv docker-stack.yml.bak docker-stack.yml 2>/dev/null || true

# Também taggear como latest para uso futuro
docker tag melodanilo/dracco-lofi:$TIMESTAMP_TAG melodanilo/dracco-lofi:latest

# Aguardar o serviço iniciar
echo "Aguardando serviço dashboard iniciar..."
sleep 10

# Verificar se o serviço está rodando
if docker service ps lofi_dashboard --format "{{.CurrentState}}" 2>/dev/null | grep -q "Running"; then
    echo "✅ Serviço dashboard está rodando"
else
    echo "⚠️  Serviço dashboard pode estar iniciando ainda..."
    echo "   Verifique com: docker service ps lofi_dashboard"
fi

echo "Deploy concluído!"
