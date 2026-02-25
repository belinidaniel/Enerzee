# Jira Story Refinement - SAP - Erros de Integracao em Producao

## 1) Contexto da historia
Titulo: SAP - Erros de integracao em producao

Evidencias recebidas:
- Erro 1: classe `IntegracaoSAPFornecedor.sendFornecedor`, job `707U500001OhQrC`, falha na linha 124 (`update`) com `INSUFFICIENT_ACCESS_OR_READONLY` no registro `a00U500000O2BhnIAF`.
- Erro 2: classe `IntegracaoSAPRepresentante.sendRepresentante`, job `707U500001OkEiZ`, falha na linha 58 (`update`) com `INSUFFICIENT_ACCESS_OR_READONLY` no registro `a00U500000BpFJwIAN`.

Problema de negocio:
- Registros de Consultor deixam de ser sincronizados com SAP (Fornecedor/Representante), gerando risco de cadastro incompleto, retrabalho operacional e atraso em processos comerciais/de atendimento.

Prioridade sugerida:
- Alta (incidente em producao com impacto operacional).

## 2) Objetivo de negocio e KPI
Objetivo:
- Restabelecer a confiabilidade do processo de sincronizacao de Consultor com SAP, reduzindo falhas por permissao e garantindo rastreabilidade de ponta a ponta.

KPIs:
- KPI-01 Taxa de sucesso da integracao Representante >= 99% (janela de 30 dias).
- KPI-02 Taxa de sucesso da integracao Fornecedor >= 99% (caso processo continue ativo).
- KPI-03 MTTR para erro de integracao por permissao <= 2 horas.
- KPI-04 100% dos erros com owner funcional e causa classificada.
- KPI-05 100% dos eventos de erro com registro auditavel para suporte.

## 3) As-Is vs To-Be (funcional)
As-Is:
- Atualizacao de Consultor dispara integracoes SAP de Representante e Fornecedor.
- Em falha de permissao no contexto de execucao, o processo nao conclui atualizacao de status do registro e gera excecao em producao.
- Existe monitoramento por email/Log, com tratamento majoritariamente reativo.

To-Be:
- Integracoes de Consultor com SAP executam sem erro de permissao no contexto autorizado.
- Fluxo de erro diferencia falha de negocio x falha de autorizacao.
- Time de suporte identifica rapidamente impacto, owner e acao de correcao.
- Processo Fornecedor fica explicitamente governado (ativo ou oficialmente descontinuado).

## 4) Escopo
In-scope:
- Refinar regra funcional de permissao/autorizacao para atualizacao de status de integracao em Consultor.
- Definir comportamento esperado para erro de permissao em producao.
- Definir governanca do processo Fornecedor (ativo vs descontinuado).
- Definir plano de validacao funcional e operacional pos-correcao.

Out-of-scope:
- Redesenho completo de arquitetura SAP.
- Inclusao de novos objetos/processos nao relacionados ao incidente.
- Mudancas em processos comerciais sem dependencia direta da integracao consultor-SAP.

## 5) Requisitos funcionais (implementation-ready para arquitetura)
### REQ-001 - Processamento sem bloqueio por permissao
Racional: evitar interrupcao da sincronizacao por contexto de usuario sem privilegio.
Ator: Processo de integracao SAP.
Trigger: alteracao de Consultor elegivel para envio SAP.
Pre-condicao: registro Consultor valido e elegivel para integracao.
Resultado esperado: integracao conclui sem erro de permissao para atualizar status de processamento.
Ownership: TI Salesforce (execucao) + Gestao de Perfis/Seguranca (governanca).

### REQ-002 - Classificacao obrigatoria de erro
Racional: reduzir tempo de diagnostico e acao corretiva.
Ator: Suporte Salesforce.
Trigger: qualquer falha de integracao.
Pre-condicao: tentativa de envio SAP executada.
Resultado esperado: erro classificado minimamente como `Permissao`, `Dados`, `Disponibilidade SAP` ou `Outros`.
Ownership: TI Salesforce.

