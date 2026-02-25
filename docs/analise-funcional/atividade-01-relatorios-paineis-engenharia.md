# Atividade 1 - Refinamento Funcional
## Relatorios e Paineis para Engenharia

## 1) Objetivo de Negocio
Disponibilizar relatorios e paineis gerenciais para a area de Engenharia com KPIs padronizados de Viabilidade, Projetos, Instalacoes e Assistencia Tecnica, garantindo visao por Gestor de Obra e capacidade de tomada de decisao operacional.

## 2) Resultado Esperado e KPIs
- Acompanhar conversao de viabilidades em fechamentos por tipo de oportunidade.
- Medir tempos medios por etapa critica do funil de engenharia.
- Monitorar volume e eficiencia de resolucao de chamados de assistencia tecnica.
- Permitir recorte por Gestor de Obra nas visoes de Projetos e Instalacoes.

## 3) Stakeholders
- Solicitante: Area de Engenharia.
- Consumidores principais: Coordenacao/Gerencia de Engenharia, Supervisores e Gestores de Obra.
- Donos de dados (negocio): Engenharia (Viabilidade/Projetos/Instalacoes) e Assistencia Tecnica.

## 4) As-Is vs To-Be
### As-Is
- Existem relatorios isolados no org (ex.: lifecycle Opportunity->Viabilidade->Projeto->Instalacao e casos de Assistencia Tecnica).
- Nao ha pacote unico de KPIs com definicao funcional padronizada para todos os indicadores solicitados.
- Parte dos marcos temporais solicitados nao esta explicitamente definida por campo de data dedicado e requer confirmacao de regra de negocio.

### To-Be
- Conjunto padronizado de relatorios e paineis de Engenharia com definicoes unicas de KPI.
- Regras de inclusao/exclusao explicitas para evitar divergencias de leitura.
- Visoes com filtros por periodo, tipo de oportunidade e Gestor de Obra.

## 5) Escopo
### In-Scope
- KPIs de Viabilidade:
  - Taxa de Conversao (Viabilidades feitas x Fechamentos), por tipo de oportunidade.
  - Tempo medio da operacao (criacao x conclusao), por tipo de oportunidade.
- KPIs de Projetos:
  - Tempo medio de execucao (criacao x protocolo).
  - Tempo medio de aprovacao (protocolo x aprovacao), separado por SCEE e Fast Track.
- KPIs de Instalacoes:
  - Tempo medio de planejamento (criacao x obra agendada).
  - Tempo medio de execucao (obra em execucao x obra concluida - aguardando troca de medidor).
  - Visao separada por Gestor de Obra.
- KPIs de Assistencia Tecnica:
  - Quantidade de chamados por status.
  - Tempo medio de resolucao (abertura x fechamento).
  - Quantidade por tipo de chamado.

### Out-of-Scope
- Redesenho de processo operacional de Engenharia.
- Automacoes de alerta, SLA proativo e previsao estatistica.
- Definicoes de arquitetura tecnica (objeto/relacionamento/Flow/Apex).

## 6) Requisitos Funcionais

### REQ-001 - Taxa de Conversao de Viabilidade por Tipo de Oportunidade
Racional de negocio: medir eficiencia da etapa de viabilidade no fechamento comercial.
- Ator: Gestao de Engenharia.
- Trigger: acesso ao painel de Viabilidade.
- Pre-condicoes:
  - Viabilidade vinculada a Oportunidade.
  - Definicao unica de "fechamento" aprovada pelo negocio.
- Fluxo principal:
  - Exibir total de viabilidades feitas no periodo.
  - Exibir total de viabilidades que resultaram em fechamento.
  - Exibir taxa percentual por tipo de oportunidade.
- Fluxos alternativos:
  - Se nao houver fechamentos, taxa = 0%.
- Excecoes:
  - Registros sem tipo de oportunidade definido devem ser exibidos em categoria "Nao Classificado" ou excluidos conforme regra de negocio.

### REQ-002 - Tempo Medio da Operacao de Viabilidade por Tipo de Oportunidade
Racional de negocio: monitorar lead time de viabilidade e gargalos por tipo.
- Ator: Gestao de Engenharia.
- Trigger: acesso ao painel de Viabilidade.
- Pre-condicoes:
  - Data de inicio e data de conclusao da viabilidade definidas para o mesmo registro.
