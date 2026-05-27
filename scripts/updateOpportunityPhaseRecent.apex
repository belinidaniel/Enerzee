// Processa oportunidades dos últimos 3 dias que ainda não foram sincronizadas com sucesso.
// Pega 50 por vez, do mais antigo para o mais recente, e chama updateOpportunityPhase por lote.
// Rodar no Developer Console: Debug → Open Execute Anonymous Window

final Integer BATCH_SIZE = 50;
final Date cutoff = Date.today().addDays(-3);

List<Opportunity> batch = [
    SELECT Id, StageName, LastModifiedDate
    FROM Opportunity
    WHERE LastModifiedDate >= :cutoff
        AND (SucessoIntegracaoNivello__c = FALSE OR SucessoIntegracaoNivello__c = NULL)
        AND IsDeleted = FALSE
    ORDER BY LastModifiedDate ASC
    LIMIT :BATCH_SIZE
];

System.debug('Pending opportunities found: ' + batch.size());
for (Opportunity opp : batch) {
    System.debug('  ' + opp.Id + ' | ' + opp.StageName + ' | ' + opp.LastModifiedDate);
}

if (batch.isEmpty()) {
    System.debug('No pending opportunities. Done.');
    return;
}

Set<Id> batchIds = new Map<Id, Opportunity>(batch).keySet();
System.debug('Dispatching updateOpportunityPhase for ' + batchIds.size() + ' opportunities...');
ProposalService.updateOpportunityPhase(batchIds);
System.debug('Batch dispatched. Run again to process the next 50.');
