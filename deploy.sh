#!/bin/bash
set -e

STACK_NAME="livestreams"
COMPOSE_FILE="docker-stack.yml"

echo "==> Buildando imagens locais..."
docker build -t dracco-lofi:cozy .
docker build -t dracco-lofi:dracco .

# Se quiser enviar para DockerHub/GitHub Container Registry, descomente:
# echo "==> Fazendo push das imagens..."
# docker tag dracco-lofi:cozy SEU_REGISTRY/dracco-lofi:cozy
# docker tag dracco-lofi:dracco SEU_REGISTRY/dracco-lofi:dracco
# docker push SEU_REGISTRY/dracco-lofi:cozy
# docker push SEU_REGISTRY/dracco-lofi:dracco

echo "==> Deployando stack..."
docker stack deploy -c $COMPOSE_FILE $STACK_NAME

echo "==> Status dos serviços:"
docker stack services $STACK_NAME

echo "==> Deploy finalizado com sucesso (rolling update start-first)."
