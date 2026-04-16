/**
 * @description       : Valida o envio das opções de financiamento para o endpoint ProposalStatus
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : OpenAI Codex
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProposalServicePaymentSimulationTest {
  private static List<String> requestBodies = new List<String>();

  private class ProposalStatusPayloadMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      ProposalServicePaymentSimulationTest.requestBodies.add(req.getBody());

      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(200);
      response.setStatus('OK');
      response.setBody('{"success":true}');
      return response;
    }
  }

  @IsTest
  static void createSimulationsPublishesOneOptionPerSimulation() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    createFinancingRate('Banco App', 'Financing', 12, 0.0199, 24, 0.0219);
    createFinancingRate('Solar Aluguel', 'Rental', 10, 0.0100, 15, 0.0150);
    Opportunity opportunityRecord = createSolarGrupoBOpportunity(100000);

    requestBodies.clear();
    enableAutomaticSync();
    Test.setMock(HttpCalloutMock.class, new ProposalStatusPayloadMock());

    Test.startTest();
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    PaymentSimulationProposalStatusService.enqueueOpportunityStatusSync(
      new Set<Id>{ opportunityRecord.Id }
    );
    Test.stopTest();

    Map<String, Object> payload = getFirstPayload();
    List<Object> options = (List<Object>) payload.get('OptionsFinanciamentos');
    Map<String, Object> firstOption = (Map<String, Object>) options[0];
    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );

    System.assertEquals(
      4,
      options.size(),
      'O payload deve enviar uma opção por linha de simulação.'
    );
    System.assert(
      String.valueOf(firstOption.get('OptionName'))
        .startsWith('Opção 1 - 12 Parcelas de R$ '),
      'O nome da opção deve ser numerado por tipo e incluir o valor da parcela.'
    );
    System.assert(
      String.valueOf(firstOption.get('OptionId')) ==
      String.valueOf(simulations[0].Id),
      'O payload deve enviar o Id Salesforce da simulação como OptionId.'
    );
    System.assertEquals(
      1,
      Integer.valueOf(String.valueOf(firstOption.get('OptionType'))),
      'Opções de financiamento devem enviar OptionType = 1.'
    );
    System.assertEquals(false, firstOption.get('OptionSelected'));

    Boolean foundRentalOption = false;
    for (Object optionItem : options) {
      Map<String, Object> optionMap = (Map<String, Object>) optionItem;
      if (Integer.valueOf(String.valueOf(optionMap.get('OptionType'))) == 2) {
        foundRentalOption = true;
        System.assert(
          String.valueOf(optionMap.get('OptionName'))
            .startsWith('Opção 1 - 10 Parcelas de R$ '),
          'As opções de aluguel também devem reiniciar a numeração por tipo.'
        );
        break;
      }
    }
    System.assertEquals(
      true,
      foundRentalOption,
      'Ao menos uma opção de aluguel deve enviar OptionType = 2.'
    );
  }

  @IsTest
  static void selectingSimulationPublishesSelectedOptionAndFinancingDetail() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    createFinancingRate('Banco Selecao', 'Financing', 12, 0.0199, 24, 0.0219);
    Opportunity opportunityRecord = createSolarGrupoBOpportunity(95000);
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );
    requestBodies.clear();
    enableAutomaticSync();
    Test.setMock(HttpCalloutMock.class, new ProposalStatusPayloadMock());

    Test.startTest();
    simulations[1].Selected__c = true;
    update simulations[1];
    Test.stopTest();

    Map<String, Object> payload = getFirstPayload();
    List<Object> options = (List<Object>) payload.get('OptionsFinanciamentos');
    Map<String, Object> selectedOption = findSelectedOption(options);
    Map<String, Object> financingDetail = (Map<String, Object>) JSON.deserializeUntyped(
      String.valueOf(payload.get('FinancingProcessDetail'))
    );

    System.assertEquals(true, selectedOption.get('OptionSelected'));
    System.assertEquals(
      String.valueOf(simulations[1].Id),
      String.valueOf(selectedOption.get('OptionId'))
    );
    System.assert(
      String.valueOf(selectedOption.get('OptionName'))
        .startsWith('Opção 2 - 24 Parcelas de R$ '),
      'A segunda opção de financiamento deve usar o índice 2 e incluir o valor.'
    );
    System.assertEquals(
      1,
      Integer.valueOf(String.valueOf(selectedOption.get('OptionType'))),
      'Simulação de financiamento selecionada deve enviar OptionType = 1.'
    );
    System.assertEquals(
      String.valueOf(simulations[1].Id),
      String.valueOf(financingDetail.get('optionId'))
    );
    System.assertEquals(
      String.valueOf(selectedOption.get('OptionName')),
      String.valueOf(financingDetail.get('optionName'))
    );
  }

  @IsTest
  static void projectIntegrationPublishesSelectedSimulation() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    createFinancingRate('Banco Projeto', 'Financing', 12, 0.0199, 24, 0.0219);
    Opportunity opportunityRecord = createSolarGrupoBOpportunity(87000);
    PaymentSimulationBO.createSimulationsForOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    ViabilityStudy__c viabilityRecord = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viabilityRecord;

    List<PaymentSimulation__c> simulations = getSimulations(
      opportunityRecord.Id
    );
    simulations[0].Selected__c = true;
    update simulations[0];

    Projeto__c projectRecord = new Projeto__c(
      Name = 'Projeto Integracao Financiamento',
      Oportunidade__c = opportunityRecord.Id,
      Viabilidade__c = viabilityRecord.Id,
      Conta__c = opportunityRecord.AccountId,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO
    );

    ProjetoTriggerHandler.disableTrigger();
    try {
      insert projectRecord;
    } finally {
      ProjetoTriggerHandler.enableTrigger();
    }

    requestBodies.clear();
    Test.setMock(HttpCalloutMock.class, new ProposalStatusPayloadMock());

    Test.startTest();
    IntegracaoNivelloProjetos.sendProjetos(
      new Set<Id>{ projectRecord.Id },
      false
    );
    Test.stopTest();

    Map<String, Object> payload = getFirstPayload();
    List<Object> options = (List<Object>) payload.get('OptionsFinanciamentos');
    Map<String, Object> selectedOption = findSelectedOption(options);

    System.assertEquals(true, selectedOption.get('OptionSelected'));
    System.assertEquals(
      String.valueOf(simulations[0].Id),
      String.valueOf(selectedOption.get('OptionId'))
    );
    System.assertEquals(
      1,
      Integer.valueOf(String.valueOf(selectedOption.get('OptionType'))),
      'A integração do projeto deve levar o tipo da opção selecionada.'
    );
    System.assertNotEquals(null, payload.get('FinancingProcessDetail'));
  }

  private static void enableAutomaticSync() {
    PaymentSimulationProposalStatusService.allowProposalStatusSyncInTest = true;
  }

  private static Opportunity createSolarGrupoBOpportunity(Decimal amount) {
    Account accountRecord = createAccount();
    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountRecord.Id,
        Amount = amount,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        GrupoTarifario__c = 'Grupo B'
      )
    );
    opportunityRecord.IdVirtualOffice__c = TestFactory.nextUniqueValue('OPPVO');

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    return [
      SELECT
        Id,
        AccountId,
        Amount,
        RecordTypeId,
        GrupoTarifario__c,
        TipoKitPromocional__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
  }

  private static Account createAccount() {
    Account accountRecord = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    accountRecord.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');
    accountRecord.CNPJ__c = formatCnpj(generateNumericSequence(14));
    insert accountRecord;
    return accountRecord;
  }

  private static FinancingRate__c createFinancingRate(
    String name,
    String paymentType,
    Integer installments1,
    Decimal installmentRate1,
    Integer installments2,
    Decimal installmentRate2
  ) {
    FinancingRate__c financingRate = new FinancingRate__c(
      Name = name,
      ProposalLabel__c = name,
      PaymentType__c = paymentType,
      Active__c = true,
      Installments1__c = installments1,
      InstallmentRate1__c = installmentRate1,
      Installments2__c = installments2,
      InstallmentRate2__c = installmentRate2
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
        ProposalLabel__c,
        PaymentType__c,
        InstallmentAmount__c,
        InstallmentCount__c,
        Selected__c
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opportunityId
      ORDER BY
        ProposalLabel__c ASC,
        InstallmentCount__c ASC,
        InterestRate__c ASC,
        Name ASC
    ];
  }

  private static Map<String, Object> getFirstPayload() {
    System.assertEquals(
      1,
      requestBodies.size(),
      'Deve haver exatamente um envio do ProposalStatus.'
    );
    return (Map<String, Object>) JSON.deserializeUntyped(requestBodies[0]);
  }

  private static Map<String, Object> findSelectedOption(List<Object> options) {
    for (Object optionItem : options) {
      Map<String, Object> optionMap = (Map<String, Object>) optionItem;
      if (optionMap.get('OptionSelected') == true) {
        return optionMap;
      }
    }

    System.assert(false, 'Deve existir uma opção selecionada no payload.');
    return null;
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
}
