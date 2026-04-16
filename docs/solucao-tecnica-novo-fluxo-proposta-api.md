# Solucao Tecnica - Novo Fluxo de Geracao de Proposta via API

## 1. Assumptions

1. A `Opportunity` continua sendo o hub central do processo comercial e da rastreabilidade da proposta.
2. O processo de envio para o aplicativo atual continua existindo apos a geracao do PDF final; o que muda e a etapa de geracao do documento.
3. A geracao por API substitui o legado `ModeloB` e deve coexistir, temporariamente, com o restante do fluxo atual ate o deploy completo.
4. A forma oficial de identificar a forma de pagamento selecionada sera `Opportunity.SelectedSimulation__c -> PaymentSimulation__c`.
5. A estrutura de capas atual deve ser preservada e `ProposalCover__c` continua sendo a entidade funcional que o usuario escolhe no console.
6. O arquivo mestre `PPTX` deve ser administrado sem codigo. Como o admin precisa anexar arquivo, a solucao recomendada e reutilizar `Files` em `ProposalCover__c`, e nao Custom Metadata para o binario.
7. Tags e secoes devem ser configuraveis sem deploy de codigo. Para isso, a solucao recomendada e usar `Custom Metadata Types`.
8. A API `POST /convertProposal` e sincrona no nivel HTTP, mas a chamada Salesforce deve ser executada em `Queueable` para reduzir risco de timeout na UX.
9. O contrato OpenAPI confirmou apenas o request. O contrato de response ainda precisa ser fechado. A recomendacao tecnica e padronizar retorno em JSON com `fileBase64`, `fileName` e `mimeType`.
10. A regra de "promocional" hoje esta fragmentada no legado. A nova solucao deve centralizar essa decisao em um unico resolver de contexto.

## 2. Modelo de Dados e Relacionamentos

### 2.1 Desenho logico ponta a ponta

1. `Opportunity (1) -> (N) PaymentSimulation__c`
2. `Opportunity (1) -> (0..1) SelectedSimulation__c`
3. `Parceiro__c (1) -> (0..1) CapaProposta__c`
4. `Parceiro__c (1) -> (0..1) CapaPromocional__c`
5. `ProposalCover__c (1) -> (N) Files(ContentDocumentLink/ContentVersion)`
6. `Opportunity (1) -> (N) ContentVersion` com `IsProposal__c = true`
7. `Opportunity (1) -> (N) OpportunityAttachmentLink__c`
8. `Opportunity (1) -> (N) ProposalPending__c`

### 2.2 Relacionamentos e justificativa Lookup vs Master-Detail

1. `PaymentSimulation__c.Opportunity__c`
   - Tipo: `Master-Detail` existente
   - Justificativa:
   - integridade referencial forte
   - ownership herdado da oportunidade
   - previne simulacoes orfas
   - adequado porque simulacao nao faz sentido fora da oportunidade

2. `Opportunity.SelectedSimulation__c -> PaymentSimulation__c`
   - Tipo: `Lookup` existente
   - Justificativa:
   - a oportunidade precisa apontar apenas uma simulacao escolhida entre varias filhas
   - nao pode ser `Master-Detail` porque a simulacao ja e filha da oportunidade
   - lookup filter existente ja previne selecao cruzada entre oportunidades

3. `Parceiro__c.CapaProposta__c` e `Parceiro__c.CapaPromocional__c -> ProposalCover__c`
   - Tipo: `Lookup` existente
   - Justificativa:
   - a capa e uma entidade reutilizavel entre parceiros/contextos
   - nao deve haver exclusao em cascata a partir do parceiro
   - mantem flexibilidade operacional

4. `OpportunityAttachmentLink__c.OpportunityId__c`
   - Tipo: `Lookup` existente
   - Justificativa:
   - o objeto ja atende cenarios genericos de anexos externos
   - ha uso combinado com `SObjectId__c`, portanto nao e recomendavel transformar em `Master-Detail`
   - para proposta, a integridade sera garantida por validacao funcional em Apex/Validation Rule

5. `ProposalPending__c.Opportunity__c`
   - Tipo: `Lookup required` existente
   - Justificativa:
   - pendencias precisam manter vinculo obrigatorio com a oportunidade
   - ownership proprio e mais flexivel que `Master-Detail`
   - delete constraint atual ja evita orfao

