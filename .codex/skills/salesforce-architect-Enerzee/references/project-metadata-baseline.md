# Baseline da Cadeia Opportunity -> ViabilityStudy -> Projeto -> Instalacao

_Fonte: leitura dos metadados em `force-app/main/default`._

_Escopo: este arquivo cobre a cadeia ponta a ponta principal. Para inventario global de dependencias do projeto inteiro, usar `docs/project-dependencies-full.md`._

## Objetos alvo

- `Opportunity`
- `ViabilityStudy__c`
- `Projeto__c`
- `Instalacao__c`

## 1) Cadeia principal e campos ancora

- `ViabilityStudy__c.Opportunity__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `Estudos_de_Viabilidades`
  - Arquivo: `force-app/main/default/objects/ViabilityStudy__c/fields/Opportunity__c.field-meta.xml`

- `Opportunity.MainViability__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `Opportunities`
  - Arquivo: `force-app/main/default/objects/Opportunity/fields/MainViability__c.field-meta.xml`

- `Projeto__c.Viabilidade__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `ProjetosViabilidade`
  - Arquivo: `force-app/main/default/objects/Projeto__c/fields/Viabilidade__c.field-meta.xml`

- `Projeto__c.Oportunidade__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `Projetos`
  - Arquivo: `force-app/main/default/objects/Projeto__c/fields/Oportunidade__c.field-meta.xml`

- `Projeto__c.Instalacao__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `SetNull`
  - RelationshipName: `Projetos`
  - Arquivo: `force-app/main/default/objects/Projeto__c/fields/Instalacao__c.field-meta.xml`

- `Instalacao__c.Projeto__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `Instalacoes`
  - Arquivo: `force-app/main/default/objects/Instalacao__c/fields/Projeto__c.field-meta.xml`

- `Instalacao__c.Oportunidade__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `Restrict`
  - RelationshipName: `InstalacoesOportunidade`
  - Arquivo: `force-app/main/default/objects/Instalacao__c/fields/Oportunidade__c.field-meta.xml`

- `Instalacao__c.OportunidadeConcluida__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `SetNull`
  - RelationshipName: `Instalacoes`
  - Arquivo: `force-app/main/default/objects/Instalacao__c/fields/OportunidadeConcluida__c.field-meta.xml`

