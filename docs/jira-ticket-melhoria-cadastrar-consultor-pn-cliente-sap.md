# Jira Story Refinement - Melhoria: Cadastrar consultor como Parceiro de Negocio Cliente

## 1) Contexto da historia
Titulo:
- Melhoria: Cadastrar consultor como Parceiro de negocio Cliente SAP.

Descricao original normalizada:
- O consultor nao esta sendo cadastrado como Parceiro de Negocio (PN) no SAP para os papeis de Cliente e Fornecedor.
- Na etapa de criacao da conta/registro de consultor no Salesforce, o consultor deve ser cadastrado no SAP como PN, respeitando a condicao de documento (PF/CPF ou PJ/CNPJ).
- Deve ser analisado e validado o contrato funcional da API SAP x Salesforce para esse cadastro.

Problema de negocio:
- Ausencia de cadastro PN do consultor no SAP causa inconsistencias cadastrais, retrabalho manual e risco de atraso em processos dependentes de cadastro no ERP.

Prioridade sugerida:
- Alta (impacta onboarding cadastral e continuidade operacional SAP).

## 2) Objetivo de negocio e KPI
Objetivo:
- Garantir que todo consultor criado/elegivel no Salesforce seja cadastrado como PN no SAP de forma padronizada, auditavel e aderente ao tipo de documento (CPF/CNPJ).

KPIs:
- KPI-01 Cobertura de cadastro: 100% dos consultores elegiveis com tentativa de cadastro PN no SAP.
- KPI-02 Taxa de sucesso no cadastro PN >= 99% em 30 dias.
- KPI-03 Tempo medio de correcao para erro de cadastro PN <= 2 horas.
- KPI-04 100% das falhas classificadas por causa (dados, permissao, indisponibilidade SAP, regra de negocio).
- KPI-05 100% dos casos com rastreabilidade de origem Salesforce para retorno SAP.

## 3) As-Is vs To-Be (funcional)
As-Is:
- Consultor e processado em integracoes SAP existentes, mas o comportamento esperado de PN Cliente + Fornecedor nao esta garantido de forma consistente para todos os casos.
- Ha necessidade de analise e alinhamento do contrato funcional da API para regras de PF/PJ.
- Operacao precisa atuar de forma reativa quando o cadastro nao ocorre corretamente.

To-Be:
- Ao criar/atualizar consultor elegivel, o processo de cadastro PN no SAP executa conforme regra de negocio e tipo de documento.
- O resultado do cadastro PN fica rastreavel e auditavel.
- Falhas possuem classificacao padrao, owner definido e trilha para tratativa/reprocessamento.

## 4) Escopo
In-scope:
- Definir requisitos funcionais para cadastro de consultor como PN Cliente no SAP.
- Definir regra funcional para tratamento de CPF (PF) e CNPJ (PJ) no cadastro PN.
- Definir expectativa de sincronizacao de papeis PN (Cliente e Fornecedor), incluindo governanca de quando cada papel deve ser aplicado.
- Definir criterios de aceite e monitoramento funcional pos-implantacao.

Out-of-scope:
- Redesenho completo de toda arquitetura de integracao SAP.
- Mudancas em processos nao relacionados ao cadastro de consultor como PN.
- Alteracoes de governanca corporativa fora da historia (ex.: politica global de dados mestre).

## 5) Requisitos funcionais
### REQ-001 - Cadastro PN no evento de criacao de consultor
Racional: garantir consistencia cadastral no ERP desde o onboarding.
Ator: Processo de integracao Salesforce x SAP.
Trigger: criacao de consultor elegivel no Salesforce.
Pre-condicao: consultor com dados minimos obrigatorios preenchidos.
Resultado esperado: consultor e enviado ao SAP para criacao de PN conforme regras aprovadas.
Ownership: TI Salesforce (processo) + Operacao Comercial (qualidade cadastral).

### REQ-002 - Regra obrigatoria por tipo de documento (CPF/CNPJ)
Racional: reduzir rejeicao de cadastro por divergencia de identificacao fiscal.
Ator: Processo de integracao.
Trigger: montagem do envio para cadastro PN.
Pre-condicao: documento informado no consultor.
Resultado esperado: aplicacao correta da regra funcional para PF/CPF e PJ/CNPJ antes do envio SAP.
Ownership: Negocio (regra oficial) + TI Salesforce (execucao da regra).