6. `ProposalCover__c -> Files`
   - Tipo: relacao nativa via `ContentDocumentLink`
   - Justificativa:
   - permite upload sem codigo do arquivo `PPTX`
   - evita criar objeto adicional apenas para armazenar binario
   - reutiliza padrao ja empregado no legado para assets de capa

### 2.3 Artefatos novos recomendados

#### Campos novos em `ProposalCover__c`

1. `IntegrationKey__c`
   - Tipo: `Text(80)`
   - Propriedades: `Unique = true`, `External Id = true`
   - Uso: chave estavel para correlacionar `ProposalCover__c` com `Custom Metadata`

#### Campos novos em `ContentVersion`

1. `ProposalTemplateRole__c`
   - Tipo: `Picklist`
   - Valores recomendados:
   - `API_PPTX_TEMPLATE`
   - `LEGACY_LAYOUT`
   - `AUXILIARY_ASSET`
   - Uso: separar o `PPTX` mestre dos arquivos legados anexados a capa

2. `ProposalPayloadHash__c`
   - Tipo: `Text(64)`
   - Uso: identificar se o contexto atual ja possui PDF gerado e permitir reuso

3. `ProposalScenario__c`
   - Tipo: `Picklist`
   - Valores:
   - `INITIAL`
   - `PAYMENT_SELECTED`
   - Uso: auditoria e troubleshooting

4. `ProposalPaymentType__c`
   - Tipo: `Text(80)`
   - Uso: registrar o tipo de pagamento considerado no PDF gerado

5. `ProposalCoverKey__c`
   - Tipo: `Text(80)`
   - Uso: armazenar a `IntegrationKey__c` da capa usada na geracao

#### Custom Metadata novo `ProposalTagMapping__mdt`

1. `CoverKey__c` - `Text(80)`
2. `TagKey__c` - `Text(255)`
3. `SourcePath__c` - `Text(255)`
4. `Scenario__c` - `Picklist` (`ALL`, `INITIAL`, `PAYMENT_SELECTED`)
5. `PaymentType__c` - `Text(80)` opcional
6. `Format__c` - `Picklist`
   - valores sugeridos: `RAW`, `DATE_BR`, `CURRENCY_BR`, `DECIMAL_BR`, `INTEGER`, `UPPER`, `LOWER`
7. `DefaultValue__c` - `Long Text Area`
8. `Required__c` - `Checkbox`
9. `SortOrder__c` - `Number(18,0)`
10. `Active__c` - `Checkbox`

#### Custom Metadata novo `ProposalSectionRule__mdt`

1. `CoverKey__c` - `Text(80)`
2. `Scenario__c` - `Picklist` (`INITIAL`, `PAYMENT_SELECTED`)
3. `PaymentType__c` - `Text(80)` opcional
4. `SectionName__c` - `Text(255)`
5. `SortOrder__c` - `Number(18,0)`
6. `Active__c` - `Checkbox`

### 2.4 Como os campos de pagamento ficam acessiveis no contexto da proposta sem duplicacao

1. Nao copiar campos de `PaymentSimulation__c` para `Opportunity`.
2. Usar `Opportunity.SelectedSimulation__c` como ancora funcional.
3. No builder de tags, permitir `SourcePath__c` com navegacao por relacionamento, por exemplo:
   - `SelectedSimulation__r.PaymentType__c`
   - `SelectedSimulation__r.ProposalLabel__c`
   - `SelectedSimulation__r.InstallmentCount__c`
   - `SelectedSimulation__r.InstallmentAmount__c`
4. Dessa forma, a proposta sempre le os dados vivos da simulacao escolhida e evita duplicacao.

### 2.5 Regras de integridade recomendadas

1. Validation Rule em `ProposalCover__c`
   - se `IsActive__c = true`, `IntegrationKey__c` obrigatoria

2. Validation Rule em `OpportunityAttachmentLink__c`
   - quando `Type__c = 'Proposal'`, exigir `OpportunityId__c`

3. Validacao em Apex ao resolver template
   - deve existir exatamente um `PPTX` ativo para a combinacao:
   - `ProposalCover`
   - `ProposalTemplateRole__c = API_PPTX_TEMPLATE`
   - contexto promocional
   - `TipoKitPromocional__c` quando aplicavel

4. Validacao em Apex ao resolver secoes
   - se `Scenario = PAYMENT_SELECTED`, deve existir configuracao especifica para o `PaymentType`
   - se nao existir, usar fallback default apenas se houver registro sem `PaymentType__c`

## 3. Configuracao Salesforce (passo a passo)

### 3.1 Integracao HTTP

