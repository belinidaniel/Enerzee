@IsTest
public with sharing class IntegracaoSAPRepresentanteTest {
  private static final String SUCCESS_RESPONSE = '{"codigoHttp": "201", "mensagem": "Inserido com sucesso", "resultado": null}';
  private static final String ERROR_RESPONSE = '{"codigoHttp": "400", "mensagem": "Erro de dados", "resultado": null}';

  public class SuccessMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody(SUCCESS_RESPONSE);
      res.setStatusCode(200);
      res.setStatus('OK');
      return res;
    }
  }

  public class ErrorMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody(ERROR_RESPONSE);
      res.setStatusCode(400);
      res.setStatus('Error');
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    // ConsultorDefaults sets RecordType = 'Consultor', required by ConsultorBO routing
    TestFactory.createSObject(new Consultor__c(), true);
  }

  @IsTest
  static void sendRepresentante_success() {
    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    Consultor__c consultor = [SELECT Id FROM Consultor__c LIMIT 1];

    Test.startTest();
    IntegracaoSAPRepresentante.sendRepresentante(new Set<Id>{ consultor.Id });
    Test.stopTest();

    Consultor__c result = [
      SELECT
        SucessoIntegracaoSAP__c,
        TipoErroIntegracaoSAP__c,
        StatusBodyIntegracaoSAP__c
      FROM Consultor__c
      WHERE Id = :consultor.Id
    ];

    Assert.areEqual(
      true,
      result.SucessoIntegracaoSAP__c,
      'Deve marcar sucesso na integração'
    );
    Assert.isNull(
      result.TipoErroIntegracaoSAP__c,
      'Tipo de erro deve ser nulo em sucesso'
    );
  }

  @IsTest
  static void sendRepresentante_sapError() {
    Test.setMock(HttpCalloutMock.class, new ErrorMock());

    Consultor__c consultor = [SELECT Id FROM Consultor__c LIMIT 1];

    Test.startTest();
    IntegracaoSAPRepresentante.sendRepresentante(new Set<Id>{ consultor.Id });
    Test.stopTest();

    Consultor__c result = [
      SELECT
        SucessoIntegracaoSAP__c,
        TipoErroIntegracaoSAP__c,
        StatusBodyIntegracaoSAP__c
      FROM Consultor__c
      WHERE Id = :consultor.Id
    ];

    Assert.areEqual(
      false,
      result.SucessoIntegracaoSAP__c,
      'Deve marcar falha quando SAP retorna erro'
    );
    Assert.areEqual(
      'Dados',
      result.TipoErroIntegracaoSAP__c,
      'Deve classificar erro HTTP do SAP como Dados'
    );
  }

  @IsTest
  static void sendRepresentante_bulk() {
    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    List<Consultor__c> consultores = new List<Consultor__c>();
    for (Integer i = 0; i < 5; i++) {
      consultores.add(
        (Consultor__c) TestFactory.createSObject(
          new Consultor__c(Name = 'Representante Bulk ' + i),
          false
        )
      );
    }
    insert consultores;

    Set<Id> ids = new Map<Id, Consultor__c>(consultores).keySet();

    Test.startTest();
    IntegracaoSAPRepresentante.sendRepresentante(ids);
    Test.stopTest();

    List<Consultor__c> results = [
      SELECT SucessoIntegracaoSAP__c
      FROM Consultor__c
      WHERE Id IN :ids
    ];

    for (Consultor__c r : results) {
      Assert.areEqual(
        true,
        r.SucessoIntegracaoSAP__c,
        'Todos devem ter sucesso no bulk'
      );
    }
  }
}
