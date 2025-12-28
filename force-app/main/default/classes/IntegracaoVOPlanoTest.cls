/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-01-2025
 * @last modified by  : Daniel Belini
**/

@isTest
private class IntegracaoVOPlanoTest {
    
    @isTest
    static void testSendPlanoReprocessesAccountWithoutVirtualOfficeId() {
        Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
            
        Consultor__c consultor = new Consultor__c(
            Name = 'Consultor Teste',
            Login_no_virtual__c = 'consultor@teste.com',
            IdVirtualOffice2__c = '14'
        );
        
        insert consultor;
        
        Account acc = new Account(
            Name = 'Cliente Teste',
            Email__c = 'cliente@teste.com',
            DataNascimento__c = Date.newInstance(1990, 5, 15),
            CPF__c = '123.456.789-00',
            ShippingStreet = 'Rua Teste',
            NumeroRuaEntrega__c = '123',
            ShippingPostalCode = '12345000',
            ComplementoEntrega__c = 'Apto 101',
            Consultor__c = consultor.id
        );
        
        insert acc;

        Opportunity opp = new Opportunity(
            IdVirtualOffice__c = '123456789',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        
        insert opp;

        Test.startTest();
        IntegracaoVOPlano.sendPlano(new Set<Id>{ opp.Id });
        Test.stopTest();
        
        acc = [SELECT IdVirtualOffice2__c FROM Account WHERE Id = :acc.Id];
        Log__c planLog = [
            SELECT Id, Method__c FROM Log__c 
            WHERE Class__c = 'IntegracaoVOPlano' AND Method__c = :('sendPlano ' + opp.Id)
            LIMIT 1
        ];

        System.assertNotEquals(null, acc.IdVirtualOffice2__c, 'IdVirtualOffice2__c deve ser preenchido antes do envio.');
        System.assertNotEquals(null, planLog, 'Envio do plano não foi registrado.');
    }
    
    @isTest
    static void testSendPlanoSkipsReprocessWhenAccountAlreadyHasId() {
		Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
        
        Account acc = new Account(
            Name = 'Cliente Teste Erro',
            IdVirtualOffice2__c = '2222'
        );
        insert acc;
        
        Opportunity opportunity = new Opportunity(
            IdVirtualOffice__c = '12345678923456',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        insert opportunity;
        
        Test.startTest();
        IntegracaoVOPlano.sendPlano(new Set<Id>{ opportunity.Id });
        Test.stopTest();

        Integer reprocessLogs = [SELECT COUNT() FROM Log__c WHERE Class__c = 'IntegracaoVOClientePreCadastro' AND Method__c LIKE 'sendClienteFromPlano%'];
        Integer planLogs = [SELECT COUNT() FROM Log__c WHERE Class__c = 'IntegracaoVOPlano' AND Method__c = :('sendPlano ' + opportunity.Id)];

        System.assertEquals(0, reprocessLogs, 'Não deveria reprocessar pré-cadastro quando IdVirtualOffice2__c já existe.');
        System.assertEquals(1, planLogs, 'Envio de plano deveria ter sido executado.');
    }

    @isTest
    static void testSendPlanoNotSentWhenPreCadastroFails() {
        Test.setMock(HttpCalloutMock.class, new ErrorMockVO());

        Account acc = new Account(
            Name = 'Cliente Sem ID'
        );
        insert acc;

        Opportunity opportunity = new Opportunity(
            IdVirtualOffice__c = 'TESTEVO999',
            Name = 'Oportunidade Teste Erro',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        insert opportunity;

        Test.startTest();
        IntegracaoVOPlano.sendPlano(new Set<Id>{ opportunity.Id });
        Test.stopTest();

        acc = [SELECT IdVirtualOffice2__c, SucessoIntegracaoVO__c FROM Account WHERE Id = :acc.Id];

        Integer planLogs = [SELECT COUNT() FROM Log__c WHERE Class__c = 'IntegracaoVOPlano' AND Method__c = :('sendPlano ' + opportunity.Id)];
        Integer skipLogs = [SELECT COUNT() FROM Log__c WHERE Class__c = 'IntegracaoVOPlano' AND Method__c LIKE 'skipSendPlanoMissingVOId%'];

        System.assertEquals(null, acc.IdVirtualOffice2__c, 'IdVirtualOffice2__c não deve ser preenchido em caso de falha.');
        System.assertEquals(0, planLogs, 'Não deve enviar plano sem ID do VO.');
        System.assertEquals(1, skipLogs, 'Deve registrar log de bloqueio de envio sem ID.');
    }

    private class ErrorMockVO implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"erro": true}');
            res.setStatusCode(200);
            return res;
        }
    }
}