### REQ-003 - Governanca de papel PN (Cliente e Fornecedor)
Racional: eliminar ambiguidades de escopo entre papeis de cadastro no SAP.
Ator: Negocio + TI Salesforce.
Trigger: definicao funcional da historia.
Pre-condicao: regra de negocio aprovada para uso de cada papel.
Resultado esperado: criterio explicito para quando cadastrar como Cliente, como Fornecedor ou ambos.
Ownership: Negocio (decisao) + TI Salesforce (operacionalizacao).

### REQ-004 - Rastreabilidade de tentativa e resultado
Racional: permitir suporte e auditoria ponta a ponta.
Ator: Suporte Salesforce.
Trigger: cada tentativa de cadastro PN.
Pre-condicao: tentativa executada no processo de integracao.
Resultado esperado: registro de sucesso/erro com dados suficientes para diagnostico e acao.
Ownership: TI Salesforce + Suporte.

### REQ-005 - Classificacao padrao de erro e tratativa
Racional: reduzir MTTR e padronizar resposta operacional.
Ator: Suporte Salesforce.
Trigger: falha de cadastro PN.
Pre-condicao: retorno de erro da API ou excecao do processo.
Resultado esperado: erro classificado em categoria padrao com owner e acao definida.
Ownership: TI Salesforce + Suporte.

### REQ-006 - Reprocessamento controlado de falhas recuperaveis
Racional: evitar retrabalho manual e perda de sincronizacao cadastral.
Ator: Suporte Salesforce.
Trigger: erro recuperavel apos correcao da causa.
Pre-condicao: causa raiz tratada.
Resultado esperado: reprocessamento com trilha auditavel e resultado final registrado.
Ownership: TI Salesforce.

## 6) Matriz de rastreabilidade de dados
| Fonte | Transformacao funcional | Destino | Ownership |
|---|---|---|---|
| `Consultor__c` (dados cadastrais e documento) | Validacao de elegibilidade e regra PF/PJ | Requisicao de cadastro PN no SAP | TI Salesforce + Operacao Comercial |
| Documento (`CPF`/`CNPJ`) | Determinacao de regra funcional de identificacao cadastral | Campo correspondente no cadastro PN SAP | Negocio + TI Salesforce |
| Retorno SAP (sucesso/erro) | Consolidacao de status e classificacao de erro | Status de integracao + log operacional | TI Salesforce + Suporte |

## 7) Regras de negocio e excecoes
| ID | Regra | Comportamento esperado | Excecao |
|---|---|---|---|
| BR-001 | Cadastro PN exige dados minimos obrigatorios | Processo envia consultor elegivel para SAP | Sem dados minimos: bloquear envio e classificar erro de dados |
| BR-002 | Documento define aplicacao da regra funcional PF/PJ | CPF segue regra PF e CNPJ segue regra PJ | Documento invalido/ausente: bloquear envio e registrar causa |
| BR-003 | Papel PN deve seguir criterio aprovado (Cliente/Fornecedor/ambos) | Cadastro respeita governanca oficial | Sem criterio aprovado: bloquear entrada em producao |
| BR-004 | Toda tentativa precisa de rastreabilidade | Sucesso/erro deve ser auditavel | Ausencia de evidencia: nao conforme |

## 8) Criterios de aceitacao (Given/When/Then)
### AC-REQ-001
- Given um consultor elegivel e com dados obrigatorios, When o registro for criado no Salesforce, Then deve ocorrer tentativa de cadastro PN no SAP.

### AC-REQ-002
- Given consultor PF com CPF valido, When o envio para SAP for montado, Then a regra funcional de identificacao PF deve ser aplicada corretamente.
- Given consultor PJ com CNPJ valido, When o envio para SAP for montado, Then a regra funcional de identificacao PJ deve ser aplicada corretamente.

### AC-REQ-003
- Given governanca aprovada para papeis PN, When ocorrer o cadastro do consultor, Then o processo deve respeitar o criterio de Cliente, Fornecedor ou ambos conforme regra oficial.

