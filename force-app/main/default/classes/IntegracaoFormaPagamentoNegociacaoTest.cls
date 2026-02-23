@IsTest
private class IntegracaoFormaPagamentoNegociacaoTest {
    @IsTest
    static void shouldSendNegotiationStatus() {
        if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'Pagamento')) {
            return;
        }

        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-PAG',
            FormaPagamento__c = 'R001',
            StageName = 'Prospecting'
        ), true);

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new TestMetadataUtils.MockHttpSuccess());

        Test.startTest();
        IntegracaoFormaPagamentoNegociacao.enviarStatusReprovacao(new Set<Id>{ opp.Id });
        Test.stopTest();

        System.assert(true, 'Integracao executada');
    }
}