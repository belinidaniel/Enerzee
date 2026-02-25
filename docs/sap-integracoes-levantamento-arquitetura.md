# Levantamento SAP - AS-IS, Riscos e Desenho Arquitetural (v1)

Skills utilizados nesta analise:
- salesforce-analyst-Enerzee: levantamento funcional estruturado e rastreabilidade.
- salesforce-architect-Enerzee: avaliacao tecnica, desenho da arquitetura e recomendacoes Admin/Dev.

## 1) Summary (max 5 linhas)
- O projeto possui 9 fluxos SAP ativos, disparados principalmente por Trigger -> BO -> classe `@future(callout=true)`.
- Existe logging tecnico (`Log__c`), tab de logs, LWC de consulta em Opportunity e relatorio/dashboard de erros.
- A arquitetura atual funciona para baixo volume, mas tem riscos criticos de bulk, consistencia e seguranca.
- Foram encontrados defeitos de mapeamento de kits, risco de `uncommitted work pending`, token hardcoded e ausencia de retry estruturado.
- O desenho To-Be recomenda padronizacao em Queueable com idempotencia, DLQ e observabilidade ponta a ponta centrada em Opportunity.

## 2) Objetivo de negocio e KPIs
Objetivo:
- Mapear 100% das integracoes SAP existentes, validar aderencia arquitetural e definir plano de evolucao para confiabilidade, suporte e escala.

KPIs sugeridos:
- KPI-01 Cobertura de inventario: 100% dos processos SAP documentados (gatilho, payload, endpoint, log, erro).
- KPI-02 Taxa de sucesso SAP: >= 99% por processo (janela de 30 dias).
- KPI-03 MTTR de falha de integracao: <= 2 horas.
- KPI-04 Taxa de reprocessamento manual: <= 2% das chamadas.
- KPI-05 Rastreabilidade de negocio: >= 95% das chamadas com correlacao a `Opportunity` quando aplicavel.

## 3) Escopo
In-scope:
- Levantamento AS-IS de classes, triggers, endpoints, tokens, logs e mecanismos de acompanhamento.
- Diagnostico de defeitos tecnicos e gaps de arquitetura.
- Desenho de chamadas por processo em `.drawio`.

Out-of-scope:
- Implementacao de refactor/correcao de codigo neste ciclo.
- Mudanca de integração em ambiente produtivo.

Dependencias:
- Validacao com time SAP/BASIS para contrato de API e renovacao de token.
- Validacao com negocio para regras de classificacao e contrato.

Assumptions:
- `Integrador__mdt` continua sendo o repositorio oficial de endpoint parametrico no org atual.
- O fluxo comercial continua ancorado em `Opportunity` para contratos e pedidos.

## 4) Inventario AS-IS de integracoes SAP implementadas

