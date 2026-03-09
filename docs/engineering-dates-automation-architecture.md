# Arquitetura — Preenchimento Automático de Datas para Indicadores de Engenharia

## 1. Diagnóstico do Estado Atual

### Campos com automação confirmada no repositório

| Campo                                 | Automação Existente                                                   |
| ------------------------------------- | --------------------------------------------------------------------- |
| `Instalacao__c.DataObraEmExecucao__c` | Flow `Instalacao_CaptureDataObraEmExecucao` — **OK**                  |
| `Projeto__c.ApprovalDate__c`          | Preenchimento manual via Layout + FieldSet `APROVACAO_DO_PROJETO_UFV` |
| `Case.ProjectApprovalDate__c`         | `OpportunityBO:2701` copia de `ApprovalDate__c` — **OK**              |

### Campos sem automação (gap confirmado)

| Campo                                           | Gap                          | Evidência no Código                                      |
| ----------------------------------------------- | ---------------------------- | -------------------------------------------------------- |
| `ViabilityStudy__c.DataConclusaoViabilidade__c` | Nenhuma automação de escrita | Zero referências de write em Apex/Flows                  |
| `Projeto__c.DataProtocoloProjeto__c`            | Nenhuma automação de escrita | Apenas FieldSet `PROTOCOLAR_PROJETO_UFV` (tela manual)   |
| `Projeto__c.DataAprovacaoProjeto__c`            | Nenhuma automação de escrita | Apenas FieldSet `APROVACAO_DO_PROJETO_UFV` (tela manual) |
| `Instalacao__c.DataConclusao__c`                | Nenhuma automação de escrita | Apenas lida por `WorkDeliveryReportPdfController`        |

### REQ-005 — Divergência ApprovalDate**c vs DataAprovacaoProjeto**c

**Mapeamento real dos dois campos:**

```
ApprovalDate__c (operacional)
  → ProjetoBO:1066  — trigger p/ criação de Task "Projeto Aprovado"
  → InstalacaoBO:127 — trigger p/ criação da Instalacao__c
  → OpportunityBO:2700 — copia para Case.ProjectApprovalDate__c
  → Múltiplos Reports legados

DataAprovacaoProjeto__c (dashboard)
  → FieldSet APROVACAO_DO_PROJETO_UFV (tela de aprovação)
  → DiasAteAprovacao__c formula: DataAprovacaoProjeto__c - DataProtocoloProjeto__c
  → Reports PRJ_TempoMedio_Aprovacao_SCEE_FastTrack
  → Dashboard Engenharia
```

**Conclusão**: São dois campos com papéis distintos — `ApprovalDate__c` é o gatilho operacional; `DataAprovacaoProjeto__c` é a data oficial para métricas. A solução é **sincronizar em uma direção** (DataAprovacaoProjeto**c → ApprovalDate**c), mantendo backward compatibility.

---

## 2. Decisão Técnica: Flow Before-Save vs Apex

### Trade-offs

| Critério                        | Before-Save Flow          | Apex beforeUpdate        |
| ------------------------------- | ------------------------- | ------------------------ |
| DML / Gov Limits                | Zero DML (não conta)      | Conta no budget          |
| Bulkificação                    | Nativa e automática       | Exige código explícito   |
| Query de registros relacionados | Não suporta               | Suporta                  |
| Auditabilidade                  | Visual no Flow Builder    | Requer leitura de código |
| Idempotência                    | Condicional simples no IF | if/null check manual     |
| Complexidade lógica             | Limitada                  | Ilimitada                |

### Decisão: Before-Save Record-Triggered Flows para todos os 4 stamps

**Justificativa**: Todos os 4 casos são stamps de `TODAY()` em campo null, condicionados a mudança de campo/status no próprio registro. Nenhum requer query de registros relacionados. Before-Save elimina DML budget, é bulkificado nativamente e mantém lógica auditável fora do Apex.

