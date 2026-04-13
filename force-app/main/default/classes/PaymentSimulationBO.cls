/**
 * @description       : Orquestra a geração, recalculo e sincronização das simulações de pagamento do Solar Grupo B
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : OpportunityTriggerTest, PaymentSimulationBOTest, ProposalServicePaymentSimulationTest
 **/
public without sharing class PaymentSimulationBO {
  @TestVisible
  private static final String SOLAR_RECORD_TYPE_DEVELOPER_NAME = 'Solar';
  @TestVisible
  private static final String GROUP_B_VALUE = 'Grupo B';
  @TestVisible
  private static final String PAYMENT_TYPE_RENTAL = 'Rental';
  @TestVisible
  private static final Decimal PF_RENTAL_LIMIT = 70000;
  @TestVisible
  private static final Decimal PJ_RENTAL_LIMIT = 250000;
  @TestVisible
  private static final String HYBRID_KIT_VALUE = 'KIT SOLAR + BESS';
  @TestVisible
  private static final Integer MAX_INSTALLMENT_OPTIONS = 4;

  private static Id solarRecordTypeId;

  public static void createSimulationsForOpportunities(
    List<Opportunity> newList
  ) {
    syncSimulationsForOpportunities(newList);
  }

  public static void recalculateOnAmountChange(
    List<Opportunity> newList,
    Map<Id, Opportunity> oldMap
  ) {
    if (newList == null || newList.isEmpty()) {
      return;
    }

    // On update we intentionally resync every eligible opportunity so a plain
    // edit/save can backfill missing simulations or normalize legacy rows.
    syncSimulationsForOpportunities(newList);
  }

  public static void normalizeSelectionDetails(
    List<PaymentSimulation__c> newList,
    Map<Id, PaymentSimulation__c> oldMap
  ) {
  }

  public static void enforceSelectedToggle(
    List<PaymentSimulation__c> newList,
    Map<Id, PaymentSimulation__c> oldMap
  ) {
    Map<Id, PaymentSimulation__c> selectedByOpportunityId = new Map<Id, PaymentSimulation__c>();
    Map<Id, PaymentSimulation__c> triggerRecordsById = new Map<Id, PaymentSimulation__c>();

    for (PaymentSimulation__c simulationRecord : newList) {
      if (simulationRecord.Id != null) {
        triggerRecordsById.put(simulationRecord.Id, simulationRecord);
      }

      PaymentSimulation__c previousSimulation = oldMap == null
        ? null
        : oldMap.get(simulationRecord.Id);
      if (
        simulationRecord.Opportunity__c == null ||
        !becameSelected(simulationRecord, previousSimulation)
      ) {
        continue;
      }

      if (
        selectedByOpportunityId.containsKey(simulationRecord.Opportunity__c)
      ) {
        selectedByOpportunityId.get(simulationRecord.Opportunity__c)
          .Selected__c = false;
      }
      selectedByOpportunityId.put(
        simulationRecord.Opportunity__c,
        simulationRecord
      );
    }

    if (selectedByOpportunityId.isEmpty()) {
      return;
    }

    List<PaymentSimulation__c> siblingUpdates = new List<PaymentSimulation__c>();
    for (
      PaymentSimulation__c siblingSimulation : PaymentSimulationDAO.getByOpportunityIds(
        selectedByOpportunityId.keySet()
      )
    ) {
      PaymentSimulation__c selectedSimulation = selectedByOpportunityId.get(
        siblingSimulation.Opportunity__c
      );
      if (
        selectedSimulation == null ||
        siblingSimulation.Id == selectedSimulation.Id ||
        siblingSimulation.Selected__c == false
      ) {
        continue;
      }

      if (triggerRecordsById.containsKey(siblingSimulation.Id)) {
        triggerRecordsById.get(siblingSimulation.Id).Selected__c = false;
        continue;
      }

      siblingUpdates.add(
        new PaymentSimulation__c(Id = siblingSimulation.Id, Selected__c = false)
      );
    }

    if (siblingUpdates.isEmpty()) {
      return;
    }

    PaymentSimulationTriggerHandler.isRunning = true;
    try {
      update siblingUpdates;
    } finally {
      PaymentSimulationTriggerHandler.isRunning = false;
    }
  }

  public static void syncSelectedToOpportunity(
    List<PaymentSimulation__c> simulationList,
    Map<Id, PaymentSimulation__c> oldMap
  ) {
    syncSelectedToOpportunity(simulationList, oldMap, false);
  }

  public static void syncSelectedToOpportunity(
    List<PaymentSimulation__c> simulationList,
    Map<Id, PaymentSimulation__c> oldMap,
    Boolean notifyExternal
  ) {
    Set<Id> affectedOpportunityIds = new Set<Id>();

    for (PaymentSimulation__c simulationRecord : simulationList) {
      if (simulationRecord.Opportunity__c == null) {
        continue;
      }

      // On insert (oldMap == null), always sync so the Opportunity reflects the
      // initial simulation state — avoids a redundant DML from the caller.
      if (oldMap == null) {
        affectedOpportunityIds.add(simulationRecord.Opportunity__c);
        continue;
      }

      PaymentSimulation__c previousSimulation = oldMap.get(simulationRecord.Id);
      if (
        didSelectionChange(simulationRecord, previousSimulation) ||
        didSelectedSimulationDetailsChange(simulationRecord, previousSimulation)
      ) {
        affectedOpportunityIds.add(simulationRecord.Opportunity__c);
      }
    }

    if (affectedOpportunityIds.isEmpty()) {
      return;
    }

    syncSelectedSimulationDetailsToOpportunity(affectedOpportunityIds);

    // Only notify external systems when explicitly requested (update/delete).
    // On insert, the Opportunity status was already sent when the Opportunity
    // itself was created — re-sending triggers an unwanted Nivello callback
    // that resets the Stage.
    if (notifyExternal) {
      PaymentSimulationProposalStatusService.enqueueOpportunityStatusSync(
        affectedOpportunityIds
      );
    }
  }

  private static void syncSimulationsForOpportunities(
    List<Opportunity> opportunities
  ) {
    List<Opportunity> eligibleOpportunities = filterEligibleOpportunities(
      opportunities
    );
    if (eligibleOpportunities.isEmpty()) {
      return;
    }

    Set<Id> opportunityIds = collectIdsFromOpportunities(eligibleOpportunities);
    Map<Id, List<PaymentSimulation__c>> simulationsByOpportunityId = groupSimulationsByOpportunityId(
      PaymentSimulationDAO.getByOpportunityIds(opportunityIds)
    );
    Map<Id, Account> accountsById = PaymentSimulationDAO.getAccountsByIds(
      collectAccountIds(eligibleOpportunities)
    );
    List<FinancingRate__c> activeFinancingRates = PaymentSimulationDAO.getActiveFinancingRates();

    SimulationSyncPlan syncPlan = buildSyncPlan(
      eligibleOpportunities,
      simulationsByOpportunityId,
      accountsById,
      activeFinancingRates
    );
    if (syncPlan.isEmpty()) {
      return;
    }

    if (!syncPlan.simulationsToDelete.isEmpty()) {
      delete syncPlan.simulationsToDelete;
    }
    if (!syncPlan.simulationsToInsert.isEmpty()) {
      insert syncPlan.simulationsToInsert;
    }
    if (!syncPlan.simulationsToUpdate.isEmpty()) {
      update syncPlan.simulationsToUpdate;
    }

    // Opportunity sync is handled by PaymentSimulationTrigger afterInsert/afterUpdate/afterDelete.
  }

  private static SimulationSyncPlan buildSyncPlan(
    List<Opportunity> eligibleOpportunities,
    Map<Id, List<PaymentSimulation__c>> simulationsByOpportunityId,
    Map<Id, Account> accountsById,
    List<FinancingRate__c> activeFinancingRates
  ) {
    SimulationSyncPlan syncPlan = new SimulationSyncPlan();

    for (Opportunity opportunityRecord : eligibleOpportunities) {
      List<PaymentSimulation__c> existingSimulations = simulationsByOpportunityId.containsKey(
          opportunityRecord.Id
        )
        ? simulationsByOpportunityId.get(opportunityRecord.Id)
        : new List<PaymentSimulation__c>();

      Decimal simulationAmount = getSimulationAmount(opportunityRecord);
      if (simulationAmount == null || activeFinancingRates.isEmpty()) {
        markForDeletion(existingSimulations, syncPlan);
        continue;
      }

      Account relatedAccount = accountsById.get(opportunityRecord.AccountId);
      String cnpj = relatedAccount == null ? null : relatedAccount.CNPJ__c;
      List<PaymentSimulation__c> desiredSimulations = buildDesiredSimulations(
        opportunityRecord,
        simulationAmount,
        activeFinancingRates,
        cnpj,
        existingSimulations
      );

      Map<String, List<PaymentSimulation__c>> existingByKey = groupSimulationsByKey(
        existingSimulations
      );
      for (PaymentSimulation__c desiredSimulation : desiredSimulations) {
        String simulationKey = buildSimulationKey(desiredSimulation);
        PaymentSimulation__c existingMatch = takeFirstSimulationForKey(
          existingByKey,
          simulationKey
        );

        if (existingMatch == null) {
          syncPlan.simulationsToInsert.add(desiredSimulation);
          syncPlan.affectedOpportunityIds.add(opportunityRecord.Id);
          continue;
        }

        PaymentSimulation__c updateSimulation = buildSimulationUpdate(
          existingMatch,
          desiredSimulation
        );
        if (updateSimulation != null) {
          syncPlan.simulationsToUpdate.add(updateSimulation);
          syncPlan.affectedOpportunityIds.add(opportunityRecord.Id);
        }
      }

      for (
        List<PaymentSimulation__c> orphanedSimulations : existingByKey.values()
      ) {
        for (PaymentSimulation__c orphanedSimulation : orphanedSimulations) {
          syncPlan.simulationsToDelete.add(orphanedSimulation);
          syncPlan.affectedOpportunityIds.add(opportunityRecord.Id);
        }
      }
    }

    return syncPlan;
  }

  private static List<PaymentSimulation__c> buildDesiredSimulations(
    Opportunity opportunityRecord,
    Decimal simulationAmount,
    List<FinancingRate__c> activeFinancingRates,
    String cnpj,
    List<PaymentSimulation__c> existingSimulations
  ) {
    List<PaymentSimulation__c> desiredSimulations = new List<PaymentSimulation__c>();
    Set<String> selectedSimulationKeys = collectSelectedSimulationKeys(
      existingSimulations
    );

    for (FinancingRate__c financingRate : activeFinancingRates) {
      if (String.isBlank(financingRate.PaymentType__c)) {
        continue;
      }
      if (
        isRentalPaymentType(financingRate.PaymentType__c) &&
        !isRentalEligible(
          simulationAmount,
          cnpj,
          opportunityRecord.TipoKitPromocional__c
        )
      ) {
        continue;
      }

      for (
        Integer optionIndex = 1;
        optionIndex <= MAX_INSTALLMENT_OPTIONS;
        optionIndex++
      ) {
        Integer installmentCount = getInstallmentCount(
          financingRate,
          optionIndex
        );
        Decimal interestRate = getInstallmentRate(financingRate, optionIndex);
        if (
          installmentCount == null ||
          installmentCount <= 0 ||
          interestRate == null
        ) {
          continue;
        }

        Decimal installmentAmount = calculatePMT(
          simulationAmount,
          interestRate,
          installmentCount
        );
        if (installmentAmount == null) {
          continue;
        }

        String simulationKey = buildSimulationKey(
          financingRate.Id,
          installmentCount,
          interestRate
        );
        desiredSimulations.add(
          new PaymentSimulation__c(
            Opportunity__c = opportunityRecord.Id,
            FinancingRate__c = financingRate.Id,
            PaymentType__c = financingRate.PaymentType__c,
            ProposalLabel__c = resolveProposalLabel(financingRate),
            InstallmentCount__c = installmentCount,
            InterestRate__c = interestRate,
            InstallmentAmount__c = installmentAmount,
            Selected__c = selectedSimulationKeys.contains(simulationKey)
          )
        );
      }
    }

    return desiredSimulations;
  }

  private static void markForDeletion(
    List<PaymentSimulation__c> simulations,
    SimulationSyncPlan syncPlan
  ) {
    for (PaymentSimulation__c simulationRecord : simulations) {
      syncPlan.simulationsToDelete.add(simulationRecord);
      if (simulationRecord.Opportunity__c != null) {
        syncPlan.affectedOpportunityIds.add(simulationRecord.Opportunity__c);
      }
    }
  }

  @TestVisible
  private static Decimal calculatePMT(
    Decimal principalValue,
    Decimal interestRate,
    Integer installments
  ) {
    if (principalValue == null || installments == null || installments <= 0) {
      return null;
    }

    Decimal normalizedInterestRate = normalizeInterestRateForPmt(interestRate);
    if (normalizedInterestRate == null || normalizedInterestRate == 0) {
      return (principalValue / installments).setScale(2, RoundingMode.HALF_UP);
    }

    Double principalAsDouble = Double.valueOf(String.valueOf(principalValue));
    Double rateAsDouble = Double.valueOf(
      String.valueOf(normalizedInterestRate)
    );
    Double factor = Math.pow(1 + rateAsDouble, installments);
    Double denominator = 1 - (1 / factor);
    if (denominator == 0) {
      return null;
    }

    Double paymentAmount = (principalAsDouble * rateAsDouble) / denominator;
    return Decimal.valueOf(String.valueOf(paymentAmount))
      .setScale(2, RoundingMode.HALF_UP);
  }

  @TestVisible
  private static Decimal normalizeInterestRateForPmt(Decimal interestRate) {
    if (interestRate == null) {
      return null;
    }

    Decimal absInterestRate = interestRate.abs();
    return absInterestRate >= 0.1
      ? (interestRate / 100).setScale(6, RoundingMode.HALF_UP)
      : interestRate;
  }

  @TestVisible
  private static Boolean isRentalEligible(
    Decimal amount,
    String cnpj,
    String tipoKitPromocional
  ) {
    if (amount == null) {
      return false;
    }

    if (HYBRID_KIT_VALUE.equalsIgnoreCase(tipoKitPromocional)) {
      return false;
    }

    return String.isBlank(cnpj)
      ? amount <= PF_RENTAL_LIMIT
      : amount <= PJ_RENTAL_LIMIT;
  }

  private static void syncSelectedSimulationDetailsToOpportunity(
    Set<Id> affectedOpportunityIds
  ) {
    if (affectedOpportunityIds == null || affectedOpportunityIds.isEmpty()) {
      return;
    }

    Map<Id, PaymentSimulation__c> selectedSimulationByOpportunityId = new Map<Id, PaymentSimulation__c>();
    Map<String, Integer> optionIndexByTypeKey = new Map<String, Integer>();
    Map<Id, String> optionNameBySimulationId = new Map<Id, String>();

    for (
      PaymentSimulation__c simulationRecord : PaymentSimulationDAO.getByOpportunityIds(
        affectedOpportunityIds
      )
    ) {
      String optionTypeKey = buildOptionTypeKey(
        simulationRecord.Opportunity__c,
        simulationRecord.PaymentType__c
      );
      Integer optionIndex = optionIndexByTypeKey.containsKey(optionTypeKey)
        ? optionIndexByTypeKey.get(optionTypeKey) + 1
        : 1;
      optionIndexByTypeKey.put(optionTypeKey, optionIndex);
      optionNameBySimulationId.put(
        simulationRecord.Id,
        buildOptionName(
          optionIndex,
          simulationRecord.InstallmentCount__c,
          simulationRecord.InstallmentAmount__c
        )
      );

      if (
        simulationRecord.Selected__c &&
        !selectedSimulationByOpportunityId.containsKey(
          simulationRecord.Opportunity__c
        )
      ) {
        selectedSimulationByOpportunityId.put(
          simulationRecord.Opportunity__c,
          simulationRecord
        );
      }
    }

    Map<Id, Opportunity> currentOpportunitiesById = PaymentSimulationDAO.getOpportunitiesByIds(
      affectedOpportunityIds
    );
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    for (Id opportunityId : affectedOpportunityIds) {
      Opportunity currentOpportunity = currentOpportunitiesById.get(
        opportunityId
      );
      if (currentOpportunity == null) {
        continue;
      }

      PaymentSimulation__c selectedSimulation = selectedSimulationByOpportunityId.get(
        opportunityId
      );
      String serializedPaymentDetails = selectedSimulation == null
        ? null
        : serializeSelectedSimulation(
            selectedSimulation,
            optionNameBySimulationId.get(selectedSimulation.Id)
          );
      if (
        currentOpportunity.FinancingProcessDetails__c ==
        serializedPaymentDetails
      ) {
        continue;
      }

      opportunitiesToUpdate.add(
        new Opportunity(
          Id = opportunityId,
          FinancingProcessDetails__c = serializedPaymentDetails
        )
      );
    }

    updateOpportunitiesWithoutTrigger(opportunitiesToUpdate);
  }

  private static List<Opportunity> filterEligibleOpportunities(
    List<Opportunity> opportunities
  ) {
    List<Opportunity> eligibleOpportunities = new List<Opportunity>();
    Id targetRecordTypeId = getSolarRecordTypeId();
    if (targetRecordTypeId == null) {
      return eligibleOpportunities;
    }

    for (Opportunity opportunityRecord : opportunities) {
      if (
        opportunityRecord == null ||
        opportunityRecord.Id == null ||
        opportunityRecord.RecordTypeId != targetRecordTypeId ||
        opportunityRecord.GrupoTarifario__c != GROUP_B_VALUE
      ) {
        continue;
      }
      eligibleOpportunities.add(opportunityRecord);
    }

    return eligibleOpportunities;
  }

  private static Set<Id> collectAccountIds(List<Opportunity> opportunities) {
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opportunityRecord : opportunities) {
      if (opportunityRecord.AccountId != null) {
        accountIds.add(opportunityRecord.AccountId);
      }
    }
    return accountIds;
  }

  private static Set<Id> collectIdsFromOpportunities(
    List<Opportunity> opportunities
  ) {
    Set<Id> opportunityIds = new Set<Id>();
    for (Opportunity opportunityRecord : opportunities) {
      if (opportunityRecord != null && opportunityRecord.Id != null) {
        opportunityIds.add(opportunityRecord.Id);
      }
    }
    return opportunityIds;
  }

  private static Map<Id, List<PaymentSimulation__c>> groupSimulationsByOpportunityId(
    List<PaymentSimulation__c> simulations
  ) {
    Map<Id, List<PaymentSimulation__c>> simulationsByOpportunityId = new Map<Id, List<PaymentSimulation__c>>();
    for (PaymentSimulation__c simulationRecord : simulations) {
      if (simulationRecord.Opportunity__c == null) {
        continue;
      }

      if (
        !simulationsByOpportunityId.containsKey(simulationRecord.Opportunity__c)
      ) {
        simulationsByOpportunityId.put(
          simulationRecord.Opportunity__c,
          new List<PaymentSimulation__c>()
        );
      }
      simulationsByOpportunityId.get(simulationRecord.Opportunity__c)
        .add(simulationRecord);
    }
    return simulationsByOpportunityId;
  }

  private static Map<String, List<PaymentSimulation__c>> groupSimulationsByKey(
    List<PaymentSimulation__c> simulations
  ) {
    Map<String, List<PaymentSimulation__c>> simulationsByKey = new Map<String, List<PaymentSimulation__c>>();
    for (PaymentSimulation__c simulationRecord : simulations) {
      String simulationKey = buildSimulationKey(simulationRecord);
      if (simulationKey == null) {
        simulationKey = 'ID:' + simulationRecord.Id;
      }

      if (!simulationsByKey.containsKey(simulationKey)) {
        simulationsByKey.put(simulationKey, new List<PaymentSimulation__c>());
      }
      simulationsByKey.get(simulationKey).add(simulationRecord);
    }
    return simulationsByKey;
  }

  private static PaymentSimulation__c takeFirstSimulationForKey(
    Map<String, List<PaymentSimulation__c>> simulationsByKey,
    String simulationKey
  ) {
    if (
      String.isBlank(simulationKey) ||
      simulationsByKey == null ||
      !simulationsByKey.containsKey(simulationKey) ||
      simulationsByKey.get(simulationKey).isEmpty()
    ) {
      return null;
    }

    PaymentSimulation__c simulationRecord = simulationsByKey.get(simulationKey)
      .remove(0);
    if (simulationsByKey.get(simulationKey).isEmpty()) {
      simulationsByKey.remove(simulationKey);
    }
    return simulationRecord;
  }

  private static Set<String> collectSelectedSimulationKeys(
    List<PaymentSimulation__c> simulations
  ) {
    Set<String> selectedSimulationKeys = new Set<String>();
    for (PaymentSimulation__c simulationRecord : simulations) {
      if (
        simulationRecord.Selected__c != true ||
        !selectedSimulationKeys.isEmpty()
      ) {
        continue;
      }

      String simulationKey = buildSimulationKey(simulationRecord);
      if (simulationKey != null) {
        selectedSimulationKeys.add(simulationKey);
      }
    }
    return selectedSimulationKeys;
  }

  private static PaymentSimulation__c buildSimulationUpdate(
    PaymentSimulation__c existingSimulation,
    PaymentSimulation__c desiredSimulation
  ) {
    if (existingSimulation == null || desiredSimulation == null) {
      return null;
    }

    List<String> synchronizedFields = new List<String>{
      'Opportunity__c',
      'FinancingRate__c',
      'PaymentType__c',
      'ProposalLabel__c',
      'Selected__c',
      'InstallmentCount__c',
      'InterestRate__c',
      'InstallmentAmount__c'
    };

    Boolean hasChanges = false;
    PaymentSimulation__c updateSimulation = new PaymentSimulation__c(
      Id = existingSimulation.Id
    );
    for (String fieldName : synchronizedFields) {
      Object desiredValue = desiredSimulation.get(fieldName);
      if (areSameValue(existingSimulation.get(fieldName), desiredValue)) {
        continue;
      }

      updateSimulation.put(fieldName, desiredValue);
      hasChanges = true;
    }

    return hasChanges ? updateSimulation : null;
  }

  private static Boolean areSameValue(
    Object currentValue,
    Object desiredValue
  ) {
    return currentValue == desiredValue ||
      String.valueOf(currentValue) == String.valueOf(desiredValue);
  }

  private static Boolean didSimulationInputsChange(
    Opportunity currentOpportunity,
    Opportunity previousOpportunity
  ) {
    if (previousOpportunity == null) {
      return true;
    }

    return getSimulationAmount(currentOpportunity) !=
      getSimulationAmount(previousOpportunity) ||
      currentOpportunity.GrupoTarifario__c !=
      previousOpportunity.GrupoTarifario__c ||
      currentOpportunity.AccountId != previousOpportunity.AccountId ||
      currentOpportunity.RecordTypeId != previousOpportunity.RecordTypeId;
  }

  private static Integer getInstallmentCount(
    FinancingRate__c financingRate,
    Integer optionIndex
  ) {
    Decimal rawInstallmentCount = (Decimal) financingRate.get(
      'Installments' + optionIndex + '__c'
    );
    return rawInstallmentCount == null
      ? null
      : Integer.valueOf(String.valueOf(rawInstallmentCount));
  }

  private static Decimal getInstallmentRate(
    FinancingRate__c financingRate,
    Integer optionIndex
  ) {
    return (Decimal) financingRate.get('InstallmentRate' + optionIndex + '__c');
  }

  private static String resolveProposalLabel(FinancingRate__c financingRate) {
    return String.isBlank(financingRate.ProposalLabel__c)
      ? financingRate.Name
      : financingRate.ProposalLabel__c;
  }

  private static String buildSimulationKey(
    PaymentSimulation__c simulationRecord
  ) {
    return simulationRecord == null
      ? null
      : buildSimulationKey(
          simulationRecord.FinancingRate__c,
          simulationRecord.InstallmentCount__c == null
            ? null
            : Integer.valueOf(
                String.valueOf(simulationRecord.InstallmentCount__c)
              ),
          simulationRecord.InterestRate__c
        );
  }

  private static String buildSimulationKey(
    Id financingRateId,
    Integer installmentCount,
    Decimal interestRate
  ) {
    if (
      financingRateId == null ||
      installmentCount == null ||
      interestRate == null
    ) {
      return null;
    }

    return String.valueOf(financingRateId) +
      '|' +
      String.valueOf(installmentCount) +
      '|' +
      normalizeDecimalKey(interestRate);
  }

  private static String normalizeDecimalKey(Decimal value) {
    return value == null
      ? null
      : String.valueOf(value.setScale(6, RoundingMode.HALF_UP));
  }

  private static String buildOptionName(
    Integer optionIndex,
    Decimal installmentCount,
    Decimal installmentAmount
  ) {
    Integer normalizedOptionIndex = optionIndex == null ||
      optionIndex <= 0
      ? 1
      : optionIndex;
    Integer normalizedInstallmentCount = installmentCount == null
      ? 0
      : Integer.valueOf(String.valueOf(installmentCount));
    return 'Opção ' +
      normalizedOptionIndex +
      ' - ' +
      normalizedInstallmentCount +
      ' Parcelas de ' +
      formatCurrencyBr(installmentAmount);
  }

  private static Boolean isRentalPaymentType(String paymentType) {
    return PAYMENT_TYPE_RENTAL.equalsIgnoreCase(paymentType);
  }

  private static Boolean becameSelected(
    PaymentSimulation__c currentSimulation,
    PaymentSimulation__c previousSimulation
  ) {
    return currentSimulation.Selected__c &&
      (previousSimulation == null || !previousSimulation.Selected__c);
  }

  private static Boolean didSelectionChange(
    PaymentSimulation__c currentSimulation,
    PaymentSimulation__c previousSimulation
  ) {
    if (previousSimulation == null) {
      return currentSimulation.Selected__c;
    }

    return currentSimulation.Selected__c != previousSimulation.Selected__c;
  }

  private static Boolean didSelectedSimulationDetailsChange(
    PaymentSimulation__c currentSimulation,
    PaymentSimulation__c previousSimulation
  ) {
    if (!currentSimulation.Selected__c) {
      return false;
    }

    if (previousSimulation == null) {
      return true;
    }

    return currentSimulation.InstallmentAmount__c !=
      previousSimulation.InstallmentAmount__c ||
      currentSimulation.InstallmentCount__c !=
      previousSimulation.InstallmentCount__c ||
      currentSimulation.InterestRate__c != previousSimulation.InterestRate__c ||
      currentSimulation.PaymentType__c != previousSimulation.PaymentType__c ||
      currentSimulation.ProposalLabel__c !=
      previousSimulation.ProposalLabel__c ||
      currentSimulation.FinancingRate__c != previousSimulation.FinancingRate__c;
  }

  private static String serializeSelectedSimulation(
    PaymentSimulation__c selectedSimulation,
    String optionName
  ) {
    SelectedSimulationDetails payload = new SelectedSimulationDetails();
    payload.paymentSimulationId = selectedSimulation.Id;
    payload.paymentSimulationNumber = selectedSimulation.Name;
    payload.optionId = String.valueOf(selectedSimulation.Id);
    payload.optionName = optionName;
    payload.financingRateId = selectedSimulation.FinancingRate__c;
    payload.paymentType = selectedSimulation.PaymentType__c;
    payload.proposalLabel = selectedSimulation.ProposalLabel__c;
    payload.selectedInstallmentOption = optionName;
    payload.installmentCount = selectedSimulation.InstallmentCount__c == null
      ? null
      : Integer.valueOf(String.valueOf(selectedSimulation.InstallmentCount__c));
    payload.installmentAmount = selectedSimulation.InstallmentAmount__c;
    payload.interestRate = selectedSimulation.InterestRate__c;

    return JSON.serialize(payload);
  }

  private static void updateOpportunitiesWithoutTrigger(
    List<Opportunity> opportunitiesToUpdate
  ) {
    if (opportunitiesToUpdate.isEmpty()) {
      return;
    }

    OpportunityTriggerHandler.disableTrigger();
    try {
      update opportunitiesToUpdate;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
  }

  private static Decimal getSimulationAmount(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return null;
    }

    Map<String, Object> populatedFields = opportunityRecord.getPopulatedFieldsAsMap();
    Decimal totalProposalValue = populatedFields.containsKey(
        'ValorTotalProposta__c'
      )
      ? (Decimal) populatedFields.get('ValorTotalProposta__c')
      : null;
    if (totalProposalValue != null && totalProposalValue > 0) {
      return totalProposalValue;
    }

    return populatedFields.containsKey('Amount')
      ? (Decimal) populatedFields.get('Amount')
      : opportunityRecord.Amount;
  }

  private static String buildOptionTypeKey(
    Id opportunityId,
    String paymentType
  ) {
    return String.valueOf(opportunityId) + '|' + String.valueOf(paymentType);
  }

  private static String formatCurrencyBr(Decimal value) {
    if (value == null) {
      return '0,00';
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

    return formattedInt + ',' + decPart;
  }

  private static Id getSolarRecordTypeId() {
    if (solarRecordTypeId == null) {
      Schema.RecordTypeInfo solarRecordTypeInfo = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get(SOLAR_RECORD_TYPE_DEVELOPER_NAME);
      solarRecordTypeId = solarRecordTypeInfo == null
        ? null
        : solarRecordTypeInfo.getRecordTypeId();
    }

    return solarRecordTypeId;
  }

  private class SimulationSyncPlan {
    public List<PaymentSimulation__c> simulationsToInsert = new List<PaymentSimulation__c>();
    public List<PaymentSimulation__c> simulationsToUpdate = new List<PaymentSimulation__c>();
    public List<PaymentSimulation__c> simulationsToDelete = new List<PaymentSimulation__c>();
    public Set<Id> affectedOpportunityIds = new Set<Id>();

    public Boolean isEmpty() {
      return simulationsToInsert.isEmpty() &&
        simulationsToUpdate.isEmpty() &&
        simulationsToDelete.isEmpty();
    }
  }

  private class SelectedSimulationDetails {
    public Id paymentSimulationId;
    public String paymentSimulationNumber;
    public String optionId;
    public String optionName;
    public Id financingRateId;
    public String paymentType;
    public String proposalLabel;
    public String selectedInstallmentOption;
    public Integer installmentCount;
    public Decimal installmentAmount;
    public Decimal interestRate;
  }
}
