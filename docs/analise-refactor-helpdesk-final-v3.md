# Analise de refactor - branch `feature/helpdesk-final-v3`

Data da analise: 2026-06-04  
Escopo: mudancas locais rastreadas e arquivos novos nao rastreados da branch.  
Restricao aplicada: nenhum teste, build, deploy, servidor local ou codigo da aplicacao foi executado. A analise usou apenas leitura de arquivos e comandos Git/Ripgrep.

## Resumo executivo

A branch esta concentrada no fluxo final de Help Desk Salesforce:

- Criacao de Case com categorizacao propria em `Case.HelpDesk_Tipo__c` e `Case.HelpDesk_Subtipo__c`.
- Substituicao do rich text da descricao inicial por texto puro no portal.
- Upload de evidencias/anexos via `AttachmentLink__c` externo, vinculado a mensagens do feed.
- Espelhamento de `HelpDeskMessage__c` para `CaseComment`, com persistencia do `CaseCommentId__c`.
- Append idempotente das URLs de anexos no `CaseComment` para o conector Getint/Jira.
- Novo LWC interno `helpDeskCaseFeed` para agentes no record page de Case.
- Ajustes de permissao, CSP Trusted Site, layout e manifests parciais.

O principal risco imediato e de deployabilidade: o novo layout de Case contem um field API name invalido (`Con  tactId`). O restante da branch tem boa intencao funcional, mas ha pontos de coesao, contratos publicos e validacao que merecem refactor controlado antes de deploy final.

## Arquivos alterados

### Apex

- `force-app/main/default/classes/HelpDeskCaseDAO.cls`
  - Alteracao atual efetiva: cabecalho `last modified`.
  - Observacao: durante a primeira leitura apareceu um diff transitorio com `ParentId,1`, mas a linha atual esta correta como `ParentId`. O achado nao esta ativo no arquivo atual.

- `force-app/main/default/classes/HelpDeskCaseService.cls`
  - `createCase` deixou de gravar `Case.Type` e `Case.Reason` para gravar os novos campos `HelpDesk_Tipo__c` e `HelpDesk_Subtipo__c` quando existem no schema.
  - `uploadMessageFileExternal` agora chama `HelpDeskMessageBO.appendAttachmentUrlsToComment` quando o upload externo gera `AttachmentLink__c` vinculado a uma mensagem.

- `force-app/main/default/classes/HelpDeskMessageBO.cls`
  - `mirrorToCaseComments` passou a guardar `CaseCommentId__c` na mensagem espelhada.
  - Novo metodo publico `appendAttachmentUrlsToComment`.
  - Nova logica privada para remover/reescrever a secao de anexos no `CaseComment`.

- `force-app/main/default/classes/ModuloHelpDeskCaseController.cls`
  - Novo endpoint `getAllMessageAttachments(Id caseId)` para visao interna.

### Testes Apex

- `HelpDeskCaseServiceTest.cls`
  - Ajusta asserts para os novos campos de categorizacao.
  - Adiciona teste de criacao/listagem de mensagens publicas e privadas.

- `HelpDeskMessageBOTest.cls`
  - Verifica persistencia de `CaseCommentId__c`.
  - Verifica append de URLs de anexos no `CaseComment`.

- `ModuloHelpDeskCaseControllerTest.cls`
  - Cobre anexos internos, mensagem de agente, listagem completa e append no comentario espelhado.

### LWC

- `helpDeskHome`
  - Troca `lightning-input-rich-text` por `lightning-textarea`.
  - Remove `richDescription` do formulario e envia `richDescription: null`.
  - Anexos da criacao passam a criar uma mensagem inicial `Evidencias:` e fazer upload externo por mensagem.

- `helpDeskCaseDetail`
  - Resolve `recordId` por `@api`, `CurrentPageReference` e fallback por URL.
  - Separa `richDescription` de `plainDescription`.
  - Combina mensagens e anexos no getter `displayMessages`, removendo dependencia de ordem entre wires.

- `helpDeskCaseFeed` novo
  - Componente interno para Record Page de Case.
  - Lista mensagens publicas e privadas, faz polling a cada 15 segundos e permite envio de resposta de agente com anexos.