**Exceção**: REQ-005 (sync ApprovalDate\_\_c) — implementado no **mesmo Before-Save Flow do Projeto**, aproveitando o contexto já ativo.

---

## 3. Arquitetura de Implementação

### Componentes a criar

```
force-app/main/default/flows/
  ViabilityStudy_StampDatasEngenharia.flow-meta.xml    (NOVO)
  Projeto_StampDatasEngenharia.flow-meta.xml           (NOVO)
  Instalacao_StampDataConclusao.flow-meta.xml          (NOVO)

force-app/main/default/classes/
  EngineeringDateBackfillBatch.cls                     (NOVO - carga retroativa)
  EngineeringDateBackfillBatchTest.cls                 (NOVO)
```

---

### Flow 1: `ViabilityStudy_StampDatasEngenharia`

```
Tipo: Record-Triggered Flow — Before-Save
Objeto: ViabilityStudy__c
Gatilho: Update (e Create para segurança)
Entry Condition: StatusFeasibility__c = 'Viabilidade Finalizada'

Decision: DataConclusaoViabilidade__c IS NULL?
  └─ SIM → Assignment: DataConclusaoViabilidade__c = {!$Flow.CurrentDate}
  └─ NÃO → (não sobrescreve — preserva data original se já preenchida)
```

**Cobertura**: AC-001, REQ-001

**Risco**: Verificar se `Finish_Viability_Study_Flow` já grava este campo — se sim, adicionar condição `OR StatusFeasibility__c CHANGED TO 'Viabilidade Finalizada'` para evitar dupla execução. O Flow existente apenas muda o status, não escreve a data (confirmado no grep).

---

### Flow 2: `Projeto_StampDatasEngenharia`

```
Tipo: Record-Triggered Flow — Before-Save
Objeto: Projeto__c
Gatilho: Update

Decision A: DataAprovacaoProjeto__c mudou AND não é null?
  └─ SIM → Assignment: ApprovalDate__c = {!$Record.DataAprovacaoProjeto__c}
            (sync unidirecional: DataAprovacaoProjeto__c → ApprovalDate__c)

Decision B: Status__c mudou para [VALOR_PROTOCOLO] AND DataProtocoloProjeto__c IS NULL?
  └─ SIM → Assignment: DataProtocoloProjeto__c = {!$Flow.CurrentDate}
```

**Cobertura**: AC-002, AC-003, REQ-002, REQ-003, REQ-005

**Questão em aberto**: Qual é o status exato de "protocolo"? FieldSet `PROTOCOLAR_PROJETO_UFV` existe para uma ação de tela — o gatilho pode ser mudança de status OU a ação de tela em si (Quick Action/LWC que salva o registro). **A definir com o negócio.**

**Impacto no Apex existente**: O sync `DataAprovacaoProjeto__c → ApprovalDate__c` fará com que `ProjetoBO:1066` (que monitora mudança de `ApprovalDate__c`) seja acionado corretamente quando o usuário preencher `DataAprovacaoProjeto__c` na tela. O Flow corre no Before-Save, o Apex roda no After-Update — sequência correta.

---

### Flow 3: `Instalacao_StampDataConclusao`

```
Tipo: Record-Triggered Flow — Before-Save
Objeto: Instalacao__c
Gatilho: Update
Entry Condition: Status__c CHANGED TO 'Obra concluída - Aguardando troca de medidor'

Decision: DataConclusao__c IS NULL?
  └─ SIM → Assignment: DataConclusao__c = {!$Flow.CurrentDate}
  └─ NÃO → (não sobrescreve)
```

**Cobertura**: AC-004, REQ-004

**Status confirmado**: A description de `DiasDeExecucao__c` já menciona explicitamente "Conclusão da Obra (aguardando troca de medidor)". O valor exato do picklist deve ser confirmado antes do deploy.

---

### Batch: `EngineeringDateBackfillBatch` (Carga Retroativa)