- `Opportunity.Instalacao__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `SetNull`
  - RelationshipName: `Oportunidades`
  - Arquivo: `force-app/main/default/objects/Opportunity/fields/Instalacao__c.field-meta.xml`

- `Opportunity.ParentOpportunity__c`
  - Tipo: `Lookup` | Required: `false` | Delete constraint: `SetNull`
  - RelationshipName: `Opportunities`
  - Arquivo: `force-app/main/default/objects/Opportunity/fields/ParentOpportunity__c.field-meta.xml`

## 2) Referencias para os 4 objetos da cadeia

Total: **26** campos (`Lookup`/`MasterDetail`) apontando para pelo menos um objeto da cadeia.

Distribuicao por alvo:
- `Opportunity`: 16
- `ViabilityStudy__c`: 3
- `Projeto__c`: 3
- `Instalacao__c`: 4

| Campo | Tipo | Referencia | RelationshipName | Required | Arquivo |
|---|---|---|---|---|---|
| `Case.Nome_da_Oportunidade__c` | `Lookup` | `Opportunity` | `Casos` | `false` | `force-app/main/default/objects/Case/fields/Nome_da_Oportunidade__c.field-meta.xml` |
| `Case.Oportunidade_Pai__c` | `Lookup` | `Opportunity` | `OportunidadePaiCasos` | `false` | `force-app/main/default/objects/Case/fields/Oportunidade_Pai__c.field-meta.xml` |
| `ClickSign__c.Opportunity__c` | `Lookup` | `Opportunity` | `ClickSign` | `false` | `force-app/main/default/objects/ClickSign__c/fields/Opportunity__c.field-meta.xml` |
| `Faturamento__c.Instalacao__c` | `Lookup` | `Instalacao__c` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Instalacao__c.field-meta.xml` |
| `Faturamento__c.Oportunidade__c` | `Lookup` | `Opportunity` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Oportunidade__c.field-meta.xml` |
| `Faturamento__c.Projeto__c` | `Lookup` | `Projeto__c` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Projeto__c.field-meta.xml` |
| `Feedback__c.Opportunity__c` | `Lookup` | `Opportunity` | `Feedbacks` | `false` | `force-app/main/default/objects/Feedback__c/fields/Opportunity__c.field-meta.xml` |
| `Instalacao__c.OportunidadeConcluida__c` | `Lookup` | `Opportunity` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/OportunidadeConcluida__c.field-meta.xml` |
| `Instalacao__c.Oportunidade__c` | `Lookup` | `Opportunity` | `InstalacoesOportunidade` | `false` | `force-app/main/default/objects/Instalacao__c/fields/Oportunidade__c.field-meta.xml` |
| `Instalacao__c.Projeto__c` | `Lookup` | `Projeto__c` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/Projeto__c.field-meta.xml` |
| `Kit_Instalacao__c.Nome_da_Oportunidade__c` | `MasterDetail` | `Opportunity` | `Kit_Instalacoes` | `(implicit/none)` | `force-app/main/default/objects/Kit_Instalacao__c/fields/Nome_da_Oportunidade__c.field-meta.xml` |
| `MessagingEndUser.Oportunidade__c` | `Lookup` | `Opportunity` | `Usuarios_do_Messaging` | `false` | `force-app/main/default/objects/MessagingEndUser/fields/Oportunidade__c.field-meta.xml` |
| `Opportunity.Instalacao__c` | `Lookup` | `Instalacao__c` | `Oportunidades` | `false` | `force-app/main/default/objects/Opportunity/fields/Instalacao__c.field-meta.xml` |
| `Opportunity.MainViability__c` | `Lookup` | `ViabilityStudy__c` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/MainViability__c.field-meta.xml` |
| `Opportunity.ParentOpportunity__c` | `Lookup` | `Opportunity` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/ParentOpportunity__c.field-meta.xml` |
| `OpportunityAttachmentLink__c.OpportunityId__c` | `Lookup` | `Opportunity` | `Anexos_Externo_da_Oportunidade` | `false` | `force-app/main/default/objects/OpportunityAttachmentLink__c/fields/OpportunityId__c.field-meta.xml` |
| `Projeto__c.Instalacao__c` | `Lookup` | `Instalacao__c` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Instalacao__c.field-meta.xml` |
| `Projeto__c.Oportunidade__c` | `Lookup` | `Opportunity` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Oportunidade__c.field-meta.xml` |
| `Projeto__c.Viabilidade__c` | `Lookup` | `ViabilityStudy__c` | `ProjetosViabilidade` | `false` | `force-app/main/default/objects/Projeto__c/fields/Viabilidade__c.field-meta.xml` |
| `ProposalPending__c.Opportunity__c` | `Lookup` | `Opportunity` | `ProposalPendings` | `true` | `force-app/main/default/objects/ProposalPending__c/fields/Opportunity__c.field-meta.xml` |
| `ServiceAppointment.Oportunidade__c` | `Lookup` | `Opportunity` | `CompromissosServico` | `false` | `force-app/main/default/objects/ServiceAppointment/fields/Oportunidade__c.field-meta.xml` |
| `ViabilityStudy__c.Opportunity__c` | `Lookup` | `Opportunity` | `Estudos_de_Viabilidades` | `false` | `force-app/main/default/objects/ViabilityStudy__c/fields/Opportunity__c.field-meta.xml` |
| `WorkOrder.InstalacaoAssociada__c` | `Lookup` | `Instalacao__c` | `OrdensTrabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/InstalacaoAssociada__c.field-meta.xml` |
| `WorkOrder.Oportunidade__c` | `Lookup` | `Opportunity` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/Oportunidade__c.field-meta.xml` |
| `WorkOrder.Projeto__c` | `Lookup` | `Projeto__c` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/Projeto__c.field-meta.xml` |
| `WorkOrder.ViabilityStudy__c` | `Lookup` | `ViabilityStudy__c` | `Work_Orders` | `false` | `force-app/main/default/objects/WorkOrder/fields/ViabilityStudy__c.field-meta.xml` |

