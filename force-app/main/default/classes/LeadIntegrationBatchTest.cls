/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public class LeadIntegrationBatchTest {
  private class IntegrationSuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"data":{"id":"EXT-LEAD-001"}}');
      return response;
    }
  }

  @IsTest
  static void shouldCoverStartExecuteAndFinish() {
    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Batch',
      IdVirtualOffice__c = 'lead-int-vo-batch',
      IdVirtualOffice2__c = '91'
    );

    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultor;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    Lead leadRecord = new Lead(
      FirstName = 'Batch',
      LastName = 'Lead',
      Company = 'Acme Corp',
      Email = 'lead.batch.' + System.now().getTime() + '@teste.com',
      CPFCNPJ__c = '12345678901',
      Lb065_FaturaEnergia__c = 1000,
      Phone = '1133334444',
      MobilePhone = '11999999999',
      Lb065_ProdutoInteresse__c = 'Ezee Solar',
      Lb065_HistoricoLead__c = 'Historico...',
      Lb065_Estado__c = 'MT',
      LeadSource = 'Nivello',
      Title = 'Sr.',
      Street = 'Rua A',
      City = 'Cidade B',
      Country = 'Brasil',
      InteresseEnergiaRenovavel__c = null,
      InteresseEnergiaSolar__c = null,
      TipoDeImovel__c = 'com telhado fibrocimento',
      CustoEnergiaMes__c = 'até R$ 300',
      ValorContaEnergia__c = 'Até R$ 200',
      Rating = 'Hot',
      Mensagem__c = 'Msg',
      Complemento__c = 'Comp',
      PostalCode = '12345-678',
      Status = 'Distribuído',
      Lab065_IntegracaoDistribuicaoLead__c = false,
      ConsultorRegional__c = consultor.Id,
      RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName()
        .get('Qualificação de Clientes')
        .getRecordTypeId()
    );

    LeadTriggerHandler.disableTrigger();
    try {
      insert leadRecord;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Lead scopeLead = [
      SELECT Id
      FROM Lead
      WHERE Id = :leadRecord.Id
      LIMIT 1
    ];

    Test.setMock(HttpCalloutMock.class, new IntegrationSuccessMock());

    Test.startTest();
    LeadIntegrationBatch batch = new LeadIntegrationBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(null, new List<SObject>{ scopeLead });
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(
      null,
      locator,
      'O start do batch deve retornar um QueryLocator valido.'
    );
  }
}