- Fluxo principal:
  - Calcular diferenca entre data de criacao e data de conclusao da viabilidade.
  - Exibir media por tipo de oportunidade.
- Fluxos alternativos:
  - Exibir contagem de registros excluidos por falta de data.
- Excecoes:
  - Duracao negativa deve ser sinalizada como inconsistencia de dado.

### REQ-003 - Tempo Medio de Execucao de Projetos
Racional de negocio: avaliar velocidade entre criacao do projeto e protocolizacao.
- Ator: Gestao de Engenharia.
- Trigger: acesso ao painel de Projetos.
- Pre-condicoes:
  - Projeto com data de criacao e data de protocolo preenchidas.
- Fluxo principal:
  - Calcular diferenca entre data de criacao do projeto e data de protocolo.
  - Exibir media do periodo selecionado.
- Fluxos alternativos:
  - Permitir filtro por tipo de oportunidade e Gestor de Obra.
- Excecoes:
  - Projetos sem data de protocolo entram em indicador de pendencia de dados.

### REQ-004 - Tempo Medio de Aprovacao de Projetos por Categoria
Racional de negocio: comparar desempenho entre SCEE e Fast Track.
- Ator: Gestao de Engenharia.
- Trigger: acesso ao painel de Projetos.
- Pre-condicoes:
  - Categoria do projeto definida (SCEE/Fast Track).
  - Data de protocolo e data de aprovacao preenchidas.
- Fluxo principal:
  - Calcular diferenca entre data de protocolo e data de aprovacao.
  - Exibir medias separadas para SCEE e Fast Track.
- Fluxos alternativos:
  - Permitir comparacao em serie temporal.
- Excecoes:
  - Registros com categoria fora do conjunto esperado devem ser tratados como "Nao Classificado".

### REQ-005 - Tempo Medio de Planejamento de Instalacoes
Racional de negocio: medir tempo de preparacao ate agendamento da obra.
- Ator: Gestao de Engenharia / Gestor de Obra.
- Trigger: acesso ao painel de Instalacoes.
- Pre-condicoes:
  - Instalacao com marco de criacao e marco "obra agendada" identificados.
- Fluxo principal:
  - Calcular diferenca entre data de criacao e data de obra agendada.
  - Exibir media geral e por Gestor de Obra.
- Fluxos alternativos:
  - Aplicar filtro por periodo e gestor.
- Excecoes:
  - Quando nao houver data explicita de "obra agendada", registrar lacuna de rastreabilidade.

### REQ-006 - Tempo Medio de Execucao de Instalacoes
Racional de negocio: medir tempo de campo ate conclusao de obra.
- Ator: Gestao de Engenharia / Gestor de Obra.
- Trigger: acesso ao painel de Instalacoes.
- Pre-condicoes:
  - Marco de "obra em execucao" e marco de "obra concluida - aguardando troca de medidor" identificados.
- Fluxo principal:
  - Calcular diferenca entre data de inicio de execucao e data de conclusao.
  - Exibir media geral e por Gestor de Obra.
- Fluxos alternativos:
  - Permitir recorte por tipo de obra.
- Excecoes:
  - Instalacoes com troca de status sem data rastreavel devem ser destacadas como incompletas para KPI.

### REQ-007 - Segmentacao por Gestor de Obra
Racional de negocio: responsabilizacao e visibilidade de performance por gestor.
- Ator: Coordenacao/Gerencia de Engenharia.
- Trigger: consulta de paineis de Projetos e Instalacoes.
- Pre-condicoes:
  - Gestor de Obra preenchido no registro (projeto/instalacao).
- Fluxo principal:
  - Exibir todos os KPIs de Projetos e Instalacoes com quebra por Gestor de Obra.
- Fluxos alternativos:
  - Filtro por gestor especifico.
- Excecoes:
  - Registros sem gestor devem ser identificados separadamente.

### REQ-008 - Quantidade de Chamados por Status (Assistencia Tecnica)
Racional de negocio: monitorar backlog e distribuicao operacional dos chamados.
- Ator: Lideranca de Assistencia Tecnica.
- Trigger: acesso ao painel de Assistencia Tecnica.
- Pre-condicoes:
  - Chamado classificado como Assistencia Tecnica.
