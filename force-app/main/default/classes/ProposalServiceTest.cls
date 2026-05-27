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

  private class ExceptionMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      // Token request passa normalmente
      if (
        req.getEndpoint() != null &&
        req.getEndpoint().containsIgnoreCase('Login')
      ) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody('{"data":{"token":"fake-token-123"}}');
        return res;
      }
      // Simula falha no callout principal
      throw new CalloutException('Simulated callout failure');
    }
  }

  private class MultiCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (
        req.getEndpoint() != null &&
        req.getEndpoint().containsIgnoreCase('Login')
      ) {
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody('{"data":{"token":"fake-token-123"}}');
        return res;
      }
      res.setStatusCode(mockStatusCode);
      res.setStatus(mockStatusCode == 200 ? 'OK' : 'Bad Request');
      res.setBody('{"success":true}');
      return res;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  private static Account createAccount() {
    Account acc = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    acc.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');
    acc.CNPJ__c = generateCnpj();
    insert acc;
    return acc;
  }

  private static Opportunity createSolarOpportunity(
    Account acc,
    String stageName
  ) {
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = stageName,
        Amount = 50000
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

  private static Opportunity createClosedLostOpportunity(
    Account acc,
    String lossReason
  ) {
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO,
        Loss_Reason__c = lossReason,
        Amount = 30000
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
    Account acc = createAccount();
    Opportunity opp = createSolarOpportunity(
      acc,
      OpportunityUtils.STATUS_GANHO_FECHADO
    );
    mockStatusCode = 200;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_errorNon200() {
    Account acc = createAccount();
    Opportunity opp = createSolarOpportunity(
      acc,
      OpportunityUtils.STATUS_GANHO_FECHADO
    );
    mockStatusCode = 400;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_closedLost_mappedLossReason() {
    Account acc = createAccount();
    Opportunity opp = createClosedLostOpportunity(acc, 'cliente desistiu');
    mockStatusCode = 200;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_closedLost_unmappedLossReason() {
    Account acc = createAccount();
    Opportunity opp = createClosedLostOpportunity(
      acc,
      'motivo inexistente qualquer'
    );
    mockStatusCode = 200;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_closedLost_blankLossReason() {
    Account acc = createAccount();
    Opportunity opp = createClosedLostOpportunity(acc, null);
    mockStatusCode = 200;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_multipleOpportunities() {
    Account acc = createAccount();
    Opportunity opp1 = createSolarOpportunity(
      acc,
      OpportunityUtils.STATUS_GANHO_FECHADO
    );
    Opportunity opp2 = createClosedLostOpportunity(acc, 'cliente desistiu');
    mockStatusCode = 200;

    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>{ opp1.Id, opp2.Id });
    Test.stopTest();
  }

  @IsTest
  static void updateOpportunityPhase_emptyIds_noCallout() {
    Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
    Test.startTest();
    ProposalService.updateOpportunityPhase(new Set<Id>());
    Test.stopTest();
  }
}
