# Análise do incidente de geração de propostas

Data da análise: 5 de junho de 2026  
Ambiente consultado: Produção (`BRA34`, alias `enerzee-PRD`)  
Escopo principal: `OpportunityBO`, geração de PDF, envio ao aplicativo, atualização de produtos e `SendKitUpdate`

## Resumo executivo

Não há evidência de que o problema tenha sido causado por uma indisponibilidade geral do Salesforce.

Foram encontrados três problemas distintos no processo:

1. **Duas propostas não geraram PDF por falha na API externa de geração.**
   - Há logs de `HTTP 400` com a mensagem `Não foi possível baixar o template`.
   - Há três logs de `Read timed out`.
   - As falhas ocorreram nos mesmos intervalos das oportunidades `P-028250` e `P-028251`.
   - Os logs não possuem `RelatedId__c`, portanto a associação individual é uma inferência temporal, embora seja forte.

2. **A geração assíncrona não possui idempotência entre transações.**
   - O controle `queuedProposalOpps` impede duplicidade apenas dentro da mesma transação Apex.
   - Enquanto `PropostaGerada__c = false`, qualquer nova atualização elegível pode enfileirar outro job.
   - Jobs concorrentes podem consultar que ainda não existe PDF e gerar dois arquivos simultaneamente.
   - A oportunidade `P-028252` possui dois PDFs e dois envios bem-sucedidos ao aplicativo.

3. **A oportunidade `P-028255` concluiu o processo e depois foi revertida pela integração.**
   - PDF criado às `17:08:43 UTC`.
   - Estágio alterado de `Elaboração de proposta` para `Proposta Gerada` às `17:08:44 UTC`.
   - `UpdatePhase` retornou HTTP 200 às `17:08:47 UTC`.
   - Envio do PDF ao aplicativo retornou HTTP 200 às `17:08:48 UTC`.
   - O usuário `Integração` voltou o estágio para `Elaboração de proposta` às `17:09:54 UTC`.
   - Em seguida, o Salesforce enviou novamente ao aplicativo o estágio de elaboração, também com HTTP 200.

Portanto, o caso principal não é “PDF gerado sem avanço”. O avanço e o envio ocorreram, mas uma atualização posterior da integração sobrescreveu o estado correto.

## Processo implementado

O fluxo atual está distribuído entre várias classes:

1. O `OpportunityTriggerHandler.afterUpdate` chama `OpportunityBO.generateProposalAsync`.
2. `OpportunityBO.generateProposalAsync` avalia a elegibilidade e enfileira `PDFControllerExtension.SavePdfJob`.
3. `SavePdfJob` decide entre o fluxo Visualforce legado e `ProposalApiGenerationJob`.
4. `ProposalApiGenerationJob` chama a API externa, salva o PDF e atualiza:
   - `PropostaGerada__c = true`;
   - `StageName = Proposta Gerada` para o record type `Solar`.
5. A alteração do estágio dispara `ProposalService.updateOpportunityPhase`.
6. O PDF é enviado ao aplicativo por `IntegracaoNivelloProposta`.

Referências:

- `force-app/main/default/classes/OpportunityTriggerHandler.cls:231`
- `force-app/main/default/classes/OpportunityBO.cls:2134`
- `force-app/main/default/classes/PDFControllerExtension.cls:795`
- `force-app/main/default/classes/ProposalApiGenerationJob.cls:24`
- `force-app/main/default/classes/ProposalService.cls:10`
- `force-app/main/default/classes/IntegracaoNivelloProposta.cls:23`

## Situação das cinco propostas

| Proposta   | Situação encontrada em produção                            | Diagnóstico                                                               |
| ---------- | ---------------------------------------------------------- | ------------------------------------------------------------------------- |
| `P-028250` | Sem PDF, `PropostaGerada__c = false`, sem envio            | Falha externa inferida por horário: erro ao baixar template ou timeout    |
| `P-028251` | Sem PDF, `PropostaGerada__c = false`, sem envio            | Falha externa inferida por horário: timeout                               |
| `P-028252` | Dois PDFs, estágio `Proposta Gerada`, dois envios HTTP 200 | Jobs concorrentes; processo acabou concluído, mas duplicado               |
| `P-028254` | Um PDF, estágio `Proposta Gerada`, envio HTTP 200          | Processo concluído normalmente                                            |
| `P-028255` | Dois PDFs; atualmente voltou para elaboração               | Processo concluiu e foi revertido por atualização posterior da integração |