- Fluxo principal:
  - Contabilizar chamados por status no periodo.
- Fluxos alternativos:
  - Permitir filtro por tipo/subtipo de chamado.
- Excecoes:
  - Status descontinuados ou nao mapeados devem ser agrupados como "Outros".

### REQ-009 - Tempo Medio de Resolucao (Assistencia Tecnica)
Racional de negocio: medir eficiencia operacional de resolucao.
- Ator: Lideranca de Assistencia Tecnica.
- Trigger: acesso ao painel de Assistencia Tecnica.
- Pre-condicoes:
  - Chamado com data de abertura e fechamento.
- Fluxo principal:
  - Calcular diferenca entre data de abertura e data de fechamento.
  - Exibir media no periodo.
- Fluxos alternativos:
  - Exibir distribuicao por faixa de tempo de resolucao.
- Excecoes:
  - Chamados ainda abertos nao entram no calculo medio de resolucao.

### REQ-010 - Quantidade por Tipo de Chamado (Assistencia Tecnica)
Racional de negocio: identificar volume por natureza de demanda.
- Ator: Lideranca de Assistencia Tecnica.
- Trigger: acesso ao painel de Assistencia Tecnica.
- Pre-condicoes:
  - Definicao de "tipo" validada (Tipo de Caso, Type e/ou Subtipo de Caso).
- Fluxo principal:
  - Exibir contagem por tipo de chamado no periodo.
- Fluxos alternativos:
  - Permitir drill-down por subtipo.
- Excecoes:
  - Chamados sem tipo devem ser destacados como "Nao Classificado".

### REQ-011 - Filtros Funcionais Comuns dos Paineis
Racional de negocio: padronizar leitura gerencial.
- Ator: Qualquer consumidor do painel.
- Trigger: interacao com painel.
- Pre-condicoes:
  - Parametros de filtro disponiveis.
- Fluxo principal:
  - Filtros minimos: periodo, tipo de oportunidade, gestor de obra (quando aplicavel), status.
- Fluxos alternativos:
  - Salvar visoes favoritas por perfil de usuario.
- Excecoes:
  - Quando filtro nao se aplicar ao KPI, sistema deve manter comportamento consistente e documentado.

### REQ-012 - Qualidade e Transparencia dos Dados dos KPIs
Racional de negocio: confiabilidade da tomada de decisao.
- Ator: Gestao de Engenharia e owners de dados.
- Trigger: consumo de qualquer KPI.
- Pre-condicoes:
  - Regras de calculo definidas e publicadas.
- Fluxo principal:
  - Exibir contagem de registros validos e excluidos por ausencia/inconsistencia de dados.
- Fluxos alternativos:
  - Exibir aviso quando qualidade de dados estiver abaixo do limiar acordado.
- Excecoes:
  - Se nao houver base valida no periodo, exibir "Sem dados suficientes" em vez de media incorreta.

## 7) Regras de Negocio e Excecoes
| ID | Regra de negocio | Excecao/Tratamento |
|---|---|---|
| BR-001 | Toda viabilidade contabilizada deve estar vinculada a uma oportunidade. | Sem vinculacao: excluir do KPI e listar como inconsistente. |
| BR-002 | Conversao de viabilidade deve usar definicao unica de fechamento aprovada. | Sem definicao fechada: bloqueia homologacao do KPI REQ-001. |
| BR-003 | Tempos medios devem considerar apenas registros com data inicial e final validas. | Datas ausentes/invalidas: nao entram na media e entram no indicador de qualidade. |
| BR-004 | KPI de aprovacao de projeto deve separar SCEE e Fast Track. | Categorias fora desse conjunto ficam em "Nao Classificado". |
| BR-005 | Visoes por Gestor de Obra sao obrigatorias para Projetos/Instalacoes. | Registros sem gestor ficam em "Sem Gestor". |
| BR-006 | Chamados de Assistencia Tecnica devem ser filtrados por classificacao oficial de atendimento. | Divergencia de classificacao: registrar em reconciliacao de dados. |

