@isTest
public class ViabilityControllerTest {
    @isTest
    static void updateViabilityTest() {
        Test.startTest();
        	ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        	Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            	CapaProposta__c = ProposalCover.id,
            	Produto__c = 'Solar'
        	), true);
        
        	Account account = (Account) TestFactory.createSObject(new Account(), true);
        	Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        	Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            	AccountId                = account.Id,
            	ConsultorOportunidade__c = consultor.Id,
            	Parceiro__c				 = parceiro.id,
            	PotenciaPicoSistema__c   = 12
        	), true);
        
        	ViabilityStudy__c viability = new ViabilityStudy__c();
        	viability.Opportunity__c = opportunity.Id;
        	viability.TypeWorkProjectFeasibility__c = 'UFV Mini acima de 300';
        	insert viability;
        
        	opportunity.StageName = opportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        	update opportunity;
        
        	Decimal latitude = -15.6131249;
        	Decimal longitude = -56.0853574;
        	String telhado = 'Ao Solo';

        	ViabilityController.updateViability(viability.id, latitude, longitude, telhado);

        	ViabilityStudy__c updatedVia = [SELECT LocalizacaoFixa__Latitude__s, LocalizacaoFixa__Longitude__s, FixationStructureVerifiedPlace__c FROM ViabilityStudy__c WHERE Id = :viability.id];

        	System.assertEquals(latitude,  updatedVia.LocalizacaoFixa__Latitude__s,  'Latitude não foi atualizada corretamente');
        	System.assertEquals(longitude, updatedVia.LocalizacaoFixa__Longitude__s, 'Longitude não foi atualizada corretamente');
        	System.assertEquals(telhado,   updatedVia.FixationStructureVerifiedPlace__c, 'telhado não foi atualizado corretamente');
        Test.stopTest();
    }
}