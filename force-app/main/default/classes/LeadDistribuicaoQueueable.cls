/**
 * @description       : Enfileira a integração de distribuição de lead com o app externo. Substitui o LeadIntegrationBatch para cenários de troca de consultor e redistribuição manual — processa um lead por vez para isolamento de falhas e rastreabilidade individual.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-08-2026
 * @last modified by  : Daniel Belini
 * @test              : LeadDistribuicaoQueueableTest
 **/
public with sharing class LeadDistribuicaoQueueable implements Queueable, Database.AllowsCallouts {
  private Set<Id> leadIds;

  public LeadDistribuicaoQueueable(Set<Id> leadIds) {
    this.leadIds = leadIds;
  }

  public void execute(QueueableContext ctx) {
    for (Id leadId : leadIds) {
      // integrateLead é autossuficiente: faz callout, DML e popula
      // Lab065_IntegracaoDistribuicaoLead__c, IntegracaoDistribuicaoLeadDataHora__c
      // e IntegracaoDistribuicaoLeadErro__c independente do resultado
      LeadIntegrationService.integrateLead(leadId);
    }
  }
}