## 8) Matriz de Rastreabilidade de Dados (Funcional)
| Dominio | Origem | Transformacao funcional | Destino (KPI/Visao) | Ownership |
|---|---|---|---|---|
| Viabilidade | `ViabilityStudy__c` + `Opportunity` | Contagem de viabilidades e identificacao de fechamento por tipo de oportunidade | Taxa de Conversao (REQ-001) | Engenharia + Comercial |
| Viabilidade | `ViabilityStudy__c.CreatedDate` + marco de conclusao da viabilidade | Diferenca temporal por registro e media por tipo | Tempo medio operacao (REQ-002) | Engenharia |
| Projetos | `Projeto__c.CreatedDate` + data de protocolo | Diferenca temporal por projeto e media | Tempo medio execucao projeto (REQ-003) | Engenharia Projetos |
| Projetos | Data protocolo + data aprovacao + categoria projeto | Diferenca temporal segmentada por categoria | Tempo medio aprovacao SCEE/Fast Track (REQ-004) | Engenharia Projetos |
| Instalacoes | `Instalacao__c.CreatedDate` + marco "obra agendada" | Diferenca temporal por instalacao e media | Tempo medio planejamento (REQ-005) | Engenharia Obras |
| Instalacoes | Marco "obra em execucao" + marco "obra concluida - aguardando troca de medidor" | Diferenca temporal e media por gestor | Tempo medio execucao (REQ-006/REQ-007) | Engenharia Obras |
| Assistencia Tecnica | `Case` (status/classificacao) | Contagem por status | Qtde chamados por status (REQ-008) | Assistencia Tecnica |
| Assistencia Tecnica | `Case.CreatedDate` + `Case.ClosedDate` | Diferenca temporal em chamados fechados | Tempo medio resolucao (REQ-009) | Assistencia Tecnica |
| Assistencia Tecnica | `Case` (tipo/subtipo) | Contagem por categoria de chamado | Qtde tipos de chamados (REQ-010) | Assistencia Tecnica |

## 9) Criterios de Aceitacao (Given/When/Then)

### AC-REQ-001
- Given viabilidades vinculadas a oportunidades no periodo, When o usuario abre o painel de viabilidade, Then o sistema exibe taxa de conversao por tipo de oportunidade com numerador, denominador e percentual.
- Given nao existem fechamentos no periodo, When o painel e carregado, Then a taxa deve ser exibida como 0% sem erro.
- Given ha viabilidade sem tipo de oportunidade, When o KPI e calculado, Then o registro deve seguir regra de classificacao acordada (Nao Classificado ou exclusao com contagem).

### AC-REQ-002
- Given viabilidades com data de criacao e data de conclusao validas, When o KPI e calculado, Then o sistema exibe tempo medio por tipo de oportunidade.
- Given ha registros sem data final, When o KPI e processado, Then esses registros nao entram na media e aparecem como excluidos por qualidade.
- Given duracao negativa, When detectada no calculo, Then o registro deve ser sinalizado como inconsistente.

### AC-REQ-003
- Given projetos com data de criacao e data de protocolo, When o painel de projetos for consultado, Then o tempo medio de execucao deve ser exibido corretamente.
- Given projeto sem data de protocolo, When o KPI for calculado, Then o projeto nao compoe a media e entra na contagem de pendencias.

### AC-REQ-004
- Given projetos com categoria SCEE e Fast Track e datas validas, When o KPI de aprovacao for exibido, Then a media deve aparecer separada para cada categoria.
- Given categoria diferente de SCEE/Fast Track, When processada, Then deve ser direcionada para "Nao Classificado".

### AC-REQ-005
- Given instalacoes com marcos de criacao e obra agendada, When o KPI de planejamento for calculado, Then o painel deve mostrar media geral e por Gestor de Obra.
- Given marco de obra agendada nao identificado, When o KPI for executado, Then o sistema deve registrar exclusao por falta de dado rastreavel.

### AC-REQ-006
- Given instalacoes com marcos de obra em execucao e obra concluida aguardando troca de medidor, When o KPI for calculado, Then o tempo medio de execucao deve ser exibido por gestor.
- Given instalacao sem um dos marcos, When processada, Then deve ser excluida da media e contabilizada em qualidade de dados.

### AC-REQ-007
- Given projetos/instalacoes com Gestor de Obra preenchido, When o usuario aplicar filtro por gestor, Then os KPIs devem refletir somente os registros daquele gestor.
- Given registros sem Gestor de Obra, When o painel for exibido, Then eles devem aparecer em agrupamento "Sem Gestor".

