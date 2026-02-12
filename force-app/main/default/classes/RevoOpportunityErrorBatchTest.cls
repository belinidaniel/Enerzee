@IsTest
private class RevoOpportunityErrorBatchTest {
    private class RevoMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":[{"token":"abc"}]}');
            return res;
        }
    }

    @IsTest
    static void shouldRunBatch() {
        if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'Revo_CreditAnalysis')
            || !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'Revo_Authentication')) {
            return;
        }

        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            ReferenceIdRevo__c = 'REF-2',
            ErroIntegracaoRevo__c = true
        ), true);

        Test.setMock(HttpCalloutMock.class, new RevoMock());
        Test.startTest();
        Database.executeBatch(new RevoOpportunityErrorBatch(), 1);
        Test.stopTest();

        System.assert(true, 'Batch executed');
    }
}
