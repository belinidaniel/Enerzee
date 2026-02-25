# Refinamento Funcional
## Atividades em Aberto e Atrasadas por Area e Departamento

## 1) Objetivo de Negocio
Garantir visibilidade operacional confiavel das atividades pendentes e vencidas por Area e por Departamento, com leitura por usuario responsavel, para apoiar priorizacao, cobranca e acompanhamento da execucao.

## 2) Resultado Esperado e KPIs
- KPI-01: Quantidade de atividades em aberto por Area (Administrativo, Comercial, Engenharia).
- KPI-02: Quantidade de atividades em aberto por Departamento dentro de cada Area.
- KPI-03: Quantidade de atividades atrasadas por Area.
- KPI-04: Quantidade de atividades atrasadas por Departamento dentro de cada Area.
- KPI-05: Capacidade de visualizar o detalhe das atividades que compoem cada indicador (rastreabilidade operacional).

## 3) Stakeholders
- Solicitante: Gestao executiva/operacional.
- Consumidores: Liderancas de Administrativo, Comercial e Engenharia.
- Ownership de dados: Donos de processo de atividades + liderancas das Areas.

## 4) As-Is vs To-Be
### As-Is
- Existem relatorios no dashboard executivo de atividades com agrupamento principal por `OWNER_ROLE`.
- A visualizacao atual nao atende diretamente ao recorte funcional solicitado (Area fixa + Departamento por Area + legenda por usuario).
- Em todos os relatorios atuais do conjunto, o detalhe de atividades nao aparece para o usuario final (sem visibilidade operacional do registro).
- Os graficos atuais priorizam visao agregada e nao evidenciam efetividade por usuario dentro de cada Area.

### To-Be
- Painel com visao separada por 3 Areas fixas: Administrativo, Comercial e Engenharia.
- Para cada Area, um grafico de atividades em aberto e um grafico de atividades atrasadas.
- Cada grafico com recorte por Departamento e legenda por usuario responsavel.
- Componente e relatorio permitindo visualizar as atividades subjacentes (detalhe rastreavel).

## 5) Escopo
### In-Scope
- Atividades em Aberto por Area (3 Areas fixas).
- Atividades em Aberto por Departamento (dentro de cada Area).
- Atividades Atrasadas por Area (3 Areas fixas).
- Atividades Atrasadas por Departamento (dentro de cada Area).
- Um grafico por Area para Aberto e um grafico por Area para Atrasado.
- Legenda por usuario responsavel em todos os graficos solicitados.
- Disponibilizacao do detalhe das atividades para consulta.

### Out-of-Scope
- Redesenho de workflow de criacao/conclusao de atividades.
- Mudanca de regra de SLA de atividade.
- Mudanca de hierarquia organizacional de cargos/perfis.

## 6) Requisitos Funcionais

### REQ-001 - Classificacao obrigatoria por Area
Racional: padronizar leitura executiva em 3 blocos de governanca.
- Ator: gestor de area.
- Trigger: abertura do painel de atividades.
- Pre-condicoes: toda atividade deve ser classificada em uma das Areas alvo para compor os graficos.
- Fluxo principal: apresentar apenas as Areas Administrativo, Comercial e Engenharia.
- Fluxo alternativo: atividade sem classificacao vai para grupo "Nao Classificada" para tratamento.
- Excecao: se origem da classificacao estiver vazia/inconsistente, atividade nao pode ser perdida silenciosamente.

### REQ-002 - Atividades em Aberto por Departamento, com 1 grafico por Area
Racional: monitorar backlog por estrutura funcional dentro de cada Area.
- Ator: lideranca da area.
- Trigger: consulta de backlog.
- Pre-condicoes: regra de "aberto" definida e departamento identificavel.
- Fluxo principal: para cada Area, exibir 1 grafico com quantidade de atividades em aberto por Departamento.
- Fluxo alternativo: permitir filtro por periodo e por usuario.
- Excecao: atividades sem departamento devem aparecer em "Departamento nao informado".

