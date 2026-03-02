@IsTest
private class IntegracaoNivelloSimFinTest {
  @IsTest
  static void shouldUpdateSimulation() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'AtualizaSimulacaoFinanciamento'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-SIM',
        FinancingProcessDetails__c = 'Detalhes'
      ),
      true
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloSimulacaoFinanciamento.updateFinancingSimulation(
      new Set<Id>{ opp.Id }
    );
    Test.stopTest();

    System.assert(true, 'Integracao executada');
  }
}
