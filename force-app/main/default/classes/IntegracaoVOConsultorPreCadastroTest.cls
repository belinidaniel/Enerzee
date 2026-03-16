/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class IntegracaoVOConsultorPreCadastroTest {
  private class MockVirtualOfficeErrorWS implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"erro": true, "retorno": "Falha de validação"}');
      return res;
    }
  }

  private class ThrowingCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      throw new CalloutException('Falha simulada na integração');
    }
  }

  private static Lead buildSafeLead(String lastName, String company) {
    Lead leadRecord = new Lead(LastName = lastName, Company = company);
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    Map<String, Schema.RecordTypeInfo> leadRecordTypes = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();

    if (leadRecordTypes.containsKey('QualificacaodeConsultores')) {
      leadRecord.RecordTypeId = leadRecordTypes.get('QualificacaodeConsultores')
        .getRecordTypeId();
    }

    if (leadFields.containsKey('FalarComAgente__c')) {
      leadRecord.put('FalarComAgente__c', true);
    }

    if (leadFields.containsKey('LeadSource')) {
      leadRecord.put('LeadSource', 'Web-To-Lead Integrador');
    }

    if (leadFields.containsKey('Lb065_ProdutoInteresse__c')) {
      leadRecord.put('Lb065_ProdutoInteresse__c', 'Solar');
    }

    if (leadFields.containsKey('CustoEnergiaMes__c')) {
      leadRecord.put('CustoEnergiaMes__c', 'até R$ 300');
    }

    String safeStatus = getLeadStatusExcluding(
      new Set<String>{ 'Novo', 'Qualified', 'Não Qualificado' }
    );
    if (!String.isBlank(safeStatus)) {
      leadRecord.Status = safeStatus;
    }

    return leadRecord;
  }

  private static String getLeadStatusExcluding(Set<String> excludedStatuses) {
    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      String value = entry.getValue();
      if (String.isBlank(value) || excludedStatuses.contains(value)) {
        continue;
      }
      return value;
    }

    return null;
  }

  @isTest
  static void testSendConsultor() {
    Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());

    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Pai Teste',
      Login_no_virtual__c = 'consultorPai@teste.com',
      IdVirtualOffice2__c = '14'
    );

    insert consultor;

    Lead lead = buildSafeLead('Teste', 'Lead Teste');
    lead.FirstName = 'Lead';
    lead.Email = 'consultor@teste.com';
    lead.DataNascimento__c = Date.newInstance(1990, 5, 15);
    lead.CPFCNPJ__c = '123.456.789-00';
    lead.street = 'Rua Teste';
    lead.streetNumber__c = '123';
    lead.postalCode = '12345000';
    lead.complemento__c = 'Apto 101';
    lead.ConsultorRegional__c = consultor.id;

    LeadTriggerHandler.disableTrigger();
    try {
      insert lead;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Set<Id> triggerIds = new Set<Id>{ lead.Id };

    Test.startTest();
    IntegracaoVOConsultorPreCadastro.sendConsultor(triggerIds);
    Test.stopTest();

    lead = [
      SELECT
        Id,
        SucessoIntegracaoVO__c,
        StatusBodyIntegracaoVO__c,
        IdVirtualOffice__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    System.assertEquals(
      true,
      lead.SucessoIntegracaoVO__c,
      'A integração não foi bem-sucedida'
    );
  }

  @isTest
  static void testSendConsultorWithException() {
    Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Pai Excecao',
      Login_no_virtual__c = 'consultor.exception@teste.com',
      IdVirtualOffice2__c = '18'
    );
    insert consultor;

    Lead lead = buildSafeLead('Teste Erro', 'Lead Teste');
    lead.FirstName = 'Consultor';
    lead.Email = 'erro@teste.com';
    lead.CPFCNPJ__c = '123.456.789-00';
    lead.ConsultorRegional__c = consultor.Id;

    LeadTriggerHandler.disableTrigger();
    try {
      insert lead;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Set<Id> triggerIds = new Set<Id>{ lead.Id };

    Test.startTest();
    IntegracaoVOConsultorPreCadastro.sendConsultor(triggerIds);
    Test.stopTest();

    lead = [
      SELECT
        Id,
        SucessoIntegracaoVO__c,
        StatusBodyIntegracaoVO__c,
        ErrorIntegracaoVO__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    System.assertEquals(
      false,
      lead.SucessoIntegracaoVO__c,
      'A integração não foi bem-sucedida'
    );
    System.assertEquals(
      'Erro desconhecido na integração com Virtual Office',
      lead.ErrorIntegracaoVO__c
    );
  }

  @isTest
  static void testSendConsultorWithBusinessErrorResponse() {
    Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeErrorWS());

    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Pai Erro',
      Login_no_virtual__c = 'consultor.error@teste.com',
      IdVirtualOffice2__c = '19'
    );
    insert consultor;

    Lead lead = buildSafeLead('Teste Regra', 'Lead Regra');
    lead.FirstName = 'Consultor';
    lead.Email = 'regra@teste.com';
    lead.CPFCNPJ__c = '987.654.321-00';
    lead.ConsultorRegional__c = consultor.Id;
    lead.DataNascimento__c = null;

    LeadTriggerHandler.disableTrigger();
    try {
      insert lead;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Test.startTest();
    IntegracaoVOConsultorPreCadastro.sendConsultor(new Set<Id>{ lead.Id });
    Test.stopTest();

    lead = [
      SELECT
        SucessoIntegracaoVO__c,
        ErrorIntegracaoVO__c,
        StatusBodyIntegracaoVO__c,
        IdVirtualOffice__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    System.assertEquals(
      false,
      lead.SucessoIntegracaoVO__c,
      'Resposta de negócio com erro deve manter a sincronização como falha.'
    );
    System.assertEquals('Falha de validação', lead.ErrorIntegracaoVO__c);
    System.assertEquals(
      null,
      lead.IdVirtualOffice__c,
      'Quando a integração retorna erro não deve preencher o Id externo.'
    );
  }
}
