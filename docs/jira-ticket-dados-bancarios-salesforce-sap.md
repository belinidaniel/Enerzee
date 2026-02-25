# Jira Story Refinement - Dados bancarios Salesforce nao refletindo no SAP

## 1) Contexto da historia
Titulo sugerido:
- Dados bancarios Salesforce nao refletindo no SAP.

Descricao original (normalizada):
- Os dados bancarios cadastrados no Salesforce nao estao sendo refletidos no SAP.

Problema de negocio:
- Divergencia entre Salesforce e SAP para dados bancarios gera risco operacional, retrabalho manual, inconsistencias cadastrais e bloqueio em processos dependentes no ERP.

Prioridade sugerida:
- Alta.

## 2) Evidencias AS-IS (codigo atual)
1. O envio de dados bancarios ao SAP existe para:
   - `Consultor__c` via `IntegracaoSAPFornecedor.sendFornecedor`.
   - `Integradores__c` via `IntegracaoSAPIntegrador.sendIntegrador`.
2. Nos dois fluxos, os campos bancarios so entram no payload quando os 3 campos estao preenchidos ao mesmo tempo (`Conta__c`, `Agencia__c`, `Banco__c`).
3. No fluxo de Consultor, existe filtro por usuario: se o usuario for `Integrador SAP`, o envio para SAP nao e disparado.
4. No fluxo de Integradores, o trigger e desabilitado no final do processamento e nao e reabilitado explicitamente, o que pode impedir envios subsequentes no mesmo ciclo de execucao.
5. Existe divergencia de token entre processos (`TokenSAP_HML` em Fornecedor vs `TokenSAP` em Integrador), o que exige governanca de credencial por ambiente/processo.