### REQ-003 - Governanca do processo Fornecedor
Racional: eliminar comportamento contraditorio entre regra de negocio e execucao atual.
Ator: Dono do processo Comercial/Operacoes + TI Salesforce.
Trigger: revisao da historia e definicao de escopo final.
Pre-condicao: decisao formal sobre continuidade do processo Fornecedor.
Resultado esperado: processo Fornecedor fica explicitamente `Ativo` ou `Descontinuado`, sem ambiguidade.
Ownership: Negocio (decisao) + TI Salesforce (execucao conforme decisao).

### REQ-004 - Atualizacao de status auditavel
Racional: garantir rastreabilidade de resultado por registro.
Ator: Suporte/Operacao.
Trigger: conclusao de tentativa de envio SAP.
Pre-condicao: tentativa executada com retorno de sucesso ou falha.
Resultado esperado: status final do registro e evidencias de erro/sucesso disponiveis para auditoria.
Ownership: TI Salesforce.

### REQ-005 - Monitoramento operacional com SLA
Racional: transformar atuacao reativa em proativa.
Ator: Time de Suporte.
Trigger: erros de integracao em producao.
Pre-condicao: definicao de janela de monitoramento e responsabilidade de resposta.
Resultado esperado: incidente de permissao identificado e tratado dentro de SLA definido.
Ownership: Suporte Salesforce + Lideranca Operacional.

### REQ-006 - Reprocessamento seguro
Racional: reduzir retrabalho manual e perda de sincronizacao.
Ator: Suporte Salesforce.
Trigger: erro classificado como recuperavel.
Pre-condicao: causa raiz corrigida.
Resultado esperado: registros impactados sao reprocessados com trilha de auditoria.
Ownership: TI Salesforce.

## 6) Matriz de rastreabilidade de dados
| Fonte | Transformacao funcional | Destino | Ownership |
|---|---|---|---|
| `Consultor__c` (dados cadastrais e status de integracao) | Montagem de payload para Fornecedor/Representante e consolidacao de resultado | SAP (Fornecedor/Representante) + status no proprio Consultor | TI Salesforce + Operacao Comercial |
| Retorno HTTP SAP (`codigoHttp`, mensagem) | Classificacao de sucesso/falha e causa | Campo de status + log tecnico | TI Salesforce |
| Excecao de permissao (`INSUFFICIENT_ACCESS_OR_READONLY`) | Classificacao como falha de autorizacao | Painel/log de erro para acao de suporte | TI Salesforce + Suporte |

## 7) Regras de negocio e tratamento de excecao
| ID | Regra | Comportamento esperado | Excecao |
|---|---|---|---|
| BR-001 | Registro elegivel deve tentar sincronizacao SAP | Tentativa unica por evento de alteracao | Se faltarem dados obrigatorios, classificar erro de dados |
| BR-002 | Falha de permissao deve ser tratada como incidente operacional | Erro deve ser classificado e roteado para owner | Nao mascarar erro como falha de negocio SAP |
| BR-003 | Processo Fornecedor deve obedecer decisao oficial de negocio | Se descontinuado, nao deve ser disparado | Se ativo, deve seguir mesmos controles de Representante |
| BR-004 | Toda tentativa deve gerar rastreabilidade de resultado | Sucesso/erro visivel para suporte | Sem registro auditavel = nao conforme |

## 8) Criterios de aceitacao (Given/When/Then)
### AC para REQ-001
- Given um Consultor elegivel para integracao, When o envio para SAP for executado em producao, Then a atualizacao de status nao deve falhar por `INSUFFICIENT_ACCESS_OR_READONLY`.

### AC para REQ-002
- Given uma tentativa com erro, When o processo registrar a ocorrencia, Then a causa deve ficar classificada em categoria padrao e vinculada ao owner de tratativa.

### AC para REQ-003
- Given a revisao do processo Fornecedor, When negocio e TI concluirem a decisao, Then a historia deve registrar explicitamente `Ativo` ou `Descontinuado` e refletir isso na execucao.