### Metadata

- Novos campos:
  - `Case.HelpDesk_Tipo__c`
  - `Case.HelpDesk_Subtipo__c`
  - `HelpDeskMessage__c.CaseCommentId__c`

- Novo CSP Trusted Site:
  - `gerenciadorblob` para `https://gerenciadorblob.blob.core.windows.net`

- Novo layout:
  - `Case-Help Desk Salesforce Layout`

- Ajustes:
  - Permission sets `HelpDesk_Aprovacao_Admin` e `Help_Desk_Guest`
  - Profile `Administrador`
  - Manifests auxiliares em `manifest/`

## Achados

### P0 - Bloqueador de deploy: field invalido no layout

Arquivo: `force-app/main/default/layouts/Case-Help Desk Salesforce Layout.layout-meta.xml`  
Linha: 20

O layout referencia:

```xml
<field>Con  tactId</field>
```

Isso deve ser `ContactId`. Do jeito atual, o metadata de Layout tende a falhar no deploy ou gerar layout invalido.

Plano de refactor/fix:

1. Corrigir apenas o field API name para `ContactId`.
2. Validar o XML.
3. Validar deploy do layout e profile que faz assignment para esse layout.

### P1 - Metodo `appendAttachmentUrlsToComment` tem parametros mortos

Arquivo: `force-app/main/default/classes/HelpDeskMessageBO.cls`  
Linhas: 87-90

O metodo recebe `fileNames` e `urls`, mas ignora os dois parametros e usa `AttachmentLink__c` como fonte da verdade.

Risco:

- Contrato publico confuso para futuras chamadas.
- Induz manutencao errada, porque o nome do metodo sugere append incremental e os parametros sugerem payload direto, mas a implementacao reescreve a secao inteira a partir do banco.

Plano de refactor:

1. Preservar o metodo publico atual por compatibilidade, se necessario.
2. Extrair metodo privado sem parametros mortos, por exemplo `rewriteMirroredCommentAttachmentSection(Id messageId)`.
3. Fazer o metodo publico atual delegar para o metodo novo ou remover os parametros se nao houver consumo externo relevante.
4. Ajustar testes para nomear a regra: "reescreve a secao de anexos a partir de AttachmentLink\_\_c".

### P1 - Append de anexos faz DML adicional dentro do fluxo de upload

Arquivos:

- `HelpDeskCaseService.cls`, linhas 441-445
- `HelpDeskMessageBO.cls`, linhas 95-160

Cada upload externo vinculado a mensagem chama uma rotina que:

- consulta `HelpDeskMessage__c`;
- consulta todos os `AttachmentLink__c` da mensagem;
- consulta `CaseComment`;
- atualiza `CaseComment`.

Risco:

- Em uploads multiplos, o mesmo `CaseComment` pode ser reescrito varias vezes na mesma interacao.
- A operacao mistura responsabilidade de upload externo, sincronizacao com Jira/Getint e formatacao de texto do comentario.
- A regra e funcionalmente importante, entao precisa ficar explicita e testavel.

Plano de refactor:

1. Separar a responsabilidade em um metodo nomeado de sincronizacao de comentario espelhado.
2. Para fluxos com multiplos anexos, considerar consolidar a reescrita para depois de todos os uploads, quando o caller tiver controle do batch.
3. Manter a chamada atual como fallback para uploads unitarios ate provar que todos os callers consolidam corretamente.
4. Cobrir com teste de upload multiplo para garantir idempotencia e ausencia de duplicacao.

### P1 - Campo tecnico `CaseCommentId__c` esta legivel para Guest

Arquivo: `force-app/main/default/permissionsets/Help_Desk_Guest.permissionset-meta.xml`  
Campo: `HelpDeskMessage__c.CaseCommentId__c`

O campo novo e uma chave tecnica da ponte `HelpDeskMessage__c -> CaseComment/Jira`. Ele foi adicionado como readable para Guest.

Risco:

- Exposicao desnecessaria de identificador tecnico para usuario de portal/guest.
- Pode virar dependencia acidental no frontend publico.

