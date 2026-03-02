@isTest
private class IntegracaoVOClientePreCadastroTest {
  @isTest
  static void testSendCliente() {
    Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
    TokenAPIVOWs.access_token = 'test-token';

    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Teste',
      Login_no_virtual__c = 'consultor@teste.com',
      IdVirtualOffice2__c = '14'
    );

    insert consultor;

    Account acc = new Account(
      Name = 'Cliente Teste',
      Email__c = 'cliente@teste.com',
      DataNascimento__c = Date.newInstance(1990, 5, 15),
      CPF__c = '123.456.789-00',
      ShippingStreet = 'Rua Teste',
      NumeroRuaEntrega__c = '123',
      ShippingPostalCode = '12345000',
      ComplementoEntrega__c = 'Apto 101',
      Consultor__c = consultor.id
    );

    insert acc;

    Set<Id> triggerIds = new Set<Id>{ acc.Id };

    Test.startTest();
    IntegracaoVOClientePreCadastro.sendCliente(triggerIds);
    Test.stopTest();

    acc = [
      SELECT
        Id,
        SucessoIntegracaoVO__c,
        StatusBodyIntegracaoVO__c,
        IdVirtualOffice2__c,
        LoginVirtualOffice__c
      FROM Account
      WHERE Id = :acc.Id
    ];

    System.assertEquals(
      true,
      acc.SucessoIntegracaoVO__c,
      'A integração não foi bem-sucedida'
    );
  }

  @isTest
  static void testSendClienteWithException() {
    TokenAPIVOWs.access_token = 'test-token';

    Account acc = new Account(
      Name = 'Cliente Teste Erro',
      Email__c = 'erro@teste.com',
      CPF__c = '123.456.789-00'
    );

    insert acc;

    Set<Id> triggerIds = new Set<Id>{ acc.Id };

    Test.startTest();
    try {
      IntegracaoVOClientePreCadastro.sendCliente(triggerIds);
    } catch (Exception e) {
      System.debug('Erro esperado: ' + e.getMessage());
    }
    Test.stopTest();

    acc = [
      SELECT Id, SucessoIntegracaoVO__c, StatusBodyIntegracaoVO__c
      FROM Account
      WHERE Id = :acc.Id
    ];

    System.assertEquals(
      false,
      acc.SucessoIntegracaoVO__c,
      'A integração deveria registrar falha sem mock de callout.'
    );
  }
}
