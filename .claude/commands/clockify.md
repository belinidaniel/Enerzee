# Lançar Horas no Clockify — Enerzee

Lança horas em um ticket SAL no Clockify usando o script `scripts/clockify-log`.

## Input

$ARGUMENTS

_(Formato: `<TICKET> <HH:MM> <HH:MM> [YYYY-MM-DD] [TAG]`)_

## O que fazer

1. Parse os argumentos fornecidos pelo usuário
2. Se o argumento estiver vazio ou incompleto, exiba o uso correto e encerre
3. Execute o script com os parâmetros extraídos:

```bash
bash scripts/clockify-log <TICKET> <START> <END> [DATE] [TAG]
```

## Tags disponíveis

| Tag           | Uso                             |
| ------------- | ------------------------------- |
| BUG           | Correção de bug (default)       |
| DEV           | Desenvolvimento geral           |
| FEATURE       | Nova funcionalidade             |
| ENHANCEMENT   | Melhoria em funcionalidade      |
| REFACTOR      | Refatoração de código           |
| UPDATE        | Atualização / ajuste            |
| TEST          | Testes e cobertura              |
| SUPPORT       | Suporte e atendimento           |
| CALL          | Reunião / chamada               |
| HOTFIX        | Correção urgente em produção    |
| INVESTIGATION | Investigação / análise de causa |

## Exemplos

```bash
# Mínimo — lança com tag BUG e data de hoje
/clockify SAL-386 14:00 15:30

# Com data específica
/clockify SAL-386 14:00 15:30 2026-03-04

# Com tag específica
/clockify SAL-386 14:00 15:30 2026-03-04 DEV
```

## Output esperado

Após executar, mostre o resultado do script diretamente. Em caso de erro (ticket não encontrado, tag inválida, etc.), exiba a mensagem de erro e oriente o usuário.