Plano de refactor/seguranca:

1. Confirmar se algum LWC publico precisa ler `CaseCommentId__c`. Pela busca atual, o LWC nao usa esse campo.
2. Remover leitura do permission set Guest se nao houver necessidade funcional.
3. Manter permissao administrativa apenas para suporte/investigacao.

### P1 - Novo endpoint interno depende de exposicao correta do LWC

Arquivos:

- `ModuloHelpDeskCaseController.cls`, linhas 38-41 e 67-71
- `helpDeskCaseFeed.js`, linhas 45-48

`getAllMessages` e `getAllMessageAttachments` retornam mensagens e anexos privados para usuarios internos. A autorizacao interna em `enforceVisibility` valida existencia do Case para usuarios internos, o que e coerente para record page interna, mas perigoso se o componente/metodo for usado em contexto publico.

Plano de refactor/controle:

1. Manter `helpDeskCaseFeed` exposto apenas para `lightning__RecordPage`.
2. Adicionar comentario/contrato de uso nos metodos internos do controller.
3. Se houver risco de reuso em Experience Cloud, criar guarda explicita de user type/permissao para endpoints `getAll*`.

### P2 - Duplicacao de helpers de anexo entre LWCs

Arquivos:

- `helpDeskCaseDetail.js`
- `helpDeskCaseFeed.js`

Ha duplicacao de:

- `IMAGE_EXTENSIONS`
- `groupAttachments`
- `extensionFromName`
- `resolveIconName`
- `formatSize`
- logica de preview/open new tab

Risco:

- Divergencia futura entre portal e feed interno.
- Regras de anexo e icone ficam espalhadas.

Plano de refactor:

1. Extrair helper compartilhado em modulo LWC local, por exemplo `helpDeskAttachmentUtils`.
2. Migrar primeiro apenas funcoes puras.
3. Nao mover estado de UI nem comportamento de modal no primeiro passo.
4. Rodar testes JS/LWC depois da aprovacao.

### P2 - `helpDeskHome` ainda mantem `buildApexFilePayload` legado nao utilizado

Arquivo: `helpDeskHome.js`  
Linhas: 486-493

A branch removeu o uso de `uploadFilesBypassLicense` e passou a usar upload externo por mensagem. `buildApexFilePayload` permanece no arquivo, mas a busca indica que nao e mais usado.

Plano de refactor:

1. Remover metodo morto depois de confirmar que nao ha template ou teste chamando.
2. Remover comentarios e imports legados relacionados ao fluxo antigo, se restarem.
3. Validar que o fluxo de criacao com anexos ainda usa `base64Data`, nao o prefixo `data:*`.

### P2 - Mudanca de rich text para textarea altera comportamento funcional

Arquivos:

- `helpDeskHome.html`, linhas 145-151
- `helpDeskHome.js`, linhas 230-234
- `helpDeskCaseDetail.js`, linhas 370-400

A branch parou de gravar `Description_Rich__c` na criacao pelo portal e passou a renderizar fallback de `Description` como texto puro.

Risco:

- E uma mudanca funcional, nao apenas refactor.
- Pode impactar usuarios que esperavam formatacao rich text, links ou imagens embutidas na descricao.

Plano:

1. Confirmar que a remocao de rich text e intencional.
2. Preservar a renderizacao de `Description_Rich__c` para casos antigos, como a branch ja faz.
3. Documentar comportamento novo: descricao inicial e texto puro; evidencias viram mensagem/anexo.

### P2 - `stripSistemaPrefix` depende de prefixo textual

Arquivo: `helpDeskCaseDetail.js`  
Linhas: 394-400

O frontend remove a primeira linha `Sistema: ...` do `Description` com regex, porque o backend injeta esse prefixo via `buildCaseDescription`.

Risco:

- Acoplamento por string entre Apex e LWC.
- Uma descricao real iniciada por `Sistema:` pode ser alterada visualmente.

Plano de refactor:

1. Preferir expor `HelpDesk_Sistema__c` no DTO/query e evitar embutir sistema na descricao.
2. Como passo minimo, tornar o strip mais especifico e coberto por teste.
3. Evitar mexer na regra ate confirmar necessidade de retrocompatibilidade dos casos ja criados.

