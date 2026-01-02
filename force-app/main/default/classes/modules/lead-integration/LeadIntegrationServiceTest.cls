@isTest(seeAllData=true)
private class LeadIntegrationServiceTest {
    
    // Mock para simular o HTTP callout
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{ "message": "OK" }');
            return res;
        }
    }
    
    @isTest static void testIntegrateLeadSuccess() {
        // Cria um registro de Lead mínimo para satisfazer o SELECT
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead',
            Company   = 'Acme Corp',
            Email     = 'test.lead@example.com',
            CPFCNPJ__c = '12345678901',
            Lb065_FaturaEnergia__c = 1000,
            Phone     = '123456789',
            Lb065_ProdutoInteresse__c = null,
            Lb065_HistoricoLead__c = 'Histórico...',
            Lb065_Estado__c = null,
            LeadSource = null,
            Title     = 'Sr.',
            Street    = 'Rua A',
            City      = 'Cidade B',
            Country   = 'Brasil',
            InteresseEnergiaRenovavel__c = null,
            InteresseEnergiaSolar__c = null,
            TipoDeImovel__c = null,
            CustoEnergiaMes__c = null,
            ValorContaEnergia__c = null,
            Rating    = null,
            Mensagem__c = 'Msg',
            Complemento__c = 'Comp',
            PostalCode = '12345-678'
        );
        insert testLead;
        
        Lead testLead2 = new Lead(
            FirstName = 'Test2',
            LastName  = 'Lead',
            Company   = 'Acme Corp',
            Email     = 'test.lead@example.com',
            CPFCNPJ__c = '12345678901',
            Lb065_FaturaEnergia__c = 1000,
            Phone     = '123456789',
            Lb065_ProdutoInteresse__c = 'Solar',
            Lb065_HistoricoLead__c = 'Histórico...',
            Lb065_Estado__c = 'SP',
            LeadSource = 'Website',
            Title     = 'Sr.',
            Street    = 'Rua A',
            City      = 'Cidade B',
            Country   = 'Brasil',
            InteresseEnergiaRenovavel__c = null,
            InteresseEnergiaSolar__c = null,
            TipoDeImovel__c = 'com telhado cerâmico',
            CustoEnergiaMes__c = null,
            ValorContaEnergia__c = null,
            Rating    = 	'Cold',
            Mensagem__c = 'Msg',
            Complemento__c = 'Comp',
            PostalCode = '12345-678'
        );
        insert testLead2;
        
        Lead testLead3 = new Lead(
            FirstName = 'Test3',
            LastName  = 'Lead',
            Company   = 'Acme Corp',
            Email     = 'test.lead@example.com',
            CPFCNPJ__c = '12345678901',
            Lb065_FaturaEnergia__c = 1000,
            Phone     = '123456789',
            Lb065_ProdutoInteresse__c = 'Ezee Solar',
            Lb065_HistoricoLead__c = 'Histórico...',
            Lb065_Estado__c = 'MT',
            LeadSource = 'Nivello',
            Title     = 'Sr.',
            Street    = 'Rua A',
            City      = 'Cidade B',
            Country   = 'Brasil',
            InteresseEnergiaRenovavel__c = null,
            InteresseEnergiaSolar__c = null,
            TipoDeImovel__c = 'com telhado fibrocimento',
            CustoEnergiaMes__c = 'até R$ 300',
            ValorContaEnergia__c = 'Até R$ 200',
            Rating    = 	'Hot',
            Mensagem__c = 'Msg',
            Complemento__c = 'Comp',
            PostalCode = '12345-678'
        );
        insert testLead3;
        
        // Seta o mock de callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Executa o método @future dentro de contexto de teste
        Test.startTest();
        LeadIntegrationService.integrateLead(testLead.Id);

        LeadIntegrationService.integrateLead(testLead2.Id);
        
        LeadIntegrationService.integrateLead(testLead3.Id);
        Test.stopTest();
        
        // Recarrega o Lead e verifica se o campo de integração foi marcado como true
        //Lead updated = [SELECT Lab065_IntegracaoDistribuicaoLead__c 
                        //FROM Lead 
                        //WHERE Id = :testLead.Id];
        //System.assertEquals(true, updated.Lab065_IntegracaoDistribuicaoLead__c,
            //'O campo Lab065_IntegracaoDistribuicaoLead__c deve ter sido atualizado para true');
    }
    
    @isTest static void testInvocableMethod() {
        // Prepara a entrada para o InvocableMethod
        LeadIntegrationService.LeadInput inp = new LeadIntegrationService.LeadInput();

		Lead leadRecord = [SELECT Id FROM Lead WHERE RecordType.DeveloperName = 'QualificacaodeClientes' LIMIT 1];

        inp.leadId = leadRecord.Id;
        
        // Chama o método invocável
        List<LeadIntegrationService.LeadOutput> outputs =
            LeadIntegrationService.sendLeadsToExternalApp(
                new List<LeadIntegrationService.LeadInput>{ inp }
            );
        
        // Deve retornar exatamente 1 resultado
        System.assertEquals(1, outputs.size());
        // Como o método apenas dispara @future e não preenche statusCode,
        // statusCode permanece null
        System.assert(outputs[0].statusCode == null,
            'statusCode deve ser null, pois não foi preenchido no sendLeadsToExternalApp');
    }
}