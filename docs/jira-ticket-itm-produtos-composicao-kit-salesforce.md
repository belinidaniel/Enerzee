# Jira Story Refinement - ITM produtos (composicao e Kit) Salesforce

## 1) Contexto da historia
Titulo:
- ITM produtos (composicao e Kit) Salesforce.

Descricao original normalizada:
- Os ITMs (codigo SAP) precisam estar informados nos produtos do Salesforce:
  - Produtos individuais.
  - Kit de instalacao (item faturado no SAP).
- O numero ITM, tanto dos produtos individuais quanto do kit, e disponibilizado por:
  - Planilhas de precos.
  - Integracao de estoque Salesforce x SAP.

Evidencias funcionais (telas):
- Na Oportunidade, as listas relacionadas `Kit Instalacao` e `Produtos` podem aparecer sem itens em determinados momentos, gerando risco de ausencia de validacao previa de ITM.
- No detalhe de `Kit Instalacao`, ha composicao de `Produto do Kit (3+)`, reforcando que existe relacao entre kit faturado e itens componentes.
- O kit e o item faturado no SAP e precisa de identificacao ITM consistente para continuidade operacional.

Problema de negocio:
- Ausencia ou inconsistencias de ITM em produtos/kit causam risco de falha no faturamento SAP, retrabalho manual, atraso operacional e potencial impacto de receita.

Prioridade sugerida:
- Alta.

## 2) Objetivo de negocio e KPI
Objetivo:
- Assegurar que o ITM SAP esteja correto, obrigatorio e rastreavel em produtos individuais e kit faturado no Salesforce, com governanca de origem de dados.

KPIs:
- KPI-01 Cobertura de ITM em produtos elegiveis: 100%.
- KPI-02 Cobertura de ITM em kits faturaveis: 100%.
- KPI-03 Taxa de erro por ITM ausente/invalido em processo SAP: <= 1%.
- KPI-04 MTTR para pendencia de ITM: <= 1 dia util.
- KPI-05 100% dos ITMs com origem identificada (planilha ou integracao estoque).

## 3) As-Is vs To-Be (funcional)
As-Is:
- Ha dependencia operacional de produtos e kit na Oportunidade.
- O kit representa item faturado no SAP.
- Regra funcional de obrigatoriedade e precedencia da origem do ITM ainda nao esta formalizada nesta historia.
- Operacao pode identificar pendencias tardiamente (ex.: itens nao visiveis na oportunidade em determinada etapa).

To-Be:
- Todo produto individual elegivel possui ITM valido.
- Todo kit faturado possui ITM valido.
- Existe regra oficial de precedencia entre planilha de precos e integracao estoque para atualizar ITM.
- Falhas de ITM sao bloqueadas antes de faturamento/integracao, com classificacao e ownership de tratativa.
- Suporte consegue rastrear origem, momento e responsavel por alteracao do ITM.

## 4) Escopo
In-scope:
- Definir obrigatoriedade funcional do ITM para produto individual e kit faturado.
- Definir regra funcional de origem e precedencia do ITM.
- Definir validacoes funcionais e comportamento em excecoes (ausente, invalido, divergente).
- Definir rastreabilidade e monitoramento operacional de ITM.
- Definir criterios objetivos para retomada de fluxo apos correcao de pendencia.

Out-of-scope:
- Redesenho completo da arquitetura SAP.
- Mudancas comerciais nao relacionadas a ITM.
- Revisao tributaria/fiscal fora da necessidade desta historia.

## 5) Requisitos funcionais
### REQ-001 - ITM obrigatorio no produto individual
Racional: garantir chave SAP no cadastro de item comercial.
Ator: Operacao Comercial / Cadastro de Produto.
Trigger: criacao ou atualizacao de produto elegivel.
Pre-condicao: produto apto ao processo comercial.
Resultado esperado: produto segue no fluxo somente com ITM valido.
Ownership: Operacao Comercial + TI Salesforce.

### REQ-002 - ITM obrigatorio no kit faturado
Racional: kit e item faturado no SAP.
Ator: Operacao de Kit.
Trigger: criacao ou atualizacao de kit elegivel para faturamento.
Pre-condicao: kit relacionado a oportunidade/processo faturavel.
Resultado esperado: kit segue no fluxo somente com ITM valido.
Ownership: Operacoes + TI Salesforce.