### P2 - Manifests parciais podem ficar inconsistentes com artefatos novos

Arquivos:

- `manifest/helpdesk-attachment-url.xml`
- `manifest/helpdesk-categorizacao.xml`
- `manifest/helpdesk-fix-deploy.xml`

Os manifests sao uteis para deploy incremental, mas nao ha um unico manifesto que contenha claramente todos os artefatos novos do fluxo final, incluindo CSP, layout, LWC interno, campos, permissions e profile.

Plano:

1. Criar ou ajustar um manifesto final do pacote Help Desk completo.
2. Manter manifests parciais apenas se forem usados para deploy em etapas.
3. Evitar deploy parcial que inclua Apex dependente de campo ainda nao deployado.

### P3 - Formatacao/estilo misto em LWC novo

Arquivo: `helpDeskCaseFeed.js`

O componente novo usa aspas simples e tabs, enquanto os LWCs existentes deste modulo usam aspas duplas e dois espacos. Isso nao e bug funcional, mas aumenta ruido de manutencao.

Plano:

1. Alinhar estilo ao padrao local do repo.
2. Fazer isso apenas junto com refactor aprovado, para nao misturar formatacao isolada com mudanca funcional.

## Plano de refactor proposto

### Fase 0 - Correcoes bloqueadoras de deploy

Objetivo: deixar a branch deployavel sem alterar comportamento de negocio.

Mudancas propostas:

- Corrigir `Con  tactId` para `ContactId` no layout.
- Conferir se todos os arquivos novos devem ser versionados.
- Consolidar manifesto final, se aprovado.

Validacao proposta apos aprovacao:

- `xmllint --noout` no layout e metadados XML alterados.
- Deploy validation focado no pacote Help Desk.

### Fase 1 - Clarificar contrato de anexos espelhados no Jira

Objetivo: reduzir ambiguidade e risco no fluxo `HelpDeskMessage__c -> CaseComment -> Jira`.

Mudancas propostas:

- Renomear/extrair a rotina que reescreve anexos no comentario.
- Remover ou isolar parametros mortos de `appendAttachmentUrlsToComment`.
- Manter comportamento de reescrever a secao inteira a partir de `AttachmentLink__c`.
- Adicionar teste para idempotencia com upload sucessivo/multiplo.

Validacao proposta apos aprovacao:

- Apex tests focados:
  - `HelpDeskMessageBOTest`
  - `HelpDeskCaseServiceTest`
  - `ModuloHelpDeskCaseControllerTest`

### Fase 2 - Segurança e contrato de visibilidade

Objetivo: garantir que mensagens/anexos privados e campos tecnicos nao vazem para Experience Cloud.

Mudancas propostas:

- Revisar `Help_Desk_Guest` para `CaseCommentId__c`.
- Adicionar guarda/contrato explicito para endpoints internos, se necessario.
- Confirmar que `helpDeskCaseFeed` permanece apenas em `lightning__RecordPage`.

Validacao proposta apos aprovacao:

- Busca por referencias LWC/Apex ao campo tecnico.
- Testes Apex de mensagens publicas vs privadas.
- Validacao manual de permissoes em org, se disponivel.

### Fase 3 - Refactor LWC de anexos

Objetivo: reduzir duplicacao entre portal e feed interno sem mudar UX.

Mudancas propostas:

- Extrair funcoes puras de anexo para helper compartilhado.
- Remover `buildApexFilePayload` legado de `helpDeskHome`.
- Manter estados, modal e handlers especificos em cada componente.

Validacao proposta apos aprovacao:

- `npm test`, se houver suites LWC aplicaveis.
- Checagem visual/manual dos fluxos:
  - criar caso com evidencias;
  - abrir detalhe no portal;
  - enviar comentario com anexo;
  - enviar mensagem interna no record page.

### Fase 4 - Revisao da descricao/categorizacao

Objetivo: remover acoplamento textual de `Sistema:` quando for seguro.

Mudancas propostas:

