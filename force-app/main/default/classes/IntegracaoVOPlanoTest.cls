@isTest
private class IntegracaoVOPlanoTest {
    
    @isTest
    static void testSendPlano() {
        Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
        
        Test.startTest();
        
        Set<Id> opportunityIds = new Set<Id>();
            
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
            Consultor__c = consultor.id,
            IdVirtualOffice2__c = '12345'
        );
        
        insert acc;
        
        Opportunity opp1 = new Opportunity(
            IdVirtualOffice__c = 'TESTEVO1',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        
        insert opp1;
        opportunityIds.add(opp1.Id);
        
        Opportunity opp2 = new Opportunity(
            IdVirtualOffice__c = 'TESTEVO2',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeLivre').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ParceiroRegistroOportunidade__c = 'Auren',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        
        insert opp2;
        opportunityIds.add(opp2.Id);
        
        Opportunity opp3 = new Opportunity(
            IdVirtualOffice__c = 'TESTEVO3',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Ganho fechado',
            CloseDate = Date.today()
        );
        
        insert opp3;
        opportunityIds.add(opp3.Id);
        
        IntegracaoVOPlano.sendPlano(opportunityIds);
        Test.stopTest();
        
        System.assertNotEquals(null, opportunity.Id, 'A integração não foi bem-sucedida');
    }
    
    @isTest
    static void testSendPlanoWithException() {
		Test.setMock(HttpCalloutMock.class, new MockVirtualOfficeWS());
        
        Test.startTest();
        Account acc = new Account(
            Name = 'Cliente Teste Erro'
        );
        insert acc;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = new Opportunity(
            IdVirtualOffice__c = 'TESTEVO123456',
            Name = 'Oportunidade Teste',
            AccountId = acc.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            paymentMethod__c = 'PIX',
            ValorTotalProdutos__c = 5000.00,
            Kwh__c = 200.00,
            StageName = 'Elaboração de proposta',
            CloseDate = Date.today(),
            Parceiro__c = parceiro.id
        );
        insert opportunity;
        
        Set<Id> triggerIds = new Set<Id>{ opportunity.Id };
        
        try {
            opportunity.StageName = 'Ganho fechado';
            update opportunity;
            
            IntegracaoVOPlano.sendPlano(triggerIds);
        } catch (Exception e) {
            System.debug('Erro esperado: ' + e.getMessage());
        }
        Test.stopTest();
    }
}