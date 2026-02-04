@IsTest(seeAllData=true)
private class IntegracaoNivelloAdditionalTest {

    private class NivelloMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setStatus('OK');

            String endpoint = req != null ? req.getEndpoint() : '';
            if (endpoint != null && endpoint.contains('update-opportunity-total-value')) {
                res.setBody('{"data":{"discountedBdi":1.1,"discountedRede":2.2,"discountedPontos":3.3,"discountedDirect":4.4}}');
            } else {
                res.setBody('{"success":true}');
            }

            return res;
        }
    }

    @IsTest
    static void testAnaliseVisitaTecnica() {
        if (!hasRequiredMetadata(new List<String>{'AnaliseVisitaTecnica', 'Login_Nivello'})) {
            return;
        }

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        String statusViabilidade = getPicklistValue('Opportunity', 'StatusViabilidade__c', new List<String>{'Inviável', 'Viável', 'Parcialmente Viável'});
        if (String.isBlank(statusViabilidade)) {
            return;
        }
        setIfExists(opp, 'StatusViabilidade__c', statusViabilidade);
        setIfExists(opp, 'TextoMotivo__c', 'Motivo teste');
        setIfExists(opp, 'TextoEstudo__c', 'Estudo teste');
        update opp;

        Test.setMock(HttpCalloutMock.class, new NivelloMock());

        Test.startTest();
        IntegracaoNivelloAnaliseVisitaTecnica.sendTechnicalVisitAnalysis(new Set<Id>{ opp.Id });
        Test.stopTest();

        assertOpportunitySuccess(opp.Id);
    }

    @IsTest
    static void testSimulacaoFinanciamento() {
        if (!hasRequiredMetadata(new List<String>{'AtualizaSimulacaoFinanciamento', 'Login_Nivello'})) {
            return;
        }

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        setIfExists(opp, 'FinancingProcessDetails__c', 'Detalhes financiamento');
        update opp;

        Test.setMock(HttpCalloutMock.class, new NivelloMock());

        Test.startTest();
        IntegracaoNivelloSimulacaoFinanciamento.updateFinancingSimulation(new Set<Id>{ opp.Id });
        Test.stopTest();

        assertOpportunitySuccess(opp.Id);
    }

    @IsTest
    static void testValorTotalProposta() {
        if (!hasRequiredMetadata(new List<String>{'Login_Nivello'})) {
            return;
        }

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        setIfExists(opp, 'CustoAdicional__c', 10);
        update opp;

        Test.setMock(HttpCalloutMock.class, new NivelloMock());

        Test.startTest();
        IntegracaoNivelloValorTotalProposta.updateOpportunityTotalValue(new Set<Id>{ opp.Id });
        Test.stopTest();

        if (hasOpportunityField('BDI__c')) {
            Opportunity updated = fetchOpportunity(opp.Id, new List<String>{'BDI__c', 'Rede3750__c', 'Pontos__c', 'Direct__c'});
            System.assertNotEquals(null, updated.get('BDI__c'), 'BDI deve ser atualizado.');
        }
    }

    @IsTest
    static void testViabilidadeEtapa() {
        if (!hasRequiredMetadata(new List<String>{'Etapa_Viabilidade', 'Login_Nivello'})) {
            return;
        }

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        String etapa = getPicklistValue('Opportunity', 'EtapaViabilidade__c', new List<String>{'Agendamento', 'Visita', 'Estudo'});
        if (String.isBlank(etapa)) {
            return;
        }
        setIfExists(opp, 'EtapaViabilidade__c', etapa);
        update opp;

        Test.setMock(HttpCalloutMock.class, new NivelloMock());

        Test.startTest();
        IntegracaoNivelloViabilidade.etapaViabilidade(new Set<Id>{ opp.Id });
        Test.stopTest();

        assertOpportunitySuccess(opp.Id);
    }

    @IsTest
    static void testViabilidadeConclusao() {
        if (!hasRequiredMetadata(new List<String>{'Conclusao_Viabilidade', 'Login_Nivello'})) {
            return;
        }

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        setIfExists(opp, 'PrazoAprovacaoViabilidade__c', System.now().addDays(5));
        update opp;

        Test.setMock(HttpCalloutMock.class, new NivelloMock());

        Test.startTest();
        IntegracaoNivelloViabilidade.conclusaoViabilidade(new Set<Id>{ opp.Id });
        Test.stopTest();

        assertOpportunitySuccess(opp.Id);
    }

    private static void assertOpportunitySuccess(Id oppId) {
        Opportunity updated = fetchOpportunity(oppId, new List<String>{'SucessoIntegracaoNivello__c', 'StatusBodyIntegracaoNivello__c'});
        if (hasOpportunityField('SucessoIntegracaoNivello__c')) {
            System.assertEquals(true, (Boolean)updated.get('SucessoIntegracaoNivello__c'), 'Deve marcar sucesso na integracao.');
        }
        if (hasOpportunityField('StatusBodyIntegracaoNivello__c')) {
            System.assertNotEquals(null, updated.get('StatusBodyIntegracaoNivello__c'), 'Deve registrar status da resposta.');
        }
    }

    private static Boolean hasRequiredMetadata(List<String> developerNames) {
        if (!Schema.getGlobalDescribe().containsKey('Integrador__mdt')) {
            return false;
        }
        if (developerNames == null || developerNames.isEmpty()) {
            return true;
        }
        for (String developerName : developerNames) {
            if (!hasMetadataRecord('Integrador__mdt', developerName)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean hasMetadataRecord(String apiName, String developerName) {
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

    private static Boolean hasOpportunityField(String fieldName) {
        return Schema.SObjectType.Opportunity.fields.getMap().containsKey(fieldName);
    }

    private static String getPicklistValue(String objectName, String fieldName, List<String> preferredValues) {
        if (String.isBlank(objectName) || String.isBlank(fieldName)) {
            return null;
        }
        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectName);
        if (sobjectType == null) {
            return null;
        }
        Schema.DescribeFieldResult describeResult = sobjectType.getDescribe().fields.getMap().get(fieldName).getDescribe();
        if (describeResult == null || describeResult.getType() != Schema.DisplayType.Picklist) {
            return null;
        }
        List<Schema.PicklistEntry> entries = describeResult.getPicklistValues();
        if (entries == null || entries.isEmpty()) {
            return null;
        }
        if (preferredValues != null) {
            for (String preferred : preferredValues) {
                for (Schema.PicklistEntry entry : entries) {
                    if (entry.getValue() == preferred) {
                        return entry.getValue();
                    }
                }
            }
        }
        return entries[0].getValue();
    }

    private static Opportunity fetchOpportunity(Id oppId, List<String> fields) {
        List<String> selectFields = new List<String>{'Id'};
        for (String fieldName : fields) {
            if (hasOpportunityField(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Opportunity WHERE Id = :oppId';
        return (Opportunity) Database.query(soql);
    }
}
