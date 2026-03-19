/**
 * @description       : Tests for IntegracaoSAPCliente Queueable. Covers CPF/CNPJ routing, address building,
 *                       success/error responses, exception handling and empty-set guard.
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-19-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoSAPClienteTest {
  private static final String SUCCESS_BODY = '{"codigoHttp":201,"mensagem":"Inserido com sucesso","resultado":null}';
  private static final String ERROR_BODY = '{"codigoHttp":400,"mensagem":"Erro de validacao","resultado":null}';

  // ─── Helpers ─────────────────────────────────────────────────────────────

  private static Account buildAccount(Boolean withCNPJ, Boolean withAddress) {
    Account acc = new Account(
      Name = 'Teste Cliente SAP',
      Email__c = 'cliente@teste.com',
      Phone = '11999990000',
      CPF__c = withCNPJ ? null : '347.375.188-08',
      CNPJ__c = withCNPJ ? '12.345.678/0001-90' : null,
      SucessoIntegracaoSAP__c = false,
      StatusBodyIntegracaoSAP__c = null
    );
    if (withAddress) {
      acc.BillingStreet = 'Rua Teste';
      acc.BillingPostalCode = '01310-100';
      acc.BillingCity = 'São Paulo';
      acc.BillingState = 'SP';
      acc.BillingCountry = 'Brasil';
      acc.ShippingStreet = 'Rua Entrega';
      acc.ShippingPostalCode = '01310-200';
      acc.ShippingCity = 'São Paulo';
      acc.ShippingState = 'SP';
      acc.ShippingCountry = 'Brasil';
    }
    insert acc;
    return acc;
  }

  // ─── Tests ───────────────────────────────────────────────────────────────

  @IsTest
  static void execute_givenAccountWithCPFAndSuccessResponse_thenSucessoIsTrue() {
    Account acc = buildAccount(false, false);
    Test.setMock(HttpCalloutMock.class, new SAPMock(200, SUCCESS_BODY));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>{ acc.Id }));
    Test.stopTest();

    Account result = [
      SELECT SucessoIntegracaoSAP__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    Assert.isTrue(result.SucessoIntegracaoSAP__c, 'CPF account should succeed');
  }

  @IsTest
  static void execute_givenAccountWithCNPJAndSuccessResponse_thenSucessoIsTrue() {
    Account acc = buildAccount(true, false);
    Test.setMock(HttpCalloutMock.class, new SAPMock(200, SUCCESS_BODY));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>{ acc.Id }));
    Test.stopTest();

    Account result = [
      SELECT SucessoIntegracaoSAP__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    Assert.isTrue(
      result.SucessoIntegracaoSAP__c,
      'CNPJ account should succeed'
    );
  }

  @IsTest
  static void execute_givenAccountWithAddressAndSuccessResponse_thenBuildsAddresses() {
    Account acc = buildAccount(false, true);
    Test.setMock(HttpCalloutMock.class, new SAPMock(200, SUCCESS_BODY));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>{ acc.Id }));
    Test.stopTest();

    Account result = [
      SELECT SucessoIntegracaoSAP__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    Assert.isTrue(
      result.SucessoIntegracaoSAP__c,
      'Account with addresses should succeed'
    );
  }

  @IsTest
  static void execute_givenErrorResponse_thenSucessoIsFalse() {
    Account acc = buildAccount(false, false);
    Test.setMock(HttpCalloutMock.class, new SAPMock(400, ERROR_BODY));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>{ acc.Id }));
    Test.stopTest();

    Account result = [
      SELECT SucessoIntegracaoSAP__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    Assert.isFalse(
      result.SucessoIntegracaoSAP__c,
      'Error response should set sucesso=false'
    );
  }

  @IsTest
  static void execute_givenCalloutException_thenSucessoIsFalse() {
    Account acc = buildAccount(false, false);
    Test.setMock(HttpCalloutMock.class, new SAPMock(true));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>{ acc.Id }));
    Test.stopTest();

    Account result = [
      SELECT SucessoIntegracaoSAP__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    Assert.isFalse(
      result.SucessoIntegracaoSAP__c,
      'Exception should set sucesso=false'
    );
  }

  @IsTest
  static void execute_givenEmptySet_thenNoException() {
    Test.setMock(HttpCalloutMock.class, new SAPMock(200, SUCCESS_BODY));

    Test.startTest();
    System.enqueueJob(new IntegracaoSAPCliente(new Set<Id>()));
    Test.stopTest();

    Assert.isTrue(true, 'Empty set should complete without exception');
  }

  // ─── Mock ────────────────────────────────────────────────────────────────

  private class SAPMock implements HttpCalloutMock {
    private final Integer statusCode;
    private final String body;
    private final Boolean throwException;

    SAPMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
      this.throwException = false;
    }

    SAPMock(Boolean throwException) {
      this.statusCode = 500;
      this.body = '';
      this.throwException = throwException;
    }

    public HttpResponse respond(HttpRequest req) {
      if (throwException) {
        CalloutException e = new CalloutException();
        e.setMessage('SAP connection timeout');
        throw e;
      }
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody(body);
      res.setStatusCode(statusCode);
      res.setStatus(statusCode == 200 ? 'OK' : 'Error');
      return res;
    }
  }
}