```apex
// Executado manualmente via Execute Anonymous após validação em Sandbox

// Invocação 1: ViabilityStudy
Database.executeBatch(new EngineeringDateBackfillBatch('ViabilityStudy'), 200);

// Invocação 2: ProjetoApproval
Database.executeBatch(new EngineeringDateBackfillBatch('ProjetoApproval'), 200);

// Invocação 3: ProjetoProtocol (apenas se existir fonte de data confiável)
Database.executeBatch(new EngineeringDateBackfillBatch('ProjetoProtocol'), 200);

// Invocação 4: Instalacao
Database.executeBatch(new EngineeringDateBackfillBatch('Instalacao'), 200);
```

**Lógica por invocação**:

| Invocação       | Query                                                                                          | Update                                                                           |
| --------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| ViabilityStudy  | `WHERE StatusFeasibility__c = 'Viabilidade Finalizada' AND DataConclusaoViabilidade__c = null` | `DataConclusaoViabilidade__c = LastModifiedDate` + flag `BackfillDate__c = true` |
| ProjetoApproval | `WHERE ApprovalDate__c != null AND DataAprovacaoProjeto__c = null`                             | `DataAprovacaoProjeto__c = ApprovalDate__c`                                      |
| ProjetoProtocol | `WHERE DataProtocoloProjeto__c = null AND Status__c = [VALOR_PROTOCOLO]`                       | `DataProtocoloProjeto__c = LastModifiedDate` + flag                              |
| Instalacao      | `WHERE Status__c = 'Obra concluída...' AND DataConclusao__c = null`                            | `DataConclusao__c = LastModifiedDate` + flag                                     |

> **Atenção**: Para todos exceto ProjetoApproval (que tem `ApprovalDate__c` como fonte exata), a data será `LastModifiedDate` como aproximação. Recomendo adicionar um campo `DataRetrocarga__c` (Checkbox) para filtrar esses registros nos relatórios se necessário. **Validar com o negócio antes da execução.**

---

## 4. Diagrama de Sequência

```
USUÁRIO altera StatusFeasibility__c → 'Viabilidade Finalizada'
  └─ Before-Save Flow executa
       └─ DataConclusaoViabilidade__c = TODAY()  ← stamp automático
  └─ Record salvo
  └─ ViabilityStudyTrigger (after update)
       └─ ViabilityStudyBO.createTasks()          ← cria tarefas do status
       └─ ViabilityStudyBO.syncOpportunityInstalledPower()

USUÁRIO preenche DataAprovacaoProjeto__c na tela de Aprovação
  └─ Before-Save Flow executa
       └─ ApprovalDate__c = DataAprovacaoProjeto__c  ← sync
  └─ Record salvo
  └─ ProjetoTrigger (after update)
       └─ ProjetoBO.createTaskProjectApproved()  ← detecta ApprovalDate__c changed
            └─ Cria Task "Projeto Aprovado" no Case
       └─ InstalacaoBO.ensureInstallationOnProjectApproved()  ← cria Instalacao__c

USUÁRIO altera Status__c da Instalacao para 'Obra concluída - Aguardando troca de medidor'
  └─ Before-Save Flow executa
       └─ DataConclusao__c = TODAY()  ← stamp automático
  └─ Record salvo
```

---

## 5. Riscos e Mitigações

| Risco                                                                       | Probabilidade | Impacto                        | Mitigação                                                                             |
| --------------------------------------------------------------------------- | ------------- | ------------------------------ | ------------------------------------------------------------------------------------- |
| `Finish_Viability_Study_Flow` já escreve `DataConclusaoViabilidade__c`      | Baixa         | Duplicidade / sobrescrita      | Verificar Flow XML antes de criar novo; adicionar condição IS NULL                    |
| 31 Flows no Opportunity acionados por mudança de status em ViabilityStudy   | Média         | Cascata de updates             | Mapear Flows que tocam `StatusFeasibility__c` antes do deploy                         |
| Sync Before-Save + update manual de `ApprovalDate__c` no layout causa loop  | Baixa         | Loop ou sobrescrita indesejada | No Flow 2, condicionar apenas se `DataAprovacaoProjeto__c` foi alterado (`ISCHANGED`) |
| Retrocarga com `LastModifiedDate` como data aproximada distorce indicadores | Alta          | Dados históricos incorretos    | Flag `DataRetrocarga__c` + filtro nos Reports + validação com negócio antes           |
| Status de "protocolo" não identificado no repositório                       | Alta          | REQ-002/AC-002 bloqueados      | Bloquear implementação de `DataProtocoloProjeto__c` até confirmação do negócio        |