1. Criar `Named Credential` recomendado:
   - API Name: `Enerzee_Proposal_Api`
   - URL base: `https://enerzeeapifile.livelybeach-f3e8be7c.brazilsouth.azurecontainerapps.io`
   - tipo: `SecuredEndpoint`
   - autenticacao: conforme contrato final da API

2. Nao reutilizar `Integrador__mdt` para segredo/autenticacao da nova API.
   - Motivo:
   - `Named Credential` e a abordagem nativa e mais segura
   - facilita rotacao de credenciais
   - reduz exposicao de segredos em metadata

3. Se houver restricao organizacional para usar o padrao legado:
   - fallback: manter URL em `Integrador__mdt`
   - ainda assim, recomendacao formal e usar `Named Credential`

### 3.2 Configuracao de dados de capa/template

1. Em cada `ProposalCover__c` ativo:
   - preencher `IntegrationKey__c`
   - manter `Template__c` legado enquanto houver coexistencia

2. Fazer upload do `PPTX` em `Files` no registro `ProposalCover__c`

3. No `ContentVersion` do arquivo `PPTX`:
   - `IsTemplate__c = true`
   - `ProposalTemplateRole__c = API_PPTX_TEMPLATE`
   - `TipoKitPromocional__c` = null quando template for generico
   - `TipoKitPromocional__c` preenchido quando template for especifico por kit promocional

4. Regra de resolucao do `PPTX`
   - nao promocional: buscar template com `TipoKitPromocional__c` nulo
   - promocional: buscar template com `TipoKitPromocional__c` correspondente
   - se nao achar especifico, nao gerar proposta; falhar com mensagem funcional

### 3.3 Configuracao sem codigo de tags

1. Criar registros de `ProposalTagMapping__mdt` por `CoverKey__c`
2. Cada registro define uma tag e sua origem
3. Exemplo de registros:
   - `CoverKey__c = GRUPO_B_PADRAO`, `TagKey__c = {{Numeroproposta__c}}`, `SourcePath__c = Numeroproposta__c`
   - `CoverKey__c = GRUPO_B_PADRAO`, `TagKey__c = {{NomeDaConta__c}}`, `SourcePath__c = Account.Name`
   - `CoverKey__c = GRUPO_B_PADRAO`, `TagKey__c = {{FormaPagamento__c}}`, `SourcePath__c = SelectedSimulation__r.PaymentType__c`

### 3.4 Configuracao sem codigo de secoes

1. Criar registros de `ProposalSectionRule__mdt`
2. Para o cenario inicial:
   - `Scenario__c = INITIAL`
   - `PaymentType__c` vazio
   - uma linha por secao, com `SortOrder__c`

3. Para o cenario apos selecao do pagamento:
   - `Scenario__c = PAYMENT_SELECTED`
   - `PaymentType__c` preenchido com o valor oficial da simulacao
   - uma linha por secao

4. Exemplo:
   - `INITIAL` -> `Proposta`
   - `INITIAL` -> `Proposta de valores`
   - `INITIAL` -> `Valor Selecionados`
   - `INITIAL` -> `rodape da proposta`
   - `PAYMENT_SELECTED` + `CartaoCredito` -> `Proposta`
   - `PAYMENT_SELECTED` + `CartaoCredito` -> `Valor Cartao de credito`
   - `PAYMENT_SELECTED` + `CartaoCredito` -> `rodape da proposta`

### 3.5 Componentes Apex recomendados

1. `ProposalContextResolver`
   - Responsabilidade:
   - centralizar a regra de `isPromotional`
   - centralizar `scenario = INITIAL | PAYMENT_SELECTED`
   - centralizar resolucao do `paymentType`

2. `ProposalConfigurationService`
   - Responsabilidade:
   - carregar `ProposalTagMapping__mdt`
   - carregar `ProposalSectionRule__mdt`
   - validar consistencia da configuracao

3. `ProposalTemplateResolver`
   - Responsabilidade:
   - localizar o `ContentVersion` do `PPTX` correto em `ProposalCover__c`

4. `DynamicSObjectPathResolver`
   - Responsabilidade:
   - navegar em paths como `Account.Name` e `SelectedSimulation__r.PaymentType__c`

5. `ProposalPayloadBuilder`
   - Responsabilidade:
   - gerar `tags` JSON
   - gerar `sections_to_show` JSON
   - calcular `payloadHash`

6. `MultipartFormDataBuilder`
   - Responsabilidade:
   - montar manualmente o `multipart/form-data` em Apex