| Processo | Disparo | Classe principal | Endpoint (Integrador__mdt) | Persistencia de retorno | Log |
|---|---|---|---|---|---|
| Cliente (Conta) | `AccountTriggerHandler.afterUpdate` | `IntegracaoSAPCliente.sendCliente` | `ClienteSAP` | `Account.SucessoIntegracaoSAP__c`, `Account.StatusBodyIntegracaoSAP__c` | `Utils.createLog` + `Log__c` |
| Cliente (via Oportunidade) | `OpportunityTriggerHandler.afterUpdate` | `OpportunityBO.sendCustomerRecordToSAP` -> `IntegracaoSAPCliente` | `ClienteSAP` | `Account.*` | `Log__c` |
| Consultor (classe implementada sem disparo ativo) | Nao identificado em Trigger/BO atual | `IntegracaoSAPConsultor.sendConsultor` | `ClienteSAP` | `Consultor__c.SucessoIntegracaoSAP__c`, `StatusBodyIntegracaoSAP__c` | `Log__c` |
| Fornecedor (Consultor) | `ConsultorTriggerHandler.afterInsert/afterUpdate` | `IntegracaoSAPFornecedor.sendFornecedor` | `FornecedorSAP` | `Consultor__c.*` | `Log__c` |
| Representante | `ConsultorTriggerHandler.afterInsert/afterUpdate` | `IntegracaoSAPRepresentante.sendRepresentante` | `RepresentanteSAP` | `Consultor__c.*` | `Log__c` |
| Integrador | `IntegradorTriggerHandler.afterInsert/afterUpdate` | `IntegracaoSAPIntegrador.sendIntegrador` | `FornecedorSAP` | `Integradores__c.SucessoIntegracaoSAP__c`, `StatusBodyIntegracaoSAP__c` | `Log__c` |
| Kit | `KitInstalacaoTriggerHandler.afterInsert/afterUpdate` | `IntegracaoSAPKit.sendKit` | `KitSAP` | `Kit_Instalacao__c.SucessoIntegracaoSAP__c`, `StatusBodyIntegracaoSAP__c` | `Log__c` |
| Pedido de Venda | `OpportunityBO.createSellBuyOrder` quando `Closed Won` | `IntegracaoSAPPedidoVenda.sendPedidoVenda` | `PedidoCompraVendaSAP` + sufixo `pedidovenda` | `Opportunity.SucessoIntegracaoSAP__c`, `StatusBodyIntegracaoSAP__c` | `Log__c` (com RelatedId) |
| Pedido de Compra | `OpportunityBO.createSellBuyOrder` quando `Closed Won` | `IntegracaoSAPPedidoCompra.sendPedidoCompra` | `PedidoCompraVendaSAP` + sufixo `pedidocompra` | `Opportunity.*` | `Log__c` (com RelatedId) |
| Contrato | `OpportunityBO.sendContractDataSAP` | `IntegracaoSAPContrato.sendContract` | `ContratoSAP` | `Opportunity.*` | `Log__c` (com RelatedId) |

## 5) Arquitetura usada hoje (AS-IS)
Padrao predominante:
1. Trigger (objeto de negocio)
2. BO/Service para regra de disparo
3. Classe SAP `@future(callout=true)`
4. Busca endpoint/token em `Integrador__mdt`
5. `HttpRequest` + `Utils.callIntegrationSAP`
6. Parse de `response.body.codigoHttp`
7. Atualiza flag/status no registro de origem
8. Grava log tecnico em `Log__c`

Caracteristicas:
- Configuracao via Custom Metadata (`Integrador__mdt`) para URL e token.
- Sem Named Credential/External Credential para SAP.
- Sem fila de reprocessamento dedicada para SAP.
- Sem correlacao unica obrigatoria por tentativa.

## 6) Defeitos e oportunidades (priorizado)

### P0 - Seguranca e compliance
- Token JWT exposto em metadata versionado:
  - `force-app/main/default/customMetadata/Integrador.TokenSAP.md-meta.xml:19`
  - `force-app/main/default/customMetadata/Integrador.TokenSAP_HML.md-meta.xml:19`
- Endpoints SAP reais versionados no repositório:
  - `force-app/main/default/customMetadata/Integrador.ClienteSAP.md-meta.xml:27`
  - `force-app/main/default/customMetadata/Integrador.PedidoCompraVendaSAP.md-meta.xml:27`

Impacto:
- Exposicao de segredo e superficie de ataque.

### P1 - Confiabilidade funcional
- Mapa de kits com chave incorreta em 3 classes, podendo agrupar itens de forma errada:
  - `IntegracaoSAPPedidoCompra.cls:26`
  - `IntegracaoSAPPedidoVenda.cls:26`
  - `IntegracaoSAPContrato.cls:24`
- DML de log dentro de `callIntegrationSAP` apos callout, com risco alto de `uncommitted work pending` em loops com multiplas chamadas:
  - `Utils.cls:286-287`
- Trigger de Integrador nao reabilita corretamente apos update:
  - `IntegracaoSAPIntegrador.cls:162` chama `isTriggerEnabled()` em vez de `enableTrigger()`
  - `IntegradorTriggerHandler.cls` nao possui `enableTrigger()`.
