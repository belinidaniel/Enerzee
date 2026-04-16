# Especificacao Funcional - Novo Fluxo de Geracao de Proposta via API

**Data:** 2026-04-10  
**Solicitante de negocio:** Comercial / Operacao de Propostas  
**Sistema impactado:** Salesforce Sales Cloud  
**Componente impactado:** `opportunityProposalConsole`  
**Status do legado:** `ModeloB` sera descontinuado

## 1. Objetivo de negocio

Substituir o fluxo atual de geracao de proposta dentro do Salesforce por um novo fluxo baseado em API externa, mantendo a experiencia operacional de consultar, visualizar e enviar a proposta dentro da oportunidade.

### Resultado esperado

- Reduzir a dependencia de templates Visualforce/PDF para o modelo descontinuado.
- Permitir geracao de proposta a partir de arquivo PowerPoint com tags substituiveis.
- Permitir administracao sem codigo das tags e das secoes exibidas por contexto de pagamento.
- Preservar a rastreabilidade da proposta dentro da oportunidade.

### KPI sugerido

- Percentual de propostas geradas com sucesso pela API.
- Tempo medio entre criacao da oportunidade e disponibilidade da proposta no console.
- Percentual de regeneracoes de proposta concluidas apos escolha da forma de pagamento.
- Quantidade de ajustes de tags/secoes realizados sem deploy.

## 2. Contexto

Hoje, a proposta e gerada no Salesforce a partir de capas/templates vinculados ao parceiro e exibida/enviada pelo console de propostas. O novo processo deve manter a logica comercial de selecao de capa, mas trocar a origem do documento base: em vez de imagem/template PDF interno, sera utilizado um arquivo `PPTX` com tags que serao substituidas por dados da oportunidade via API externa.

O comportamento atual identificado no repositorio mostra que:

- o console `opportunityProposalConsole` permite visualizar e enviar proposta;
- a escolha do modelo hoje depende das capas vinculadas ao parceiro;
- a proposta enviada passa a aparecer como anexo/documento da oportunidade;
- a selecao de proposta promocional ja considera contexto promocional e `TipoKitPromocional__c`.

## 3. Resumo As-Is vs To-Be

### As-Is

- A proposta e gerada dentro do Salesforce.
- O parceiro define a capa de proposta e a capa promocional.
- O usuario consegue visualizar a proposta e enviar a proposta pelo console da oportunidade.
- O arquivo gerado fica associado a oportunidade e volta a aparecer na lista de propostas.

### To-Be

- A geracao da proposta deixa de ocorrer pelo modelo `ModeloB`.
- O Salesforce passa a enviar para uma API externa:
  - o arquivo `PPTX` base;
  - as tags e respectivos valores;
  - a lista de secoes a exibir.
- A API retorna o arquivo final da proposta.
- O arquivo final continua disponivel no fluxo de visualizar proposta e enviar proposta dentro do `opportunityProposalConsole`.
- As tags e as secoes devem ser administraveis sem codigo.

## 4. Escopo

### Em escopo

- Nova geracao de proposta via API externa.
- Selecao do arquivo `PPTX` base conforme parceiro, contexto promocional e tipo de kit promocional.
- Montagem do payload com arquivo, tags e secoes.
- Suporte a primeira geracao sem forma de pagamento definida.
- Suporte a regeneracao apos escolha da forma de pagamento.
- Manutencao das funcionalidades de visualizar proposta e enviar proposta no console atual.
- Administracao sem codigo das tags e das secoes.

### Fora de escopo

- Redesenho do layout comercial da proposta.
- Definicao tecnica de objetos, relacoes, Flow vs Apex ou modelo de persistencia.
- Alteracao do processo comercial de escolha da forma de pagamento.
- Refatoracao completa do console de propostas, desde que as funcoes atuais continuem atendidas.

## 5. Premissas

- A estrutura conceitual de capas continuara existindo.
- O arquivo base da proposta passara a ser um `PPTX` com tags substituiveis.
- A escolha da forma de pagamento ocorre em momento posterior a primeira geracao da proposta.
- A API externa e a origem oficial para conversao do `PPTX` em proposta final.
- O usuario administrador precisa conseguir ajustar configuracoes sem deploy.

## 6. Dependencias

