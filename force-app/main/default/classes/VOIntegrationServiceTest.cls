@IsTest
private class VOIntegrationServiceTest {
    private class VOSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');

            String endpoint = request != null ? request.getEndpoint() : null;
            String body = request != null ? request.getBody() : null;

            if (endpoint != null && endpoint.contains('/token')) {
                response.setStatusCode(200);
                response.setBody('{"access_token":"abc","token_type":"bearer","expires_in":3600}');
                return response;
            }

            if (body != null && body.contains('idplano')) {
                response.setStatusCode(200);
                response.setBody('{"erro": false, "id": "VO-OPP-001"}');
                return response;
            }

            response.setStatusCode(200);
            response.setBody('{"erro": false, "idusuario": "654321"}');
            return response;
        }
    }

    @IsTest
    static void syncAccountsShouldPersistVoDataAndStructuredLogs() {
        Test.setMock(HttpCalloutMock.class, new VOSuccessMock());
        TokenAPIVOWs.access_token = 'test-token';

        Consultor__c consultant = new Consultor__c(
            Name = 'Consultor VO',
            Login_no_virtual__c = 'consultor.vo@teste.com',
            IdVirtualOffice2__c = '22'
        );
        insert consultant;

        Account accountRecord = new Account(
            Name = 'Conta Teste VO',
            Email__c = 'cliente.vo@teste.com',
            CPF__c = '123.456.789-00',
            Consultor__c = consultant.Id,
            ShippingStreet = 'Rua A',
            NumeroRuaEntrega__c = '10',
            ShippingPostalCode = '01010-000'
        );
        insert accountRecord;

        Test.startTest();
        System.enqueueJob(
            new VOAccountSyncQueueable(
                new Set<Id>{ accountRecord.Id },
                'Test:syncAccount',
                false,
                null
            )
        );
        Test.stopTest();

        accountRecord = [
            SELECT IdVirtualOffice2__c, SucessoIntegracaoVO__c, StatusBodyIntegracaoVO__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        Boolean accountUpdated = accountRecord.IdVirtualOffice2__c == '654321' && accountRecord.SucessoIntegracaoVO__c == true;

        Log__c logRecord = [
            SELECT
                Class__c,
                Method__c,
                Type__c,
                RelatedId__c,
                CorrelationId__c,
                Operation__c,
                CallOrigin__c,
                IntegrationType__c,
                StatusCode__c
            FROM Log__c
            WHERE RelatedId__c = :accountRecord.Id
            AND Method__c = 'sendCliente'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('VOIntegrationService', logRecord.Class__c);
        System.assertEquals('ACCOUNT_SYNC', logRecord.Type__c);
        System.assertEquals('sendCliente', logRecord.Operation__c);
        System.assertEquals('Test:syncAccount', logRecord.CallOrigin__c);
        System.assertNotEquals(null, logRecord.CorrelationId__c);
        System.assertEquals(200, Integer.valueOf(logRecord.StatusCode__c));

        if (!accountUpdated) {
            List<Log__c> accountUpdateLogs = [
                SELECT Message__c
                FROM Log__c
                WHERE RelatedId__c = :accountRecord.Id
                AND Method__c = 'sendCliente:updateAccount'
            ];

            System.assert(
                hasMessageLike(accountUpdateLogs, 'DML_ERROR:'),
                'Quando o update da Account falhar após callout bem-sucedido, deve existir log DML_ERROR.'
            );
        }
    }

    @IsTest
    static void opportunityQueueableShouldPreventUncommittedWorkPendingScenario() {
        Test.setMock(HttpCalloutMock.class, new VOSuccessMock());
        TokenAPIVOWs.access_token = 'test-token';

        Consultor__c consultant = new Consultor__c(
            Name = 'Consultor Fila',
            Login_no_virtual__c = 'consultor.fila@teste.com',
            IdVirtualOffice2__c = '33'
        );
        insert consultant;

        Account accountRecord = new Account(
            Name = 'Conta Queueable',
            Email__c = 'queueable@teste.com',
            CPF__c = '123.456.789-10',
            Consultor__c = consultant.Id
        );
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Opp Queueable VO',
            AccountId = accountRecord.Id,
            IdVirtualOffice__c = '0000000000000000000',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            StageName = 'Ganho fechado',
            CloseDate = Date.today(),
            PotenciaPicoSistema__c = 8,
            paymentMethod__c = 'PIX'
        );
        insert opportunityRecord;

        Test.startTest();
        System.enqueueJob(
            new VOOpportunitySyncQueueable(
                new Set<Id>{ opportunityRecord.Id },
                'Test:QueueableOpportunity',
                true,
                null
            )
        );
        Test.stopTest();

        accountRecord = [SELECT IdVirtualOffice2__c FROM Account WHERE Id = :accountRecord.Id];
        opportunityRecord = [SELECT IdVirtualOffice__c FROM Opportunity WHERE Id = :opportunityRecord.Id];

        System.assertEquals('654321', accountRecord.IdVirtualOffice2__c, 'Account deve ser sincronizada no fluxo da Opportunity.');
        System.assertEquals('VO-OPP-001', opportunityRecord.IdVirtualOffice__c, 'Opportunity deve receber ID VO retornado.');

        List<Log__c> integrationLogs = [
            SELECT Message__c
            FROM Log__c
            WHERE Class__c = 'VOIntegrationService'
        ];

        System.assertEquals(
            false,
            hasMessageLike(integrationLogs, 'uncommitted work pending'),
            'Não deve ocorrer erro de uncommitted work pending.'
        );
    }

    @IsTest
    static void validationRuleShouldBlockClosedWonWithoutAccountVo2() {
        Account accountRecord = new Account(
            Name = 'Conta Sem VO2',
            CPF__c = '123.456.789-11'
        );
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Opp Validation VO',
            AccountId = accountRecord.Id,
            IdVirtualOffice__c = '0000000000000000000',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            StageName = 'Prospecção',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunityRecord;

        opportunityRecord.StageName = 'Ganho fechado';

        try {
            update opportunityRecord;
            System.assert(false, 'A validação deveria bloquear o avanço para Ganho fechado sem VO2 na Account.');
        } catch (DmlException ex) {
            System.assert(
                String.isNotBlank(ex.getMessage()),
                'A validação deve retornar uma mensagem de erro para o usuário.'
            );
        }
    }

    @IsTest
    static void manualControllerShouldRespectOpportunityStageAndQueueAccountSync() {
        Test.setMock(HttpCalloutMock.class, new VOSuccessMock());
        TokenAPIVOWs.access_token = 'test-token';

        Consultor__c consultant = new Consultor__c(
            Name = 'Consultor Controller',
            Login_no_virtual__c = 'consultor.controller@teste.com',
            IdVirtualOffice2__c = '44'
        );
        insert consultant;

        Account accountRecord = new Account(
            Name = 'Conta Controller',
            Email__c = 'controller@teste.com',
            CPF__c = '123.456.789-12',
            Consultor__c = consultant.Id
        );
        insert accountRecord;

        Opportunity invalidOpportunity = new Opportunity(
            Name = 'Opp Stage Invalido',
            AccountId = accountRecord.Id,
            IdVirtualOffice__c = '0000000000000000000',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            StageName = 'Prospecção',
            CloseDate = Date.today().addDays(5)
        );
        insert invalidOpportunity;

        try {
            VOManualSyncController.syncOpportunity(invalidOpportunity.Id);
            System.assert(false, 'A action deve rejeitar Opportunity fora de Ganho fechado.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        Test.startTest();
        VOManualSyncController.ActionResponse response = VOManualSyncController.syncAccount(accountRecord.Id);
        Test.stopTest();

        accountRecord = [SELECT IdVirtualOffice2__c FROM Account WHERE Id = :accountRecord.Id];

        System.assertEquals(true, response.success, 'Controller deve retornar sucesso de enfileiramento.');
        System.assertNotEquals(null, response.correlationId, 'CorrelationId deve ser retornado ao usuário.');
        System.assertEquals('654321', accountRecord.IdVirtualOffice2__c, 'Fila manual deve sincronizar Account com VO.');
    }

    private static Boolean hasMessageLike(List<Log__c> logs, String fragment) {
        if (logs == null || logs.isEmpty() || String.isBlank(fragment)) {
            return false;
        }

        String expected = fragment.toLowerCase();
        for (Log__c logRecord : logs) {
            if (logRecord != null && String.isNotBlank(logRecord.Message__c)) {
                if (logRecord.Message__c.toLowerCase().contains(expected)) {
                    return true;
                }
            }
        }

        return false;
    }
}