Os campos obrigatórios usados por `areRequiredFieldsFilled` estão preenchidos nas propostas `P-028250` e `P-028251`. Logo, a ausência de PDF não decorre de dados obrigatórios faltantes no estado atual.

## Evidências das falhas de geração

Entre `14:43` e `14:49 UTC`, foram registrados quatro erros em `ProposalApiGenerationJob`:

- `Falha ao gerar proposta na API. Status 400: {"detail":"Não foi possível baixar o template: "}`
- Três ocorrências de `System.CalloutException: Read timed out`

O job captura qualquer exceção:

```apex
try {
  // geração, avanço e integração
} catch (Exception e) {
  Utils.createLog('ProposalApiGenerationJob', 'execute', e);
}
```

Consequências:

- o `AsyncApexJob` termina com status `Completed`;
- `NumberOfErrors` permanece zero;
- não existe retry;
- a oportunidade permanece em elaboração;
- o log não recebe o ID da oportunidade, dificultando a rastreabilidade.

Referência: `force-app/main/default/classes/ProposalApiGenerationJob.cls:24`.

Isso explica por que a falha pode parecer um comportamento irregular do Salesforce mesmo quando o erro ocorreu no endpoint externo.

## Duplicidade dos produtos

A oportunidade `006U500000a8jUfIAI` possui 32 `OpportunityLineItem`.

Todos foram criados pelo usuário `Integração` entre `17:11:56` e `17:11:57 UTC`. O conjunto esperado possui oito itens. Foram registradas quatro chamadas `PUT /OpportunityEntry` nesse mesmo intervalo, resultando em quatro conjuntos concorrentes.

Exemplos:

- `710 Wp - ASTRONERGY BIFACIAL`: 4 registros;
- `SPW02-275-20`: 4 registros;
- `MC4 6 mm²`: 4 registros;
- cabos preto e vermelho: 4 registros de cada produto.

O endpoint executa o padrão:

```text
SELECT itens atuais
DELETE itens atuais
INSERT itens do payload
```

Referência: `force-app/main/default/classes/OpportunityEntryRest.cls:409`.

Não existe:

- `FOR UPDATE` na oportunidade;
- chave externa/idempotente no item;
- token de versão do kit;
- rejeição de payload repetido;
- serialização por oportunidade.

Com quatro requisições paralelas, todas podem consultar/deletar o mesmo estado inicial e depois inserir seus próprios oito itens. O resultado observado, 32 itens, é compatível exatamente com essa corrida.

## Excesso de `SendKitUpdate`

Após cada inserção ou alteração de `OpportunityLineItem`, o trigger chama:

```text
OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate
KitInstalacaoBO.SendKitUpdate
```

Referências:

- `force-app/main/default/classes/OpportunityLineItemTriggerHandler.cls:71`
- `force-app/main/default/classes/OpportunityLineItemTriggerHandler.cls:112`
- `force-app/main/default/classes/OpportunityLineItemBO.cls:10`
- `force-app/main/default/classes/KitInstalacaoBO.cls:313`

Cada transação de atualização de produtos dispara um novo `@future`. Não existe debounce ou consolidação persistente por oportunidade/kit.

Além disso, alterações em parâmetros da oportunidade também chamam `SendKitUpdate`:

- `ConsumoInformadoB__c`;
- `TipoTelhadoEstrutura__c`;
- `IsRSD__c`.

Referência: `force-app/main/default/classes/OpportunityBO.cls:3500`.

Isso cria um risco de realimentação:

1. aplicativo atualiza produtos no Salesforce;
2. trigger dos itens envia `updateInfosKit` ao aplicativo;
3. aplicativo recalcula e envia novas atualizações;
4. novas transações repetem produtos, cálculos e jobs.

Os históricos de `BDI`, `Rede`, `Pontos`, `Direct` e campos de valores anteriores alternando repetidamente no mesmo minuto são compatíveis com esse ciclo.

## Fragilidade da deduplicação de propostas

`ApprovalProcessService.enqueueProposalSavePdfJobIfAbsent` usa um `Set<Id>` estático:

```apex
private static Set<Id> queuedProposalOpps = new Set<Id>();
```

Referência: `force-app/main/default/classes/ApprovalProcessService.cls:20`.

Esse estado existe somente durante uma transação. Duas requisições, flows, futures ou queueables diferentes não compartilham o conjunto.

Também existe `PDFControllerExtension.processingOpps`, mas ele possui a mesma limitação transacional.