- Conversao sem null-check em Pedido Compra:
  - `IntegracaoSAPPedidoCompra.cls:48` (`Integer.valueOf(opp.NumeroContrato__c)`).
- Uso extensivo de `equalsIgnoreCase` sem protecao para null em campos de negocio:
  - ex. `IntegracaoSAPPedidoCompra.cls:51-57`, `70-90`.

Impacto:
- Falhas intermitentes, dados inconsistentes para SAP, risco de bloqueio em massa em transacoes bulk.

### P2 - Arquitetura e operacao
- Classe `IntegracaoSAPConsultor` implementada, mas sem invocacao de producao identificada (somente testes/chamada direta).
- `ConsultorBO` diz que Fornecedor esta descontinuado, mas ainda chama `IntegracaoSAPFornecedor`:
  - `ConsultorBO.cls:14` e `ConsultorBO.cls:38-40`.
- Regra de bypass por nome de usuario (`Integrador SAP`) e nao por permissao/perfil:
  - `AccountBO.cls`, `ConsultorBO.cls`, `OpportunityBO.cls`.
- Token diferente para Fornecedor (`TokenSAP_HML`) vs outros processos (`TokenSAP`):
  - `IntegracaoSAPFornecedor.cls:138`.
- Ausencia de idempotencia/retry/DLQ para SAP.

## 7) Sistema de log: existe? da para acompanhar?
Sim, existe.

O que existe hoje:
- Objeto `Log__c` com campos tecnicos de request/response/erro.
- Tab nativa: `force-app/main/default/tabs/Log__c.tab-meta.xml`.
- LWC de consulta por Opportunity:
  - `opportunityIntegrationLogs` em paginas de Opportunity (flexipages).
- Controller Apex para consulta de log com detalhe:
  - `OpportunityLogViewerController`.
- Relatorio e dashboard de erros enviados:
  - `reports/RelatriosAdministrativo/Logs_Erros_Enviados.report-meta.xml`
  - `dashboards/PastaPaineis/Erros_Integracoes_VO.dashboard-meta.xml`

Limitacoes de observabilidade:
- SAP nao padroniza `CorrelationId__c`/`IntegrationType__c` como VOLogService.
- Nem todos os processos gravam `RelatedId__c` com entidade rastreavel de negocio.
- Filtro de dashboard usa `Erro_Enviado__c = true`, campo que normalmente nao e setado pelos fluxos SAP.
- Consulta detalhada por LWC restringe acesso a perfis com `ViewAllData`/`ModifyAllData`.

## 8) Escalabilidade: faz sentido o que tem hoje?
Resposta curta: faz sentido para baixo volume e operacao assistida, nao para crescimento com SLA rigoroso.

Principais limites:
- `@future` em massa sem controle de microbatch por endpoint.
- Sem retry/backoff/dead-letter para falhas temporarias.
- Potencial conflito callout+DML em loop (`Utils.callIntegrationSAP`).
- Sem idempotency key e sem deduplicacao de eventos de trigger.
- Modelo de monitoramento mais reativo do que proativo.

## 9) As-Is vs To-Be (funcional)

AS-IS:
- Disparos automaticos por trigger com pouca governanca de reprocesso.
- Log tecnico existe, mas parcialmente padronizado entre integracoes.
- Falhas sao observadas por status em objeto e logs.

TO-BE:
- Integracao SAP orientada a fila (Queueable com `Database.AllowsCallouts`) com microbatch e idempotencia.
- Contrato de erro unificado com classificacao (transiente x permanente).
- Reprocesso controlado com fila de pendencias SAP.
- Observabilidade com `CorrelationId` obrigatorio e dashboard operacional por processo.

## 10) Requisitos funcionais (Analyst) para melhoria

### REQ-001 - Inventario oficial de integracoes SAP
Racional: governanca tecnica e visao unica do ecossistema.
Trigger: inicio de projeto de melhoria SAP.
Resultado esperado: catalogo unificado por processo, endpoint e ownership.

