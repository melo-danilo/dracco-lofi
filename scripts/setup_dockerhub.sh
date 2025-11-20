#!/bin/bash
# Script para configurar credenciais do Docker Hub
# Execute este script uma vez para configurar o push automático

echo "=== Configuração de Credenciais do Docker Hub ==="
echo ""
echo "Este script configura as credenciais do Docker Hub para permitir"
echo "push automático das imagens durante o deploy."
echo ""
echo "Você precisa ter uma conta no Docker Hub e criar um access token."
echo "Veja: https://docs.docker.com/docker-hub/access-tokens/"
echo ""

read -p "Docker Hub username: " DOCKER_USERNAME
read -sp "Docker Hub access token (ou senha): " DOCKER_TOKEN
echo ""

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_TOKEN" ]; then
    echo "❌ Username e token são obrigatórios!"
    exit 1
fi

# Fazer login no Docker Hub
echo "Fazendo login no Docker Hub..."
echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Login realizado com sucesso!"
    echo ""
    echo "As credenciais foram salvas em ~/.docker/config.json"
    echo "Agora o script deploy.sh poderá fazer push das imagens automaticamente."
else
    echo "❌ Erro ao fazer login. Verifique suas credenciais."
    exit 1
fi

