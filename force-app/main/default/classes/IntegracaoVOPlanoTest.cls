/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 02-13-2026
 * @last modified by	 : GPT-5 Codex
 **/
@isTest
private class IntegracaoVOPlanoTest {
  @isTest
  static void testSendPlanoReprocessesAccountWithoutVirtualOfficeId() {
    Test.setMock(HttpCalloutMock.class, new SuccessAccountAndOpportunityMock());
    TokenAPIVOWs.access_token = 'test-token';

    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Teste',
      Login_no_virtual__c = 'consultor@teste.com',
      IdVirtualOffice2__c = '14'
    );
    insert consultor;

    Account accountRecord = new Account(
      Name = 'Cliente Teste',
      Email__c = 'cliente@teste.com',
      DataNascimento__c = Date.newInstance(1990, 5, 15),
      CPF__c = '123.456.789-00',
      ShippingStreet = 'Rua Teste',
      NumeroRuaEntrega__c = '123',
      ShippingPostalCode = '12345000',
      ComplementoEntrega__c = 'Apto 101',
      Consultor__c = consultor.Id
    );
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Oportunidade Teste',
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = '0000000000000000000',
      RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Solar')
        .getRecordTypeId(),
      paymentMethod__c = 'PIX',
      PotenciaPicoSistema__c = 5,
      StageName = 'Ganho fechado',
      CloseDate = Date.today()
    );
    insert opportunityRecord;

    Test.startTest();
    IntegracaoVOPlano.sendPlano(new Set<Id>{ opportunityRecord.Id });
    Test.stopTest();

    accountRecord = [
      SELECT IdVirtualOffice2__c, SucessoIntegracaoVO__c
      FROM Account
      WHERE Id = :accountRecord.Id
    ];
    opportunityRecord = [
      SELECT IdVirtualOffice__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    System.assertEquals(
      '98765',
      accountRecord.IdVirtualOffice2__c,
      'Account deve ser sincronizada antes do envio de oportunidade.'
    );
    System.assertEquals(
      true,
      accountRecord.SucessoIntegracaoVO__c,
      'Status de integração da Account deve ser sucesso.'
    );
    System.assertEquals(
      'OPP-VO-123',
      opportunityRecord.IdVirtualOffice__c,
      'Opportunity deve receber ID retornado pelo VO.'
    );

    Integer logsCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        Class__c = 'VOIntegrationService'
        AND Method__c = 'sendPlano'
        AND RelatedId__c = :opportunityRecord.Id
    ];

    System.assertEquals(
      1,
      logsCount,
      'Deve existir log de envio da Opportunity para VO.'
    );
  }

  @isTest
  static void testSendPlanoShouldNotSkipClosedWonWhenOpportunityAlreadyHasExternalId() {
    Test.setMock(HttpCalloutMock.class, new SuccessAccountAndOpportunityMock());
    TokenAPIVOWs.access_token = 'test-token';

    Account accountRecord = new Account(
      Name = 'Cliente Com ID',
      IdVirtualOffice2__c = '2222'
    );
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Oportunidade Com ID',
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = 'OPP-EXISTENTE',
      RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Solar')
        .getRecordTypeId(),
      StageName = 'Ganho fechado',
      CloseDate = Date.today()
    );
    insert opportunityRecord;

    Test.startTest();
    IntegracaoVOPlano.sendPlano(new Set<Id>{ opportunityRecord.Id });
    Test.stopTest();

    opportunityRecord = [
      SELECT IdVirtualOffice__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    List<Log__c> sendLogs = [
      SELECT Message__c, StatusCode__c
      FROM Log__c
      WHERE
        Class__c = 'VOIntegrationService'
        AND Method__c = 'sendPlano'
        AND RelatedId__c = :opportunityRecord.Id
    ];

    System.assert(
      !sendLogs.isEmpty(),
      'O envio em Ganho fechado deve ocorrer mesmo quando a Opportunity já possui IdVirtualOffice__c.'
    );
    System.assert(
      !hasLogMessagePrefix(sendLogs, 'SKIPPED_ALREADY_SYNCED:'),
      'Não deve pular envio em Ganho fechado apenas por IdVirtualOffice__c já preenchido.'
    );
    System.assertEquals(
      'OPP-EXISTENTE',
      opportunityRecord.IdVirtualOffice__c,
      'Id externo da Opportunity deve ser preservado.'
    );
  }

  @isTest
  static void testSendPlanoLogsPreconditionWhenAccountSyncFails() {
    Test.setMock(HttpCalloutMock.class, new AccountFailureMock());
    TokenAPIVOWs.access_token = 'test-token';

    Account accountRecord = new Account(Name = 'Cliente Sem ID');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Oportunidade Sem Sync',
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = '0000000000000000000',
      RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Solar')
        .getRecordTypeId(),
      StageName = 'Ganho fechado',
      CloseDate = Date.today()
    );
    insert opportunityRecord;

    Test.startTest();
    IntegracaoVOPlano.sendPlano(new Set<Id>{ opportunityRecord.Id });
    Test.stopTest();

    accountRecord = [
      SELECT IdVirtualOffice2__c, SucessoIntegracaoVO__c
      FROM Account
      WHERE Id = :accountRecord.Id
    ];
    opportunityRecord = [
      SELECT IdVirtualOffice__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    System.assertEquals(
      null,
      accountRecord.IdVirtualOffice2__c,
      'Account deve continuar sem ID quando pré-cadastro falha.'
    );
    System.assertEquals(
      false,
      accountRecord.SucessoIntegracaoVO__c,
      'Account deve registrar falha de integração.'
    );
    System.assertEquals(
      false,
      VOIntegrationService.hasSyncedOpportunityVoId(
        opportunityRecord.IdVirtualOffice__c
      ),
      'Opportunity não deve receber ID sem sincronização da Account.'
    );

    List<Log__c> blockedLogs = [
      SELECT Message__c
      FROM Log__c
      WHERE
        Class__c = 'VOIntegrationService'
        AND Method__c = 'sendPlano'
        AND RelatedId__c = :opportunityRecord.Id
    ];

    System.assert(
      hasLogMessagePrefix(blockedLogs, 'PRECONDITION_FAILED:'),
      'Deve registrar no log o bloqueio por falha na sincronização da Account.'
    );
  }

  private static Boolean hasLogMessagePrefix(List<Log__c> logs, String prefix) {
    if (logs == null || logs.isEmpty() || String.isBlank(prefix)) {
      return false;
    }

    for (Log__c logRecord : logs) {
      if (
        logRecord != null &&
        String.isNotBlank(logRecord.Message__c) &&
        logRecord.Message__c.startsWith(prefix)
      ) {
        return true;
      }
    }

    return false;
  }

  private class SuccessAccountAndOpportunityMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      String body = request != null ? request.getBody() : null;

      if (body != null && body.contains('IdAccountSalesForce')) {
        response.setBody('{"erro": false, "idusuario": "98765"}');
        response.setStatusCode(200);
        return response;
      }

      if (body != null && body.contains('idplano')) {
        response.setBody('{"erro": false, "id": "OPP-VO-123"}');
        response.setStatusCode(200);
        return response;
      }

      response.setBody(
        '{"access_token":"abc","token_type":"bearer","expires_in":3600}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  private class AccountFailureMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      String body = request != null ? request.getBody() : null;

      if (body != null && body.contains('IdAccountSalesForce')) {
        response.setBody('{"erro": true, "retorno": "Cliente inválido"}');
        response.setStatusCode(200);
        return response;
      }

      response.setBody('{"erro": false}');
      response.setStatusCode(200);
      return response;
    }
  }
}