### REQ-003 - Atividades Atrasadas por Departamento, com 1 grafico por Area
Racional: destacar risco operacional por atraso.
- Ator: lideranca da area.
- Trigger: consulta de atrasos.
- Pre-condicoes: regra de "atrasado" definida com base em data de vencimento e status.
- Fluxo principal: para cada Area, exibir 1 grafico com quantidade de atividades atrasadas por Departamento.
- Fluxo alternativo: permitir recorte por janela temporal.
- Excecao: atividades sem data de vencimento seguem regra explicita (excluir ou separar em "Sem vencimento").

### REQ-004 - Legenda obrigatoria por Usuario
Racional: responsabilizacao e direcionamento de acao.
- Ator: liderancas e coordenadores.
- Trigger: visualizacao de qualquer grafico solicitado.
- Pre-condicoes: usuario responsavel da atividade identificado.
- Fluxo principal: grafico exibe legenda por usuario responsavel.
- Fluxo alternativo: quando houver alto volume, permitir exibicao paginada/filtrada sem perder rastreabilidade.
- Excecao: atividades com responsavel ausente devem ir para "Sem responsavel".

### REQ-005 - Visibilidade de detalhe das atividades
Racional: sem detalhe nao ha capacidade de auditoria/acao.
- Ator: usuario de negocio consumidor dos relatorios.
- Trigger: abrir relatorio de origem ou detalhar componente.
- Pre-condicoes: permissao de leitura do registro.
- Fluxo principal: usuario consegue listar os registros de atividade que compoem cada agregado.
- Fluxo alternativo: permitir exportacao/consulta tabular do mesmo conjunto.
- Excecao: se usuario nao tiver permissao em parte dos registros, sistema deve indicar parcialidade da visao.

### REQ-006 - Filtros funcionais padrao
Racional: leitura consistente entre areas e periodos.
- Ator: qualquer consumidor do painel.
- Trigger: aplicacao de filtro no painel/relatorio.
- Pre-condicoes: parametros disponiveis.
- Fluxo principal: filtros minimos: Area, Departamento, Usuario, Status, Periodo.
- Fluxo alternativo: visao padrao inicial por periodo vigente.
- Excecao: filtro nao aplicavel deve ter comportamento explicito (nao silencioso).

### REQ-007 - Consistencia de contagem entre relatorio e grafico
Racional: evitar divergencia de numero entre tela analitica e detalhe.
- Ator: gestor/auditoria.
- Trigger: comparacao entre componente e relatorio.
- Pre-condicoes: mesma base de filtro.
- Fluxo principal: totais exibidos no grafico devem bater com totais do detalhe.
- Fluxo alternativo: ao mudar filtro, os dois lados atualizam de forma sincronizada.
- Excecao: quando houver restricao de acesso, sistema deve sinalizar diferenca por escopo de visibilidade.

## 7) Regras de Negocio e Excecoes
| ID | Regra | Tratamento de excecao |
|---|---|---|
| BR-001 | "Aberto" deve usar regra unica de status definida pelo negocio. | Status fora da regra entram em "Nao classificado" para saneamento. |
| BR-002 | "Atrasado" = atividade em aberto com vencimento anterior a data corrente (regra a confirmar). | Sem data de vencimento: separar ou excluir conforme decisao formal. |
| BR-003 | Area obrigatoria com dominio fixo: Administrativo, Comercial, Engenharia. | Sem area: bucket "Nao Classificada". |
| BR-004 | Departamento obrigatorio para analise por area. | Sem departamento: bucket "Departamento nao informado". |
| BR-005 | Usuario responsavel deve aparecer na legenda dos graficos. | Sem responsavel: bucket "Sem responsavel". |
| BR-006 | Todo agregado deve ter rastreabilidade no detalhe. | Sem detalhe disponivel: nao homologar requisito. |

## 8) Matriz de Rastreabilidade de Dados
| Fonte | Transformacao funcional | Destino analitico | Ownership |
|---|---|---|---|
| Atividade (registro base) | Classificacao em Area | Graficos por Area (Aberto/Atrasado) | Gestao das Areas |
| Atividade + referencia organizacional | Classificacao em Departamento | Graficos por Departamento dentro da Area | Gestao das Areas |
| Atividade + responsavel | Agrupamento por usuario | Legenda por usuario | Lideranca operacional |
| Atividade + status + vencimento | Regra de aberto/atrasado | KPIs de backlog e atraso | PMO/Operacao |
| Relatorio detalhado | Exibicao de registros subjacentes | Auditoria operacional | Usuarios de negocio |

