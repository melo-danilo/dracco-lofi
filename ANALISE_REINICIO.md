# Análise da Lógica de Reinício Automático

## Problemas Identificados e Corrigidos

### 1. ✅ Comparação de Horas com Zero à Esquerda
**Problema**: Comparação `"09" == "9"` falharia em alguns casos.

**Solução**: Normalização usando `$((10#$VAR))` que remove zero à esquerda e converte para número.

```bash
# Antes (problemático)
[[ "$current_hour" == "$RESTART_HOUR" ]]

# Depois (corrigido)
current_hour=$((10#$current_hour))
restart_hour=$((10#$RESTART_HOUR))
[[ $current_hour -eq $restart_hour ]]
```

### 2. ✅ Janela de Tempo para Reinício
**Problema**: A lógica original só reiniciava nos primeiros 5 minutos, mas isso poderia falhar se o script iniciasse depois desse período.

**Solução**: Reduzido para 2 minutos e melhorada a lógica de detecção.

```bash
# Reinicia se for a hora configurada e estiver nos primeiros 2 minutos
if [[ $current_hour -eq $restart_hour ]] && [[ $current_minute -lt 2 ]]; then
  return 0
fi
```

### 3. ✅ Rastreamento de Último Reinício
**Problema**: Usava apenas a hora (HH), o que poderia causar problemas se o script reiniciasse múltiplas vezes no mesmo dia.

**Solução**: Agora usa formato `YYYY-MM-DD-HH` para garantir reinício apenas uma vez por hora.

```bash
# Antes
LAST_RESTART_TIME=$(date +%H)

# Depois
LAST_RESTART_TIME=$(date '+%Y-%m-%d-%H')
```

## Como Funciona Agora

1. **Verificação Contínua**: O script verifica a cada 60 segundos se é hora de reiniciar.

2. **Condições para Reinício**:
   - Hora atual deve ser igual à `RESTART_HOUR` (0-23)
   - Minuto atual deve ser menor que 2 (0 ou 1)
   - Não deve ter reiniciado nesta mesma hora hoje

3. **Exemplo de Funcionamento**:
   - Se `RESTART_HOUR=12`:
     - ✅ 12:00 → Reinicia
     - ✅ 12:01 → Reinicia (ainda dentro da janela)
     - ❌ 12:02 → Não reinicia (fora da janela)
     - ❌ 12:03 → Não reinicia
     - ❌ 13:00 → Não reinicia (hora diferente)

## Testes Recomendados

Para testar a funcionalidade:

1. **Teste Manual**: Configure `RESTART_HOUR` para alguns minutos à frente e observe os logs.

2. **Verificar Logs**: Procure por:
   ```
   [INFO] Hora de reiniciar a live (12h)...
   [INFO] Encerrando stream atual...
   [INFO] Iniciando stream com vídeo: ...
   ```

3. **Verificar Estatísticas**: O arquivo `/app/stats/{canal}.json` deve ter `last_restart` atualizado.

## Configuração

Para configurar a hora de reinício, adicione no arquivo `.env` do canal:

```bash
RESTART_HOUR=12  # Reinicia às 12:00
```

Ou configure pelo dashboard na aba "Configuração".

## Possíveis Melhorias Futuras

1. **Tolerância Configurável**: Permitir configurar quantos minutos de tolerância (atualmente fixo em 2).

2. **Múltiplos Horários**: Permitir reiniciar em múltiplos horários do dia.

3. **Notificações**: Enviar notificação antes do reinício.

4. **Logs Detalhados**: Registrar quando o próximo reinício está agendado.

