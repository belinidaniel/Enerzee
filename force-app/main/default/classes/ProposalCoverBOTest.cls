/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 08-09-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
public with sharing class ProposalCoverBOTest {
    
    @IsTest
    static void testUpdateDefaultStatus() {
        // Arrange
        List<ProposalCover__c> proposalCovers = new List<ProposalCover__c>{
            new ProposalCover__c(
                Name = 'Cover 1',
                GrupoTarifario__c = 'Grupo A',
                IsDefault__c = true,
                Template__c ='ModeloPropostaA'
            ),
            new ProposalCover__c(
                Name = 'Cover 2',
                GrupoTarifario__c = 'Grupo A',
                IsDefault__c = false,
                Template__c ='ModeloPropostaA'
            ),
            new ProposalCover__c(
                Name = 'Cover 3',
                GrupoTarifario__c = 'Grupo B',
                IsDefault__c = true,
                Template__c ='ModeloPropostaB'
            )
        };
        insert proposalCovers;

        // Act
        Test.startTest();
        ProposalCoverBO.updateDefaultStatus(proposalCovers);
        Test.stopTest();

        // Assert
        List<ProposalCover__c> updatedCovers = [SELECT Id, GrupoTarifario__c, IsDefault__c FROM ProposalCover__c WHERE Id IN :proposalCovers];
        for (ProposalCover__c cover : updatedCovers) {
            if (cover.GrupoTarifario__c == 'Group A' && cover.Name == 'Cover 2') {
                System.assertEquals(false, cover.IsDefault__c);
            } else if (cover.GrupoTarifario__c == 'Group A' && cover.Name == 'Cover 1') {
                System.assertEquals(true, cover.IsDefault__c);
            } else if (cover.GrupoTarifario__c == 'Group B') {
                System.assertEquals(true, cover.IsDefault__c);
            }
        }
    }
}