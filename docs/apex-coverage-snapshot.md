# Apex Coverage Snapshot

## Execução mais recente (RunLocalTests)

- Data: 2026-02-27
- Org alvo: `jean.carlos@enerzee.com.br.qa` (`enrz--qa.sandbox.my.salesforce.com`)
- Deploy validation id: `0AfHZ00000MnE8P0AV`
- Resultado: `Failed` (ainda há falhas de testes e cobertura < 75%)
- Testes: `477` totais | `447` pass | `30` fail
- Cobertura global calculada: `72.47%` (`19694/27174`)
- Linhas faltantes para `85%`: `3404`

## Evolução desta sessão

- Baseline inicial: `67.24%` (`18273/27174`) no deploy `0AfHZ00000Mn3wC0AR`
- Após bloco anterior: `68.86%` (`18712/27174`) no deploy `0AfHZ00000Mn7wX0AR`
- Atual (após estabilização do bloco de falhas): `72.47%` (`19694/27174`) no deploy `0AfHZ00000MnE8P0AV`
- Ganho total nesta sessão: `+5.23 p.p.` e `+1421` linhas cobertas

## Bloco executado agora (estabilização de testes críticos)

Classes tratadas:

- `IntegracaoSAPTest`
- `InstalacaoBOTest`
- `ProjetoBOTest`
- `TaskTriggerTest`
- `ClickSignVisibilityRulesEngineTest`

Validação do bloco:

- Deploy id `0AfHZ00000MnE6n0AF`
- Resultado: `36/36` testes passados

## Top classes por linhas não cobertas (maior -> menor)

1. `MetadataService`: 773
2. `TaskSlaDailySummaryService`: 487
3. `OpportunityBO`: 359
4. `ProjetoBO`: 302
5. `WorkDeliveryReportService`: 296
6. `TaskBO`: 241
7. `ClickSignTemplateController`: 183
8. `ViabilityStudyBO`: 182
9. `OpportunityCommentNotificationService`: 170
10. `MessagingSessionSLABatch`: 154
11. `PDFControllerExtension`: 147
12. `InstalacaoTaskBO`: 144
13. `ProposalConsoleController`: 137
14. `ClickSignVisibilityRulesEngine`: 117
15. `ActivityDocumentController`: 113

## Testes ainda falhando no RunLocalTests (top)

1. `ProductTriggerTest` (3)
2. `TaskTemplateFlowTest` (3)
3. `WorkDeliveryReportServiceTest` (3)
4. `KitInstalacaoTriggerTest` (2)
5. `ModuloHelpDeskCaseControllerTest` (2)
6. `OpportunityBOPaymentReminderTaskTest` (2)
7. `OpportunityLineItemTriggerTest` (2)
8. `ProjetoTriggerTest` (2)
9. `ProposalConsoleControllerTest` (2)
10. `TaskCompletionServiceTest` (2)

## Próximo bloco recomendado

1. Estabilizar os 10 testes acima (reduz risco de regressão e destrava RunLocalTests com menos ruído).
2. Em paralelo, ampliar cobertura em `TaskSlaDailySummaryService`, `ProjetoBO` e `TaskBO` (maior impacto por volume de linhas descobertas).