- API externa `convertProposal` disponivel e homologada.
- Contrato de resposta da API confirmado.
- Endpoint auxiliar `/sections` disponivel para retorno das secoes existentes no `PPTX`.
- Cadastro/relacao do arquivo `PPTX` correto por parceiro e por tipo kit promocional.
- Definicao de ownership para manutencao de tags e secoes.
- Disponibilidade dos campos da oportunidade usados como fonte das tags.

## 7. Restricoes

- O `ModeloB` nao deve mais ser usado no novo fluxo.
- O processo deve continuar visivel para o usuario final dentro da oportunidade.
- A nova solucao nao pode exigir alteracao de codigo para manutencao rotineira de tags e secoes.

## 8. Atores

- Consultor/comercial: cria a oportunidade e aciona a proposta.
- Usuario de vendas: visualiza e envia a proposta ao cliente.
- Administrador Salesforce: mantem configuracoes de tags e secoes sem codigo.
- API externa de conversao: recebe o arquivo e devolve a proposta final.

## 9. Fluxo To-Be

### Trigger principal

Criacao de nova oportunidade elegivel para geracao de proposta.

### Pre-condicoes

- A oportunidade possui parceiro definido em `Parceiro__c`.
- Existe configuracao valida para identificar o arquivo base da proposta.
- Existe configuracao ativa de tags para o tipo de proposta.
- Existe configuracao ativa de secoes para o cenario inicial.

### Fluxo principal - primeira geracao

1. O usuario cria uma nova oportunidade.
2. O sistema identifica o parceiro da oportunidade.
3. O sistema identifica se a proposta e promocional ou nao, conforme regra comercial vigente.
4. Quando a proposta for promocional, o sistema identifica o `PPTX` correto com base no `TipoKitPromocional__c` e na relacao "proposta x pptx details".
5. O sistema carrega o arquivo `PPTX` base da proposta.
6. O sistema monta o conjunto de tags no formato `{{ApiNameDoCampo}}`.
7. O sistema define a lista de secoes iniciais a exibir, contemplando o cenario em que a forma de pagamento ainda nao foi escolhida.
8. O sistema envia para a API externa:
   - arquivo binario/blob;
   - tags;
   - secoes a exibir no parametro `sections_to_show`.
9. O sistema recebe o arquivo final gerado.
10. O sistema associa o arquivo final a oportunidade.
11. O sistema disponibiliza o arquivo no console de propostas para visualizacao e envio.

### Fluxo alternativo - regeneracao apos escolha da forma de pagamento

1. O usuario seleciona a forma de pagamento no processo comercial.
2. O usuario aciona a regeneracao da proposta.
3. O sistema identifica a configuracao de secoes correspondente a forma de pagamento escolhida.
4. O sistema reutiliza o `PPTX` base e as tags vigentes da oportunidade.
5. O sistema envia nova solicitacao para a API contendo apenas as secoes configuradas para a forma de pagamento selecionada.
6. O sistema substitui ou adiciona uma nova versao de proposta disponivel no console, conforme regra de negocio definida para historico.

### Fluxos de excecao

- Se nao existir configuracao de arquivo base para o contexto da oportunidade, a proposta nao deve ser gerada.
- Se nao existir configuracao de tags ativa, a proposta nao deve ser gerada.
- Se nao existir configuracao de secoes para o cenario solicitado, a proposta nao deve ser gerada.
- Se a API externa retornar erro, o usuario deve ser informado e a oportunidade nao deve ficar com status falso de proposta gerada.
- Se o arquivo final nao puder ser associado a oportunidade, o usuario deve ser informado e o evento deve ser rastreavel para suporte.

## 10. Requisitos funcionais

### REQ-001 - Identificacao da origem do modelo

O sistema deve identificar o contexto da oportunidade a partir do `Parceiro__c` para determinar qual configuracao de proposta deve ser utilizada.

**Racional de negocio:** garantir que a proposta gerada respeite a identidade comercial e o contexto do parceiro.

### REQ-002 - Tratamento de proposta promocional

Quando a oportunidade estiver em contexto promocional, o sistema deve selecionar o arquivo `PPTX` com base no `TipoKitPromocional__c` e na relacao configurada entre proposta e `PPTX`.