## 9) Criterios de Aceitacao (Given/When/Then)

### AC-REQ-001
- Given atividades no periodo, When o painel e carregado, Then a visualizacao deve estar segmentada em Administrativo, Comercial e Engenharia.
- Given atividade sem classificacao de area, When processada, Then deve aparecer em "Nao Classificada".

### AC-REQ-002
- Given atividades em aberto de uma Area, When o grafico da Area for exibido, Then deve mostrar quantidade por Departamento.
- Given filtro de periodo aplicado, When o grafico atualizar, Then os valores devem refletir apenas o periodo filtrado.

### AC-REQ-003
- Given atividades atrasadas de uma Area, When o grafico da Area for exibido, Then deve mostrar quantidade por Departamento.
- Given atividade em aberto sem vencimento, When regra de atraso for aplicada, Then comportamento deve seguir decisao formal documentada.

### AC-REQ-004
- Given qualquer grafico solicitado, When renderizado, Then deve exibir legenda por usuario responsavel.
- Given atividade sem responsavel, When agrupada, Then deve constar em "Sem responsavel".

### AC-REQ-005
- Given usuario com permissao de leitura, When abrir o relatorio relacionado ao grafico, Then deve visualizar os registros de atividade subjacentes.
- Given usuario sem permissao em parte dos registros, When abrir detalhe, Then sistema deve indicar visao parcial.

### AC-REQ-006
- Given painel publicado, When usuario aplicar filtros de Area/Departamento/Usuario/Status/Periodo, Then todos os componentes afetados devem recalcular consistentemente.

### AC-REQ-007
- Given mesmo conjunto de filtros, When comparar total do grafico com total do detalhe, Then os numeros devem ser iguais.

## 10) Dependencias
- Definicao oficial de como derivar Area e Departamento (origem organizacional de classificacao).
- Definicao oficial de status considerados "abertos".
- Definicao oficial para tratamento de atividades sem data de vencimento em "atrasadas".
- Validacao de permissao/escopo de execucao dos relatorios para todos os perfis consumidores.

## 11) Restricoes
- Relatorio sem detalhe visivel nao atende a necessidade de operacao.
- Classificacao incompleta de area/departamento compromete confiabilidade do KPI.
- Divergencia de escopo de visibilidade entre usuarios pode gerar leituras distintas.

## 12) Premissas
- A demanda cobre o conjunto de atividades monitoradas pelo dashboard executivo de atividades.
- A segmentacao por Area sera obrigatoria em todo componente solicitado.
- A legenda por usuario e requisito mandatorio para gestao operacional.

## 13) Open Questions
1. A classificacao de Area e Departamento deve usar qual origem oficial: Role, Role pai, `User.Department` ou tabela de mapeamento de negocio?
2. "Atividades" inclui apenas tarefas ou tambem compromissos/eventos?
3. Status de "aberto" sera estritamente "Status != Completed" ou existe lista corporativa de status fechados/cancelados?
4. Para "atrasadas", atividades sem data de vencimento devem ser excluidas ou exibidas em categoria separada?
5. A legenda por usuario deve mostrar nome completo, alias ou ambos?
6. O painel deve exibir exatamente 6 graficos (3 Areas x 2 visoes: Aberto/Atrasado)?
7. A solicitacao "Atividades em Aberto/Atrasadas por Departamento" deve manter tambem visao agregada por Area no mesmo componente ou em componente separado?
8. O escopo de visualizacao e organizacao inteira ou equipe do usuario logado?

## 14) Decision Log
- DL-001: A demanda foi estruturada em dois blocos principais: Aberto por Area/Departamento e Atrasado por Area/Departamento.
- DL-002: Foi formalizada a exigencia de 1 grafico por Area para cada bloco solicitado.
- DL-003: Foi formalizada a exigencia de legenda por usuario em todos os graficos alvo.
- DL-004: Foi registrada a lacuna funcional critica atual: ausencia de visibilidade do detalhe das atividades nos relatorios consumidos.