Referencias de codigo (AS-IS):
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegracaoSAPFornecedor.cls:38`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegracaoSAPFornecedor.cls:138`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/ConsultorBO.cls:22`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegracaoSAPIntegrador.cls:75`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegracaoSAPIntegrador.cls:160`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegracaoSAPIntegrador.cls:162`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/IntegradorTriggerHandler.cls:13`

## 3) Objetivo de negocio e KPI
Objetivo:
- Garantir que alteracoes de dados bancarios no Salesforce sejam refletidas no SAP de forma consistente, auditavel e dentro de SLA operacional.

KPIs:
- KPI-01 Cobertura de sincronizacao de dados bancarios elegiveis: 100%.
- KPI-02 Taxa de sucesso da sincronizacao bancaria no SAP: >= 99% (30 dias).
- KPI-03 MTTR para falha de sincronizacao bancaria: <= 2 horas.
- KPI-04 100% das falhas classificadas por causa e owner.
- KPI-05 100% dos eventos com rastreabilidade de origem e resultado.

## 4) As-Is vs To-Be (funcional)
As-Is:
- Existe envio de dados bancarios para SAP, mas com dependencia de condicoes implicitas (ex.: trio de campos completos, contexto de usuario, estado de trigger).
- Falhas e ausencias de sincronizacao podem ocorrer sem padronizacao completa de tratativa funcional.

To-Be:
- Toda alteracao bancaria elegivel e processada e refletida no SAP com comportamento previsivel.
- Casos com dados incompletos, credencial invalida ou bloqueios operacionais sao classificados e tratados com ownership claro.
- Operacao possui rastreabilidade ponta a ponta e mecanismo de retomada controlada.

## 5) Escopo
In-scope:
- Refinar regra funcional de sincronizacao de dados bancarios Salesforce -> SAP para entidades elegiveis.
- Definir comportamento para dados bancarios incompletos.
- Definir governanca de credencial/processo para evitar divergencia de ambiente.
- Definir monitoramento, classificacao de falha e retomada operacional.

Out-of-scope:
- Redesenho completo de toda arquitetura SAP.
- Mudancas em processos nao relacionados a dados bancarios.
- Revisoes fiscais/contabeis fora do cadastro bancario.

## 6) Requisitos funcionais
### REQ-001 - Sincronizacao obrigatoria de alteracao bancaria elegivel
Racional: garantir consistencia cadastral entre Salesforce e SAP.
Ator: Processo de integracao SAP.
Trigger: criacao/atualizacao de registro elegivel com impacto bancario.
Pre-condicao: registro em status apto para integracao.
Resultado esperado: alteracao bancaria e enviada e refletida no SAP.
Ownership: TI Salesforce + Operacao.

### REQ-002 - Regra explicita para dados bancarios incompletos
Racional: evitar perda silenciosa de sincronizacao.
Ator: Processo de integracao / Suporte.
Trigger: tentativa de envio com campos bancarios incompletos.
Pre-condicao: ao menos 1 campo bancario preenchido sem completude minima exigida.
Resultado esperado: bloqueio controlado da sincronizacao com classificacao de pendencia e orientacao de tratativa.
Ownership: TI Salesforce + Suporte + Negocio (regra de completude).

### REQ-003 - Aplicacao consistente independente do usuario executor
Racional: evitar divergencia entre atualizacao manual e automatizada.
Ator: Usuario operacional / Integracao.
Trigger: alteracao bancaria por usuario humano ou tecnico.
Pre-condicao: alteracao elegivel para refletir no SAP.
Resultado esperado: comportamento funcional padronizado para sincronizacao, sem lacunas por perfil/nome de usuario sem governanca formal.
Ownership: TI Salesforce + Governanca de Acesso.

### REQ-004 - Continuidade de disparo para atualizacoes consecutivas
Racional: evitar interrupcao de envios futuros apos primeira tentativa.
Ator: Processo de trigger/integracao.
Trigger: multiplas atualizacoes sequenciais de dados bancarios.
Pre-condicao: registros elegiveis alterados em sequencia.
Resultado esperado: cada alteracao elegivel gera tentativa correspondente sem bloqueio residual de disparo.
Ownership: TI Salesforce.

### REQ-005 - Governanca de credencial por ambiente/processo
Racional: reduzir falha por configuracao divergente.
Ator: Administracao de integracao.
Trigger: chamada de integracao bancaria para SAP.
Pre-condicao: credenciais e endpoints configurados por ambiente.
Resultado esperado: processo usa credencial valida e aderente ao ambiente/processo oficial.
Ownership: TI Salesforce + Integracao SAP.

### REQ-006 - Rastreabilidade operacional completa
Racional: reduzir tempo de diagnostico.
Ator: Suporte.
Trigger: qualquer tentativa de sincronizacao bancaria.
Pre-condicao: tentativa executada.
Resultado esperado: suporte localiza origem, payload relevante, retorno, status e owner da tratativa.
Ownership: TI Salesforce + Suporte.

### REQ-007 - Reprocessamento controlado de pendencias bancarias
Racional: recuperar consistencia apos correcao sem retrabalho disperso.
Ator: Suporte.
Trigger: pendencia bancaria corrigida.
Pre-condicao: causa raiz resolvida.
Resultado esperado: registro retorna ao fluxo com trilha de auditoria.
Ownership: TI Salesforce + Suporte.

## 7) Matriz de rastreabilidade de dados
| Fonte | Transformacao funcional | Destino | Ownership |
|---|---|---|---|
| `Consultor__c` (`Banco__c`, `Agencia__c`, `Conta__c`) | Mapeamento para atributos bancarios do parceiro no SAP | SAP (cadastro de parceiro) | Operacao Comercial + TI Salesforce |
| `Integradores__c` (`Banco__c`, `Agencia__c`, `Conta__c`) | Mapeamento para atributos bancarios do parceiro no SAP | SAP (cadastro de parceiro) | Operacoes + TI Salesforce |
| Configuracao de integracao (token/endpoint) | Resolucao de credencial e destino | Chamada SAP | TI Salesforce + Integracao SAP |
| Retorno HTTP/erro | Classificacao de sucesso/falha e tratativa | Log operacional + status de sincronizacao | TI Salesforce + Suporte |

## 8) Regras de negocio e excecoes
| ID | Regra | Comportamento esperado | Excecao |
|---|---|---|---|
| BR-001 | Registro elegivel com dados bancarios completos deve sincronizar | Atualizacao refletida no SAP | Falha de conectividade/credencial => classificar e tratar |
| BR-002 | Dados bancarios incompletos nao podem seguir como sucesso | Bloqueio controlado com pendencia explicita | Se regra de completude nao definida => bloquear go-live |
| BR-003 | Alteracao bancaria deve ter comportamento uniforme por contexto de execucao | Sem diferenca funcional indevida por usuario | Excecao governada deve ser documentada e auditavel |
| BR-004 | Disparos sequenciais devem permanecer ativos | Cada alteracao elegivel gera nova tentativa | Se disparo ficar inativo => incidente operacional |
| BR-005 | Toda tentativa precisa de trilha de auditoria | Origem, horario, retorno e owner visiveis | Sem rastreabilidade => nao conforme |

## 9) Criterios de aceitacao (Given/When/Then)
### AC-REQ-001
- Given registro elegivel com `Banco`, `Agencia` e `Conta` validos, When ocorrer criacao/atualizacao, Then os dados bancarios devem refletir no SAP.

### AC-REQ-002
- Given registro com dados bancarios parciais, When processo de sincronizacao for acionado, Then a tentativa nao deve finalizar como sucesso e deve gerar pendencia classificada.

### AC-REQ-003
- Given alteracao bancaria feita por contexto operacional distinto (usuario comum ou usuario tecnico), When evento elegivel ocorrer, Then o comportamento de sincronizacao deve ser consistente conforme regra oficial.

### AC-REQ-004
- Given duas ou mais alteracoes bancarias consecutivas no mesmo objeto, When os eventos forem processados, Then cada alteracao deve gerar tentativa de sincronizacao sem perda de disparo.

### AC-REQ-005
- Given ambiente produtivo com credenciais oficiais configuradas, When chamada bancaria ao SAP ocorrer, Then o processo deve usar credencial aderente ao ambiente e retornar status auditavel.

### AC-REQ-006
- Given suporte consultando um erro bancario, When abrir o registro de integracao, Then deve visualizar causa classificada, owner e proximo passo.

### AC-REQ-007
- Given pendencia bancaria corrigida, When reprocessamento for executado, Then o registro deve retomar fluxo com evidencia de resultado.

## 10) Dependencias
- Definicao oficial de regra de completude bancaria (campos obrigatorios e formato).
- Validacao conjunta com time SAP para contrato de retorno em cenarios de erro.
- Governanca de credenciais por ambiente/processo.
- Definicao de ownership operacional para tratativa e SLA.

## 11) Assumptions
- O ticket cobre entidades hoje integradas para fornecedor/parceiro no SAP.
- Os campos bancarios permanecem como origem de dado no Salesforce.
- A operacao deseja sincronizacao automatica, nao manual.

## 12) Open Questions
1. O escopo inclui apenas `Consultor__c`, apenas `Integradores__c`, ou ambos?
2. Qual regra oficial de completude bancaria (todos os 3 campos obrigatorios ou regra alternativa)?
3. Existe excecao formal para atualizacoes feitas por usuario tecnico (`Integrador SAP`)?
4. Qual credencial oficial por ambiente para os fluxos de fornecedor/parceiro?
5. Ha necessidade de backfill/reprocessamento de historico nao refletido no SAP?

## 13) Decision Log (inicial)
- DEC-001: Ticket classificado como sincronizacao critica Salesforce -> SAP para dados bancarios.
- DEC-002: Historias devem incluir regra explicita para dados incompletos para evitar falso sucesso.
- DEC-003: Handoff tecnico depende do fechamento de escopo (Consultor/Integrador) e regra de completude.

## 14) Plano de execucao (texto pronto para Jira)
### Fase 1 - Diagnostico e alinhamento funcional (D0-D1)
- Confirmar entidades no escopo e regra de completude bancaria.
- Validar comportamento esperado por contexto de usuario.
- Confirmar politica de credencial por ambiente/processo.

### Fase 2 - Refinamento e aprovacao (D1-D2)
- Aprovar REQ-001 a REQ-007 com Operacao, Suporte, TI e SAP.
- Fechar Open Questions criticas.
- Congelar escopo para handoff tecnico.

### Fase 3 - Implementacao e homologacao funcional (D2-D4)
- Executar implementacao conforme arquitetura aprovada.
- Homologar cenarios positivos, negativos e sequenciais.
- Validar rastreabilidade e classificacao operacional.

### Fase 4 - Go-live e monitoramento assistido (D4-D6)
- Publicar em producao em janela aprovada.
- Monitorar sucesso e falhas por 48h.
- Reprocessar pendencias corrigidas com evidencia.

### Fase 5 - Encerramento (D6)
- Medir KPIs iniciais.
- Registrar licoes aprendidas.
- Encerrar com evidencias de estabilidade.

## 15) Checklist Definition of Ready
- [ ] Escopo fechado (Consultor, Integrador ou ambos).
- [ ] Regra de completude bancaria aprovada.
- [ ] Regra de contexto de usuario aprovada.
- [ ] REQ-001 a REQ-007 aprovados.
- [ ] Ownership e SLA de tratativa definidos.
- [ ] Criterios Given/When/Then aprovados.
