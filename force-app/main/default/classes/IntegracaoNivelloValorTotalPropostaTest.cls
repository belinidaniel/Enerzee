@IsTest
private class IntegracaoNivelloValorTotalPropostaTest {
    private class ValueMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":{"discountedBdi":1,"discountedRede":2,"discountedPontos":3,"discountedDirect":4}}');
            return res;
        }
    }

    @IsTest
    static void shouldUpdateTotals() {
        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-TOTAL',
            CustoAdicional__c = 10
        ), true);

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new ValueMock());

        Test.startTest();
        IntegracaoNivelloValorTotalProposta.updateOpportunityTotalValue(new Set<Id>{ opp.Id });
        Test.stopTest();

        Opportunity updated = [SELECT BDI__c, Rede3750__c, Pontos__c, Direct__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(1, updated.BDI__c);
        System.assertEquals(2, updated.Rede3750__c);
        System.assertEquals(3, updated.Pontos__c);
        System.assertEquals(4, updated.Direct__c);
    }
}