## 3) Regras de integridade (Validation Rules)

| Objeto | Regra | Ativa | Objetivo | Arquivo |
|---|---|---|---|---|
| `Opportunity` | `MainViability_Must_Belong_to_Opportunity` | `true` | `MainViability__c` deve pertencer a mesma Opportunity | `force-app/main/default/objects/Opportunity/validationRules/MainViability_Must_Belong_to_Opportunity.validationRule-meta.xml` |
| `Opportunity` | `ViabilityShouldFinished` | `true` | Bloqueia avancar fase sem viabilidade finalizada | `force-app/main/default/objects/Opportunity/validationRules/ViabilityShouldFinished.validationRule-meta.xml` |
| `ViabilityStudy__c` | `Require_Opportunity` | `false` | Impede viabilidade sem Opportunity | `force-app/main/default/objects/ViabilityStudy__c/validationRules/Require_Opportunity.validationRule-meta.xml` |
| `Projeto__c` | `Require_Opp_and_Viability` | `false` | Impede projeto sem Opportunity e Viabilidade | `force-app/main/default/objects/Projeto__c/validationRules/Require_Opp_and_Viability.validationRule-meta.xml` |
| `Projeto__c` | `Viability_Must_Belong_to_Opportunity` | `false` | `Viabilidade__r.Opportunity__c` deve ser igual a `Oportunidade__c` | `force-app/main/default/objects/Projeto__c/validationRules/Viability_Must_Belong_to_Opportunity.validationRule-meta.xml` |
| `Instalacao__c` | `Require_Projeto` | `false` | Impede instalacao sem projeto | `force-app/main/default/objects/Instalacao__c/validationRules/Require_Projeto.validationRule-meta.xml` |
| `Instalacao__c` | `Oportunidade_Must_Match_Projeto` | `false` | `Oportunidade__c` deve bater com `Projeto__r.Oportunidade__c` | `force-app/main/default/objects/Instalacao__c/validationRules/Oportunidade_Must_Match_Projeto.validationRule-meta.xml` |

## 4) Formulas e referencias cross-object da cadeia

- `Projeto__c/validationRules/Viability_Must_Belong_to_Opportunity`: `Viabilidade__r.Opportunity__c <> Oportunidade__c`
- `Instalacao__c/validationRules/Oportunidade_Must_Match_Projeto`: `Oportunidade__c <> Projeto__r.Oportunidade__c`
- `Instalacao__c/fields/ValorInstalacaoPlanejado__c`: usa `OportunidadeConcluida__r.ValorInstalacao__c`
- `Projeto__c/fields/ConcessionariaEnergia__c`: usa `Oportunidade__r.ConcessionariaEnergia__c`
- `Projeto__c/fields/NecessarioProtocolarProjetoCCSS__c`: usa `Oportunidade__r.NecessarioProtocolarProjetoCCSS__c`
- `Projeto__c/fields/TipoRegistroOportunidade__c`: usa `Oportunidade__r.RecordType.DeveloperName`
- `Projeto__c/fields/PotenciaPicoSistemakWp__c`: usa `Oportunidade__r.PotenciaPicoSistema__c`
- `Projeto__c/fields/UFConcessionAriaEnergia__c`: usa `Oportunidade__r.UF_Concessionaria__c`
- `Projeto__c/fields/ViabilityStudyOwner__c`: usa `Oportunidade__r.ViabilityStudyOwner__r.*`
- `ViabilityStudy__c/fields/OpportunityType__c`: usa `Opportunity__r.RecordType.Name`

## 5) Automacoes

### 5.1 Triggers e handlers da cadeia

- `force-app/main/default/triggers/OpportunityTrigger.trigger` -> `OpportunityTriggerHandler`
- `force-app/main/default/triggers/ViabilityStudyTrigger.trigger` -> `ViabilityStudyTriggerHandler`
- `force-app/main/default/triggers/ProjetoTrigger.trigger` -> `ProjetoTriggerHandler`
- `force-app/main/default/triggers/InstalacaoTrigger.trigger` -> `InstalacaoTriggerHandler`

