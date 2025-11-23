/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-19-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class ProposalConsoleControllerTest {

    @TestSetup
    static void setup() {
        Account account = (Account) TestFactory.createSObject(new Account(
            Name = 'Conta Teste'
        ), true);

        ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(
            Template__c = 'ModeloPropostaA'
        ), true);

        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = cover.Id,
            CapaPromocional__c = cover.Id
        ), true);

        TestFactory.createSObject(new Opportunity(
            AccountId = account.Id,
            StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            Parceiro__c = parceiro.Id,
            GrupoTarifario__c = 'Grupo B'
        ), true);
    }

    @isTest
    static void loadProposalDataReturnsTemplatesAndFiles() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        ContentVersion version = new ContentVersion(
            Title = 'Proposta teste',
            ContentLocation = 'S',
            PathOnClient = 'Proposta.pdf',
            VersionData = Blob.valueOf('teste'),
            FirstPublishLocationId = opp.Id,
            IsProposal__c = true,
            NomePaginaPDF__c = 'ModeloPropostaA'
        );
        insert version;

        Test.startTest();
        ProposalConsoleController.ProposalDataDTO result =
            ProposalConsoleController.loadProposalData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Resultado não deveria ser nulo.');
        System.assertEquals(1, result.templates.size(), 'Deveria retornar pelo menos um modelo.');
        System.assertEquals(1, result.files.size(), 'Deveria retornar o histórico inserido.');
    }

    @isTest
    static void sendProposalCreatesContentVersionAndUpdatesOpportunity() {
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        ProposalCover__c cover = [
            SELECT Id
            FROM ProposalCover__c
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloTest.IntegracaoNivelloMock());

        Test.startTest();
        ProposalConsoleController.ProposalActionResult result =
            ProposalConsoleController.sendProposal(opp.Id, cover.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'A chamada deveria retornar sucesso.');
        System.assertNotEquals(null, result.contentVersionId, 'O arquivo deveria ser retornado.');

        ContentVersion saved = [
            SELECT Id, FirstPublishLocationId
            FROM ContentVersion
            WHERE Id = :result.contentVersionId
        ];
        System.assertEquals(opp.Id, saved.FirstPublishLocationId, 'O arquivo deve estar associado à oportunidade.');

        Opportunity updatedOpp = [
            SELECT PropostaGerada__c, StageName
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals(true, updatedOpp.PropostaGerada__c, 'Flag de proposta gerada precisa ser verdadeira.');
        System.assertEquals(OpportunityUtils.STATUS_PROPOSTA_GERADA, updatedOpp.StageName,
            'A fase deve avançar para Proposta Gerada.');
    }
}