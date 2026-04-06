/**
 * @description       : Valida a geração e sincronização das simulações de pagamento do Solar Grupo B
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : OpenAI Codex
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public class PaymentSimulationBOTest {
  @IsTest
  static void createSimulationsGeneratesOneRecordPerOptionForEligibleOpportunity() {
    FinancingRate__c financingRate = createFinancingRate(
      'Banco do Brasil',
      'Financing',
      true,
      10,
      0.0200,
      15,
      0.0300,
      48,
      0.0400,
      60,
      0.0500
    );
    FinancingRate__c rentalRate = createFinancingRate(
      'Solar Aluguel',
      'Rental',
      true,
      12,
      0.0100,
      24,
      0.0150,
      null,
      null,
      null,
      null
    );
    createFinancingRate(
      'Banco Inativo',
      'Financing',
      false,
      12,
      0.0199,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Opportunity opportunityRecord = createOpportunity(
      createAccount('TestFactoryDefaults.LegalPersonAccount').Id,
      100000,
      'Solar',
      'Grupo B'
    );

    Test.startTest();
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );

    System.assertEquals(
      6,
      simulations.size(),
      'A oportunidade elegível deve gerar uma linha para cada opção ativa de cada taxa.'
    );
    System.assertEquals(financingRate.Id, simulations[0].FinancingRate__c);
    System.assertEquals(10, simulations[0].InstallmentCount__c);
    System.assertEquals(0.0200, simulations[0].InterestRate__c);
    System.assertEquals(
      calculateExpectedPmt(100000, 0.0200, 10),
      simulations[0].InstallmentAmount__c
    );
    System.assertEquals(financingRate.Id, simulations[3].FinancingRate__c);
    System.assertEquals(60, simulations[3].InstallmentCount__c);
    System.assertEquals(rentalRate.Id, simulations[4].FinancingRate__c);
    System.assertEquals(12, simulations[4].InstallmentCount__c);
    System.assertEquals(rentalRate.Id, simulations[5].FinancingRate__c);
    System.assertEquals(24, simulations[5].InstallmentCount__c);
  }

  @IsTest
  static void createSimulationsNormalizesWholePercentRatesForPmt() {
    createFinancingRate(
      'Banco Percentual',
      'Financing',
      true,
      25,
      2,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Opportunity opportunityRecord = createOpportunity(
      createAccount('TestFactoryDefaults.LegalPersonAccount').Id,
      60195,
      'Solar',
      'Grupo B'
    );

    Test.startTest();
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );
    System.assertEquals(1, simulations.size());
    System.assertEquals(2, simulations[0].InterestRate__c);
    System.assertEquals(
      calculateExpectedPmt(60195, 0.02, 25),
      simulations[0].InstallmentAmount__c,
      'O PMT deve tratar 2 no cadastro como 2% e não como 200%.'
    );
  }

  @IsTest
  static void createSimulationsAppliesEligibilityAndScope() {
    createFinancingRate(
      'Banco Elegibilidade',
      'Financing',
      true,
      12,
      0.0199,
      null,
      null,
      null,
      null,
      null,
      null
    );
    createFinancingRate(
      'Rental Elegibilidade',
      'Rental',
      true,
      12,
      0,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Account physicalAccount = createAccount(
      'TestFactoryDefaults.PhysicalPersonAccount'
    );
    Account legalAccount = createAccount(
      'TestFactoryDefaults.LegalPersonAccount'
    );
    Opportunity pfOverLimitOpportunity = createOpportunity(
      physicalAccount.Id,
      71000,
      'Solar',
      'Grupo B'
    );
    Opportunity differentTariffOpportunity = createOpportunity(
      legalAccount.Id,
      90000,
      'Solar',
      'Grupo A'
    );
    Opportunity differentRecordTypeOpportunity = createOpportunity(
      legalAccount.Id,
      90000,
      'EzeeSolarB',
      'Grupo B'
    );

    Test.startTest();
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{
        pfOverLimitOpportunity,
        differentTariffOpportunity,
        differentRecordTypeOpportunity
      }
    );
    Test.stopTest();

    List<PaymentSimulation__c> pfOverLimitSimulations = getSimulations(
      pfOverLimitOpportunity.Id
    );

    System.assertEquals(
      1,
      pfOverLimitSimulations.size(),
      'Pessoa física acima do limite rental deve manter apenas a opção financing.'
    );
    System.assertEquals('Financing', pfOverLimitSimulations[0].PaymentType__c);
    System.assertEquals(
      0,
      getSimulations(differentTariffOpportunity.Id).size()
    );
    System.assertEquals(
      0,
      getSimulations(differentRecordTypeOpportunity.Id).size()
    );
  }

  @IsTest
  static void recalculateOnAmountChangeBackfillsAndUpdatesOptions() {
    createFinancingRate(
      'Banco Recalculo',
      'Financing',
      true,
      12,
      0.0199,
      24,
      0.0219,
      null,
      null,
      null,
      null
    );
    Opportunity opportunityRecord = createOpportunity(
      createAccount('TestFactoryDefaults.LegalPersonAccount').Id,
      100000,
      'Solar',
      'Grupo B'
    );
    Opportunity previousOpportunity = getOpportunity(opportunityRecord.Id);

    Test.startTest();
    PaymentSimulationBO.recalculateOnAmountChange(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>{ opportunityRecord.Id => previousOpportunity }
    );
    Test.stopTest();

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );
    System.assertEquals(
      2,
      simulations.size(),
      'O after update deve criar as simulações faltantes quando a oportunidade ainda não tiver nenhuma.'
    );

    OpportunityTriggerHandler.disableTrigger();
    try {
      update new Opportunity(Id = opportunityRecord.Id, Amount = 120000);
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    Opportunity currentOpportunity = getOpportunity(opportunityRecord.Id);
    PaymentSimulationBO.recalculateOnAmountChange(
      new List<Opportunity>{ currentOpportunity },
      new Map<Id, Opportunity>{ currentOpportunity.Id => previousOpportunity }
    );

    simulations = getSimulations(opportunityRecord.Id);
    System.assertEquals(2, simulations.size());
    System.assertEquals(
      calculateExpectedPmt(120000, 0.0199, 12),
      simulations[0].InstallmentAmount__c
    );
    System.assertEquals(
      calculateExpectedPmt(120000, 0.0219, 24),
      simulations[1].InstallmentAmount__c
    );
  }

  @IsTest
  static void recalculateOnAmountChangeConvertsLegacyRowsIntoOptionRows() {
    FinancingRate__c financingRate = createFinancingRate(
      'Banco Legado',
      'Financing',
      true,
      12,
      0.0199,
      24,
      0.0219,
      null,
      null,
      null,
      null
    );
    Opportunity opportunityRecord = createOpportunity(
      createAccount('TestFactoryDefaults.LegalPersonAccount').Id,
      100000,
      'Solar',
      'Grupo B'
    );

    PaymentSimulationTriggerHandler.isRunning = true;
    try {
      insert new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        FinancingRate__c = financingRate.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = financingRate.Name,
        InstallmentCount__c = 24,
        InterestRate__c = 0.0219,
        InstallmentAmount__c = calculateExpectedPmt(100000, 0.0219, 24),
        Selected__c = true
      );
    } finally {
      PaymentSimulationTriggerHandler.isRunning = false;
    }

    Test.startTest();
    PaymentSimulationBO.recalculateOnAmountChange(
      new List<Opportunity>{ getOpportunity(opportunityRecord.Id) },
      new Map<Id, Opportunity>{
        opportunityRecord.Id => getOpportunity(opportunityRecord.Id)
      }
    );
    Test.stopTest();

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );

    System.assertEquals(
      2,
      simulations.size(),
      'A conversão deve voltar a ter uma linha para cada opção da taxa.'
    );
    System.assertEquals(12, simulations[0].InstallmentCount__c);
    System.assertEquals(false, simulations[0].Selected__c);
    System.assertEquals(24, simulations[1].InstallmentCount__c);
    System.assertEquals(true, simulations[1].Selected__c);
  }

  @IsTest
  static void paymentSimulationTriggerUpdatesSelectionAndOpportunityDetails() {
    createFinancingRate(
      'Banco Selecao',
      'Financing',
      true,
      12,
      0.0199,
      24,
      0.0219,
      null,
      null,
      null,
      null
    );

    Opportunity opportunityRecord = createOpportunity(
      createAccount('TestFactoryDefaults.LegalPersonAccount').Id,
      90000,
      'Solar',
      'Grupo B'
    );
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );
    simulations[0].Selected__c = true;
    update simulations[0];

    simulations = getSimulations(opportunityRecord.Id);
    simulations[1].Selected__c = true;
    update simulations[1];
    simulations = getSimulations(opportunityRecord.Id);

    Opportunity syncedOpportunity = [
      SELECT FinancingProcessDetails__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    Map<String, Object> paymentDetails = deserializePaymentDetails(
      syncedOpportunity.FinancingProcessDetails__c
    );

    System.assertEquals(false, simulations[0].Selected__c);
    System.assertEquals(true, simulations[1].Selected__c);
    System.assertEquals(
      String.valueOf(simulations[1].Id),
      String.valueOf(paymentDetails.get('paymentSimulationId'))
    );
    System.assertEquals(
      simulations[1].Name,
      String.valueOf(paymentDetails.get('optionId'))
    );
    System.assertEquals(
      'Banco Selecao 24 Parcelas',
      String.valueOf(paymentDetails.get('optionName'))
    );
  }

  private static Account createAccount(String defaultsClassName) {
    Account accountRecord = (Account) TestFactory.createSObject(
      new Account(),
      defaultsClassName
    );
    accountRecord.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');

    if (String.isNotBlank(accountRecord.CNPJ__c)) {
      accountRecord.CNPJ__c = formatCnpj(generateNumericSequence(14));
    }

    insert accountRecord;
    return accountRecord;
  }

  private static Opportunity createOpportunity(
    Id accountId,
    Decimal amount,
    String recordTypeDeveloperName,
    String grupoTarifario
  ) {
    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountId,
        Amount = amount,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get(recordTypeDeveloperName)
          .getRecordTypeId(),
        GrupoTarifario__c = grupoTarifario
      )
    );
    opportunityRecord.IdVirtualOffice__c = TestFactory.nextUniqueValue('OPPVO');

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    return getOpportunity(opportunityRecord.Id);
  }

  private static Opportunity getOpportunity(Id opportunityId) {
    return [
      SELECT Id, AccountId, Amount, RecordTypeId, GrupoTarifario__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }

  private static FinancingRate__c createFinancingRate(
    String name,
    String paymentType,
    Boolean active,
    Integer installments1,
    Decimal installmentRate1,
    Integer installments2,
    Decimal installmentRate2,
    Integer installments3,
    Decimal installmentRate3,
    Integer installments4,
    Decimal installmentRate4
  ) {
    FinancingRate__c financingRate = new FinancingRate__c(
      Name = name,
      ProposalLabel__c = name,
      PaymentType__c = paymentType,
      Active__c = active,
      Installments1__c = installments1,
      InstallmentRate1__c = installmentRate1,
      Installments2__c = installments2,
      InstallmentRate2__c = installmentRate2,
      Installments3__c = installments3,
      InstallmentRate3__c = installmentRate3,
      Installments4__c = installments4,
      InstallmentRate4__c = installmentRate4
    );
    insert financingRate;
    return financingRate;
  }

  private static List<PaymentSimulation__c> getSimulations(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        Opportunity__c,
        FinancingRate__c,
        ProposalLabel__c,
        PaymentType__c,
        Selected__c,
        InstallmentCount__c,
        InterestRate__c,
        InstallmentAmount__c
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opportunityId
      ORDER BY
        ProposalLabel__c ASC,
        InstallmentCount__c ASC,
        InterestRate__c ASC,
        Name ASC
    ];
  }

  private static String generateNumericSequence(Integer length) {
    String digitsOnly = TestFactory.nextUniqueValue('DOC')
      .replaceAll('[^0-9]', '');
    while (digitsOnly.length() < length) {
      digitsOnly += digitsOnly;
    }
    return digitsOnly.substring(0, length);
  }

  private static String formatCnpj(String digitsOnly) {
    return digitsOnly.substring(0, 2) +
      '.' +
      digitsOnly.substring(2, 5) +
      '.' +
      digitsOnly.substring(5, 8) +
      '/' +
      digitsOnly.substring(8, 12) +
      '-' +
      digitsOnly.substring(12, 14);
  }

  private static Decimal calculateExpectedPmt(
    Decimal principalValue,
    Decimal interestRate,
    Integer installments
  ) {
    if (interestRate == null || interestRate == 0) {
      return (principalValue / installments).setScale(2, RoundingMode.HALF_UP);
    }

    Double principalAsDouble = Double.valueOf(String.valueOf(principalValue));
    Double rateAsDouble = Double.valueOf(String.valueOf(interestRate));
    Double factor = Math.pow(1 + rateAsDouble, installments);
    Double denominator = 1 - (1 / factor);
    Double paymentAmount = (principalAsDouble * rateAsDouble) / denominator;

    return Decimal.valueOf(String.valueOf(paymentAmount))
      .setScale(2, RoundingMode.HALF_UP);
  }

  private static Map<String, Object> deserializePaymentDetails(String payload) {
    return (Map<String, Object>) JSON.deserializeUntyped(payload);
  }
}