### AC para REQ-004
- Given uma tentativa de integracao finalizada, When suporte consultar o registro impactado, Then deve localizar status final, horario e detalhe suficiente para auditoria.

### AC para REQ-005
- Given erro de permissao em producao, When o monitoramento detectar o evento, Then a tratativa deve iniciar dentro do SLA acordado.

### AC para REQ-006
- Given falhas recuperaveis com causa resolvida, When o suporte acionar reprocessamento, Then os registros devem ser reenviados com trilha de auditoria do resultado.

## 9) Dependencias
- Definicao de ownership entre Suporte Salesforce e Seguranca/Administracao de perfis.
- Validacao com negocio sobre continuidade do processo Fornecedor.
- Janela de implantacao aprovada para ajuste em producao.
- Validacao com time SAP para confirmar comportamento esperado do retorno em cenarios de erro.

## 10) Assumptions
- O objeto `Consultor__c` permanece como origem oficial para essas integracoes.
- O erro observado nas evidencias representa incidente recorrente (nao evento isolado).
- O monitoramento atual pode ser evoluido sem troca de ferramenta.

## 11) Restricoes
- Correcao deve preservar continuidade operacional.
- Nao pode haver perda de rastreabilidade de tentativas durante a transicao.
- Mudancas devem respeitar politica de acesso e governanca vigente.

## 12) Open Questions (escalacao obrigatoria)
1. O processo Fornecedor esta oficialmente ativo em producao ou deve ser descontinuado agora?
2. Quem e o owner final da matriz de permissao para esse fluxo (Perfil, Permission Set ou outro mecanismo de governanca)?
3. Qual SLA oficial para incidentes de integracao SAP em horario comercial e fora de horario?
4. Qual janela de volume/pico deve ser usada para validacao de estabilidade pos-ajuste?
5. Existe necessidade de comunicacao formal para areas impactadas durante a estabilizacao?

## 13) Decision Log (inicial)
- DEC-001: Incidente classificado como prioridade alta por impacto operacional em producao.
- DEC-002: Historias de Representante e Fornecedor seguem no mesmo escopo ate decisao explicita de descontinuacao do Fornecedor.
- DEC-003: Plano exige classificacao formal de erro e ownership de tratativa antes do handoff tecnico.

## 14) Plano de execucao (texto pronto para Jira)
### Fase 1 - Contencao e triagem (D0)
- Validar volume de registros impactados e periodo do incidente.
- Confirmar owner de resposta (Suporte Salesforce + Admin de acesso).
- Registrar classificacao inicial do incidente e impacto de negocio.

### Fase 2 - Refinamento funcional e decisoes (D0-D1)
- Fechar Open Questions criticas (Fornecedor ativo/descontinuado; ownership de permissao; SLA).
- Aprovar requisitos REQ-001 a REQ-006 com negocio e suporte.
- Congelar escopo da historia para handoff tecnico.

### Fase 3 - Implementacao e validacao funcional (D1-D3)
- Executar ajuste tecnico conforme arquitetura aprovada.
- Validar criterios de aceitacao em ambiente controlado com cenarios positivos e de excecao.
- Evidenciar rastreabilidade de resultado por registro impactado.

### Fase 4 - Deploy e monitoramento assistido (D3-D5)
- Publicar ajuste em producao dentro da janela aprovada.
- Monitorar taxa de sucesso, erros de permissao e tempo de tratativa por 48h.
- Acionar reprocessamento seguro para pendencias recuperaveis.

### Fase 5 - Encerramento e prevencao (D5)
- Registrar resultados dos KPIs iniciais.
- Formalizar licoes aprendidas e plano de prevencao de recorrencia.
- Encerrar incidente com evidencias de estabilidade.

## 15) Checklist de pronto para handoff (Definition of Ready)
- [ ] Escopo aprovado (in/out) com stakeholders.
- [ ] REQ-001 a REQ-006 revisados e aceitos.
- [ ] Open Questions criticas respondidas.
- [ ] Ownership de tratativa definido.
- [ ] Criterios de aceitacao aprovados.
- [ ] KPI e janela de monitoramento definidos.
