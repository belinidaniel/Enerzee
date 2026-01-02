@isTest
private class IntegracaoVOConsultorPreCadastroTest {

    @isTest static void testSendConsultor() {
        Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
        
        Consultor__c consultor = new Consultor__c(
            Name = 'Consultor Pai Teste',
            Login_no_virtual__c = 'consultorPai@teste.com',
            IdVirtualOffice2__c = '14'
        );
        
        insert consultor;

        Lead lead = new Lead(
            FirstName = 'Lead',
            LastName = 'Teste',
            Company = 'Lead Teste',
            Email = 'consultor@teste.com',
            DataNascimento__c = Date.newInstance(1990, 5, 15),
            CPFCNPJ__c = '123.456.789-00',
            street = 'Rua Teste',
            streetNumber__c = '123',
            postalCode = '12345000',
            complemento__c = 'Apto 101',
            ConsultorRegional__c = consultor.id
        );
        
        insert lead;

        Set<Id> triggerIds = new Set<Id>{ lead.Id };

        Test.startTest();
        IntegracaoVOConsultorPreCadastro.sendConsultor(triggerIds);
        Test.stopTest();

        lead = [SELECT Id, SucessoIntegracaoVO__c, StatusBodyIntegracaoVO__c, IdVirtualOffice__c FROM Lead WHERE Id = :lead.Id];

        System.assertEquals(true, lead.SucessoIntegracaoVO__c, 'A integração não foi bem-sucedida');
    }

    @isTest static void testSendConsultorWithException() {
        Lead lead = new Lead(
            FirstName = 'Consultor',
            LastName = 'Teste Erro',
            Company = 'Lead Teste',
            Email = 'erro@teste.com',
            CPFCNPJ__c = '123.456.789-00'
        );

        insert lead;

        Set<Id> triggerIds = new Set<Id>{ lead.Id };

        Test.startTest();
        try {
            IntegracaoVOClientePreCadastro.sendCliente(triggerIds);
        } catch (Exception e) {
            System.debug('Erro esperado: ' + e.getMessage());
        }
        Test.stopTest();

        lead = [SELECT Id, SucessoIntegracaoVO__c, StatusBodyIntegracaoVO__c FROM Lead WHERE Id = :lead.Id];

        System.assertEquals(false, lead.SucessoIntegracaoVO__c, 'A integração não foi bem-sucedida');
    }
}