**Racional de negocio:** garantir que kits promocionais usem o documento correto.

### REQ-003 - Arquivo base em PowerPoint

O sistema deve usar um arquivo `PPTX` como documento base da proposta, em substituicao ao modelo legado descontinuado.

**Racional de negocio:** viabilizar a nova estrategia de geracao por API com tags substituiveis.

### REQ-004 - Payload de integracao

O sistema deve enviar para a API externa tres grupos de informacao:

- arquivo `PPTX` em formato binario/blob;
- tags com valores de negocio, enviadas como `string` JSON;
- lista de secoes a exibir, enviada como `string` JSON no parametro `sections_to_show`.

**Racional de negocio:** permitir que a API gere a proposta final com os dados corretos e o conteudo apropriado.

### REQ-005 - Padrao das tags

As tags devem ser montadas usando o nome API do campo Salesforce entre chaves duplas, no formato `{{ApiNameDoCampo}}`.

Exemplo:

```json
{
  "{{AccountId}}": "ENZ-2026-00847",
  "{{Logradouro__c}}": "Rua das Palmeiras, 342",
  "{{Complemento__c}}": "Galpao B",
  "{{Bairro__c}}": "Jardim Industrial",
  "{{CEP__c}}": "78045-210",
  "{{MunicipioInstalacao__c}}": "Cuiaba",
  "{{EstadoInstalacao__c}}": "MT",
  "{{Numeroproposta__c}}": "PROP-2026-1183"
}
```

**Racional de negocio:** padronizar a substituicao de valores no documento final.

### REQ-006 - Administracao sem codigo das tags

O sistema deve permitir que um administrador autorizado mantenha o conjunto de tags, seus nomes e suas fontes de dados sem necessidade de alteracao de codigo.

**Racional de negocio:** reduzir dependencia de deploy para ajustes operacionais.

### REQ-007 - Administracao sem codigo das secoes

O sistema deve permitir que um administrador autorizado mantenha, sem codigo, a lista ordenada de secoes que devem ser exibidas por cenario de proposta e por forma de pagamento.

**Racional de negocio:** permitir ajustes comerciais sem intervencao tecnica recorrente.

### REQ-008 - Geracao inicial sem forma de pagamento definida

Na primeira geracao da proposta, quando a forma de pagamento ainda nao tiver sido decidida, o sistema deve usar uma configuracao de secoes que contemple todas as opcoes comerciais que precisam ser apresentadas ao cliente.

Exemplo informado pelo negocio:

```text
["Proposta","Proposta de valores","Valor Selecionados","rodape da proposta"]
```

**Racional de negocio:** permitir apresentacao inicial ampla antes da tomada de decisao comercial.

### REQ-009 - Regeneracao por forma de pagamento

Depois que a forma de pagamento for definida, o sistema deve permitir gerar novamente a proposta usando apenas as secoes configuradas para a opcao escolhida.

Exemplo informado pelo negocio para cartao de credito:

```text
proposta; Valor Cartao de credito; rodape de prosta
```

**Racional de negocio:** entregar ao cliente uma proposta final aderente a negociacao escolhida.

### REQ-010 - Preservacao do console de proposta

O novo fluxo deve manter no `opportunityProposalConsole` as capacidades de:

- visualizar proposta;
- enviar proposta.

**Racional de negocio:** evitar ruptura operacional para o time comercial.

### REQ-011 - Disponibilizacao do arquivo gerado na oportunidade

Toda proposta gerada pela API deve ficar associada a oportunidade e disponivel na listagem de propostas exibida ao usuario.

**Racional de negocio:** manter rastreabilidade, historico operacional e acesso posterior ao documento.

### REQ-012 - Tratamento de falhas operacionais

O sistema deve informar o usuario quando houver falha de configuracao, falha de integracao, falha de retorno do arquivo ou falha de associacao do documento a oportunidade.

**Racional de negocio:** permitir acao corretiva rapida e reduzir retrabalho comercial.

## 11. Matriz de rastreabilidade de dados