### REQ-002 - Rastreabilidade ponta a ponta por tentativa
Racional: reduzir tempo de diagnostico.
Trigger: envio de qualquer chamada SAP.
Resultado esperado: correlacao entre evento de negocio, request, response e resultado.

### REQ-003 - Reprocessamento controlado
Racional: recuperar falhas transientes sem acao manual ad-hoc.
Trigger: erro classificado como transiente.
Resultado esperado: nova tentativa com limite e trilha de auditoria.

### REQ-004 - Classificacao padrao de erro
Racional: separar incidente tecnico de erro de negocio.
Trigger: retorno nao sucesso.
Resultado esperado: categoria de erro, causa raiz e acao recomendada.

### REQ-005 - Monitoramento operacional
Racional: operacao proativa.
Trigger: atualizacao diaria/near real-time de indicadores.
Resultado esperado: painel por processo com volume, sucesso, erro e backlog de reprocesso.

### REQ-006 - Seguranca de credenciais
Racional: compliance e mitigacao de risco.
Trigger: leitura de token/segredo para chamada SAP.
Resultado esperado: segredo protegido, sem exposicao em metadata versionada.

### REQ-007 - Garantia de consistencia de payload
Racional: evitar falha por dados nulos/invalidos.
Trigger: montagem de payload.
Resultado esperado: validacao pre-envio e tratamento deterministico de campos obrigatorios.

### REQ-008 - Escalabilidade por volume
Racional: sustentar crescimento de dados/processos.
Trigger: lotes com multiplos registros.
Resultado esperado: processamento em lote com limites conhecidos e sem regressao funcional.

## 11) Data traceability matrix (alto nivel)

| Fonte | Transformacao | Destino | Ownership |
|---|---|---|---|
| `Account`, `Consultor__c`, `Integradores__c` | Mapeamento para `CardCode/CardName/...` | SAP Cliente/Fornecedor/Representante | Comercial + TI Salesforce |
| `Opportunity` + `Kit_Instalacao__c` | Mapeamento para contratos/pedidos | SAP Contrato/Pedido Compra/Pedido Venda | Operacoes + TI Salesforce |
| `Integrador__mdt` | Resolucao endpoint/token | Camada de callout | TI Salesforce |
| `HttpRequest/HttpResponse/Exception` | Persistencia tecnica | `Log__c` | TI Salesforce |

## 12) Business rules and exception handling matrix

| Regra | Comportamento esperado | Excecao |
|---|---|---|
| BR-001 | Nao enviar payload sem identificador externo valido (`CardCode`) | Registrar erro e bloquear envio |
| BR-002 | Pedido/Contrato so envia com kit valido por oportunidade | Registrar erro de consistencia e marcar para reprocesso |
| BR-003 | Falha transiente (timeout/5xx) deve entrar em retry | Apos max retries, enviar para fila de erro permanente |
| BR-004 | Falha funcional (4xx de negocio) nao deve retry automatico | Exigir correcao de dado origem |

## 13) Acceptance criteria (Given/When/Then)
- Given lote com 50 oportunidades elegiveis, When o processo de pedido roda, Then todas as 50 sao processadas sem erro de callout x DML.
- Given token expirado, When ocorre chamada SAP, Then o sistema renova credencial de forma segura e reenvia uma unica vez.
- Given erro 503 no endpoint, When a chamada falha, Then registro entra em fila de retry com tentativa incremental.
- Given erro 400 de negocio, When a chamada falha, Then nao ha retry automatico e a causa fica visivel no painel operacional.
- Given usuario de suporte autorizado, When abre tela de logs, Then consegue rastrear tentativa pelo CorrelationId e entidade de negocio.

## 14) Open questions
1. Qual e o contrato oficial de retorno SAP para todos os endpoints (sempre existe `codigoHttp` no body)?
2. Token SAP deve ser unico por ambiente ou por endpoint?
3. Qual politica de reprocessamento desejada (max tentativas, intervalo e owner)?
4. Quais processos sao criticos para SLA (ordem de prioridade entre Cliente, Pedido, Contrato, Kit)?
5. Qual e a volumetria media/pico por objeto por dia?

