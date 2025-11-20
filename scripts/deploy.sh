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

# Aguardar um pouco para evitar erros de "update out of sequence"
echo "Aguardando atualizações pendentes..."
sleep 5

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

# Fazer deploy do stack
echo "Fazendo deploy do stack..."
docker stack deploy -c docker-stack.yml lofi

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
