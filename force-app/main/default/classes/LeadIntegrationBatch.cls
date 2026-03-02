/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 10-16-2025
 * @last modified by	 : Daniel Belini
 **/
global class LeadIntegrationBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
  global Database.QueryLocator start(Database.BatchableContext BC) {
    // Query para selecionar os Leads desejados conforme filtros fornecidos
    String query =
      'SELECT Id, Status, Lab065_IntegracaoDistribuicaoLead__c, CreatedDate, LeadSource, RecordType.Name ' +
      'FROM Lead ' +
      'WHERE Lab065_IntegracaoDistribuicaoLead__c = false ' +
      'AND Status = \'Distribuído\' ' +
      'AND RecordType.Name = \'Qualificação de Clientes\' AND ConsultorRegional__r.IdVirtualOffice__c != null ' +
      ' ORDER BY CreatedDate DESC LIMIT 10 ';
    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext BC, List<SObject> scope) {
    List<LeadIntegrationService.LeadInput> inputs = new List<LeadIntegrationService.LeadInput>();
    for (SObject s : scope) {
      Lead l = (Lead) s;
      LeadIntegrationService.LeadInput input = new LeadIntegrationService.LeadInput();
      input.leadId = l.Id;
      inputs.add(input);
    }
    LeadIntegrationService.sendLeadsToExternalApp(inputs);
  }

  global void finish(Database.BatchableContext BC) {
    // Lógica opcional pós-processamento
  }
}
