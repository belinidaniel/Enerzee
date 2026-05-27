/**
 * @description       : Test coverage for ProposalService.updateOpportunityPhase
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-27-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProposalServiceTest {
  private static Integer mockStatusCode = 200;
  private static List<String> capturedBodies = new List<String>();

  private class NivelloMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(mockStatusCode);
      res.setStatus(mockStatusCode == 200 ? 'OK' : 'Bad Request');
      res.setBody('{"success":true}');
      capturedBodies.add(req.getBody());
      return res;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  private static Opportunity createSolarOpportunity() {
    Account acc = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    acc.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');
    acc.CNPJ__c = generateCnpj();
    insert acc;

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_GANHO_FECHADO,
        ValorTotalProposta__c = 50000
      )
    );
    opp.IdVirtualOffice__c = TestFactory.nextUniqueValue('OPPVO');

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opp;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
    return opp;
  }

  private static Opportunity createClosedLostOpportunity(String lossReason) {
    Account acc = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    acc.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');
    acc.CNPJ__c = generateCnpj();
    insert acc;

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO,
        Loss_Reason__c = lossReason,
        ValorTotalProposta__c = 30000
      )
    );
    opp.IdVirtualOffice__c = TestFactory.nextUniqueValue('OPPVO');

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opp;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
    return opp;
  }

  private static String generateCnpj() {
    String digits = TestFactory.nextUniqueValue('DOC').replaceAll('[^0-9]', '');
    while (digits.length() < 14) {
      digits += digits;
    }
    digits = digits.substring(0, 14);
    return digits.substring(0, 2) +
      '.' +
      digits.substring(2, 5) +
      '.' +
      digits.substring(5, 8) +
      '/' +
      digits.substring(8, 12) +
      '-' +
      digits.substring(12, 14);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tests
  // ──────────────────────────────────────────────────────────────────────────

  @IsTest
  static void updateOpportunityPhase_success200() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    Opportunity opp = createSolarOpportunity();
    TokenAPINivelloWs.access_token = 'fake-token-test';
    mockStatusCode = 200;
    capturedBodies.clear();

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();

    Opportunity updated = [
      SELECT SucessoIntegracaoNivello__c, StatusBodyIntegracaoNivello__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    Assert.areEqual(
      true,
      updated.SucessoIntegracaoNivello__c,
      'Deve marcar sucesso na integração.'
    );
    Assert.isTrue(
      updated.StatusBodyIntegracaoNivello__c.contains('200'),
      'StatusBody deve conter o código 200.'
    );
  }

  @IsTest
  static void updateOpportunityPhase_errorNon200() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    Opportunity opp = createSolarOpportunity();
    TokenAPINivelloWs.access_token = 'fake-token-test';
    mockStatusCode = 400;
    capturedBodies.clear();

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();

    Opportunity updated = [
      SELECT SucessoIntegracaoNivello__c, StatusBodyIntegracaoNivello__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    Assert.areEqual(
      false,
      updated.SucessoIntegracaoNivello__c,
      'Deve marcar falha na integração.'
    );
    Assert.isTrue(
      updated.StatusBodyIntegracaoNivello__c.contains('400'),
      'StatusBody deve conter o código 400.'
    );
  }

  @IsTest
  static void updateOpportunityPhase_closedLost_mappedLossReason() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    Opportunity opp = createClosedLostOpportunity('cliente desistiu');
    TokenAPINivelloWs.access_token = 'fake-token-test';
    mockStatusCode = 200;
    capturedBodies.clear();

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();

    Assert.isFalse(
      capturedBodies.isEmpty(),
      'Deve ter feito pelo menos uma chamada.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBodies[0]
    );
    Assert.areEqual(
      8,
      Integer.valueOf(String.valueOf(payload.get('LossReason'))),
      'LossReason deve ser 8 para "cliente desistiu".'
    );
  }

  @IsTest
  static void updateOpportunityPhase_closedLost_unmappedLossReason() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    // Motivo não mapeado — deve gerar WARNING log mas não lançar exception
    Opportunity opp = createClosedLostOpportunity(
      'motivo inexistente qualquer'
    );
    TokenAPINivelloWs.access_token = 'fake-token-test';
    mockStatusCode = 200;
    capturedBodies.clear();

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();

    Assert.isFalse(
      capturedBodies.isEmpty(),
      'Deve ter feito a chamada mesmo com LossReason não mapeado.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBodies[0]
    );
    Assert.isNull(
      payload.get('LossReason'),
      'LossReason deve ser null quando não mapeado.'
    );
  }

  @IsTest
  static void updateOpportunityPhase_emptyIds_noCallout() {
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
    ) {
      return;
    }

    capturedBodies.clear();
    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>());
    Test.stopTest();

    Assert.isTrue(
      capturedBodies.isEmpty(),
      'Não deve fazer callout com conjunto vazio.'
    );
  }
}