Handlers:
- `force-app/main/default/classes/OpportunityTriggerHandler.cls`
- `force-app/main/default/classes/ViabilityStudyTriggerHandler.cls`
- `force-app/main/default/classes/ProjetoTriggerHandler.cls`
- `force-app/main/default/classes/InstalacaoTriggerHandler.cls`

Classes de dominio/servico principais:
- `force-app/main/default/classes/OpportunityBO.cls`
- `force-app/main/default/classes/ViabilityStudyBO.cls`
- `force-app/main/default/classes/ProjetoBO.cls`
- `force-app/main/default/classes/InstalacaoBO.cls`
- `force-app/main/default/classes/CaseBO.cls`
- `force-app/main/default/classes/FaturamentoBO.cls`
- `force-app/main/default/classes/ServiceAppointmentBO.cls`
- `force-app/main/default/classes/IntegracaoNivelloViabilidade.cls`
- `force-app/main/default/classes/IntegracaoNivelloProjetos.cls`

Busca textual em Apex/Trigger para a cadeia: **143 arquivos** (criterio: ocorrencias de `Opportunity|ViabilityStudy__c|Projeto__c|Instalacao__c` em `classes/` e `triggers/`).

### 5.2 Flows por objeto

Opportunity (31):
- `Batch_Task_Project_Journey.flow-meta.xml`
- `Create_Viability_Study_Flow.flow-meta.xml`
- `Enviar_Email_Nova_Oportunidade_Criada.flow-meta.xml`
- `Enviar_Email_Solicitacao_de_Simulacao_de_Financiamento.flow-meta.xml`
- `Enviar_Email_ap_s_7_dias_teis_do_envio_de_Contrato.flow-meta.xml`
- `Finish_Viability_Study_Flow.flow-meta.xml`
- `Fluxo_Aceite_Proposta.flow-meta.xml`
- `Fluxo_atualizar_Opp_concluida_em_Instalacao.flow-meta.xml`
- `Notificacao_Readequar_Proposta.flow-meta.xml`
- `Notificar_Proprietario_sobre_fases_da_proposta.flow-meta.xml`
- `Notificar_fases_da_proposta_financeiro.flow-meta.xml`
- `OpportunityAfterSave.flow-meta.xml`
- `OpportunityUpdateOpportunityOwner.flow-meta.xml`
- `Opportunity_Before_Insert.flow-meta.xml`
- `Opportunity_Bow_e_is_promotional.flow-meta.xml`
- `Opportunity_Monitoramento_SLA.flow-meta.xml`
- `Opportunity_Send_Proposal_Manually.flow-meta.xml`
- `Opportunity_Shipping_address.flow-meta.xml`
- `Opportunity_Update_Owner_Integracao.flow-meta.xml`
- `Opportunity_Update_Viability_Approval.flow-meta.xml`
- `Opportunity_Update_economic_simulation_data.flow-meta.xml`
- `Opportunity_close_Opportunity_with_Activitity.flow-meta.xml`
- `Readequacao_de_Propostas.flow-meta.xml`
- `Send_Feedback_Email.flow-meta.xml`
- `Start_Conversation_Opportunity.flow-meta.xml`
- `TaskAfterSave.flow-meta.xml`
- `TaskNotificarAtribuicaoAoFechador.flow-meta.xml`
- `Task_Before_Insert.flow-meta.xml`
- `Task_Jornada_do_Cliente.flow-meta.xml`
- `VarListaOpp.flow-meta.xml`
- `Viability_Solicitacao_de_Viabilidade_Local.flow-meta.xml`

ViabilityStudy__c (4):
- `Create_Viability_Study_Flow.flow-meta.xml`
- `Finish_Viability_Study_Flow.flow-meta.xml`
- `Opportunity_Update_Viability_Approval.flow-meta.xml`
- `Viability_Solicitacao_de_Viabilidade_Local.flow-meta.xml`

Projeto__c (3):
- `Fluxo_atualizar_Opp_concluida_em_Instalacao.flow-meta.xml`
- `Project_After_Update.flow-meta.xml`
- `Projeto_After_save.flow-meta.xml`