No fluxo API, a prevenção de arquivos duplicados segue o padrão:

```text
consultar PDF pelo hash
chamar API
inserir ContentVersion
```

Referências:

- `force-app/main/default/classes/ProposalGenerationService.cls:125`
- `force-app/main/default/classes/ProposalFileService.cls:24`

Dois jobs concorrentes podem consultar antes que qualquer um tenha inserido o arquivo. Ambos geram e salvam o PDF. Foi o que ocorreu em `P-028252`.

## Retorno indevido do estágio

Na `P-028255`, o histórico mostra:

| Horário UTC | Evento                                                            |
| ----------- | ----------------------------------------------------------------- |
| `17:08:43`  | PDF criado                                                        |
| `17:08:44`  | `Elaboração de proposta -> Proposta Gerada`                       |
| `17:08:47`  | `UpdatePhase`, status 2, HTTP 200                                 |
| `17:08:48`  | PDF enviado ao aplicativo, HTTP 200                               |
| `17:09:48`  | Novo `PUT /OpportunityEntry` com produtos                         |
| `17:09:54`  | usuário `Integração`: `Proposta Gerada -> Elaboração de proposta` |
| `17:09:56`  | `UpdatePhase`, status 1, HTTP 200                                 |

O código Salesforce não protege o estágio contra regressão após `PropostaGerada__c = true`. A proteção existente em `revertStageForNivelloAPIUser` trata somente:

```text
Elaboração de proposta -> Prospecção
```

Referência: `force-app/main/default/classes/OpportunityBO.cls:2086`.

Ela não cobre:

```text
Proposta Gerada -> Elaboração de proposta
```

Assim, uma atualização do aplicativo pode desfazer o resultado do processo concluído e o Salesforce ainda confirma essa regressão de volta ao aplicativo por `UpdatePhase`.

## Avaliação sobre incidente Salesforce

Não foram encontrados sinais de falha geral da plataforma:

- DML de oportunidades, produtos, arquivos e histórico ocorreu normalmente.
- Jobs Apex foram executados.
- `ProposalService` e `IntegracaoNivelloProposta` tiveram respostas HTTP 200 nos casos concluídos.
- As falhas registradas ocorreram dentro do callout para a API externa de geração.
- A instância identificada é `BRA34`; a página oficial é [Salesforce Trust - BRA34](https://status.salesforce.com/instances/BRA34).

O fato de os jobs aparecerem como `Completed` não prova sucesso funcional, porque o código captura as exceções e não as relança.

Conclusão: **o incidente é explicado pelo desenho assíncrono, concorrência sem idempotência e atualizações posteriores da integração. Não há evidência de que o Salesforce tenha duplicado registros por conta própria.**

## Recomendações técnicas

Nenhuma alteração de código ou metadata Salesforce foi realizada nesta análise.

Prioridade crítica:

1. Tornar `PUT /OpportunityEntry` idempotente e serializado por oportunidade.
2. Impedir regressão de `Proposta Gerada` para `Elaboração de proposta` quando a proposta já foi concluída, salvo readequação explícita.
3. Persistir o estado de geração (`Pending`, `Processing`, `Succeeded`, `Failed`) em vez de usar apenas variáveis estáticas.
4. Adicionar `OpportunityId` aos logs de `ProposalApiGenerationJob`.
5. Implementar retry controlado para timeout e erro transitório da API externa.

Prioridade alta:

1. Consolidar `SendKitUpdate` por oportunidade/kit.
2. Adicionar correlation ID entre `PUT /OpportunityEntry`, `SendKitUpdate`, geração e `UpdatePhase`.
3. Criar restrição lógica contra múltiplos PDFs com o mesmo `OpportunityId + payloadHash`.
4. Não considerar o job funcionalmente concluído quando a geração falhar.
5. Monitorar oportunidades em elaboração com todos os campos preenchidos e sem PDF após um tempo limite.

## Conclusão

Os cinco casos não possuem uma única causa:

- dois falharam no callout externo de geração;
- um apresentou geração/envio duplicados por concorrência;
- um concluiu normalmente;
- um concluiu, foi enviado e depois teve o estágio e os produtos sobrescritos por chamadas posteriores da integração.

A duplicidade dos produtos é originada por múltiplas requisições concorrentes ao endpoint Salesforce, combinadas com o padrão não idempotente de apagar e reinserir itens. O Salesforce persistiu corretamente as quatro transações que recebeu.