### REQ-003 - Governanca da origem do ITM
Racional: evitar conflito entre fontes.
Ator: Negocio (Pricing/Estoque) + TI Salesforce.
Trigger: recebimento/atualizacao de ITM por planilha ou integracao.
Pre-condicao: mais de uma fonte potencial para o mesmo item.
Resultado esperado: regra oficial de precedencia aplicada sem ambiguidade.
Ownership: Negocio + TI Salesforce.

### REQ-004 - Consistencia entre kit e composicao
Racional: manter coerencia entre item faturado e itens relacionados.
Ator: Operacao / Suporte.
Trigger: alteracao da composicao do kit ou dados do kit.
Pre-condicao: kit com itens vinculados.
Resultado esperado: kit nao fica faturavel sem ITM valido.
Ownership: Operacoes + TI Salesforce.

### REQ-005 - Tratamento de excecoes de ITM
Racional: prevenir falha a jusante no SAP.
Ator: Processo operacional de faturamento/integracao.
Trigger: tentativa de processamento com ITM ausente/invalido/divergente.
Pre-condicao: item em etapa que exige ITM.
Resultado esperado: bloqueio da continuidade + classificacao da causa + owner.
Ownership: TI Salesforce + Suporte.

### REQ-006 - Rastreabilidade de ITM
Racional: auditoria e diagnostico rapido.
Ator: Suporte Salesforce.
Trigger: consulta de produto/kit com pendencia ou auditoria.
Pre-condicao: historico de alteracoes disponivel.
Resultado esperado: origem, data/hora e responsavel da ultima alteracao de ITM visiveis.
Ownership: TI Salesforce + Suporte.

### REQ-007 - Visibilidade operacional na oportunidade
Racional: conferencia precoce antes de faturamento.
Ator: Comercial / Backoffice.
Trigger: revisao de oportunidade com produtos e kit.
Pre-condicao: oportunidade em etapa de validacao/pre-faturamento.
Resultado esperado: usuario identifica facilmente status de ITM dos registros criticos.
Ownership: Comercial + TI Salesforce.

### REQ-008 - Retomada controlada de pendencias
Racional: recuperar fluxo com controle e sem retrabalho disperso.
Ator: Suporte.
Trigger: correcao de ITM em registro pendente.
Pre-condicao: causa raiz corrigida.
Resultado esperado: item volta ao fluxo com trilha de reprocessamento e resultado final.
Ownership: TI Salesforce + Suporte.

## 6) Matriz de rastreabilidade de dados
| Fonte | Transformacao funcional | Destino | Ownership |
|---|---|---|---|
| Planilha de precos | Aplicacao/atualizacao de ITM por regra de negocio | Produto individual e/ou kit no Salesforce | Pricing/Comercial + TI Salesforce |
| Integracao estoque Salesforce x SAP | Sincronizacao de ITM em registros elegiveis | Produto individual e/ou kit no Salesforce | Operacoes/Estoque + TI Salesforce |
| Cadastro de produto individual | Uso de ITM em processos comerciais | Oportunidade e processos dependentes de SAP | Comercial + TI Salesforce |
| Cadastro de kit instalacao | Uso de ITM do item faturado | Faturamento/integracao SAP | Operacoes + TI Salesforce |

## 7) Regras de negocio e excecoes
| ID | Regra | Comportamento esperado | Excecao |
|---|---|---|---|
| BR-001 | Produto elegivel deve ter ITM valido | Pode seguir no fluxo comercial/faturavel | Sem ITM: bloquear continuidade e classificar pendencia |
| BR-002 | Kit faturado deve ter ITM valido | Pode seguir para faturamento SAP | Sem ITM: bloquear faturamento/integracao |
| BR-003 | Fontes de ITM seguem precedencia oficial | Conflito resolvido por regra unica | Sem precedencia definida: bloqueio de go-live |
| BR-004 | Alteracao de ITM deve ser auditavel | Origem, responsavel e horario disponiveis | Sem trilha: nao conforme |
| BR-005 | Pendencia corrigida deve retomar fluxo com controle | Reprocessamento com evidencia | Falha apos reprocesso: manter classificada e com owner |

## 8) Criterios de aceitacao (Given/When/Then)
### AC-REQ-001
- Given produto elegivel sem ITM valido, When usuario tentar avancar etapa que depende de faturamento/integracao, Then o sistema deve bloquear e informar pendencia de ITM.