Instalacao__c (1):
- `Fluxo_atualizar_Opp_concluida_em_Instalacao.flow-meta.xml`

Flows com maior impacto de consistencia:
- `Create_Viability_Study_Flow.flow-meta.xml`
- `Finish_Viability_Study_Flow.flow-meta.xml`
- `Opportunity_Update_Viability_Approval.flow-meta.xml`
- `Fluxo_atualizar_Opp_concluida_em_Instalacao.flow-meta.xml`
- `Project_After_Update.flow-meta.xml`

## 6) Reportabilidade

### 6.1 Report type ponta a ponta

- API name: `Oportunidades_com_Viabilidade_Projeto_Instalacao`
- Arquivo: `force-app/main/default/reportTypes/Oportunidades_com_Viabilidade_Projeto_Instalacao.reportType-meta.xml`
- Cadeia:
  - `Opportunity`
  - `Opportunity.Estudos_de_Viabilidades__r` (`outerJoin=true`)
  - `Opportunity.Estudos_de_Viabilidades__r.ProjetosViabilidade__r` (`outerJoin=true`)
  - `Opportunity.Estudos_de_Viabilidades__r.ProjetosViabilidade__r.Instalacoes__r` (`outerJoin=true`)
- Campo ancora exposto: `Opportunity.MainViability__c`

### 6.2 Outros report types com dependencias da cadeia

- `force-app/main/default/reportTypes/Oportunidades_com_Projetos.reportType-meta.xml`
- `force-app/main/default/reportTypes/Oportunidades_e_Projetos.reportType-meta.xml`
- `force-app/main/default/reportTypes/Projeto.reportType-meta.xml`
- `force-app/main/default/reportTypes/Ordem_de_trabalho.reportType-meta.xml`
- `force-app/main/default/reportTypes/Ordem_de_trabalho_e_compromisso.reportType-meta.xml`
- `force-app/main/default/reportTypes/Compromissos_de_servicos.reportType-meta.xml`
- `force-app/main/default/reportTypes/Atividades_de_tarefas_para_projeto_e_oportunidades.reportType-meta.xml`

### 6.3 Relatorios consumidores (encontrados)

Baseado em `Oportunidades_com_Viabilidade_Projeto_Instalacao__c`:
- `force-app/main/default/reports/RelatriosViabilidade/Lifecycle_Oportunidade_Viabilidade_Projeto_Instalacao.report-meta.xml`

Baseado em `Oportunidades_e_Projetos__c`:
- `force-app/main/default/reports/CONTROLE_EZEESOLAR_REVO/REVO_GERAL_FIN_dv7.report-meta.xml`
- `force-app/main/default/reports/CONTROLE_EZEESOLAR_REVO/REVO_PERDIDO_FIN_QSR.report-meta.xml`
- `force-app/main/default/reports/CONTROLE_EZEESOLAR_REVO/ENGENHARIA_REVO_GERAL_0DV.report-meta.xml`
- `force-app/main/default/reports/CONTROLE_EZEESOLAR_REVO/COMISSAO_REVO_Ft8.report-meta.xml`

Baseado em `Ordem_de_trabalho__c`:
- `force-app/main/default/reports/Service_Dashboards_Reports/Ordens_de_Trabalho_SMR.report-meta.xml`

## 7) UI, Experience e componentes

Flexipages com objetos/campos da cadeia: **12**
- `force-app/main/default/flexipages/Estudo_de_Viabilidade_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/Instala_o_P_gina_de_registro.flexipage-meta.xml`
- `force-app/main/default/flexipages/OportunidadePaginaDeRegistroEzeeBowE.flexipage-meta.xml`
- `force-app/main/default/flexipages/Oportunidade_P_gina_de_registro.flexipage-meta.xml`
- `force-app/main/default/flexipages/Oportunidade_P_gina_de_registro1.flexipage-meta.xml`
- `force-app/main/default/flexipages/Oportunidade_P_gina_de_registro1_Ezee_Solar.flexipage-meta.xml`
- `force-app/main/default/flexipages/Oportunidade_P_gina_de_registro_Ezee_Connect.flexipage-meta.xml`
- `force-app/main/default/flexipages/Opportunity_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/Opportunity_Record_Page1.flexipage-meta.xml`
- `force-app/main/default/flexipages/Opportunity_Record_Page2.flexipage-meta.xml`
- `force-app/main/default/flexipages/Projeto_Pagina_de_registro.flexipage-meta.xml`
- `force-app/main/default/flexipages/Projeto_Pagina_de_registro_OLD.flexipage-meta.xml`