7. `ProposalApiClient`
   - Responsabilidade:
   - chamar `POST /convertProposal`
   - opcionalmente chamar `POST /sections` em modo validacao/admin

8. `ProposalFileService`
   - Responsabilidade:
   - salvar PDF retornado como `ContentVersion`
   - preencher `IsProposal__c = true`
   - preencher metadados de auditoria

9. `ProposalGenerationService`
   - Responsabilidade:
   - orquestrar resolucao de contexto, template, tags, secoes, API, cache e persistencia

10. `ProposalGenerationQueueable`
    - Responsabilidade:
    - executar o callout fora da thread da UI
    - permitir preview e send com o mesmo motor

### 3.6 Ajustes nas classes e componentes existentes

1. Atualizar `ProposalConsoleController`
   - manter `loadProposalData`
   - substituir dependencia direta de `PDFControllerExtension.generatePdfContent`
   - incluir novos metodos:
   - `generatePreview(opportunityId, coverId)`
   - `sendProposal(opportunityId, coverId)` delegando ao novo motor

2. Atualizar `opportunityProposalConsole`
   - remover dependencia de preview por `iframe` Visualforce para o fluxo API
   - ao clicar em `Visualizar proposta`, chamar `generatePreview`
   - ao receber URL do PDF gerado, abrir modal de preview com o arquivo
   - manter tabs/listagem de propostas ja enviadas

3. Atualizar `paymentSimulationCards`
   - manter chamada para `sendProposal`
   - o novo service deve inferir automaticamente `PAYMENT_SELECTED` quando houver `SelectedSimulation__c`

4. Refatorar `IntegracaoNivelloProposta`
   - adicionar overload recomendado:
   - `gerandoPropostaSincrona(Id oppId, Id contentVersionId)`
   - `gerandoProposta(Id oppId, Id contentVersionId)`
   - Motivo:
   - evitar ambiguidade de "ultimo PDF da oportunidade"
   - garantir que o arquivo enviado ao app seja exatamente o mesmo gerado pela API

### 3.7 Algoritmo tecnico recomendado

1. Usuario escolhe a capa no console
2. Apex resolve contexto:
   - opportunity
   - partner
   - cover
   - isPromotional
   - tipoKitPromocional
   - selectedSimulation
   - paymentType
   - scenario

3. Apex resolve o `PPTX` mestre anexado ao `ProposalCover__c`
4. Apex carrega mappings e section rules via `Custom Metadata`
5. Apex monta query dinamica da `Opportunity` com todos os `SourcePath__c` unicos
6. Apex resolve valores e formata `tags`
7. Apex monta `sections_to_show`
8. Apex calcula `payloadHash = SHA-256(cover + templateVersion + tagsJson + sectionsJson)`
9. Apex verifica se ja existe `ContentVersion` com o mesmo hash
10. Se existir:
    - `Preview`: reutiliza o arquivo existente
    - `Send`: reutiliza o arquivo existente e envia ao app
11. Se nao existir:
    - executa callout `convertProposal`
    - salva PDF interno em `ContentVersion`
12. Se acao = `Preview`:
    - retorna URL interna do `ContentVersion`
13. Se acao = `Send`:
    - chama `IntegracaoNivelloProposta` com o `contentVersionId`
    - mantem criacao/upsert de `OpportunityAttachmentLink__c` como comprovante de envio ao app

### 3.8 Contrato tecnico recomendado para response da API

Padrao recomendado:

```json
{
  "success": true,
  "fileName": "Proposta_B_PROP-2026-1183.pdf",
  "mimeType": "application/pdf",
  "fileBase64": "JVBERi0xLjcK..."
}
```

Motivo:

1. evita segundo callout para baixar arquivo
2. simplifica persistencia em `ContentVersion`
3. reduz dependencia de URL externa temporaria

Fallback aceito se o provedor nao puder alterar:

```json
{
  "success": true,
  "urlFile": "https://.../arquivo.pdf"
}
```

Nesse caso, Salesforce fara um segundo `GET` para baixar o binario antes de salvar em `ContentVersion`.

### 3.9 Seguranca e permissoes

1. Permission Set tecnico recomendado: `Proposal_API_Admin`
   - acesso a `ProposalCover__c`
   - acesso aos novos campos em `ContentVersion`
   - acesso de leitura a `PaymentSimulation__c`
   - acesso aos `Custom Metadata Types`

