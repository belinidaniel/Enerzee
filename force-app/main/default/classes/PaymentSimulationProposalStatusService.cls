/**
 * @description       : Monta os dados de simulação de pagamento enviados ao endpoint ProposalStatus
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : OpenAI Codex
 * @test              : ProposalServicePaymentSimulationTest
 **/
public without sharing class PaymentSimulationProposalStatusService {
  @TestVisible
  private static Boolean allowProposalStatusSyncInTest = false;

  private static Set<Id> enqueuedOpportunityIds = new Set<Id>();

  public static Map<Id, List<GORecordsTO.FinancingOptionTO>> getOptionsByOpportunityIds(
    Set<Id> opportunityIds
  ) {
    Map<Id, List<GORecordsTO.FinancingOptionTO>> optionsByOpportunityId = new Map<Id, List<GORecordsTO.FinancingOptionTO>>();
    Map<Id, Integer> optionIndexByOpportunityId = new Map<Id, Integer>();
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return optionsByOpportunityId;
    }

    for (
      PaymentSimulation__c simulationRecord : PaymentSimulationDAO.getByOpportunityIds(
        opportunityIds
      )
    ) {
      if (simulationRecord.Opportunity__c == null) {
        continue;
      }

      if (
        !optionsByOpportunityId.containsKey(simulationRecord.Opportunity__c)
      ) {
        optionsByOpportunityId.put(
          simulationRecord.Opportunity__c,
          new List<GORecordsTO.FinancingOptionTO>()
        );
      }

      Integer optionIndex = optionIndexByOpportunityId.containsKey(
          simulationRecord.Opportunity__c
        )
        ? optionIndexByOpportunityId.get(simulationRecord.Opportunity__c) + 1
        : 1;
      optionIndexByOpportunityId.put(
        simulationRecord.Opportunity__c,
        optionIndex
      );

      optionsByOpportunityId.get(simulationRecord.Opportunity__c)
        .add(
          new GORecordsTO.FinancingOptionTO(
            buildOptionName(optionIndex, simulationRecord),
            simulationRecord.Id,
            simulationRecord.Selected__c == true
          )
        );
    }

    return optionsByOpportunityId;
  }

  public static void enqueueOpportunityStatusSync(Set<Id> opportunityIds) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return;
    }
    if (Test.isRunningTest() && !allowProposalStatusSyncInTest) {
      return;
    }

    Set<Id> opportunityIdsToSync = new Set<Id>();
    for (Id opportunityId : opportunityIds) {
      if (
        opportunityId != null && !enqueuedOpportunityIds.contains(opportunityId)
      ) {
        opportunityIdsToSync.add(opportunityId);
      }
    }

    if (opportunityIdsToSync.isEmpty()) {
      return;
    }

    enqueuedOpportunityIds.addAll(opportunityIdsToSync);
    ProposalService.updateOpportunityPhase(opportunityIdsToSync);
  }

  @TestVisible
  private static String buildOptionName(
    Integer optionIndex,
    PaymentSimulation__c simulationRecord
  ) {
    String proposalLabel = simulationRecord == null ||
      String.isBlank(simulationRecord.ProposalLabel__c)
      ? 'Opcao'
      : simulationRecord.ProposalLabel__c.trim();
    Integer installmentCount = simulationRecord == null ||
      simulationRecord.InstallmentCount__c == null
      ? 0
      : Integer.valueOf(String.valueOf(simulationRecord.InstallmentCount__c));
    return proposalLabel + ' ' + installmentCount + ' Parcelas';
  }
}