### AC-REQ-004
- Given uma tentativa de cadastro PN finalizada, When o suporte consultar a ocorrencia, Then deve localizar status final, horario e informacoes de diagnostico.

### AC-REQ-005
- Given uma falha no cadastro PN, When o erro for registrado, Then a causa deve estar classificada em categoria padrao e atribuida ao owner de tratativa.

### AC-REQ-006
- Given falha recuperavel com causa corrigida, When o reprocessamento for acionado, Then o cadastro PN deve ser reenviado com trilha de auditoria do resultado.

## 9) Dependencias
- Validacao funcional do contrato da API SAP para cadastro PN de consultor.
- Definicao oficial de regra de negocio para papel PN (Cliente/Fornecedor/ambos).
- Definicao de ownership para tratativa operacional de falhas.
- Janela de homologacao e implantacao alinhada com times Salesforce e SAP.

## 10) Assumptions
- Consultor continua sendo entidade de origem para esse cadastro no Salesforce.
- API SAP suporta o cadastro PN conforme retorno esperado para sucesso e erro.
- A classificacao PF/PJ depende exclusivamente de dados cadastrais confiaveis no momento do envio.

## 11) Restricoes
- Sem perda de rastreabilidade durante a implantacao.
- Sem degradar cadastros ja estabilizados de outros processos SAP.
- Mudancas devem respeitar governanca de acesso e compliance vigente.

## 12) Open Questions
1. Qual e o criterio oficial para cadastrar consultor como Cliente, Fornecedor ou ambos no SAP?
2. Quais campos sao obrigatorios por perfil PF e PJ para aceite do cadastro PN?
3. Existe regra de prioridade ou sequencia quando ambos os papeis (Cliente e Fornecedor) forem necessarios?
4. Qual SLA de tratativa para erro de cadastro PN em producao?
5. Quem aprova a matriz final de ownership entre Negocio, Suporte e TI Salesforce?

## 13) Decision Log (inicial)
- DEC-001: Historias de cadastro PN devem explicitar regra funcional de papel (Cliente/Fornecedor/ambos) antes do handoff tecnico.
- DEC-002: Criterio PF/PJ passa a ser requisito obrigatorio e auditavel no processo.
- DEC-003: Story so entra em implantacao apos fechamento das Open Questions criticas de governanca.

## 14) Plano de execucao (texto pronto para Jira)
### Fase 1 - Descoberta funcional (D0-D1)
- Consolidar contrato funcional da API SAP para cadastro PN do consultor.
- Fechar regra de negocio de papel PN (Cliente/Fornecedor/ambos).
- Confirmar campos obrigatorios para PF/CPF e PJ/CNPJ.

### Fase 2 - Refinamento e aprovacao (D1-D2)
- Validar REQ-001 a REQ-006 com negocio, suporte e TI Salesforce.
- Fechar Open Questions criticas e ownership de tratativa.
- Congelar escopo funcional para handoff.

### Fase 3 - Implementacao e homologacao funcional (D2-D4)
- Executar implementacao tecnica conforme arquitetura aprovada.
- Validar criterios de aceite com cenarios PF, PJ, sucesso e falha.
- Confirmar rastreabilidade e classificacao de erro.

### Fase 4 - Go-live e monitoramento assistido (D4-D6)
- Publicar em producao na janela aprovada.
- Monitorar sucesso de cadastro PN e ocorrencias por 48h.
- Reprocessar pendencias recuperaveis com evidencia.

### Fase 5 - Encerramento (D6)
- Medir KPIs iniciais.
- Formalizar licoes aprendidas e acoes preventivas.
- Encerrar historia com evidencias de estabilidade.

## 15) Checklist Definition of Ready
- [ ] Objetivo de negocio e KPI aprovados.
- [ ] REQ-001 a REQ-006 aprovados pelos stakeholders.
- [ ] Regra oficial de papel PN definida (Cliente/Fornecedor/ambos).
- [ ] Regras PF/PJ validadas (CPF/CNPJ).
- [ ] Ownership de tratativa definido.
- [ ] Criterios Given/When/Then aprovados.
