global class RevoOpportunityErrorBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
  global Database.QueryLocator start(Database.BatchableContext BC) {
    String query = 'SELECT Id, ReferenceIdRevo__c FROM Opportunity WHERE ErroIntegracaoRevo__c = true';
    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
    for (Opportunity opp : scope) {
      try {
        // Chama a integração usando a classe RevoIntegrationService
        RevoIntegrationService.sendToCreditAnalysis(opp.Id);
      } catch (Exception e) {
        System.debug(
          'Erro ao integrar a oportunidade com a REVO: ' + e.getMessage()
        );
      }
    }
  }

  global void finish(Database.BatchableContext BC) {
    System.debug(
      'Processamento do Batch Apex de oportunidades com erro concluído.'
    );
  }

  global void execute(SchedulableContext sc) {
    Database.executeBatch(new RevoOpportunityErrorBatch());
  }
}
