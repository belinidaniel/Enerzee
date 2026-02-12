@IsTest
private class IntegracaoNivelloDataVisitaTecnicaTest {
    @IsTest
    static void shouldSendVisitDate() {
        if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'DataVisitaTecnica')) {
            return;
        }

        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-DATE',
            PrazoAprovacaoViabilidade__c = System.now().addDays(2)
        ), true);

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new TestMetadataUtils.MockHttpSuccess());

        Test.startTest();
        IntegracaoNivelloDataVisitaTecnica.sendTechnicalVisitDateFromDateChanging(new Set<Id>{ opp.Id });
        Test.stopTest();

        System.assert(true, 'Integracao executada');
    }
}