### AC-REQ-002
- Given kit elegivel para faturamento sem ITM valido, When processo tentar prosseguir, Then a continuidade deve ser bloqueada.

### AC-REQ-003
- Given ITM informado por planilha e por integracao com valores divergentes, When ocorrer conflito, Then deve prevalecer a fonte definida na regra oficial aprovada.

### AC-REQ-004
- Given alteracao na composicao do kit, When a alteracao for confirmada, Then o kit nao pode permanecer apto sem ITM valido.

### AC-REQ-005
- Given tentativa de processamento com ITM invalido, When o processo executar, Then deve registrar classificacao de erro e owner de tratativa.

### AC-REQ-006
- Given consulta de suporte em item com pendencia, When abrir detalhes do registro, Then deve ser possivel identificar origem e ultima alteracao do ITM.

### AC-REQ-007
- Given oportunidade em etapa pre-faturamento, When usuario revisar kit/produtos relacionados, Then deve conseguir validar status de ITM dos registros obrigatorios.

### AC-REQ-008
- Given pendencia de ITM corrigida, When reprocessamento for acionado, Then o item deve retomar fluxo com trilha auditavel do resultado.

## 9) Dependencias
- Definicao formal de precedencia entre planilha de precos e integracao estoque.
- Qualidade e disponibilidade das fontes de ITM.
- Definicao de ownership operacional para pendencias.
- Janela de homologacao com cenarios de faturamento SAP.

## 10) Assumptions
- ITM e dado obrigatorio para continuidade dos fluxos que faturam no SAP.
- Kit instalacao e item faturado no contexto desta historia.
- Fontes de ITM permanecem operantes (planilha e integracao).

## 11) Restricoes
- Sem perda de rastreabilidade de ITM.
- Sem degradar processos comerciais existentes em producao.
- Mudancas devem respeitar governanca de dados mestres.

## 12) Open Questions
1. Qual campo oficial representa ITM no produto individual (ProductCode, NumeroItem__c ou outro)?
2. Qual campo oficial representa ITM do kit faturado (NumeroItemSAP__c ou outro)?
3. Qual precedencia oficial entre planilha de precos e integracao estoque em caso de divergencia?
4. Qual formato/validacao oficial do ITM (tamanho, mascara, zeros a esquerda)?
5. Havera carga corretiva para itens historicos sem ITM ou com ITM inconsistente?

## 13) Decision Log (inicial)
- DEC-001: ITM classificado como dado critico para faturamento SAP.
- DEC-002: Escopo unificado para produto individual e kit faturado.
- DEC-003: Handoff tecnico depende de fechamento da regra de campo oficial e precedencia de fonte.

## 14) Plano de execucao (texto pronto para Jira)
### Fase 1 - Descoberta funcional (D0-D1)
- Confirmar campo oficial de ITM para produto e kit.
- Confirmar regra de precedencia entre fontes.
- Definir padrao de validacao do ITM.

### Fase 2 - Refinamento e aprovacao (D1-D2)
- Validar REQ-001 a REQ-008 com Comercial, Operacoes, Suporte e TI.
- Fechar Open Questions criticas e ownership.
- Congelar escopo para handoff tecnico.

### Fase 3 - Implementacao e homologacao funcional (D2-D4)
- Executar implementacao conforme arquitetura aprovada.
- Homologar cenarios de sucesso, erro e conflito de origem.
- Validar bloqueios e rastreabilidade.

### Fase 4 - Go-live e monitoramento assistido (D4-D6)
- Publicar em producao em janela aprovada.
- Monitorar cobertura de ITM, erros e pendencias por 48h.
- Reprocessar pendencias corrigidas com evidencias.

### Fase 5 - Encerramento (D6)
- Medir KPIs iniciais.
- Registrar licoes aprendidas.
- Encerrar historia com evidencias de estabilidade.

## 15) Checklist Definition of Ready
- [ ] Campo oficial de ITM por entidade definido.
- [ ] Regra de precedencia entre fontes aprovada.
- [ ] REQ-001 a REQ-008 aprovados.
- [ ] Ownership de tratativa definido.
- [ ] Criterios Given/When/Then aprovados.
- [ ] Plano de validacao funcional aprovado.
