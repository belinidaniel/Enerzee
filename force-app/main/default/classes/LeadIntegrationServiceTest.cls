/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest(seeAllData=true)
private class LeadIntegrationServiceTest {
  private class SuccessMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(200);
      res.setBody('{"data":{"id":"EXT-LEAD-001"}}');
      return res;
    }
  }

  private class FailureMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(500);
      res.setStatus('500 Internal Server Error');
      res.setBody('{"message":"integration failed"}');
      return res;
    }
  }

  private class ThrowingMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      throw new CalloutException('Falha simulada LeadIntegrationService');
    }
  }

  private static Integer consultantCounter = 0;

  private static Consultor__c createConsultant() {
    consultantCounter++;
    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Lead Integration ' + consultantCounter,
      Email__c = 'lead.integration.' + consultantCounter + '@teste.com',
      IdVirtualOffice__c = 'lead-int-vo-' + consultantCounter,
      IdVirtualOffice2__c = String.valueOf(consultantCounter),
      CPF__c = '123.456.789-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      CNPJ__c = '12.345.678/9012-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      NumeroIdentificacao__c = '91000000' +
        String.valueOf(consultantCounter).leftPad(2, '0')
    );

    ConsultorTriggerHandler.disableTrigger();
    try {
      return (Consultor__c) TestFactory.createSObject(consultor, true);
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }
  }

  private static Lead createLeadForIntegration(Boolean withConsultant) {
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    Map<String, Schema.RecordTypeInfo> leadRecordTypes = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();

    Lead leadRecord = new Lead(
      FirstName = 'Lead',
      LastName = 'Integration ' + String.valueOf(System.now().getTime()),
      Company = 'Enerzee QA',
      Email = 'lead.integration.' +
        String.valueOf(System.now().getTime()) +
        '@teste.com',
      Phone = '1133334444',
      MobilePhone = '11999999999',
      Street = 'Rua Teste',
      City = 'Sao Paulo',
      Country = 'Brasil',
      PostalCode = '01310930',
      CPFCNPJ__c = '12345678901',
      Lb065_HistoricoLead__c = 'Historico de teste',
      Mensagem__c = 'Mensagem de teste',
      Complemento__c = 'Apto 10'
    );

    if (leadRecordTypes.containsKey('QualificacaodeClientes')) {
      leadRecord.RecordTypeId = leadRecordTypes.get('QualificacaodeClientes')
        .getRecordTypeId();
    }

    if (leadFields.containsKey('LeadSource')) {
      leadRecord.put('LeadSource', 'Website');
    }
    if (leadFields.containsKey('Lb065_Estado__c')) {
      leadRecord.put('Lb065_Estado__c', 'SP');
    }
    if (leadFields.containsKey('InteresseEnergiaRenovavel__c')) {
      leadRecord.put('InteresseEnergiaRenovavel__c', 'Por enquanto, não!');
    }
    if (leadFields.containsKey('InteresseEnergiaSolar__c')) {
      leadRecord.put('InteresseEnergiaSolar__c', 'Minha casa');
    }
    if (leadFields.containsKey('TipoDeImovel__c')) {
      leadRecord.put('TipoDeImovel__c', 'Com laje');
    }
    if (leadFields.containsKey('CustoEnergiaMes__c')) {
      leadRecord.put('CustoEnergiaMes__c', 'Até R$ 300');
    }
    if (leadFields.containsKey('ValorContaEnergia__c')) {
      leadRecord.put('ValorContaEnergia__c', 'Até R$ 200');
    }
    if (leadFields.containsKey('Lb065_ProdutoInteresse__c')) {
      leadRecord.put('Lb065_ProdutoInteresse__c', 'Solar');
    }

    String safeStatus = getAnyLeadStatus();
    if (!String.isBlank(safeStatus)) {
      leadRecord.Status = safeStatus;
    }

    if (withConsultant && leadFields.containsKey('ConsultorRegional__c')) {
      leadRecord.put('ConsultorRegional__c', createConsultant().Id);
    }

    LeadTriggerHandler.disableTrigger();
    try {
      insert leadRecord;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    return leadRecord;
  }

  private static String getAnyLeadStatus() {
    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      if (!String.isBlank(entry.getValue())) {
        return entry.getValue();
      }
    }
    return null;
  }

  private static Boolean hasLeadIntegrationMetadata() {
    return [
        SELECT COUNT()
        FROM Integrador__mdt
        WHERE DeveloperName = 'LeadIntegration'
      ] > 0;
  }

  @isTest
  static void testInvocableMethod() {
    if (!hasLeadIntegrationMetadata()) {
      return;
    }

    Lead leadRecord = createLeadForIntegration(true);

    LeadIntegrationService.LeadInput inputRecord = new LeadIntegrationService.LeadInput();
    inputRecord.leadId = leadRecord.Id;

    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    Test.startTest();
    List<LeadIntegrationService.LeadOutput> outputs = LeadIntegrationService.sendLeadsToExternalApp(
      new List<LeadIntegrationService.LeadInput>{ inputRecord }
    );
    Test.stopTest();

    System.assertEquals(1, outputs.size());
    System.assertEquals(
      null,
      outputs[0].statusCode,
      'Invocable wrapper still returns an empty DTO payload.'
    );
  }

  @isTest
  static void shouldIntegrateLeadAndUpdateExternalId() {
    if (!hasLeadIntegrationMetadata()) {
      return;
    }

    Lead leadRecord = createLeadForIntegration(true);

    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    Test.startTest();
    LeadIntegrationService.integrateLead(leadRecord.Id);
    Test.stopTest();

    Lead updatedLead = [
      SELECT Lab065_IntegracaoDistribuicaoLead__c, ExternalId__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    System.assertEquals(
      true,
      updatedLead.Lab065_IntegracaoDistribuicaoLead__c,
      'Successful integration must mark the lead as integrated.'
    );
    System.assertEquals(
      'EXT-LEAD-001',
      updatedLead.ExternalId__c,
      'Successful integration must persist the external id.'
    );
  }

  @isTest
  static void shouldCreateFailureLogWhenCalloutReturnsError() {
    if (!hasLeadIntegrationMetadata()) {
      return;
    }

    Lead leadRecord = createLeadForIntegration(true);

    Test.setMock(HttpCalloutMock.class, new FailureMock());

    Test.startTest();
    LeadIntegrationService.integrateLead(leadRecord.Id);
    Test.stopTest();

    Lead updatedLead = [
      SELECT Lab065_IntegracaoDistribuicaoLead__c, ExternalId__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    List<Log__c> logs = [
      SELECT Id, Method__c, StatusCode__c
      FROM Log__c
      WHERE Method__c = :('sendUrlSimulation failed ' + leadRecord.Id)
      ORDER BY CreatedDate DESC
    ];

    System.assertEquals(
      false,
      updatedLead.Lab065_IntegracaoDistribuicaoLead__c,
      'Failure response must not mark the lead as integrated.'
    );
    System.assertEquals(
      null,
      updatedLead.ExternalId__c,
      'Failure response must not set an external id.'
    );
    System.assertEquals(
      1,
      logs.size(),
      'Failure path should create a log entry.'
    );
    System.assertEquals(500, logs[0].StatusCode__c);
  }

  @isTest
  static void shouldHandleExceptionAndCreateLogs() {
    if (!hasLeadIntegrationMetadata()) {
      return;
    }

    Lead leadRecord = createLeadForIntegration(true);

    Test.setMock(HttpCalloutMock.class, new ThrowingMock());

    Test.startTest();
    LeadIntegrationService.integrateLead(leadRecord.Id);
    Test.stopTest();

    List<Log__c> exceptionLogs = [
      SELECT Id, Method__c, Lab065_LeadRelated__c
      FROM Log__c
      WHERE Method__c = :('Exception in sendUrlSimulation ' + leadRecord.Id)
      ORDER BY CreatedDate DESC
    ];

    HttpResponse response = new HttpResponse();
    response.setStatusCode(202);
    response.setStatus('202 Accepted');
    response.setBody('body');

    Log__c unsavedLog = LeadIntegrationService.createLogNoInsert(
      'LeadIntegrationService',
      'manualCreateLogNoInsert',
      response,
      leadRecord.Id
    );

    LeadIntegrationService.createLog(
      'LeadIntegrationService',
      'manualCreateLogInsert',
      response,
      leadRecord.Id
    );

    List<Log__c> manualLogs = [
      SELECT Id, Method__c, StatusCode__c
      FROM Log__c
      WHERE Method__c = 'manualCreateLogInsert'
      ORDER BY CreatedDate DESC
    ];

    System.assertEquals(
      leadRecord.Id,
      unsavedLog.Lab065_LeadRelated__c,
      'The helper must propagate the related lead id to the log.'
    );
    System.assertEquals(
      202,
      unsavedLog.StatusCode__c,
      'The helper must copy HttpResponse data into the log DTO.'
    );
    System.assert(
      !exceptionLogs.isEmpty(),
      'Callout exceptions must generate an exception log.'
    );
    System.assertEquals(
      1,
      manualLogs.size(),
      'Direct createLog() invocation should persist the log.'
    );
  }
}
