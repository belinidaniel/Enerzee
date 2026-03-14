@isTest
private class IntegracaoVOConsultorPreCadastroTest {
  private static Lead buildSafeLead(String lastName, String company) {
    Lead leadRecord = new Lead(LastName = lastName, Company = company);
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();

    if (leadFields.containsKey('FalarComAgente__c')) {
      leadRecord.put('FalarComAgente__c', true);
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

    insert lead;

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
    Lead lead = buildSafeLead('Teste Erro', 'Lead Teste');
    lead.FirstName = 'Consultor';
    lead.Email = 'erro@teste.com';
    lead.CPFCNPJ__c = '123.456.789-00';

    insert lead;

    Set<Id> triggerIds = new Set<Id>{ lead.Id };

    Test.startTest();
    try {
      IntegracaoVOClientePreCadastro.sendCliente(triggerIds);
    } catch (Exception e) {
      System.debug('Erro esperado: ' + e.getMessage());
    }
    Test.stopTest();

    lead = [
      SELECT Id, SucessoIntegracaoVO__c, StatusBodyIntegracaoVO__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    System.assertEquals(
      false,
      lead.SucessoIntegracaoVO__c,
      'A integração não foi bem-sucedida'
    );
  }
}
