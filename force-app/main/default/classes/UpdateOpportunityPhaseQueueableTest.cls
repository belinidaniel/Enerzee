/**
 * @description       : Test coverage for UpdateOpportunityPhaseQueueable
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-27-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class UpdateOpportunityPhaseQueueableTest {
  private class NivelloMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (
        req.getEndpoint() != null &&
        req.getEndpoint().containsIgnoreCase('Login')
      ) {
        res.setStatusCode(200);
        res.setBody('{"data":{"token":"fake-token"}}');
      } else {
        res.setStatusCode(200);
        res.setBody('{"success":true}');
      }
      return res;
    }
  }

  private static Opportunity createOpportunity(Boolean sucesso) {
    Account acc = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    insert acc;

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Amount = 10000,
        SucessoIntegracaoNivello__c = sucesso
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

  @IsTest
  static void execute_pendingOpportunities_dispatchesAndChains() {
    createOpportunity(false);
    createOpportunity(null);

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    System.enqueueJob(
      new UpdateOpportunityPhaseQueueable(Date.today().addDays(-1))
    );
    Test.stopTest();
  }

  @IsTest
  static void execute_noPendingOpportunities_stopsGracefully() {
    createOpportunity(true);

    Test.setMock(HttpCalloutMock.class, new NivelloMock());
    Test.startTest();
    System.enqueueJob(
      new UpdateOpportunityPhaseQueueable(Date.today().addDays(-1))
    );
    Test.stopTest();
  }
}
