h1. ITM produtos (composicao e Kit) Salesforce

*Resumo*
Garantir que o codigo ITM (SAP) esteja corretamente informado e rastreavel nos produtos individuais e no Kit de Instalacao (item faturado no SAP), com regra clara de origem de dados entre planilha de precos e integracao estoque Salesforce x SAP.

h2. Contexto
* Os ITMs precisam existir em:
** Produto individual
** Kit de Instalacao (item faturado)
* A origem do ITM pode ser:
** Planilha de precos
** Integracao estoque Salesforce x SAP
* Evidencia operacional:
** Em algumas oportunidades, listas relacionadas de Kit/Produtos podem estar vazias na etapa de analise.
** No detalhe do Kit, existe composicao de produtos, reforcando necessidade de consistencia do ITM.

h2. Objetivo de negocio
Assegurar consistencia de ITM para reduzir falhas no faturamento SAP, retrabalho manual e atraso operacional.

h2. KPIs
* KPI-01: Cobertura de ITM em produtos elegiveis = 100%
* KPI-02: Cobertura de ITM em kits faturaveis = 100%
* KPI-03: Taxa de erro por ITM ausente/invalido no processo SAP <= 1%
* KPI-04: MTTR de pendencia de ITM <= 1 dia util
* KPI-05: 100% dos ITMs com origem rastreavel (planilha ou integracao)

h2. Escopo
*In-scope*
* Definir obrigatoriedade de ITM em produto individual e kit faturado
* Definir regra de precedencia entre fontes de ITM
* Definir bloqueio funcional para ITM ausente/invalido/divergente
* Definir rastreabilidade de origem e alteracao de ITM
* Definir criterios para retomada do fluxo apos correcao

*Out-of-scope*
* Redesenho completo da arquitetura SAP
* Mudancas comerciais sem relacao com ITM
* Revisao fiscal/tributaria fora desta demanda

h2. Requisitos funcionais
*REQ-001* - ITM obrigatorio no produto individual
* Trigger: criacao/atualizacao de produto elegivel
* Resultado esperado: produto so segue no fluxo com ITM valido
* Ownership: Operacao Comercial + TI Salesforce

*REQ-002* - ITM obrigatorio no Kit faturado
* Trigger: criacao/atualizacao de kit elegivel para faturamento
* Resultado esperado: kit so segue no fluxo com ITM valido
* Ownership: Operacoes + TI Salesforce

*REQ-003* - Governanca da origem do ITM
* Trigger: atualizacao por planilha ou integracao
* Resultado esperado: aplicacao de precedencia oficial sem ambiguidade
* Ownership: Negocio (Pricing/Estoque) + TI Salesforce

*REQ-004* - Consistencia entre kit e composicao
* Trigger: alteracao da composicao do kit
* Resultado esperado: kit nao pode permanecer faturavel sem ITM valido
* Ownership: Operacoes + TI Salesforce

*REQ-005* - Tratamento de excecao
* Trigger: tentativa com ITM ausente/invalido/divergente
* Resultado esperado: bloqueio + classificacao + owner
* Ownership: TI Salesforce + Suporte

*REQ-006* - Rastreabilidade de ITM
* Trigger: consulta operacional/auditoria
* Resultado esperado: origem, horario e responsavel visiveis
* Ownership: TI Salesforce + Suporte

*REQ-007* - Visibilidade operacional na oportunidade
* Trigger: revisao pre-faturamento
* Resultado esperado: status de ITM visivel para kit/produtos criticos
* Ownership: Comercial + TI Salesforce

*REQ-008* - Retomada controlada
* Trigger: correcao de pendencia de ITM
* Resultado esperado: reprocessamento com trilha de auditoria
* Ownership: TI Salesforce + Suporte

h2. Matriz de rastreabilidade
|| Fonte || Transformacao funcional || Destino || Ownership ||
| Planilha de precos | Aplicacao/atualizacao de ITM | Produto e/ou Kit no Salesforce | Pricing/Comercial + TI Salesforce |
| Integracao estoque Salesforce x SAP | Sincronizacao de ITM | Produto e/ou Kit no Salesforce | Operacoes/Estoque + TI Salesforce |
| Cadastro de Produto | Uso do ITM no processo comercial | Oportunidade e processos SAP | Comercial + TI Salesforce |
| Cadastro de Kit | Uso do ITM do item faturado | Faturamento/integracao SAP | Operacoes + TI Salesforce |

