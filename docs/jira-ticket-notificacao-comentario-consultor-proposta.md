# Jira Story Refinement - Criar notificacao para responsavel da proposta quando houver comentario do consultor

## 1) Contexto da historia
Titulo sugerido:
- Criar notificacao para responsavel da proposta quando houver comentario do consultor.

Descricao normalizada:
- Deve ser criada uma notificacao para o usuario responsavel pela proposta sempre que a proposta criada tiver comentario do consultor no campo "Comentario do solicitante".

Problema de negocio:
- Comentarios do consultor em proposta podem nao ser percebidos rapidamente pelo responsavel, gerando atraso em tratativa, readequacao e resposta ao cliente.

Prioridade sugerida:
- Media/Alta (impacto em tempo de resposta comercial e experiencia do consultor/cliente).

## 2) Evidencias AS-IS (codigo atual)
1. O campo de comentario existe em Opportunity (`ComentarioSolicitante__c`) e e LongTextArea.
2. O campo esta presente em layouts/flexipages, mas nao ha automacao especifica encontrada que dispare notificacao com base nesse campo.
3. Existe automacao de notificacao por fase de proposta (`Notificar_Proprietario_sobre_fases_da_proposta`), mas gatilhada por `StageName` e via email alert, nao por comentario do solicitante.
4. A proposta e tratada no dominio Opportunity (ex.: `PropostaGerada__c`) e o responsavel da oportunidade pode ser definido por parceiro (`OwnerOpportunity__c` -> `OwnerId`).

Referencias de codigo (AS-IS):
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/objects/Opportunity/fields/ComentarioSolicitante__c.field-meta.xml:3`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/flows/Notificar_Proprietario_sobre_fases_da_proposta.flow-meta.xml:88`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/OpportunityBO.cls:710`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/OpportunityBO.cls:1706`
- `/Users/danielbelini/Documents/_Workspace/GitHub/Enerzee-GIT/force-app/main/default/classes/OpportunityTriggerHandler.cls:88`

## 3) Objetivo de negocio e KPI
Objetivo:
- Garantir que comentarios do consultor em propostas gerem notificacao tempestiva ao responsavel, reduzindo tempo de resposta e retrabalho.

KPIs:
- KPI-01 Cobertura de notificacao para propostas elegiveis com comentario: 100%.
- KPI-02 Tempo medio entre comentario e notificacao ao responsavel: <= 5 minutos.
- KPI-03 Taxa de notificacoes com destinatario valido (usuario ativo): 100%.
- KPI-04 Taxa de duplicidade indevida de notificacao por mesmo comentario: <= 1%.
- KPI-05 Rastreabilidade de disparo/notificacao: 100% dos eventos.

## 4) As-Is vs To-Be (funcional)
As-Is:
- Comentario do solicitante existe, mas sem regra funcional explicita para notificar o responsavel da proposta quando houver comentario.
- Notificacoes de proposta existentes focam transicao de fase (`StageName`) e nao mudanca de comentario.

To-Be:
- Sempre que proposta elegivel receber comentario do consultor, o responsavel pela proposta recebe notificacao no canal definido.
- Processo evita notificacao duplicada sem alteracao de conteudo.
- Falhas de destinatario/entrega ficam classificadas para tratativa.

## 5) Escopo
In-scope:
- Definir gatilho funcional para comentario do consultor em proposta.
- Definir destinatario oficial da notificacao (responsavel da proposta).
- Definir regra anti-duplicidade e criterios de elegibilidade da proposta.
- Definir conteudo minimo da notificacao (contexto e link da oportunidade/proposta).
- Definir rastreabilidade e monitoramento do disparo.

Out-of-scope:
- Redesenho de toda jornada de notificacoes da oportunidade.
- Mudancas em regras de fase/proposta sem relacao com comentario do solicitante.
- Alteracao de ownership comercial fora da necessidade desta historia.

## 6) Requisitos funcionais
### REQ-001 - Disparo de notificacao por comentario em proposta elegivel
Racional: garantir visibilidade imediata de observacao do consultor.
Ator: Sistema Salesforce.
Trigger: criacao/atualizacao de comentario do solicitante em oportunidade com proposta elegivel.
Pre-condicao: proposta em estado elegivel definido pelo negocio.
Resultado esperado: notificacao enviada ao responsavel da proposta.
Ownership: TI Salesforce + Operacao Comercial.