---

## 6. Checklist de Implementação

### Pré-deploy (validações obrigatórias)

- [ ] Confirmar valor exato do picklist de status de "protocolo" em `Projeto__c`
- [ ] Confirmar valor exato do picklist `'Obra concluída - Aguardando troca de medidor'` em `Instalacao__c`
- [ ] Verificar conteúdo de `Finish_Viability_Study_Flow` — buscar qualquer escrita em `DataConclusaoViabilidade__c`
- [ ] Mapear quais dos 31 Flows de Opportunity reagem a mudança de `StatusFeasibility__c` em ViabilityStudy
- [ ] Confirmar com negócio: retrocarga usa `LastModifiedDate` como aproximação ou existe fonte externa?
- [ ] Confirmar com negócio: `ApprovalDate__c` será descontinuado após a migração ou mantido para compatibilidade?

### Implementação — Prioridade 1

- [ ] Criar `ViabilityStudy_StampDatasEngenharia` (Before-Save Flow)
- [ ] Criar `Projeto_StampDatasEngenharia` com Decision A apenas (sync DataAprovacaoProjeto**c → ApprovalDate**c)
- [ ] Criar `Instalacao_StampDataConclusao` (Before-Save Flow)
- [ ] Testes unitários: verificar que campos só são gravados quando null (idempotência)
- [ ] Deploy em Sandbox + validar com Relatório de Engenharia

### Implementação — Prioridade 2 (após confirmação de status de protocolo)

- [ ] Adicionar Decision B em `Projeto_StampDatasEngenharia` (stamp `DataProtocoloProjeto__c`)

### Implementação — Prioridade 3 (retrocarga)

- [ ] Criar `EngineeringDateBackfillBatch` + `EngineeringDateBackfillBatchTest`
- [ ] Executar em Sandbox com volume real, validar com Report de Engenharia
- [ ] Aprovação explícita do negócio para datas aproximadas
- [ ] Executar em Produção em janela de baixo uso (fora do horário comercial)
- [ ] Validar contagem de registros atualizados vs esperado

### Manifest

```xml
<!-- package.xml -->
<types>
  <members>ViabilityStudy_StampDatasEngenharia</members>
  <members>Projeto_StampDatasEngenharia</members>
  <members>Instalacao_StampDataConclusao</members>
  <name>Flow</name>
</types>
<types>
  <members>EngineeringDateBackfillBatch</members>
  <members>EngineeringDateBackfillBatchTest</members>
  <name>ApexClass</name>
</types>
```

---

## 7. Questões em Aberto — Decisão Necessária Antes de Implementar

| #   | Questão                                                                                                          | Impacto se não respondida                    |
| --- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Q1  | Qual o status exato de "protocolo" do Projeto? (mudança de status, Task fechada, ou ação em tela?)               | Bloqueia REQ-002/AC-002                      |
| Q2  | `ApprovalDate__c` será descontinuado após migração?                                                              | Define se o sync é permanente ou temporário  |
| Q3  | A retrocarga aceita `LastModifiedDate` como data aproximada para `DataConclusao__c` e `DataProtocoloProjeto__c`? | Bloqueia REQ-006/AC-005                      |
| Q4  | Existe sistema externo (SAP, planilha) com datas históricas dos marcos?                                          | Muda completamente a abordagem da retrocarga |
