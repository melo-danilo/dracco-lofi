#!/bin/bash
# Script de teste para validar a lógica de reinício

echo "=== Teste da Lógica de Reinício Automático ==="
echo ""

# Simula a função should_restart
should_restart() {
  local RESTART_HOUR=$1
  local current_hour=$2
  local current_minute=$3
  
  # Remove zero à esquerda para comparação
  current_hour=$((10#$current_hour))
  local restart_hour=$((10#$RESTART_HOUR))
  current_minute=$((10#$current_minute))
  
  # Reinicia se for exatamente a hora configurada e estiver nos primeiros 2 minutos
  if [[ $current_hour -eq $restart_hour ]] && [[ $current_minute -lt 2 ]]; then
    return 0
  fi
  
  return 1
}

# Testes
echo "Teste 1: Hora 12:00 (deve reiniciar)"
if should_restart 12 12 0; then
  echo "✅ PASSOU: 12:00 deve reiniciar"
else
  echo "❌ FALHOU: 12:00 deveria reiniciar"
fi

echo ""
echo "Teste 2: Hora 12:01 (deve reiniciar - dentro dos 2 minutos)"
if should_restart 12 12 1; then
  echo "✅ PASSOU: 12:01 deve reiniciar"
else
  echo "❌ FALHOU: 12:01 deveria reiniciar"
fi

echo ""
echo "Teste 3: Hora 12:02 (NÃO deve reiniciar - fora dos 2 minutos)"
if should_restart 12 12 2; then
  echo "❌ FALHOU: 12:02 NÃO deveria reiniciar"
else
  echo "✅ PASSOU: 12:02 não reinicia"
fi

echo ""
echo "Teste 4: Hora 11:59 (NÃO deve reiniciar)"
if should_restart 12 11 59; then
  echo "❌ FALHOU: 11:59 NÃO deveria reiniciar"
else
  echo "✅ PASSOU: 11:59 não reinicia"
fi

echo ""
echo "Teste 5: Hora 13:00 (NÃO deve reiniciar - hora diferente)"
if should_restart 12 13 0; then
  echo "❌ FALHOU: 13:00 NÃO deveria reiniciar"
else
  echo "✅ PASSOU: 13:00 não reinicia"
fi

echo ""
echo "Teste 6: Hora 09:00 com RESTART_HOUR=9 (deve reiniciar - testa zero à esquerda)"
if should_restart 9 09 0; then
  echo "✅ PASSOU: 09:00 com RESTART_HOUR=9 deve reiniciar"
else
  echo "❌ FALHOU: 09:00 com RESTART_HOUR=9 deveria reiniciar"
fi

echo ""
echo "Teste 7: Hora 09:00 com RESTART_HOUR=09 (deve reiniciar - testa zero à esquerda)"
if should_restart 09 9 0; then
  echo "✅ PASSOU: 09:00 com RESTART_HOUR=09 deve reiniciar"
else
  echo "❌ FALHOU: 09:00 com RESTART_HOUR=09 deveria reiniciar"
fi

echo ""
echo "=== Resumo dos Testes ==="
echo "A lógica de reinício funciona se:"
echo "- A hora atual for igual à RESTART_HOUR"
echo "- E o minuto atual for menor que 2 (0 ou 1)"
echo "- Isso garante que reinicie exatamente na hora configurada"

