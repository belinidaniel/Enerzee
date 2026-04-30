/**
 * @description       : Controller LWC para exibição das simulações de pagamento agrupadas por ProposalLabel
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-14-2026
 * @last modified by  : Daniel Belini
 * @test              : PaymentSimulationCardControllerTest
 **/
public with sharing class PaymentSimulationCardController {
  private static final String READJUSTMENT_STAGE = 'Readequação de Proposta';
  private static final String CREDIT_ANALYSIS_STAGE = 'Análise de Crédito';
  private static final String MANUAL_SIMULATION_LABEL = 'Simulação ajustada';
  private static final String RENTAL_PAYMENT_TYPE = 'Rental';

  @AuraEnabled(cacheable=true)
  public static List<ProposalCardWrapper> getSimulationCards(Id opportunityId) {
    if (opportunityId == null) {
      return new List<ProposalCardWrapper>();
    }

    List<Opportunity> opps = [
      SELECT SelectedSimulation__c, ValorTotalProposta__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    String selectedSimulationId = opps.isEmpty()
      ? null
      : opps[0].SelectedSimulation__c;
    Decimal opportunityPrincipalValue = opps.isEmpty()
      ? null
      : opps[0].ValorTotalProposta__c;

    List<PaymentSimulation__c> simulations = PaymentSimulationDAO.getByOpportunityIds(
      new Set<Id>{ opportunityId }
    );

    Set<Id> existingSimulationIds = new Set<Id>();
    for (PaymentSimulation__c simulationRecord : simulations) {
      existingSimulationIds.add(simulationRecord.Id);
    }
    if (String.isNotBlank(selectedSimulationId) && !existingSimulationIds.contains((Id) selectedSimulationId)) {
      selectedSimulationId = null;
    }

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
        card.anticipationRate = sim.FinancingRate__r?.AnticipationRate__c;
        card.principalValue = opportunityPrincipalValue;
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
  public static void saveSimulationSelection(
    Id opportunityId,
    Id simulationId
  ) {
    if (opportunityId == null || simulationId == null) {
      throw new AuraHandledException(
        'opportunityId e simulationId são obrigatórios.'
      );
    }
    Opportunity opportunityRecord = [
      SELECT
        Id,
        StageName,
        Status__c,
        SelectedSimulation__c,
        FormaPagamento__c,
        RecordType.DeveloperName
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    PaymentSimulation__c simulationRecord = [
      SELECT Id, Selected__c, PaymentType__c, ProposalLabel__c
      FROM PaymentSimulation__c
      WHERE Id = :simulationId
      LIMIT 1
    ];
    selectSimulation(simulationRecord, opportunityRecord);
  }

  @AuraEnabled
  public static ManualSimulationResult createManualSimulation(
    Id opportunityId,
    Id baseSimulationId,
    Integer installmentCount,
    Decimal installmentAmount,
    String paymentType
  ) {
    validateManualSimulationRequest(
      opportunityId,
      installmentCount,
      installmentAmount
    );
    validateManualSimulationPermissions();

    Opportunity opportunityRecord = [
      SELECT
        Id,
        StageName,
        Status__c,
        SelectedSimulation__c,
        FormaPagamento__c,
        RecordType.DeveloperName
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (!isManualSimulationAllowedStage(opportunityRecord.StageName)) {
      throw new AuraHandledException(
        'A simulação manual só pode ser criada nas fases Readequação de Proposta ou Análise de Crédito.'
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

    String manualPaymentType = String.isNotBlank(paymentType) ? paymentType : baseSimulation.PaymentType__c;
    PaymentSimulation__c manualSimulation = new PaymentSimulation__c(
      Opportunity__c = opportunityRecord.Id,
      FinancingRate__c = null,
      PaymentType__c = manualPaymentType,
      ProposalLabel__c = MANUAL_SIMULATION_LABEL,
      InstallmentCount__c = installmentCount,
      InstallmentAmount__c = normalizedInstallmentAmount,
      InterestRate__c = null,
      Selected__c = false
    );

    deleteExistingSimulations(opportunityRecord.Id);

    insert manualSimulation;

    manualSimulation = [
      SELECT Id, Name, Selected__c, PaymentType__c, ProposalLabel__c
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
    public Decimal anticipationRate;
    @AuraEnabled
    public Decimal principalValue;
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

  private static final Map<String, String> PAYMENT_TYPE_TO_FORMA_PAGAMENTO = new Map<String, String>{
    'Financing' => 'REC FINANCIAMEN',
    'Card' => 'REC CARTAO',
    'Pix' => 'R0002',
    'Boleto' => 'R001',
    'Negociacao' => 'Negociação'
  };

  private static String mapPaymentTypeToFormaPagamento(String paymentType) {
    if (String.isBlank(paymentType))
      return null;
    return PAYMENT_TYPE_TO_FORMA_PAGAMENTO.get(paymentType);
  }

  private static void selectSimulation(
    PaymentSimulation__c simulationRecord,
    Opportunity opportunityRecord
  ) {
    if (simulationRecord.Selected__c != true) {
      update new PaymentSimulation__c(
        Id = simulationRecord.Id,
        Selected__c = true
      );
      // PaymentSimulationBO.syncSelectedToOpportunity (afterUpdate trigger) handles
      // SelectedSimulation__c sync automatically after this DML.
    }

    // Manual simulations don't change FormaPagamento__c or StageName on the opportunity —
    // only selecting a standard simulation should drive those fields.
    Boolean isManualSimulation = MANUAL_SIMULATION_LABEL.equals(
      simulationRecord.ProposalLabel__c
    );
    if (isManualSimulation) {
      return;
    }

    // FormaPagamento__c and StageName are not managed by the trigger — update them here.
    Opportunity oppToUpdate = new Opportunity(Id = opportunityRecord.Id);
    Boolean needsOppUpdate = false;

    String mappedFormaPagamento = mapPaymentTypeToFormaPagamento(
      simulationRecord.PaymentType__c
    );
    if (
      mappedFormaPagamento != null &&
      opportunityRecord.FormaPagamento__c != mappedFormaPagamento
    ) {
      oppToUpdate.FormaPagamento__c = mappedFormaPagamento;
      needsOppUpdate = true;
    }

    if (
      RENTAL_PAYMENT_TYPE.equalsIgnoreCase(simulationRecord.PaymentType__c) &&
      opportunityRecord.RecordType?.DeveloperName == 'Solar' &&
      opportunityRecord.StageName != CREDIT_ANALYSIS_STAGE
    ) {
      oppToUpdate.StageName = CREDIT_ANALYSIS_STAGE;
      oppToUpdate.Status__c = OpportunityUtils.SUB_STATUS_ANALISE_CREDITO;
      needsOppUpdate = true;
    }

    if (needsOppUpdate) {
      OpportunityTriggerHandler.disableTrigger();
      try {
        update oppToUpdate;
      } finally {
        OpportunityTriggerHandler.enableTrigger();
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

  private static Boolean isManualSimulationAllowedStage(String stageName) {
    return stageName == READJUSTMENT_STAGE ||
      stageName == CREDIT_ANALYSIS_STAGE;
  }

  private static void deleteExistingSimulations(Id opportunityId) {
    if (opportunityId == null) {
      return;
    }

    List<PaymentSimulation__c> simulationsToDelete = [
      SELECT Id
      FROM PaymentSimulation__c
      WHERE
        Opportunity__c = :opportunityId
        AND ProposalLabel__c = :MANUAL_SIMULATION_LABEL
    ];
    if (!simulationsToDelete.isEmpty()) {
      delete simulationsToDelete;
    }
  }
}