### REQ-002 - Destinatario oficial da notificacao
Racional: evitar ambiguidade de quem deve agir.
Ator: Sistema Salesforce.
Trigger: evento elegivel de comentario.
Pre-condicao: regra de ownership definida.
Resultado esperado: notificacao enviada ao usuario responsavel oficial da proposta.
Ownership: Negocio + TI Salesforce.

### REQ-003 - Regra anti-duplicidade
Racional: evitar ruido operacional.
Ator: Sistema Salesforce.
Trigger: atualizacao de oportunidade.
Pre-condicao: comentario ja notificado sem mudanca de conteudo.
Resultado esperado: nao reenviar notificacao duplicada sem alteracao relevante.
Ownership: TI Salesforce.

### REQ-004 - Conteudo minimo da notificacao
Racional: permitir acao imediata do responsavel.
Ator: Sistema Salesforce.
Trigger: notificacao gerada.
Pre-condicao: evento elegivel confirmado.
Resultado esperado: notificacao contem numero/nome da proposta, trecho do comentario e link para o registro.
Ownership: TI Salesforce + Operacao Comercial.

### REQ-005 - Tratamento de excecao de destinatario
Racional: garantir continuidade operacional quando destinatario estiver invalido/inativo.
Ator: Sistema + Suporte.
Trigger: tentativa de envio para destinatario invalido.
Pre-condicao: owner ausente, inativo ou sem canal valido.
Resultado esperado: falha classificada com rota de fallback definida (owner alternativo/fila/suporte).
Ownership: TI Salesforce + Suporte.

### REQ-006 - Rastreabilidade de notificacao
Racional: auditoria e diagnostico.
Ator: Suporte.
Trigger: qualquer tentativa de notificacao.
Pre-condicao: tentativa executada.
Resultado esperado: registro auditavel de sucesso/falha, destinatario e horario.
Ownership: TI Salesforce + Suporte.

### REQ-007 - Alinhamento com notificacoes ja existentes de proposta
Racional: evitar sobreposicao e conflito entre fluxos.
Ator: TI Salesforce.
Trigger: ativacao da nova regra.
Pre-condicao: coexistencia com fluxo de notificacao por fase.
Resultado esperado: regras convivem sem duplicar comunicacao indevida.
Ownership: TI Salesforce.

## 7) Matriz de rastreabilidade de dados
| Fonte | Transformacao funcional | Destino | Ownership |
|---|---|---|---|
| `Opportunity.ComentarioSolicitante__c` | Identificacao de comentario elegivel para notificacao | Evento de notificacao | Comercial + TI Salesforce |
| `Opportunity.PropostaGerada__c` e/ou criterio de proposta elegivel | Determinacao de elegibilidade do disparo | Regra de gatilho | Negocio + TI Salesforce |
| `Opportunity.OwnerId` (ou responsavel oficial definido) | Resolucao do destinatario | Usuario que recebe notificacao | Comercial + TI Salesforce |
| Dados do registro (`Id`, `Name`, `Numeroproposta__c`) | Montagem de mensagem com contexto | Conteudo da notificacao | TI Salesforce |
| Resultado do envio | Classificacao sucesso/falha | Auditoria e suporte | TI Salesforce + Suporte |

## 8) Regras de negocio e excecoes
| ID | Regra | Comportamento esperado | Excecao |
|---|---|---|---|
| BR-001 | Comentario em proposta elegivel deve notificar responsavel | Notificacao disparada no evento elegivel | Sem proposta elegivel: nao notificar |
| BR-002 | Destinatario deve ser o responsavel oficial da proposta | Envio ao owner/responsavel definido | Se invalido/inativo, aplicar fallback aprovado |
| BR-003 | Nao reenviar sem mudanca de comentario | Evitar duplicidade | Mudanca relevante no comentario permite novo envio |
| BR-004 | Conteudo da notificacao deve permitir acao imediata | Titulo, comentario e link presentes | Conteudo incompleto = nao conforme |
| BR-005 | Disparos devem ser auditaveis | Log de sucesso/falha e horario | Sem trilha = nao conforme |

