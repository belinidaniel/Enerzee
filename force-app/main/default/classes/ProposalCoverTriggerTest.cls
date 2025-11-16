/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-16-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class ProposalCoverTriggerTest{

    // Método para criar dados de teste
    private static ProposalCover__c createTestProposalCover(String grupoTarifario, Boolean isDefault) {
        ProposalCover__c cover = new ProposalCover__c();
        cover.GrupoTarifario__c = grupoTarifario;
        cover.IsDefault__c = isDefault;
        cover.IsActive__c = true;
        cover.Template__c ='ModeloPropostaB';
        

        return cover;
    }

    // Teste para o cenário de inserção
    @isTest 
    static void testProposalCoverInsert() {
        // Prepare dados de teste
        ProposalCover__c cover1 = createTestProposalCover('Grupo A', true);
        insert cover1;

        ProposalCover__c cover2 = createTestProposalCover('Grupo A', false);
        ProposalCover__c cover3 = createTestProposalCover('Grupo A', true);

        // Inicie um contexto de teste
        Test.startTest();

        // Insira os dados de teste
        insert new List<ProposalCover__c>{cover2, cover3};

        // Encerre o contexto de teste
        Test.stopTest();

        // Faça as verificações
        List<ProposalCover__c> insertedCovers = [SELECT Id, IsDefault__c FROM ProposalCover__c WHERE Id IN :new List<Id>{cover1.Id, cover3.Id}];
        //System.assertEquals(false, insertedCovers[0].IsDefault__c);
        //System.assertEquals(true, insertedCovers[1].IsDefault__c);
    }

    // Teste para o cenário de atualização
    @isTest 
    static void testProposalCoverUpdate() {
        // Prepare e insira dados de teste
        ProposalCover__c cover1 = createTestProposalCover('Grupo A', true);
        insert cover1;
        ProposalCover__c cover2 = createTestProposalCover('Grupo A', false);
        insert cover2;
        ProposalCover__c cover3 = createTestProposalCover('Grupo A', true);
        insert cover3;

        // Atualize um registro para ser padrão
        cover2.IsDefault__c = true;
        
        // Inicie um contexto de teste
        Test.startTest();

        // Atualize os dados de teste
        update cover2;

        // Encerre o contexto de teste
        Test.stopTest();

        // Faça as verificações
        List<ProposalCover__c> updatedCovers = [SELECT Id, IsDefault__c FROM ProposalCover__c WHERE Id IN :new List<Id>{cover1.Id, cover2.Id}];
        //System.assertEquals(false, updatedCovers[0].IsDefault__c);
        //System.assertEquals(true, updatedCovers[1].IsDefault__c);
    }
}