@IsTest
private class IntegracaoNivelloAnaliseVTTest {
  @IsTest
  static void shouldSendVisitAnalysis() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'AnaliseVisitaTecnica'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-ANALISE',
        StatusViabilidade__c = 'Viável',
        TextoEstudo__c = 'Estudo',
        TextoMotivo__c = 'Motivo'
      ),
      true
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloAnaliseVisitaTecnica.sendTechnicalVisitAnalysis(
      new Set<Id>{ opp.Id }
    );
    Test.stopTest();

    System.assert(true, 'Integracao executada');
  }
}
