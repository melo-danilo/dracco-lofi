# Lógica de Reinício Automático

## Como Funciona

O sistema reinicia automaticamente as lives em um horário configurado para garantir que cada live tenha exatamente 24 horas de duração.

### Verificação Contínua

O script verifica a cada 60 segundos se é hora de reiniciar.

### Condições para Reinício

- Hora atual deve ser igual à `RESTART_HOUR` (0-23)
- Minuto atual deve ser menor que 2 (0 ou 1)
- Não deve ter reiniciado nesta mesma hora hoje

### Exemplo de Funcionamento

Se `RESTART_HOUR=12`:
- ✅ 12:00 → Reinicia
- ✅ 12:01 → Reinicia (ainda dentro da janela)
- ❌ 12:02 → Não reinicia (fora da janela)
- ❌ 12:03 → Não reinicia
- ❌ 13:00 → Não reinicia (hora diferente)

## Configuração

Para configurar a hora de reinício, adicione no arquivo `.env` do canal:

```bash
RESTART_HOUR=12  # Reinicia às 12:00
```

Ou configure pelo dashboard na aba "Configuração".

## Problemas Corrigidos

### 1. Comparação de Horas com Zero à Esquerda

**Problema**: Comparação `"09" == "9"` falharia em alguns casos.

**Solução**: Normalização usando `$((10#$VAR))` que remove zero à esquerda e converte para número.

### 2. Janela de Tempo para Reinício

**Problema**: A lógica original só reiniciava nos primeiros 5 minutos, mas isso poderia falhar se o script iniciasse depois desse período.

**Solução**: Reduzido para 2 minutos e melhorada a lógica de detecção.

### 3. Rastreamento de Último Reinício

**Problema**: Usava apenas a hora (HH), o que poderia causar problemas se o script reiniciasse múltiplas vezes no mesmo dia.

**Solução**: Agora usa formato `YYYY-MM-DD-HH` para garantir reinício apenas uma vez por hora.

## Testes Recomendados

1. **Teste Manual**: Configure `RESTART_HOUR` para alguns minutos à frente e observe os logs.

2. **Verificar Logs**: Procure por:
   ```
   [INFO] Hora de reiniciar a live (12h)...
   [INFO] Encerrando stream atual...
   [INFO] Iniciando stream com vídeo: ...
   ```

3. **Verificar Estatísticas**: O arquivo `/app/stats/{canal}.json` deve ter `last_restart` atualizado.

## Possíveis Melhorias Futuras

1. **Tolerância Configurável**: Permitir configurar quantos minutos de tolerância (atualmente fixo em 2).

2. **Múltiplos Horários**: Permitir reiniciar em múltiplos horários do dia.

3. **Notificações**: Enviar notificação antes do reinício.

4. **Logs Detalhados**: Registrar quando o próximo reinício está agendado.

