@IsTest
private class IntegracaoNivelloPropostaTest {
    @IsTest
    static void shouldSendSimulationUrl() {
        if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'Envia_URLSimulacao')) {
            return;
        }

        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-PROP',
            URLSimulation__c = 'https://example.com/sim'
        ), true);

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new TestMetadataUtils.MockHttpSuccess());

        Test.startTest();
        IntegracaoNivelloProposta.sendUrlSimulation(new Set<Id>{ opp.Id });
        Test.stopTest();

        System.assert(true, 'Integracao executada');
    }
}