| Origem                               | Transformacao esperada                   | Destino                                 | Ownership                             |
| ------------------------------------ | ---------------------------------------- | --------------------------------------- | ------------------------------------- |
| `Opportunity.Parceiro__c`            | Identificar contexto da proposta         | Selecionar configuracao do arquivo base | Operacao comercial / Admin Salesforce |
| Contexto promocional da oportunidade | Definir se usa fluxo promocional         | Escolha do arquivo `PPTX` promocional   | Operacao comercial                    |
| `Opportunity.TipoKitPromocional__c`  | Resolver variante do `PPTX` promocional  | Arquivo base enviado a API              | Operacao comercial / Admin Salesforce |
| Campos da oportunidade               | Converter em pares `{{ApiName}}: valor`  | Payload de tags da API                  | Admin Salesforce                      |
| Forma de pagamento selecionada       | Resolver conjunto de secoes aplicavel    | Payload de secoes da API                | Operacao comercial / Admin Salesforce |
| Arquivo final retornado pela API     | Associar ao registro comercial correto   | Oportunidade / console de propostas     | Salesforce                            |
| Proposta associada a oportunidade    | Exibir e disponibilizar acoes ao usuario | `opportunityProposalConsole`            | Salesforce                            |

## 12. Regras de negocio e excecoes

| Regra ID | Regra                                                                                                                                  |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| BR-001   | Toda proposta nova deve partir de uma oportunidade com `Parceiro__c` preenchido.                                                       |
| BR-002   | Quando o contexto for promocional, o `PPTX` deve respeitar o `TipoKitPromocional__c`.                                                  |
| BR-003   | A chave de cada tag deve usar obrigatoriamente o nome API do campo entre `{{` e `}}`.                                                  |
| BR-004   | A lista de secoes deve ser ordenada, refletir exatamente o conteudo esperado para o cenario e ser enviada no campo `sections_to_show`. |
| BR-005   | Na primeira geracao, a proposta deve contemplar o conjunto inicial de secoes configurado para "sem forma de pagamento definida".       |
| BR-006   | Apos escolha da forma de pagamento, a nova geracao deve usar somente as secoes configuradas para a opcao escolhida.                    |
| BR-007   | O usuario final deve continuar conseguindo visualizar e enviar a proposta no console atual.                                            |
| BR-008   | Falta de configuracao obrigatoria deve impedir a geracao e exibir mensagem clara ao usuario.                                           |
| BR-009   | Falha da API nao pode ser registrada como sucesso operacional silencioso.                                                              |

## 13. Criterios de aceite

### AC-001 - Selecao do arquivo base

**Given** uma oportunidade com parceiro configurado  
**When** o usuario iniciar a geracao da proposta  
**Then** o sistema deve identificar o arquivo base correto para aquele contexto

### AC-002 - Variacao promocional

**Given** uma oportunidade em contexto promocional com `TipoKitPromocional__c` preenchido  
**When** o usuario iniciar a geracao da proposta  
**Then** o sistema deve usar o `PPTX` correspondente ao tipo kit promocional configurado

### AC-003 - Montagem das tags

**Given** uma oportunidade com campos elegiveis para a proposta  
**When** o sistema montar o payload da API  
**Then** cada tag deve ser enviada no formato `{{ApiNameDoCampo}}`

### AC-004 - Configuracao sem codigo de tags

**Given** uma configuracao ativa de tags mantida por administrador  
**When** o administrador alterar uma tag sem deploy  
**Then** a proxima geracao de proposta deve refletir a alteracao

### AC-005 - Configuracao sem codigo de secoes

**Given** uma configuracao ativa de secoes mantida por administrador  
**When** o administrador alterar a lista de secoes de um cenario  
**Then** a proxima geracao de proposta deve usar a nova lista

### AC-006 - Primeira proposta sem forma de pagamento

**Given** uma oportunidade sem forma de pagamento definida  
**When** a primeira proposta for gerada  
**Then** a API deve receber a lista de secoes inicial configurada para esse cenario no parametro `sections_to_show`

### AC-007 - Regeneracao apos escolha da forma de pagamento

**Given** uma oportunidade com forma de pagamento escolhida  
**When** o usuario gerar novamente a proposta  
**Then** a API deve receber apenas as secoes configuradas para a forma de pagamento selecionada no parametro `sections_to_show`

### AC-008 - Disponibilizacao no console

**Given** que a API retornou a proposta com sucesso  
**When** o processamento for concluido  
**Then** o usuario deve conseguir localizar a proposta no `opportunityProposalConsole`