## 9) Criterios de aceitacao (Given/When/Then)
### AC-REQ-001
- Given oportunidade com proposta elegivel, When `ComentarioSolicitante__c` for preenchido com conteudo valido, Then o responsavel da proposta deve receber notificacao.

### AC-REQ-002
- Given oportunidade com proposta elegivel e comentario alterado, When houver nova alteracao de conteudo, Then deve ser enviada nova notificacao correspondente.

### AC-REQ-003
- Given comentario sem alteracao relevante apos notificacao ja enviada, When registro for atualizado, Then nao deve haver notificacao duplicada.

### AC-REQ-004
- Given responsavel da proposta invalido/inativo, When ocorrer evento elegivel, Then a notificacao deve seguir regra de fallback definida e registrar a ocorrencia.

### AC-REQ-005
- Given notificacao enviada, When usuario abrir o alerta, Then deve conseguir acessar diretamente a oportunidade/proposta relacionada.

### AC-REQ-006
- Given tentativa de notificacao (sucesso ou falha), When suporte auditar o evento, Then deve localizar destinatario, horario, status e causa.

### AC-REQ-007
- Given fluxo de notificacao por fase ativo no org, When comentario do solicitante disparar a nova regra, Then nao deve ocorrer conflito funcional ou duplicidade indevida de comunicacao.

## 10) Dependencias
- Definicao oficial de "responsavel pela proposta" (Owner ou outro campo).
- Definicao de canal de notificacao (in-app, email ou ambos).
- Definicao de regra de elegibilidade da proposta (ex.: `PropostaGerada__c = true`, fase especifica etc.).
- Definicao de fallback para owner invalido/inativo.

## 11) Assumptions
- O comentario do consultor e armazenado em `ComentarioSolicitante__c`.
- A proposta relevante esta no contexto de Opportunity.
- O usuario responsavel pela proposta pode ser resolvido a partir de ownership oficial da oportunidade, salvo regra em contrario.

## 12) Open Questions
1. "Responsavel pela proposta" sera `OwnerId` da Opportunity ou outro campo/regra?
2. O disparo deve ocorrer apenas quando `PropostaGerada__c = true` ou tambem em outras fases?
3. O canal esperado e notificacao in-app, email, ou os dois?
4. Qual fallback oficial quando owner estiver inativo/ausente?
5. Qual criterio de "mudanca relevante" no comentario para permitir novo disparo?

## 13) Decision Log (inicial)
- DEC-001: necessidade classificada como melhoria de comunicacao operacional em proposta.
- DEC-002: historia deve evitar duplicidade e conflitar minimamente com notificacoes de fase ja ativas.
- DEC-003: handoff tecnico depende de fechamento de ownership/canal/elegibilidade.

## 14) Plano de execucao (texto pronto para Jira)
### Fase 1 - Descoberta funcional (D0-D1)
- Fechar definicoes de ownership, canal e elegibilidade da proposta.
- Fechar regra de fallback e anti-duplicidade.

### Fase 2 - Refinamento e aprovacao (D1-D2)
- Validar REQ-001 a REQ-007 com Comercial, Suporte e TI.
- Fechar Open Questions criticas.
- Congelar escopo funcional para handoff tecnico.

### Fase 3 - Implementacao e homologacao funcional (D2-D4)
- Implementar conforme arquitetura aprovada.
- Homologar cenarios positivos, negativos e de duplicidade.
- Validar coexistencia com notificacoes de fase existentes.

### Fase 4 - Go-live e monitoramento assistido (D4-D5)
- Publicar em producao.
- Monitorar disparos, falhas e ruido por 48h.
- Ajustar fallback operacional se necessario.

### Fase 5 - Encerramento (D5)
- Medir KPIs iniciais.
- Registrar licoes aprendidas.
- Encerrar com evidencias de estabilidade.

## 15) Checklist Definition of Ready
- [ ] Responsavel oficial da proposta definido.
- [ ] Canal de notificacao definido.
- [ ] Regra de elegibilidade da proposta definida.
- [ ] Regra anti-duplicidade aprovada.
- [ ] REQ-001 a REQ-007 aprovados.
- [ ] Criterios Given/When/Then aprovados.
