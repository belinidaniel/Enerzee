/**
 * @description       : Controller LWC para exibição das simulações de pagamento agrupadas por ProposalLabel
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-07-2026
 * @last modified by  : Daniel Belini
 * @test              : PaymentSimulationCardControllerTest
 **/
public with sharing class PaymentSimulationCardController {
  private static final String READJUSTMENT_STAGE = 'Readequação de Proposta';
  private static final String MANUAL_SIMULATION_LABEL = 'Simulação ajustada';

  @AuraEnabled(cacheable=true)
  public static List<ProposalCardWrapper> getSimulationCards(Id opportunityId) {
    if (opportunityId == null) {
      return new List<ProposalCardWrapper>();
    }

    List<Opportunity> opps = [
      SELECT SelectedSimulation__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    String selectedSimulationId = opps.isEmpty()
      ? null
      : opps[0].SelectedSimulation__c;

    List<PaymentSimulation__c> simulations = PaymentSimulationDAO.getByOpportunityIds(
      new Set<Id>{ opportunityId }
    );
    if (String.isBlank(selectedSimulationId)) {
      for (PaymentSimulation__c simulationRecord : simulations) {
        if (simulationRecord.Selected__c == true) {
          selectedSimulationId = simulationRecord.Id;
          break;
        }
      }
    }

    Map<String, ProposalCardWrapper> cardsByKey = new Map<String, ProposalCardWrapper>();
    List<String> cardOrder = new List<String>();

    for (PaymentSimulation__c sim : simulations) {
      String label = sim.ProposalLabel__c;
      if (String.isBlank(label)) {
        continue;
      }

      String cardKey = buildCardKey(sim);

      if (!cardsByKey.containsKey(cardKey)) {
        ProposalCardWrapper card = new ProposalCardWrapper();
        card.key = cardKey;
        card.proposalLabel = label;
        card.paymentType = sim.PaymentType__c;
        card.isManual = isManualProposalLabel(label);
        card.hasSelected = false;
        card.selectedSimulationId = selectedSimulationId;
        card.options = new List<SimulationOptionWrapper>();
        cardsByKey.put(cardKey, card);
        cardOrder.add(cardKey);
      }

      Boolean isAppSelected =
        String.isNotBlank(selectedSimulationId) &&
        sim.Id == (Id) selectedSimulationId;

      SimulationOptionWrapper option = new SimulationOptionWrapper();
      option.id = sim.Id;
      option.name = sim.Name;
      option.installmentCount = sim.InstallmentCount__c == null
        ? null
        : Integer.valueOf(String.valueOf(sim.InstallmentCount__c));
      option.installmentAmount = sim.InstallmentAmount__c;
      option.interestRate = sim.InterestRate__c;
      option.selected = isAppSelected;

      ProposalCardWrapper card = cardsByKey.get(cardKey);
      card.options.add(option);

      if (isAppSelected) {
        card.hasSelected = true;
      }
    }

    List<ProposalCardWrapper> cards = new List<ProposalCardWrapper>();
    for (String cardKey : cardOrder) {
      cards.add(cardsByKey.get(cardKey));
    }
    return cards;
  }

  @AuraEnabled
  public static ManualSimulationResult createManualSimulation(
    Id opportunityId,
    Id baseSimulationId,
    Integer installmentCount,
    Decimal installmentAmount
  ) {
    validateManualSimulationRequest(
      opportunityId,
      installmentCount,
      installmentAmount
    );
    validateManualSimulationPermissions();

    Opportunity opportunityRecord = [
      SELECT Id, StageName, SelectedSimulation__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (opportunityRecord.StageName != READJUSTMENT_STAGE) {
      throw new AuraHandledException(
        'A simulação manual só pode ser criada na fase Readequação de Proposta.'
      );
    }

    PaymentSimulation__c baseSimulation = resolveBaseSimulation(
      opportunityRecord,
      baseSimulationId
    );
    if (baseSimulation == null) {
      throw new AuraHandledException(
        'Nenhuma simulação base foi encontrada para esta oportunidade.'
      );
    }

    ManualSimulationResult result = new ManualSimulationResult();
    Decimal normalizedInstallmentAmount = installmentAmount.setScale(
      2,
      RoundingMode.HALF_UP
    );
    if (
      baseSimulation.InstallmentCount__c == installmentCount &&
      areSameInstallmentAmount(
        baseSimulation.InstallmentAmount__c,
        normalizedInstallmentAmount
      )
    ) {
      selectSimulation(baseSimulation, opportunityRecord);
      result.createdNewSimulation = false;
      result.simulationId = baseSimulation.Id;
      result.simulationNumber = baseSimulation.Name;
      return result;
    }

    PaymentSimulation__c manualSimulation = new PaymentSimulation__c(
      Opportunity__c = opportunityRecord.Id,
      FinancingRate__c = baseSimulation.FinancingRate__c,
      PaymentType__c = baseSimulation.PaymentType__c,
      ProposalLabel__c = MANUAL_SIMULATION_LABEL,
      InstallmentCount__c = installmentCount,
      InstallmentAmount__c = normalizedInstallmentAmount,
      InterestRate__c = baseSimulation.InterestRate__c,
      Selected__c = false
    );
    insert manualSimulation;

    manualSimulation = [
      SELECT Id, Name, Selected__c
      FROM PaymentSimulation__c
      WHERE Id = :manualSimulation.Id
      LIMIT 1
    ];
    selectSimulation(manualSimulation, opportunityRecord);

    result.createdNewSimulation = true;
    result.simulationId = manualSimulation.Id;
    result.simulationNumber = manualSimulation.Name;
    return result;
  }

  public class ProposalCardWrapper {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String proposalLabel;
    @AuraEnabled
    public String paymentType;
    @AuraEnabled
    public Boolean isManual;
    @AuraEnabled
    public Boolean hasSelected;
    @AuraEnabled
    public String selectedSimulationId;
    @AuraEnabled
    public List<SimulationOptionWrapper> options;
  }

  private static String buildCardKey(PaymentSimulation__c simulationRecord) {
    if (simulationRecord == null) {
      return null;
    }

    if (isManualProposalLabel(simulationRecord.ProposalLabel__c)) {
      return String.valueOf(simulationRecord.Id);
    }

    return String.valueOf(simulationRecord.ProposalLabel__c) +
      '|' +
      String.valueOf(simulationRecord.PaymentType__c);
  }

  private static Boolean isManualProposalLabel(String proposalLabel) {
    return proposalLabel == MANUAL_SIMULATION_LABEL;
  }

  public class SimulationOptionWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer installmentCount;
    @AuraEnabled
    public Decimal installmentAmount;
    @AuraEnabled
    public Decimal interestRate;
    @AuraEnabled
    public Boolean selected;
  }

  public class ManualSimulationResult {
    @AuraEnabled
    public Id simulationId;
    @AuraEnabled
    public String simulationNumber;
    @AuraEnabled
    public Boolean createdNewSimulation;
  }

  private static void validateManualSimulationRequest(
    Id opportunityId,
    Integer installmentCount,
    Decimal installmentAmount
  ) {
    if (opportunityId == null) {
      throw new AuraHandledException('A oportunidade é obrigatória.');
    }
    if (installmentCount == null || installmentCount <= 0) {
      throw new AuraHandledException(
        'Informe uma quantidade de parcelas válida.'
      );
    }
    if (installmentAmount == null || installmentAmount <= 0) {
      throw new AuraHandledException('Informe um valor de parcela válido.');
    }
  }

  private static void validateManualSimulationPermissions() {
    if (
      !Schema.sObjectType.PaymentSimulation__c.isCreateable() ||
      !Schema.sObjectType.PaymentSimulation__c.isUpdateable() ||
      !Schema.sObjectType.Opportunity.isUpdateable()
    ) {
      throw new AuraHandledException(
        'Você não possui permissão para atualizar a simulação de pagamento.'
      );
    }
  }

  private static PaymentSimulation__c resolveBaseSimulation(
    Opportunity opportunityRecord,
    Id requestedSimulationId
  ) {
    Id baseSimulationId = requestedSimulationId != null
      ? requestedSimulationId
      : opportunityRecord.SelectedSimulation__c;
    if (baseSimulationId != null) {
      List<PaymentSimulation__c> directMatch = [
        SELECT
          Id,
          Name,
          Opportunity__c,
          FinancingRate__c,
          PaymentType__c,
          ProposalLabel__c,
          InstallmentCount__c,
          InstallmentAmount__c,
          InterestRate__c,
          Selected__c
        FROM PaymentSimulation__c
        WHERE Id = :baseSimulationId AND Opportunity__c = :opportunityRecord.Id
        LIMIT 1
      ];
      if (!directMatch.isEmpty()) {
        return directMatch[0];
      }
    }

    List<PaymentSimulation__c> fallback = [
      SELECT
        Id,
        Name,
        Opportunity__c,
        FinancingRate__c,
        PaymentType__c,
        ProposalLabel__c,
        InstallmentCount__c,
        InstallmentAmount__c,
        InterestRate__c,
        Selected__c
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opportunityRecord.Id
      ORDER BY
        Selected__c DESC,
        ProposalLabel__c ASC,
        InstallmentCount__c ASC,
        Name ASC
      LIMIT 1
    ];
    return fallback.isEmpty() ? null : fallback[0];
  }

  private static void selectSimulation(
    PaymentSimulation__c simulationRecord,
    Opportunity opportunityRecord
  ) {
    Boolean updatedSimulationSelection = false;
    if (simulationRecord.Selected__c != true) {
      update new PaymentSimulation__c(
        Id = simulationRecord.Id,
        Selected__c = true
      );
      updatedSimulationSelection = true;
    }

    if (opportunityRecord.SelectedSimulation__c != simulationRecord.Id) {
      OpportunityTriggerHandler.disableTrigger();
      try {
        update new Opportunity(
          Id = opportunityRecord.Id,
          SelectedSimulation__c = simulationRecord.Id
        );
      } finally {
        OpportunityTriggerHandler.enableTrigger();
      }

      if (!updatedSimulationSelection) {
        PaymentSimulationProposalStatusService.enqueueOpportunityStatusSync(
          new Set<Id>{ opportunityRecord.Id }
        );
      }
    }
  }

  private static Boolean areSameInstallmentAmount(
    Decimal currentAmount,
    Decimal desiredAmount
  ) {
    if (currentAmount == null || desiredAmount == null) {
      return currentAmount == desiredAmount;
    }

    return currentAmount.setScale(2, RoundingMode.HALF_UP) ==
      desiredAmount.setScale(2, RoundingMode.HALF_UP);
  }
}