h2. Regras de negocio e excecoes
|| ID || Regra || Comportamento esperado || Excecao ||
| BR-001 | Produto elegivel deve ter ITM valido | Pode seguir no fluxo | Sem ITM: bloquear e classificar pendencia |
| BR-002 | Kit faturado deve ter ITM valido | Pode seguir para SAP | Sem ITM: bloquear faturamento/integracao |
| BR-003 | Fontes de ITM seguem precedencia oficial | Conflito resolvido por regra unica | Sem precedencia: bloquear go-live |
| BR-004 | Alteracao de ITM deve ser auditavel | Origem/horario/responsavel visiveis | Sem trilha: nao conforme |
| BR-005 | Pendencia corrigida retoma fluxo com controle | Reprocessamento com evidencia | Falha apos reprocesso: manter classificada |

h2. Criterios de aceitacao (Given/When/Then)
*AC-REQ-001*
* Given produto elegivel sem ITM valido
* When usuario tentar avancar etapa dependente de SAP
* Then o sistema deve bloquear continuidade e informar pendencia

*AC-REQ-002*
* Given kit elegivel sem ITM valido
* When processo tentar prosseguir para faturamento
* Then a continuidade deve ser bloqueada

*AC-REQ-003*
* Given ITM divergente entre planilha e integracao
* When conflito ocorrer
* Then deve prevalecer a fonte definida na regra oficial

*AC-REQ-004*
* Given alteracao na composicao do kit
* When alteracao for confirmada
* Then kit nao pode permanecer apto sem ITM valido

*AC-REQ-005*
* Given tentativa com ITM invalido
* When processo executar
* Then registrar classificacao de erro e owner

*AC-REQ-006*
* Given consulta de suporte em item com pendencia
* When abrir detalhes
* Then identificar origem e ultima alteracao do ITM

*AC-REQ-007*
* Given oportunidade em etapa pre-faturamento
* When usuario revisar kit/produtos
* Then deve visualizar status de ITM dos registros obrigatorios

*AC-REQ-008*
* Given pendencia de ITM corrigida
* When reprocessamento for acionado
* Then item retoma fluxo com trilha auditavel

h2. Dependencias
* Definicao da precedencia oficial entre planilha e integracao
* Qualidade/disponibilidade das fontes de ITM
* Definicao de ownership operacional
* Janela de homologacao com cenarios de faturamento SAP

h2. Open Questions
# Qual campo oficial representa ITM do produto (ex.: ProductCode, NumeroItem__c ou outro)?
# Qual campo oficial representa ITM do Kit (ex.: NumeroItemSAP__c ou outro)?
# Qual regra de precedencia entre planilha e integracao em caso de divergencia?
# Qual padrao de validacao do ITM (tamanho, mascara, zeros a esquerda)?
# Havera backfill de historico sem ITM ou com ITM inconsistente?

h2. Plano de execucao
*Fase 1 - Descoberta (D0-D1)*
* Confirmar campo oficial de ITM por entidade
* Confirmar precedencia de fontes
* Definir validacao formal de ITM

*Fase 2 - Refinamento e aprovacao (D1-D2)*
* Validar REQ-001 a REQ-008 com stakeholders
* Fechar open questions criticas
* Congelar escopo para handoff tecnico

*Fase 3 - Implementacao e homologacao (D2-D4)*
* Implementar conforme arquitetura aprovada
* Homologar sucesso, erro e conflito entre fontes
* Validar bloqueios e rastreabilidade

*Fase 4 - Go-live e monitoramento (D4-D6)*
* Publicar em producao
* Monitorar cobertura ITM, erros e pendencias por 48h
* Reprocessar pendencias corrigidas com evidencia

*Fase 5 - Encerramento (D6)*
* Medir KPIs
* Registrar licoes aprendidas
* Encerrar historia com evidencias

h2. Definition of Ready
* [ ] Campo oficial de ITM por entidade definido
* [ ] Regra de precedencia entre fontes aprovada
* [ ] REQ-001 a REQ-008 aprovados
* [ ] Ownership de tratativa definido
* [ ] Criterios Given/When/Then aprovados
* [ ] Plano de validacao funcional aprovado