- Confirmar regra de negocio da mudanca rich text -> textarea.
- Avaliar expor `HelpDesk_Sistema__c`, `HelpDesk_Tipo__c`, `HelpDesk_Subtipo__c` diretamente no detalhe.
- Reduzir dependencia de `stripSistemaPrefix`.

Validacao proposta apos aprovacao:

- Teste de criacao de Case com categorizacao.
- Verificacao de casos antigos com `Description_Rich__c`.
- Verificacao de casos novos com `Description` texto puro.

## Invariantes que o refactor deve preservar

- Mensagens nativas do portal continuam espelhando para `CaseComment`.
- Mensagens vindas da ponte oposta continuam sem loop de espelhamento.
- Anexos externos continuam gravados em `AttachmentLink__c`.
- URLs de anexo continuam chegando ao Jira via texto do `CaseComment`.
- Mensagens privadas continuam visiveis apenas na experiencia interna.
- Cliente/portal continua vendo apenas mensagens publicas.
- Criacao de Case continua usando `Help_Desk_Salesforce`.
- Categorizacao do Help Desk continua gravando sistema/tipo/subtipo.
- Casos antigos com rich text continuam renderizando `Description_Rich__c`.

## O que nao foi feito nesta etapa

- Nao corrigi codigo.
- Nao executei testes Apex.
- Nao executei `npm test`.
- Nao executei deploy/validate.
- Nao iniciei servidor local.
- Nao adicionei dependencias.
- Nao fiz commit.

## Decisao funcional aprovada em 2026-06-05

A aprovacao do Help Desk passa a ter somente uma etapa, atribuida ao Gerente do
contato. A ausencia de Supervisor nao deve mais impedir o status `Pendente` nem
a submissao automatica ao processo de aprovacao.

Escopo aprovado:

- remover a etapa de Supervisor do Approval Process;
- exigir somente `Gerente__c` para submissao;
- definir `StatusAprovacao__c = Pendente` quando houver Gerente;
- remover Supervisor do painel e do layout de aprovacao;
- preservar os campos de Supervisor no modelo para historico e outros usos.

Restricao de plataforma identificada na validacao:

- Salesforce nao permite remover etapas de um Approval Process que ja foi
  ativado.
- O processo legado `AprovacaoHelpDesk` deve ser desativado sem alterar suas
  etapas.
- O processo novo `AprovacaoHelpDeskGerente` passa a ser o processo ativo e
  possui somente a etapa do Gerente.

## Implementacao do plano de refactor

Executado em 2026-06-05:

- corrigido o field `ContactId` do layout;
- criado o processo `AprovacaoHelpDeskGerente` e desativado o processo legado;
- submissao e status `Pendente` passam a depender somente de `Gerente__c`;
- Supervisor removido do painel e da secao de aprovacao do layout;
- sincronizacao de anexos renomeada para
  `syncMirroredCommentAttachments`, mantendo o metodo anterior como
  compatibilidade;
- adicionada validacao de mensagem/caso antes de vincular anexos;
- endpoints de mensagens privadas protegidos para usuarios internos;
- removida leitura de `CaseCommentId__c` do permission set Guest;
- helpers puros de anexos extraidos para `helpDeskAttachmentUtils`;
- removido `buildApexFilePayload`, que nao possuia consumidores;
- remocao do prefixo `Sistema:` passou a comparar o valor real do Case;
- criado `manifest/helpdesk-final-v3.xml`.

Decisao deliberada para preservar comportamento:

- uploads externos continuam sendo executados por arquivo e em transacoes
  separadas. Consolidar os uploads em um unico Apex introduziria callout depois
  de DML entre arquivos, alterando o limite/transacao atual.

Observacao de deploy:

- `Administrador.profile` nao faz parte do manifesto portatil porque o profile
  completo possui dependencias diferentes entre ambientes. Na UAT, ele
  referencia `Case.rsplus__Phone_Number__c`, campo inexistente na org.
- o assignment do layout `Case-Help Desk Salesforce Layout` ao record type deve
  ser aplicado por metadata de profile recuperada da org alvo ou manualmente no
  Setup.
