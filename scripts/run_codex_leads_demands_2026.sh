#!/usr/bin/env bash

set -euo pipefail

if ! command -v codex >/dev/null 2>&1; then
  echo "Erro: comando 'codex' nao encontrado no PATH." >&2
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

MODEL=""
if [[ $# -ge 2 && "$1" == "--model" ]]; then
  MODEL="$2"
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$ROOT_DIR/.codex/runs"
mkdir -p "$RUN_DIR"

PROMPT_FILE="$RUN_DIR/lead_demands_2026_prompt_${TIMESTAMP}.md"
LAST_MESSAGE_FILE="$RUN_DIR/lead_demands_2026_result_${TIMESTAMP}.md"
EVENTS_FILE="$RUN_DIR/lead_demands_2026_events_${TIMESTAMP}.jsonl"

cat >"$PROMPT_FILE" <<'PROMPT'
Contexto: projeto Salesforce da Enerzee.
Objetivo: implementar as demandas de Lead de 29/01/2026 em codigo e metadata, sem deixar apenas analise.

Demandas que DEVEM ser implementadas:
1) Lead Consultor
- Distribuicao automatica para consultores habilitados para receber Lead Consultor.
- Criterios de elegibilidade:
  - Faixa Verde V.O.
  - Gold para cima.
  - Campo de excecao "Faixa Especial Consultor" (recebe mesmo fora do criterio padrao).
  - Campo para congelar recebimento de Lead Consultor.
- Rodizio com prioridade geografia:
  - Preferir mesmo estado/cidade do lead e consultor.
  - Distribuicao equilibrada (evitar concentracao).
- Leads de consultor chegam por Web-to-Lead-Consultor ou SDR tag de tipo de registro "Qualificacao de Consultores".

2) Lead Consumidor Final / Cliente
- Investigar e corrigir porque alguns Leads entram no status "Trabalhando" indevidamente.
- Corrigir fluxo de troca manual do consultor:
  - Ao alterar consultor manualmente, refletir no app sem necessidade de desmarcar "Integracao Distribuicao Lead".
  - Evitar remarcacao automatica confusa desse checkbox.
- Atualizar Score de Qualificacao conforme documento 2026.
  - Se o documento nao existir no repo, implementar estrutura parametrizavel e registrar TODO objetivo no output final.

3) Agente SDR
- Quando lead demonstrar interesse inicial mas nao completar todos os dados:
  - Marcar como "Lead incompleto" (tag/campo/status conforme padrao do projeto).
- Ajustar classificacao de produto:
  - Nao assumir "ezee solar" quando nao houver clareza.
  - Nesses casos, manter produto aberto/neutro e encaminhar para especialista.

4) Lead Cliente B2B
- Criar modo de recebimento de leads B2B sem rodizio por faixa/nivel.
- Deixar opcao manual de habilitar quem recebe B2B (consultores especificos ou comercial interno).
- Quando campanha B2B (ex: Bess) for criada, distribuir automaticamente para os habilitados B2B.
- Validar regra do email do consultor especifico vindo do formulario Meta:
  - Garantir que apenas o consultor indicado receba, quando esse modo for usado.

Arquivos/alvos provaveis (nao limitado a estes):
- force-app/main/default/classes/LeadDistributionSelector.cls
- force-app/main/default/classes/LeadBO.cls
- force-app/main/default/classes/LeadIntegrationService.cls
- force-app/main/default/classes/LeadIntegrationBatch.cls
- force-app/main/default/classes/LeadTriggerHandler.cls
- force-app/main/default/triggers/LeadTrigger.trigger
- force-app/main/default/flows/Lead_Update_After_Distribui_o_do_Lead.flow-meta.xml
- force-app/main/default/flows/Flow_Atualiza_Status_do_Lead.flow-meta.xml
- force-app/main/default/flows/Lead_After_Save.flow-meta.xml
- force-app/main/default/flows/AgentForce_Update_Lead_by_Lead_Interaction.flow-meta.xml
- force-app/main/default/flows/Messaging_Session_After_Update.flow-meta.xml
- force-app/main/default/flows/Lead_Qualification_Score.flow-meta.xml
- force-app/main/default/objects/Lead/fields/*
- force-app/main/default/objects/Consultor__c/fields/*

Requisitos tecnicos:
- Preferir logica centralizada e testavel em Apex para distribuicao.
- Manter compatibilidade com fluxo atual de integracao e evitar regressao de distribuicao existente.
- Criar/atualizar testes Apex para os cenarios novos e regressivos.
- Nao remover funcionalidades existentes sem substituicao clara.

Validacao obrigatoria ao final:
1) Executar testes relevantes (ideal: os testes de Lead/distribuicao/integracao).
2) Mostrar resumo objetivo:
   - arquivos alterados
   - regras implementadas por demanda
   - lacunas remanescentes (se houver)
3) Entregar sugestao de deploy/rollback.
PROMPT

CODEX_CMD=(codex -a never exec -C "$ROOT_DIR" -s danger-full-access --json -o "$LAST_MESSAGE_FILE")
if [[ -n "$MODEL" ]]; then
  CODEX_CMD+=(-m "$MODEL")
fi
CODEX_CMD+=(-)

echo "Executando Codex para implementar demandas de Lead..."
echo "Prompt: $PROMPT_FILE"
echo "Resumo final: $LAST_MESSAGE_FILE"
echo "Eventos JSONL: $EVENTS_FILE"

"${CODEX_CMD[@]}" < "$PROMPT_FILE" | tee "$EVENTS_FILE"

echo
echo "Execucao concluida."
echo "- Prompt: $PROMPT_FILE"
echo "- Resultado: $LAST_MESSAGE_FILE"
echo "- Eventos: $EVENTS_FILE"