## 15) Integration Design (To-Be) - Admin/Dev
- Trocar `@future` por `Queueable` com `Database.AllowsCallouts` e microbatch (ex.: 20 registros por job).
- Criar `SAP_Integration_Job__c` (cabecalho) e `SAP_Integration_Item__c` (itens) para controle de estado, retry e DLQ.
- Adotar Named Credential + External Credential + segredo em vault (sem token em metadata versionada).
- Padronizar contrato de log no padrao `VOLogService` (CorrelationId, IntegrationType, Operation, CallOrigin, Erro_Enviado).
- Garantir ancora Opportunity para processos comerciais (Pedido/Contrato) com `RelatedId__c` e `Opportunity__c` de referencia.

## 16) Data Model (To-Be) - objetos e relacionamentos
- `SAP_Integration_Job__c`
  - Campos: `Processo__c`, `Status__c`, `Tentativas__c`, `CorrelationId__c`, `StartedAt__c`, `FinishedAt__c`.
- `SAP_Integration_Item__c`
  - Campos: `Job__c` (Master-Detail), `SourceRecordId__c`, `Opportunity__c` (Lookup), `PayloadHash__c`, `HTTPStatus__c`, `ErrorType__c`, `CanRetry__c`, `NextRetryAt__c`.
- `Log__c` (evolucao)
  - Adicionar `Opportunity__c` (Lookup) para reportabilidade Opportunity-centric.

Cardinalidade:
- `SAP_Integration_Job__c (1) -> (N) SAP_Integration_Item__c`.
- `SAP_Integration_Item__c (N) -> (1) Opportunity` (quando aplicavel).

## 17) Automation Strategy (Flow vs Apex)
- Apex para orquestracao de integracao SAP (callout, retry, DLQ, idempotencia).
- Flow apenas para orquestracao declarativa simples de negocio (sem callout SAP critico).
Justificativa:
- Controle de limites, resiliencia e padronizacao de erros exigem runtime programatico.

## 18) Security Model
- Credenciais fora de Custom Metadata em texto claro.
- Permissoes de leitura de logs via Permission Set dedicado de suporte, sem exigir `ViewAllData` global.
- Mascaramento de dados sensiveis no payload persistido (`cpf`, `cnpj`, token, email), seguindo padrao de `VOLogService`.

## 19) Custom Report Type e Standard Report (To-Be)
Custom Report Type sugerido:
- Primary object: `Opportunity`.
- Related: `SAP_Integration_Item__c` (with or without).
- Relatorio por fase, processo SAP, taxa de erro e tempo medio de processamento.

Standard report sugerido:
- Tipo: `Logs` / `Opportunity with SAP Integration Items`.
- Filtros: data, processo, status, `CanRetry__c`, `ErrorType__c`.
- Agrupamentos: processo, classe de erro, owner.
- Formulas: `% sucesso`, `% erro permanente`, `tempo medio ate sucesso`.

## 20) Validation checklist
- [ ] Nao ha token/segredo versionado em metadata.
- [ ] Processamento em lote nao quebra por `uncommitted work pending`.
- [ ] Retry ocorre apenas para erro transiente e respeita limite.
- [ ] Logs possuem `CorrelationId`, `Operation`, `IntegrationType`, `RelatedId`.
- [ ] Processo comercial (pedido/contrato) e rastreavel por Opportunity.
- [ ] Dashboard operacional mostra volume/sucesso/erro por processo.

## 21) Risks, Limitations and Alternatives
Riscos atuais:
- Vazamento de segredo.
- Falha em massa por limite de callout/transacao.
- Dificuldade de suporte por falta de correlacao padronizada.

Alternativas:
- Curto prazo: corrigir bugs criticos (mapa kit, null checks, trigger enable, token handling).
- Medio prazo: migrar para Queueable + Named Credential + DLQ.
- Longo prazo: event-driven com Platform Events para desacoplamento de trigger.