### AC-009 - Visualizacao

**Given** uma proposta associada a oportunidade  
**When** o usuario usar a acao de visualizar proposta  
**Then** o sistema deve abrir a proposta gerada

### AC-010 - Envio

**Given** uma proposta associada a oportunidade  
**When** o usuario usar a acao de enviar proposta  
**Then** o sistema deve executar o fluxo de envio da proposta mantendo o comportamento operacional esperado

### AC-011 - Erro de configuracao

**Given** que falte configuracao obrigatoria de arquivo, tags ou secoes  
**When** o usuario tentar gerar a proposta  
**Then** o sistema deve bloquear a geracao e informar claramente a pendencia

### AC-012 - Erro da API

**Given** que a API externa retorne erro ou nao devolva um arquivo valido  
**When** o sistema finalizar a tentativa de geracao  
**Then** o usuario deve receber retorno de falha e a proposta nao deve ser marcada como concluida com sucesso

## 14. Decisoes ja confirmadas

| ID      | Decisao                                                                                                                  |
| ------- | ------------------------------------------------------------------------------------------------------------------------ |
| DEC-001 | `ModeloB` sera descontinuado.                                                                                            |
| DEC-002 | O novo fluxo de geracao nao sera mais executado integralmente dentro do Salesforce; a conversao passara por API externa. |
| DEC-003 | A estrutura de capas permanece como referencia funcional do processo.                                                    |
| DEC-004 | O arquivo base da proposta sera um `PPTX` com tags substituiveis.                                                        |
| DEC-005 | Tags usarao o padrao `{{ApiNameDoCampo}}`.                                                                               |
| DEC-006 | A lista de secoes deve variar entre geracao inicial e geracao apos escolha da forma de pagamento.                        |
| DEC-007 | A API recebe a lista de secoes no parametro `sections_to_show`.                                                          |
| DEC-008 | Existe endpoint auxiliar `/sections` para retorno das secoes disponiveis no `PPTX`.                                      |
| DEC-009 | Tags e secoes precisam ser mantidas sem codigo.                                                                          |
| DEC-010 | O `opportunityProposalConsole` deve continuar suportando visualizacao e envio de proposta.                               |

## 15. Log de decisoes para arquitetura

- O solicitante sugeriu usar configuracao administravel por metadata para tags e secoes.
- A necessidade funcional e "administracao sem codigo"; a decisao tecnica final deve ser definida na etapa de arquitetura.

## 16. Perguntas em aberto

1. Qual e o contrato exato de resposta da API `convertProposal`:
   - tipo do arquivo retornado;
   - nome do arquivo;
   - mime type;
   - estrutura de erro;
   - necessidade de polling ou retorno sincrono?
2. Quando uma tag estiver configurada, mas o campo de origem estiver vazio, a geracao deve:
   - enviar valor em branco;
   - bloquear a geracao;
   - ou seguir regra por tag?
3. A proposta regenerada apos escolha da forma de pagamento deve substituir a anterior ou manter historico de multiplas versoes?
4. Qual campo oficial representa "forma de pagamento escolhida" para disparar a segunda geracao?
5. Os nomes das secoes enviados no payload precisam ser exatamente iguais aos identificadores existentes no `PPTX`? Se sim, quais sao os valores oficiais e validados?
6. O fluxo de "enviar proposta" continuara usando o mesmo canal/aplicativo atual, sem alteracao de regra de negocio?
7. O preview da proposta no console sera feito com o arquivo final devolvido pela API ou sera necessario um formato adicional para visualizacao?

## 17. Observacao de validacao externa

O contrato OpenAPI foi validado durante a analise e confirmou:

- endpoint `POST /convertProposal`;
- payload `multipart/form-data`;
- campo `file` em binario;
- campo `tags` como `string` JSON;
- campo `sections_to_show` como `string` JSON;
- endpoint auxiliar `POST /sections` para listar as sections disponiveis no `PPTX`.

Ainda permanecem em aberto apenas os detalhes da estrutura de resposta funcional da API. Portanto, os requisitos acima usam como fonte:

- a regra de negocio informada pelo solicitante;
- o comportamento atual identificado no repositorio;
- o contrato OpenAPI validado da API externa.