Layouts com campos da cadeia: **32** (mapeados por busca textual).

LWC expostos na cadeia via `.js-meta.xml`:
- `force-app/main/default/lwc/opportunityIntegrationLogs/opportunityIntegrationLogs.js-meta.xml`
- `force-app/main/default/lwc/opportunityProposalConsole/opportunityProposalConsole.js-meta.xml`
- `force-app/main/default/lwc/proposalPendingPanel/proposalPendingPanel.js-meta.xml`

LWC com referencias de objetos/campos da cadeia no codigo:
- `force-app/main/default/lwc/clickSignDataSource/clickSignDataSource.js`
- `force-app/main/default/lwc/feedbackConsultant/feedbackConsultant.html`
- `force-app/main/default/lwc/feedbackConsultant/feedbackConsultant.js`
- `force-app/main/default/lwc/leadOpportunityAlert/leadOpportunityAlert.js`
- `force-app/main/default/lwc/messageSessionOrgnizer/messageSessionOrgnizer.js`
- `force-app/main/default/lwc/opportunityIntegrationLogs/opportunityIntegrationLogs.js`
- `force-app/main/default/lwc/opportunityProposalConsole/opportunityProposalConsole.js`
- `force-app/main/default/lwc/opportunityViabilityForm/opportunityViabilityForm.html`
- `force-app/main/default/lwc/opportunityViabilityForm/opportunityViabilityForm.js`
- `force-app/main/default/lwc/proposalPendingPanel/proposalPendingPanel.js`

Visualforce com `standardController="Opportunity"`:
- `force-app/main/default/pages/PropostaContainer.page`
- `force-app/main/default/pages/ModeloPropostaA.page`
- `force-app/main/default/pages/ModeloPropostaB.page`
- `force-app/main/default/pages/ModeloPropostaBowe.page`
- `force-app/main/default/pages/ModeloPropostaEzeeConnect.page`

## 8) Acesso e aplicacoes

Permission Sets com permissao para objetos da cadeia: **8**
- `force-app/main/default/permissionsets/ConjuntoPermissaoPowerBI.permissionset-meta.xml`
- `force-app/main/default/permissionsets/CreateFieldPermission.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Custom_permission_user.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Engenharia.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Estudo_de_viabilidade.permissionset-meta.xml`
- `force-app/main/default/permissionsets/FSL_Resource_Permissions.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Modificar_todos_os_dados.permissionset-meta.xml`
- `force-app/main/default/permissionsets/close_any_task.permissionset-meta.xml`

Profiles com permissao para objetos da cadeia: **1**
- `force-app/main/default/profiles/Administrador.profile-meta.xml`

Aplicacoes com navegacao/visibilidade da cadeia:
- `force-app/main/default/applications/New_App_Sales.app-meta.xml`
- `force-app/main/default/applications/Sales.app-meta.xml`
- `force-app/main/default/applications/Vendas.app-meta.xml`

## 9) Riscos arquiteturais no estado atual

- Relacionamentos criticos da cadeia estao, em sua maioria, com `required=false`.
- Regras de integridade mais importantes em `ViabilityStudy__c`, `Projeto__c` e `Instalacao__c` estao inativas.
- Ha redundancia de caminhos para a mesma verdade de negocio:
  - `Projeto__c.Oportunidade__c` vs `Projeto__c.Viabilidade__r.Opportunity__c`
  - `Instalacao__c.Oportunidade__c` vs `Instalacao__c.Projeto__r.Oportunidade__c`
- Report type ponta a ponta usa `outerJoin=true` em todos os niveis, o que preserva linhas mas pode mascarar inconsistencias.
- A rastreabilidade depende fortemente de automacoes (triggers + flows), elevando risco de regressao por ordem de execucao.
