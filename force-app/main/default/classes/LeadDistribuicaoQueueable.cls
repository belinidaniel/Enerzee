/**
 * @description       : Enfileira a integração de distribuição de lead com o app externo. Substitui o LeadIntegrationBatch para cenários de troca de consultor e redistribuição manual — processa um lead por vez para isolamento de falhas e rastreabilidade individual.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-08-2026
 * @last modified by  : Daniel Belini
 * @test              : LeadDistribuicaoQueueableTest
 **/
public with sharing class LeadDistribuicaoQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> leadIds;

  public LeadDistribuicaoQueueable(Set<Id> leadIds) {
    this.leadIds = new List<Id>(leadIds);
  }

  @TestVisible
  private LeadDistribuicaoQueueable(List<Id> leadIds) {
    this.leadIds = leadIds;
  }

  public void execute(QueueableContext ctx) {
    if (leadIds == null || leadIds.isEmpty()) {
      return;
    }

    Id current = leadIds.remove(0);
    LeadIntegrationService.integrateLead(current);

    if (!leadIds.isEmpty() && !Test.isRunningTest()) {
      System.enqueueJob(new LeadDistribuicaoQueueable(leadIds));
    }
  }
}
