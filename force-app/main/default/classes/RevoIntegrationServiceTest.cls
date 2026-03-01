@IsTest
private class RevoIntegrationServiceTest {
  private class RevoMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"data":[{"token":"abc"}]}');
      return res;
    }
  }

  @IsTest
  static void shouldSendToCreditAnalysis() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Revo_CreditAnalysis'
      ) ||
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Revo_Authentication'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        ReferenceIdRevo__c = 'REF-1',
        ErroIntegracaoRevo__c = true
      ),
      true
    );

    Test.setMock(HttpCalloutMock.class, new RevoMock());
    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis(opp.Id);
    Test.stopTest();

    Opportunity updated = [
      SELECT IntegradoRevo__c, ErroIntegracaoRevo__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(true, updated.IntegradoRevo__c);
    System.assertEquals(false, updated.ErroIntegracaoRevo__c);
  }
}