### AC-REQ-008
- Given chamados classificados como Assistencia Tecnica, When o painel for aberto, Then a quantidade por status deve ser exibida no periodo filtrado.
- Given status nao mapeado para exibicao, When encontrado, Then deve ser agrupado em "Outros".

### AC-REQ-009
- Given chamados fechados com data de abertura e fechamento, When o KPI for calculado, Then deve ser exibido o tempo medio de resolucao.
- Given chamado aberto, When o KPI de resolucao for calculado, Then o chamado nao deve compor a media.

### AC-REQ-010
- Given chamados com tipo/subtipo preenchido, When o painel for exibido, Then deve apresentar contagem por tipo de chamado.
- Given chamado sem tipo, When contabilizado, Then deve aparecer como "Nao Classificado".

### AC-REQ-011
- Given usuario no painel, When aplicar filtro de periodo/tipo/gestor/status, Then todos os componentes aplicaveis devem responder de forma consistente.

### AC-REQ-012
- Given qualquer KPI com exclusoes por dados incompletos, When o usuario consultar o componente, Then deve visualizar quantidade de registros validos e excluidos.

## 10) Dependencias
- Definicao oficial de "fechamento" para o KPI de conversao (ex.: Closed Won vs fechado em qualquer condicao).
- Confirmacao do campo funcional para "tipo de oportunidade" (Record Type, Type ou campo derivado).
- Confirmacao do marco de "conclusao da viabilidade" para REQ-002.
- Confirmacao do marco de "obra agendada" e "obra em execucao" para REQ-005/REQ-006.
- Confirmacao da classificacao oficial de "tipo de chamado" em Assistencia Tecnica.

## 11) Restricoes
- KPI so pode ser homologado com regra de negocio unica para cada marco temporal.
- Ausencia de datas criticas reduz cobertura de registros validos.
- Registros com relacionamento incompleto (sem oportunidade/projeto/gestor) impactam representatividade.

## 12) Premissas
- O processo operacional continuara registrando os marcos de data em tempo adequado.
- Gestor de Obra e informacao obrigatoria de governanca para leitura gerencial.
- O periodo padrao de analise sera mensal, com possibilidade de recorte customizado.

## 13) Open Questions
1. Para REQ-001, "fechamento" significa somente `Closed Won` ou qualquer oportunidade fechada (`IsClosed = true`)?
2. Para REQ-001/REQ-002, o "tipo de oportunidade" oficial sera `RecordType`, campo `Type` ou outro campo corporativo?
3. Para REQ-002, qual e a data oficial de "conclusao da viabilidade": `ApproveDate__c`, mudanca para status "Viabilidade Finalizada" ou outro marco?
4. Para REQ-003, confirmar uso de `DataProtocoloProjeto__c` como data oficial de protocolo.
5. Para REQ-004, confirmar uso de `DataAprovacaoProjeto__c` ou `ApprovalDate__c` como data oficial de aprovacao.
6. Para REQ-005, existe campo de data explicito para "Obra agendada" ou sera considerado timestamp de mudanca de status?
7. Para REQ-006, o marco inicial sera `InstallDate__c` ou data de entrada no status "Obra em execucao"?
8. Para REQ-010, "Tipos de chamados" refere-se a `Tipo_de_Caso__c`, `Type`, `Subtipo_de_caso__c` ou combinacao hierarquica?
9. O recorte por Gestor de Obra em Instalacoes deve usar gestor da propria Instalacao, do Projeto, ou regra de precedencia entre ambos?
10. Qual a janela de tempo padrao dos paineis (Mensal, Trimestral, YTD)?

## 14) Decision Log
- DL-001: Atividade 1 consolidada em quatro blocos funcionais (Viabilidade, Projetos, Instalacoes, Assistencia Tecnica).
- DL-002: Todos os KPIs foram especificados com regra de qualidade de dados (validos x excluidos).
- DL-003: Segmentacao por Gestor de Obra tratada como obrigatoria para Projetos/Instalacoes, conforme solicitacao.
- DL-004: Pontos sem definicao unica de marco temporal foram formalizados em Open Questions para destravar handoff deterministico.

