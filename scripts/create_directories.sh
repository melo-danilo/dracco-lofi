#!/bin/bash
# Script para criar diretórios necessários para o Docker Swarm
# Execute este script no servidor antes de fazer deploy

BASE_DIR="${1:-/root/dracco-stack}"

echo "Criando diretórios necessários em: $BASE_DIR"
echo ""

# Criar diretórios se não existirem
mkdir -p "$BASE_DIR/logs"
mkdir -p "$BASE_DIR/control"
mkdir -p "$BASE_DIR/stats"

# Verificar se foram criados
if [ -d "$BASE_DIR/logs" ] && [ -d "$BASE_DIR/control" ] && [ -d "$BASE_DIR/stats" ]; then
    echo "✅ Diretórios criados com sucesso!"
    echo ""
    echo "Diretórios criados:"
    ls -ld "$BASE_DIR"/{logs,control,stats} 2>/dev/null
else
    echo "❌ Erro ao criar diretórios"
    exit 1
fi

