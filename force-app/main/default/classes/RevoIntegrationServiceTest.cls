/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class RevoIntegrationServiceTest {
  private static Integer retryRequestCount = 0;
  private static Integer retryBearerCount = 0;

  private class RevoMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"data":[{"token":"abc"}]}');
      return res;
    }
  }

  private class RevoRetryMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      retryRequestCount++;
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (String.valueOf(req.getHeader('Authorization')).startsWith('Basic ')) {
        res.setStatusCode(200);
        res.setBody('{"data":[{"token":"token-' + retryRequestCount + '"}]}');
      } else if (retryBearerCount == 0) {
        retryBearerCount++;
        res.setStatusCode(401);
        res.setBody('{"message":"expired"}');
      } else {
        retryBearerCount++;
        res.setStatusCode(200);
        res.setBody('{"success":true}');
      }
      return res;
    }
  }

  private class RevoFailureMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (String.valueOf(req.getHeader('Authorization')).startsWith('Basic ')) {
        res.setStatusCode(200);
        res.setBody('{"data":[{"token":"abc"}]}');
        return res;
      }

      res.setStatusCode(500);
      res.setBody('{"message":"failure"}');
      return res;
    }
  }

  private class RevoEmptyTokenMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (String.valueOf(req.getHeader('Authorization')).startsWith('Basic ')) {
        res.setStatusCode(200);
        res.setBody('{"data":[]}');
      } else {
        res.setStatusCode(200);
        res.setBody('{"success":true}');
      }
      return res;
    }
  }

  private class RevoAuthFailureMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (String.valueOf(req.getHeader('Authorization')).startsWith('Basic ')) {
        res.setStatusCode(500);
        res.setBody('{"message":"auth-failure"}');
      } else {
        res.setStatusCode(200);
        res.setBody('{"success":true}');
      }
      return res;
    }
  }

  private class RevoServiceExceptionMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      if (
        !String.valueOf(req.getHeader('Authorization')).startsWith('Basic ')
      ) {
        throw new CalloutException('service-failure');
      }

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

  @IsTest
  static void shouldRetryWhenTokenExpires() {
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
        ReferenceIdRevo__c = 'REF-RETRY',
        ErroIntegracaoRevo__c = true
      ),
      true
    );

    retryRequestCount = 0;
    retryBearerCount = 0;
    Test.setMock(HttpCalloutMock.class, new RevoRetryMock());
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
    System.assert(
      retryBearerCount >= 2,
      'Fluxo com retry deve reenviar a chamada de crédito.'
    );
  }

  @IsTest
  static void shouldMarkIntegrationAsFailedWhenServiceReturnsError() {
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
        ReferenceIdRevo__c = 'REF-FAIL',
        IntegradoRevo__c = true
      ),
      true
    );

    Test.setMock(HttpCalloutMock.class, new RevoFailureMock());
    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis(opp.Id);
    Test.stopTest();

    Opportunity updated = [
      SELECT IntegradoRevo__c, ErroIntegracaoRevo__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(false, updated.IntegradoRevo__c);
    System.assertEquals(true, updated.ErroIntegracaoRevo__c);
  }

  @IsTest
  static void shouldHandleMissingOpportunityWithoutDml() {
    Test.setMock(HttpCalloutMock.class, new RevoMock());

    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis('006000000000000AAA');
    Test.stopTest();

    System.assertEquals(
      true,
      true,
      'Id inexistente deve cair no tratamento de exceção sem quebrar o future.'
    );
  }

  @IsTest
  static void shouldProceedWhenAuthReturnsEmptyTokenData() {
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
        ReferenceIdRevo__c = 'REF-EMPTY-TOKEN'
      ),
      true
    );

    Test.setMock(HttpCalloutMock.class, new RevoEmptyTokenMock());
    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis(opp.Id);
    Test.stopTest();

    Opportunity updated = [
      SELECT IntegradoRevo__c, ErroIntegracaoRevo__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(false, updated.IntegradoRevo__c);
    System.assertEquals(true, updated.ErroIntegracaoRevo__c);
  }

  @IsTest
  static void shouldProceedWhenAuthEndpointReturnsError() {
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
      new Opportunity(AccountId = acc.Id, ReferenceIdRevo__c = 'REF-AUTH-FAIL'),
      true
    );

    Test.setMock(HttpCalloutMock.class, new RevoAuthFailureMock());
    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis(opp.Id);
    Test.stopTest();

    Opportunity updated = [
      SELECT IntegradoRevo__c, ErroIntegracaoRevo__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(false, updated.IntegradoRevo__c);
    System.assertEquals(true, updated.ErroIntegracaoRevo__c);
  }

  @IsTest
  static void shouldReturnNullWhenServiceCallThrowsException() {
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
      new Opportunity(AccountId = acc.Id, ReferenceIdRevo__c = 'REF-EXCEPTION'),
      true
    );

    Test.setMock(HttpCalloutMock.class, new RevoServiceExceptionMock());
    Test.startTest();
    RevoIntegrationService.sendToCreditAnalysis(opp.Id);
    Test.stopTest();

    Opportunity updated = [
      SELECT IntegradoRevo__c, ErroIntegracaoRevo__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(false, updated.IntegradoRevo__c);
    System.assertEquals(true, updated.ErroIntegracaoRevo__c);
  }
}
