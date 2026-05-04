/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class UtilsTest {
  @isTest
  static void callIntegrationNivelloTest() {
    Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

    Test.startTest();

    TokenAPINivelloWs.access_token = 'teste';

    ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = ProposalCover.id, Produto__c = 'Solar'),
      true
    );

    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = parceiro.id
      ),
      true
    );

    opportunity.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
    opportunity.EtapaViabilidade__c = 'Agendamento';
    update opportunity;

    Test.stopTest();
  }

  @isTest
  static void callIntegrationSAPTest() {
    Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

    Test.startTest();

    Account cliente = (Account) TestFactory.createSObject(new Account(), true);

    Test.stopTest();
  }

  @isTest
  static void createLogTest() {
    //	Exception
    try {
      Integer num = 5 / 0;
    } catch (Exception e) {
      Utils.createLog('UtilsTest', 'createLogTest', e);
    }

    //	RestRequest
    OpportunityEntryRestTest.makeData();
    OpportunityEntryRestTest.testCallout();

    //	HttpResponse
    callIntegrationNivelloTest();
  }

  @isTest
  static void notificacaoPersonalizadaTest() {
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(),
      true
    );

    Utils.notificacaoPersonalizada(
      'mensagem',
      'titulo',
      opportunity.Id,
      opportunity.Id
    );
  }

  @isTest
  static void createLogDtoTest() {
    Lead ld = new Lead(LastName = 'DTO Test', Company = 'N/A');
    insert ld;

    Utils.LogDTO dto = new Utils.LogDTO();
    dto.className = 'UtilsTest';
    dto.methodName = 'createLogDtoTest';
    dto.httpMethod = 'POST';
    dto.requestBody = '{"test":true}';
    dto.requestURI = '/test/uri';
    dto.responseBody = '{"ok":true}';
    dto.statusCode = 200;
    dto.status = 'OK';
    dto.message = 'teste';
    dto.typeName = 'System.DmlException';
    dto.stackTraceString = 'line 1';
    dto.lineNumber = '1';
    dto.relatedId = ld.Id;

    Test.startTest();
    Log__c lg = Utils.createLogNoInsert(dto);
    Assert.isNotNull(lg);
    Assert.areEqual('UtilsTest', lg.Class__c);
    Assert.areEqual(String.valueOf(ld.Id), lg.RelatedId__c);

    Utils.createLog(dto);

    Utils.createLog((Utils.LogDTO) null);
    Test.stopTest();
  }

  @isTest
  static void createLogFromJsonTest() {
    Utils.LogDTO dto = new Utils.LogDTO();
    dto.className = 'UtilsTest';
    dto.methodName = 'createLogFromJsonTest';
    dto.message = 'via json';

    String json = JSON.serialize(dto);

    Test.startTest();
    Utils.createLogFromJson(json);
    Utils.createLogFromJson('');
    Utils.createLogFromJson(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Log__c WHERE Method__c = 'createLogFromJsonTest']
    );
  }

  @isTest
  static void createLogNoInsertHttpRequestTest() {
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://example.com/api');
    req.setBody('body-content');

    Test.startTest();
    Log__c lg = Utils.createLogNoInsert('UtilsTest', 'httpRequestBranch', req);
    Test.stopTest();

    Assert.isNotNull(lg);
    Assert.areEqual('GET', lg.HTTPMethod__c);
    Assert.areEqual('https://example.com/api', lg.RequestURI__c);
  }

  @isTest
  static void getSAPMetadataNameTest() {
    Test.startTest();
    String result = Utils.getSAPMetadataName('SAP_Cliente');
    Test.stopTest();

    Assert.isNotNull(result);
    Assert.isTrue(
      result == 'SAP_Cliente' || result == 'SAP_Cliente_QA',
      'Nome deve ser base ou base_QA'
    );
  }

  @isTest
  static void createLogNoInsertWithRelatedIdTest() {
    Lead ld = new Lead(LastName = 'Teste', Company = 'N/A');
    insert ld;

    Test.startTest();
    Utils.createLog('UtilsTest', 'relatedIdBranch', 'msg', ld.Id);
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Log__c
        WHERE Method__c = 'relatedIdBranch' AND RelatedId__c = :ld.Id
      ]
    );
  }

  public class IntegracaoSAPExemploMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();

      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '	 {' +
          '		 "codigoHttp": "201",' +
          '		 "mensagem": "Inserido com sucesso",' +
          '		 "resultado": null' +
          '	 }'
      );
      res.setStatusCode(200);
      res.setStatus('OK');

      return res;
    }
  }

  public class IntegracaoNivelloMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();

      res.setHeader('Content-Type', 'application/json');
      res.setBody('	 {' + '		 "success": "true"' + '	 }');
      res.setStatusCode(200);
      res.setStatus('OK');

      return res;
    }
  }

  public class Mock401ThenOk implements HttpCalloutMock {
    private Integer callCount = 0;

    public HTTPResponse respond(HTTPRequest req) {
      callCount++;
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      if (callCount == 1) {
        res.setStatusCode(401);
        res.setStatus('Unauthorized');
        res.setBody('{"error":"unauthorized"}');
      } else {
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody('{"ok":true}');
      }
      return res;
    }
  }

  @isTest
  static void callIntegrationNivello401Test() {
    Test.setMock(HttpCalloutMock.class, new Mock401ThenOk());

    TokenAPINivelloWs.access_token = 'token-inicial';

    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://nivello.example.com/api');

    Test.startTest();
    HttpResponse res = Utils.callIntegrationNivello(req);
    Test.stopTest();

    Assert.isNotNull(res);
  }

  @isTest
  static void callIntegrationNivelloNoTokenTest() {
    Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

    TokenAPINivelloWs.access_token = null;

    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://nivello.example.com/api');

    Test.startTest();
    HttpResponse res = Utils.callIntegrationNivello(req);
    Test.stopTest();

    Assert.isNotNull(res);
  }

  @isTest
  static void callIntegrationVONoTokenTest() {
    Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

    TokenAPIVOWs.access_token = null;

    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://vo.example.com/api');

    Test.startTest();
    HttpResponse res = Utils.callIntegrationVO(req);
    Test.stopTest();

    Assert.isNotNull(res);
  }

  @isTest
  static void callIntegrationVOTest() {
    Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

    TokenAPIVOWs.access_token = 'token-vo-teste';

    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://vo.example.com/api');

    Test.startTest();
    HttpResponse res = Utils.callIntegrationVO(req);
    Test.stopTest();

    Assert.isNotNull(res);
    Assert.areEqual(200, res.getStatusCode());
  }

  @isTest
  static void callIntegrationVO401Test() {
    Test.setMock(HttpCalloutMock.class, new Mock401ThenOk());

    TokenAPIVOWs.access_token = 'token-vo-inicial';

    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('https://vo.example.com/api');

    Test.startTest();
    HttpResponse res = Utils.callIntegrationVO(req);
    Test.stopTest();

    Assert.isNotNull(res);
  }

  @isTest
  static void removeNonNumericCharactersTest() {
    Assert.areEqual('12345', Utils.removeNonNumericCharacters('(12) 3-45'));
    Assert.areEqual('55119', Utils.removeNonNumericCharacters('55119'));
    Assert.isNull(Utils.removeNonNumericCharacters(null));
    Assert.isNull(Utils.removeNonNumericCharacters(''));
    Assert.isNull(Utils.removeNonNumericCharacters('   '));
  }
}
