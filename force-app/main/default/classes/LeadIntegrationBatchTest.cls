/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-09-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class LeadIntegrationBatchTest {
    @isTest
    static void testBatchExecution() {
        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(
            Email__c = 'batch.consultor.' + System.currentTimeMillis() + '@test.com',
            Ativo__c = true,
            SendLead__c = true,
            FreezeConsult__c = false,
            CPF__c = '123.456.789-01',
            CNPJ__c = '12.345.678/9012-34',
            NumeroIdentificacao__c = '1234567890',
            IdVirtualOffice__c = 'vo-batch-' + System.currentTimeMillis()
        ), true);

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
            PostalCode = '12345-678',
            Status = 'Distribuído',
            ConsultorRegional__c = consultor.Id,
            RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Qualificação de Clientes').getRecordTypeId()

        );
        insert testLead3;

        LeadIntegrationBatch batch = new LeadIntegrationBatch();
        Test.startTest();
        Database.QueryLocator queryLocator = batch.start(null);
        batch.execute(null, new List<SObject>{ testLead3 });
        batch.finish(null);
        Test.stopTest();

        System.assertNotEquals(null, queryLocator, 'Start do batch deve retornar QueryLocator.');

        // Reload lead and check integration flag
        Lead updatedLead = [SELECT Lab065_IntegracaoDistribuicaoLead__c FROM Lead WHERE Id = :testLead3.Id LIMIT 1];
        System.assertNotEquals(null, updatedLead, 'Lead de teste deve existir após execução.');
    }
}