2. Permission Set usuario operacional: `Proposal_API_User`
   - acesso ao LWC
   - execucao das classes Apex novas
   - leitura de propostas internas

3. FLS minimo para tag source
   - todos os campos usados em `SourcePath__c` devem estar legiveis para o contexto da classe ou tratados via `without sharing` controlado + `stripInaccessible` na saida quando aplicavel

### 3.10 Validacao opcional de sections

Recomendacao adicional:

1. Criar um `Screen Flow` ou quick action admin `Validar sections do PPTX`
2. O flow envia o arquivo para `POST /sections`
3. Exibe a lista retornada
4. Admin compara com `ProposalSectionRule__mdt`

Isso reduz erro de digitacao em nome de secao.

## 4. Custom Report Type

### 4.1 Report Type recomendado

1. Nome: `Oportunidades com ou sem anexos externos de proposta`
2. Objeto primario: `Opportunity`
3. Objeto relacionado: `OpportunityAttachmentLink__c`
4. Relacao:
   - `Opportunity with or without OpportunityAttachmentLink__c`

### 4.2 Justificativa do join

1. Usar `with or without`
   - quando o objetivo e monitorar o funil inteiro
   - incluindo oportunidades ainda sem proposta enviada ao app

2. Usar `with`
   - apenas em relatorios estritamente operacionais de propostas ja enviadas
   - por exemplo, compliance de envio ou SLA de entrega ao app

### 4.3 Campos recomendados no layout do Report Type

#### Opportunity

1. `Name`
2. `Account.Name`
3. `Owner.Name`
4. `StageName`
5. `Parceiro__c`
6. `TipoKitPromocional__c`
7. `Numeroproposta__c`
8. `PropostaGerada__c`
9. `SelectedSimulation__r.PaymentType__c`
10. `SelectedSimulation__r.ProposalLabel__c`
11. `SelectedSimulation__r.InstallmentCount__c`
12. `SelectedSimulation__r.InstallmentAmount__c`

#### OpportunityAttachmentLink\_\_c

1. `Type__c`
2. `AttachmentDescription__c`
3. `AttachmentURL__c`
4. `ExternalId__c`
5. `CreatedDate`

### 4.4 Observacao de plataforma

`ContentVersion` nao e o melhor objeto para relatorio operacional de negocio em `Custom Report Type`. Por isso:

1. o PDF interno em `ContentVersion` sera a verdade tecnica do documento
2. o CRT operacional deve usar `OpportunityAttachmentLink__c` para reportar o que foi efetivamente enviado ao app

## 5. Relatorio Padrao

### 5.1 Nome sugerido

`Pipeline de Propostas API - Comercial`

### 5.2 Filtros padrao

1. `Opportunity.IsClosed = false` ou conforme recorte desejado
2. `Opportunity.StageName` em:
   - elaboracao de proposta
   - metodo de pagamento
   - proposta gerada
   - proposta enviada
3. `OpportunityAttachmentLink__c.Type__c = Proposal` quando o foco for apenas enviadas
4. `CreatedDate = THIS_MONTH` ou `LAST 90 DAYS`

### 5.3 Agrupamentos sugeridos

1. Primeiro agrupamento: `Opportunity.Owner`
2. Segundo agrupamento: `Opportunity.StageName`
3. Terceiro agrupamento: `Opportunity.SelectedSimulation__r.PaymentType__c`

### 5.4 Colunas minimas

1. `Opportunity.Name`
2. `Account.Name`
3. `Owner.Name`
4. `StageName`
5. `Parceiro__c`
6. `TipoKitPromocional__c`
7. `Numeroproposta__c`
8. `SelectedSimulation__r.PaymentType__c`
9. `SelectedSimulation__r.ProposalLabel__c`
10. `OpportunityAttachmentLink__c.AttachmentDescription__c`
11. `OpportunityAttachmentLink__c.AttachmentURL__c`
12. `OpportunityAttachmentLink__c.CreatedDate`

### 5.5 Colunas avancadas

1. `PropostaGerada__c`
2. `ValorTotalProposta__c`
3. `SelectedSimulation__r.InstallmentCount__c`
4. `SelectedSimulation__r.InstallmentAmount__c`
5. `StatusBodyIntegracaoNivello__c`
6. `SucessoIntegracaoNivello__c`

## 6. Criterios de Aceitacao e Validacao

### 6.1 Configuracao

1. Dado um `ProposalCover__c` ativo sem `IntegrationKey__c`
   - quando o admin tentar ativar/usar a configuracao
   - entao o sistema deve bloquear

