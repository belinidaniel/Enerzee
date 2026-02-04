@IsTest(seeAllData=true)
private class IntegracaoGeradorPropostasTest {

    private class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true,"data":"VO-123"}');
            return res;
        }
    }

    private class MockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":false,"data":""}');
            return res;
        }
    }

    @IsTest
    static void testSendClienteSuccess() {
        if (!hasMetadata('Integrador__mdt')
            || !hasMetadataRecord('Integrador__mdt', 'Cliente')
            || !hasMetadataRecord('Integrador__mdt', 'Login_Nivello')) {
            return;
        }

        Lead lead = new Lead(
            FirstName = 'Teste',
            LastName = 'Cliente',
            Company = 'Empresa',
            Email = 'cliente@teste.com',
            Phone = '11999999999',
            PostalCode = '01001-000',
            State = 'SP',
            City = 'Sao Paulo',
            Street = 'Rua Teste',
            Status = 'Novo'
        );
        setIfExists(lead, 'CPFCNPJ__c', '12345678901');
        setIfExists(lead, 'Bairro__c', 'Centro');
        setIfExists(lead, 'Complemento__c', 'Apto 1');
        insert lead;
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        IntegracaoGeradorPropostas.sendCliente(new Set<Id>{ lead.Id });
        Test.stopTest();

        Lead updated = fetchLead(lead.Id, new List<String>{'SucessoIntegracaoNivello__c', 'StatusBodyIntegracaoNivello__c'});
        if (hasLeadField('SucessoIntegracaoNivello__c')) {
            System.assertEquals(true, (Boolean)updated.get('SucessoIntegracaoNivello__c'), 'Deve marcar sucesso na integracao.');
        }
        if (hasLeadField('StatusBodyIntegracaoNivello__c')) {
            System.assertNotEquals(null, updated.get('StatusBodyIntegracaoNivello__c'), 'Deve registrar status da resposta.');
        }
    }

    @IsTest
    static void testSendClienteFailure() {
        if (!hasMetadata('Integrador__mdt')
            || !hasMetadataRecord('Integrador__mdt', 'Cliente')
            || !hasMetadataRecord('Integrador__mdt', 'Login_Nivello')) {
            return;
        }

        Lead lead = new Lead(
            FirstName = 'Teste',
            LastName = 'Cliente Falha',
            Company = 'Empresa',
            Email = 'cliente2@teste.com',
            Phone = '11999999999',
            PostalCode = '01001-000',
            State = 'SP',
            City = 'Sao Paulo',
            Street = 'Rua Teste',
            Status = 'Novo'
        );
        setIfExists(lead, 'CPFCNPJ__c', '12345678901234');
        setIfExists(lead, 'Bairro__c', 'Centro');
        setIfExists(lead, 'Complemento__c', 'Apto 2');
        insert lead;

        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();
        IntegracaoGeradorPropostas.sendCliente(new Set<Id>{ lead.Id });
        Test.stopTest();

        Lead updated = fetchLead(lead.Id, new List<String>{'SucessoIntegracaoNivello__c', 'StatusBodyIntegracaoNivello__c'});
        if (hasLeadField('SucessoIntegracaoNivello__c')) {
            System.assertEquals(false, (Boolean)updated.get('SucessoIntegracaoNivello__c'), 'Deve marcar falha na integracao.');
        }
        if (hasLeadField('StatusBodyIntegracaoNivello__c')) {
            System.assertNotEquals(null, updated.get('StatusBodyIntegracaoNivello__c'), 'Deve registrar status da resposta.');
        }
    }

    private static Boolean hasMetadata(String apiName) {
        return Schema.getGlobalDescribe().containsKey(apiName);
    }

    private static Boolean hasMetadataRecord(String apiName, String developerName) {
        if (!hasMetadata(apiName)) {
            return false;
        }
        String soql = 'SELECT Id FROM ' + apiName + ' WHERE DeveloperName = :developerName LIMIT 1';
        List<SObject> records = Database.query(soql);
        return !records.isEmpty();
    }

    private static void setIfExists(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static Boolean hasLeadField(String fieldName) {
        return Schema.SObjectType.Lead.fields.getMap().containsKey(fieldName);
    }

    private static Lead fetchLead(Id leadId, List<String> fields) {
        List<String> selectFields = new List<String>{'Id'};
        for (String fieldName : fields) {
            if (hasLeadField(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Lead WHERE Id = :leadId';
        return (Lead) Database.query(soql);
    }
}
