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
    Map<String, Integer> optionIndexByTypeKey = new Map<String, Integer>();
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

      String optionTypeKey = buildOptionTypeKey(
        simulationRecord.Opportunity__c,
        simulationRecord.PaymentType__c
      );
      Integer optionIndex = optionIndexByTypeKey.containsKey(optionTypeKey)
        ? optionIndexByTypeKey.get(optionTypeKey) + 1
        : 1;
      optionIndexByTypeKey.put(optionTypeKey, optionIndex);

      optionsByOpportunityId.get(simulationRecord.Opportunity__c)
        .add(
          new GORecordsTO.FinancingOptionTO(
            buildOptionName(optionIndex, simulationRecord),
            String.valueOf(simulationRecord.Id),
            resolveOptionType(simulationRecord),
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
    Integer normalizedOptionIndex = optionIndex == null ||
      optionIndex <= 0
      ? 1
      : optionIndex;
    Integer installmentCount = simulationRecord == null ||
      simulationRecord.InstallmentCount__c == null
      ? 0
      : Integer.valueOf(String.valueOf(simulationRecord.InstallmentCount__c));
    Decimal installmentAmount = simulationRecord == null
      ? null
      : simulationRecord.InstallmentAmount__c;

    return 'Opção ' +
      normalizedOptionIndex +
      ' - ' +
      installmentCount +
      ' Parcelas de ' +
      formatCurrencyBr(installmentAmount);
  }

  @TestVisible
  private static Integer resolveOptionType(
    PaymentSimulation__c simulationRecord
  ) {
    if (
      simulationRecord == null ||
      String.isBlank(simulationRecord.PaymentType__c)
    ) {
      return null;
    }

    if ('Financing'.equalsIgnoreCase(simulationRecord.PaymentType__c)) {
      return 1;
    }
    if ('Rental'.equalsIgnoreCase(simulationRecord.PaymentType__c)) {
      return 2;
    }

    return null;
  }

  private static String buildOptionTypeKey(
    Id opportunityId,
    String paymentType
  ) {
    return String.valueOf(opportunityId) + '|' + String.valueOf(paymentType);
  }

  @TestVisible
  private static String formatCurrencyBr(Decimal value) {
    if (value == null) {
      return 'R$ 0,00';
    }

    String str = String.valueOf(value.setScale(2, RoundingMode.HALF_UP));
    List<String> parts = str.split('\\.');
    String intPart = parts[0];
    String decPart = parts.size() > 1 ? parts[1] : '00';

    String formattedInt = '';
    Integer count = 0;
    for (Integer i = intPart.length() - 1; i >= 0; i--) {
      formattedInt = intPart.substring(i, i + 1) + formattedInt;
      count++;
      if (count == 3 && i != 0) {
        formattedInt = '.' + formattedInt;
        count = 0;
      }
    }

    return 'R$ ' + formattedInt + ',' + decPart;
  }
}