2. Dado um cover com mais de um `PPTX` valido para a mesma combinacao
   - quando o usuario gerar a proposta
   - entao o sistema deve falhar com erro de configuracao ambigua

### 6.2 Geracao inicial

1. Dada uma oportunidade sem `SelectedSimulation__c`
   - quando o usuario gerar preview
   - entao o sistema deve usar `Scenario = INITIAL`
   - e enviar `sections_to_show` conforme metadata inicial

2. Dada uma oportunidade promocional com `TipoKitPromocional__c = X`
   - quando o usuario gerar proposta
   - entao o sistema deve usar o `PPTX` do cover com `TipoKitPromocional__c = X`

### 6.3 Geracao apos forma de pagamento

1. Dada uma oportunidade com `SelectedSimulation__c` preenchido
   - quando o usuario enviar proposta
   - entao o sistema deve usar `Scenario = PAYMENT_SELECTED`
   - e `PaymentType = SelectedSimulation__r.PaymentType__c`

2. Dada uma section rule especifica para o payment type selecionado
   - quando a proposta for gerada
   - entao apenas essas secoes devem ser enviadas no payload

### 6.4 Reuso de arquivo

1. Dado que tags, secoes e cover nao mudaram
   - quando o usuario visualizar e depois enviar
   - entao o sistema deve reutilizar o `ContentVersion` ja gerado
   - e nao chamar a API duas vezes

### 6.5 Persistencia e envio

1. Dado retorno valido da API
   - quando a geracao concluir
   - entao o PDF deve ser salvo como `ContentVersion` na oportunidade com `IsProposal__c = true`

2. Dado envio ao app com sucesso
   - quando `IntegracaoNivelloProposta` for executada
   - entao o sistema deve criar ou atualizar `OpportunityAttachmentLink__c` tipo `Proposal`

3. Dado que existam multiplos PDFs na oportunidade
   - quando o usuario enviar a proposta gerada
   - entao a integracao deve usar explicitamente o `contentVersionId` retornado pelo motor
   - e nao o "ultimo PDF" por consulta generica

### 6.6 Erro

1. Dado erro 4xx/5xx da API
   - quando o job de geracao falhar
   - entao o usuario deve receber mensagem clara
   - e a oportunidade nao deve ser marcada como proposta enviada com sucesso

2. Dado mapping com campo obrigatorio sem valor
   - quando `Required__c = true`
   - entao o motor deve falhar antes do callout, indicando a tag e o campo ausente

## 7. Limitacoes, Riscos e Alternativas

### 7.1 Limitacoes da plataforma

1. `multipart/form-data` em Apex exige montagem manual de boundary e corpo binario.
2. `ContentVersion` nao e ideal para reportabilidade operacional em CRT.
3. Se a API levar perto de 120 segundos, chamadas sincronas a partir do controller terao risco de timeout.

### 7.2 Riscos do legado atual

1. A regra de `isPromotional` esta inconsistente no legado.
   - Recomendacao:
   - centralizar em `ProposalContextResolver`

2. O metodo atual de envio ao app busca o ultimo PDF da oportunidade.
   - Risco:
   - enviar arquivo errado em cenarios com preview + reenvio
   - Recomendacao:
   - overload com `contentVersionId`

3. O cover hoje mistura arquivos de layout legados e futuros `PPTX`.
   - Risco:
   - query pegar arquivo errado
   - Recomendacao:
   - usar `ProposalTemplateRole__c`

### 7.3 Alternativa recomendada se a administracao de Files em `ProposalCover__c` ficar complexa

Criar objeto custom `ProposalPptxDetail__c` com `Master-Detail` para `ProposalCover__c` e relacionar o `PPTX` via `Files` nesse objeto filho.

Usar essa alternativa apenas se:

1. houver muitas variantes por cover
2. o admin precisar editar varios atributos por template
3. a manutencao via Files diretamente no cover se tornar confusa

### 7.4 Recomendacao final

1. Reutilizar `ProposalCover__c` como raiz funcional
2. Reutilizar `Files` no cover para armazenar o `PPTX`
3. Usar `Custom Metadata` para tags e secoes
4. Usar `Named Credential` para a nova API
5. Salvar sempre o PDF final em `ContentVersion`
6. Manter `OpportunityAttachmentLink__c` para comprovante de envio ao app
7. Refatorar `IntegracaoNivelloProposta` para envio por `contentVersionId`
