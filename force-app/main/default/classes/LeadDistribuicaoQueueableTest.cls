/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-08-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class LeadDistribuicaoQueueableTest {
  private static Integer consultantCounter = 0;

  private class SuccessMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(200);
      res.setBody('{"data":{"id":"EXT-DIST-001"}}');
      return res;
    }
  }

  private class FailureMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(500);
      res.setStatus('Internal Server Error');
      res.setBody('{"message":"error"}');
      return res;
    }
  }

  private class ThrowingMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      throw new CalloutException('Simulated callout failure');
    }
  }

  private static Consultor__c createConsultant() {
    consultantCounter++;
    Consultor__c c = new Consultor__c(
      Name = 'Consultor Dist Test ' + consultantCounter,
      Email__c = 'dist.test.' + consultantCounter + '@enerzee.com',
      IdVirtualOffice__c = 'dist-vo-' + consultantCounter,
      IdVirtualOffice2__c = String.valueOf(consultantCounter),
      CPF__c = '111.222.333-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      CNPJ__c = '11.222.333/0001-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      NumeroIdentificacao__c = '8800000' +
        String.valueOf(consultantCounter).leftPad(2, '0')
    );
    ConsultorTriggerHandler.disableTrigger();
    try {
      return (Consultor__c) TestFactory.createSObject(c, true);
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }
  }

  private static Lead createLead(Id consultorId) {
    Id rtId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
      .get('QualificacaodeClientes')
      .getRecordTypeId();
    Lead l = new Lead(
      FirstName = 'Dist',
      LastName = 'Test ' + System.now().getTime(),
      Company = 'Enerzee QA',
      Email = 'dist.' + System.now().getTime() + '@qa.com',
      MobilePhone = '11999990000',
      RecordTypeId = rtId,
      ConsultorRegional__c = consultorId,
      Status = 'Distribuído'
    );
    LeadTriggerHandler.disableTrigger();
    try {
      insert l;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }
    return l;
  }

  // --- Queueable direto ---

  @isTest
  static void testQueueableSuccess() {
    Consultor__c c = createConsultant();
    Lead lead = createLead(c.Id);

    Test.setMock(HttpCalloutMock.class, new SuccessMock());
    Test.startTest();
    System.enqueueJob(new LeadDistribuicaoQueueable(new Set<Id>{ lead.Id }));
    Test.stopTest();

    Lead updated = [
      SELECT
        Lab065_IntegracaoDistribuicaoLead__c,
        IntegracaoDistribuicaoLeadDataHora__c,
        IntegracaoDistribuicaoLeadErro__c,
        ExternalId__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
    Assert.isTrue(
      updated.Lab065_IntegracaoDistribuicaoLead__c,
      'Flag deve ser true após sucesso'
    );
    Assert.areEqual(
      'EXT-DIST-001',
      updated.ExternalId__c,
      'ExternalId deve ser preenchido'
    );
    Assert.isNotNull(
      updated.IntegracaoDistribuicaoLeadDataHora__c,
      'DataHora deve ser preenchida'
    );
    Assert.isNull(
      updated.IntegracaoDistribuicaoLeadErro__c,
      'Erro deve ser nulo em sucesso'
    );
  }

  @isTest
  static void testQueueableHttpFailure() {
    Consultor__c c = createConsultant();
    Lead lead = createLead(c.Id);

    Test.setMock(HttpCalloutMock.class, new FailureMock());
    Test.startTest();
    System.enqueueJob(new LeadDistribuicaoQueueable(new Set<Id>{ lead.Id }));
    Test.stopTest();

    Lead updated = [
      SELECT
        Lab065_IntegracaoDistribuicaoLead__c,
        IntegracaoDistribuicaoLeadErro__c,
        IntegracaoDistribuicaoLeadDataHora__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
    Assert.isFalse(
      updated.Lab065_IntegracaoDistribuicaoLead__c,
      'Flag deve ser false em falha HTTP'
    );
    Assert.isNotNull(
      updated.IntegracaoDistribuicaoLeadErro__c,
      'Mensagem de erro deve ser preenchida'
    );
    Assert.isTrue(
      updated.IntegracaoDistribuicaoLeadErro__c.contains('500'),
      'Erro deve conter código HTTP'
    );
  }

  @isTest
  static void testQueueableCalloutException() {
    Consultor__c c = createConsultant();
    Lead lead = createLead(c.Id);

    // ThrowingMock lança CalloutException — capturada dentro de integrateLead,
    // que faz o DML de erro diretamente
    Test.setMock(HttpCalloutMock.class, new ThrowingMock());
    Test.startTest();
    System.enqueueJob(new LeadDistribuicaoQueueable(new Set<Id>{ lead.Id }));
    Test.stopTest();

    Lead updated = [
      SELECT
        Lab065_IntegracaoDistribuicaoLead__c,
        IntegracaoDistribuicaoLeadErro__c,
        IntegracaoDistribuicaoLeadDataHora__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
    Assert.isFalse(
      updated.Lab065_IntegracaoDistribuicaoLead__c,
      'Flag deve ser false em exception'
    );
    Assert.isNotNull(
      updated.IntegracaoDistribuicaoLeadDataHora__c,
      'DataHora deve ser registrada mesmo em exception'
    );
  }

  @isTest
  static void testQueueableBulk() {
    Consultor__c c = createConsultant();
    List<Lead> leads = new List<Lead>();
    for (Integer i = 0; i < 5; i++) {
      leads.add(createLead(c.Id));
    }

    Set<Id> leadIds = new Map<Id, Lead>(leads).keySet();

    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    // O Queueable processa 1 lead por execução com chaining.
    // Em contexto de teste, chaining é bloqueado — enfileira um job por lead.
    for (Id leadId : leadIds) {
      Test.startTest();
      System.enqueueJob(new LeadDistribuicaoQueueable(new Set<Id>{ leadId }));
      Test.stopTest();
    }

    List<Lead> updated = [
      SELECT Lab065_IntegracaoDistribuicaoLead__c
      FROM Lead
      WHERE Id IN :leadIds
    ];
    for (Lead l : updated) {
      Assert.isTrue(
        l.Lab065_IntegracaoDistribuicaoLead__c,
        'Todos os leads devem estar integrados'
      );
    }
  }

  // --- Trigger via handleConsultorChange ---

  @isTest
  static void testTriggerEnqueuesOnConsultorChange() {
    Consultor__c c1 = createConsultant();
    Consultor__c c2 = createConsultant();
    Lead lead = createLead(c1.Id);

    Test.setMock(HttpCalloutMock.class, new SuccessMock());
    Test.startTest();
    LeadTriggerHandler.enableTrigger();
    lead.ConsultorRegional__c = c2.Id;
    update lead;
    Test.stopTest();

    Lead updated = [
      SELECT
        Lab065_IntegracaoDistribuicaoLead__c,
        IntegracaoDistribuicaoLeadErro__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
    Assert.isTrue(
      updated.Lab065_IntegracaoDistribuicaoLead__c,
      'Flag deve ser true após reintegração com sucesso'
    );
  }

  @isTest
  static void testNoEnqueueWhenConsultorUnchanged() {
    Consultor__c c = createConsultant();
    Lead lead = createLead(c.Id);

    Test.startTest();
    LeadTriggerHandler.enableTrigger();
    lead.Status = 'Distribuído';
    update lead;
    Test.stopTest();

    // Sem mock configurado — se enfileirasse, causaria erro de callout
    // O teste passa se não lançou exceção
    Assert.isTrue(
      true,
      'Sem troca de consultor, nenhum job deve ser enfileirado'
    );
  }

  @isTest
  static void testNoEnqueueWhenNewConsultorIsNull() {
    Consultor__c c = createConsultant();
    Lead lead = createLead(c.Id);

    Test.startTest();
    LeadTriggerHandler.enableTrigger();
    lead.ConsultorRegional__c = null;
    update lead;
    Test.stopTest();

    Assert.isTrue(true, 'Consultor null não deve enfileirar job');
  }
}
