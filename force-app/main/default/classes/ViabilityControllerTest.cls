@isTest
public class ViabilityControllerTest {
    @isTest
    static void updateViabilityTest() {
        Test.startTest();
        ViabilityStudyTriggerHandler.disableTrigger();
        ViabilityStudyBO.bypassTaskCreation = true;
        	Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);

        	ViabilityStudy__c viability = new ViabilityStudy__c();
        	viability.TypeWorkProjectFeasibility__c = 'UFV Mini acima de 300';
        	insert viability;
        
        Decimal latitude = -15.6131249;
        Decimal longitude = -56.0853574;
        String telhado = 'Ao Solo';
        String adequacyEnerzee = 'Ramal CC;Laudo Estrutural';
        String adequacyClient = 'Ramal CA';
        Decimal visitCost = 1250.55;
        String teamOption = 'Integrador';

        ViabilityController.updateViability(
            viability.id,
            latitude,
            longitude,
            telhado,
            consultor.Id,
            adequacyEnerzee,
            adequacyClient,
            visitCost,
            teamOption
        );

        ViabilityStudy__c updatedVia = [
            SELECT  LocalizacaoFixa__Latitude__s,
                    LocalizacaoFixa__Longitude__s,
                    FixationStructureVerifiedPlace__c,
                    Consultor__c,
                    AdequacyCostEnerzee__c,
                    AdequacyCostClient__c,
                    TechnicalVisitCost__c,
                    OwnTeamThirdParty__c
            FROM    ViabilityStudy__c
            WHERE   Id = :viability.id
        ];

        System.assertEquals(latitude,  updatedVia.LocalizacaoFixa__Latitude__s,  'Latitude não foi atualizada corretamente');
        System.assertEquals(longitude, updatedVia.LocalizacaoFixa__Longitude__s, 'Longitude não foi atualizada corretamente');
        System.assertEquals(telhado,   updatedVia.FixationStructureVerifiedPlace__c, 'telhado não foi atualizado corretamente');
        System.assertEquals(consultor.Id, updatedVia.Consultor__c, 'Consultor não atualizado.');
        System.assertEquals(adequacyEnerzee, updatedVia.AdequacyCostEnerzee__c, 'Adequação Enerzee incorreta.');
        System.assertEquals(adequacyClient, updatedVia.AdequacyCostClient__c, 'Adequação Cliente incorreta.');
        System.assertEquals(visitCost, updatedVia.TechnicalVisitCost__c, 'Custo de visita técnico não atualizado.');
        System.assertEquals(teamOption, updatedVia.OwnTeamThirdParty__c, 'Equipe não atualizada.');
        Test.stopTest();
        ViabilityStudyTriggerHandler.enableTrigger();
        ViabilityStudyBO.bypassTaskCreation = false;
    }
}
