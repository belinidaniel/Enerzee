/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class ViabilityControllerTest {
  @isTest
  static void updateViabilityTest() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(),
      true
    );
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        ConsultorOportunidade__c = consultor.Id,
        Parceiro__c = parceiro.Id,
        PotenciaPicoSistema__c = 12
      ),
      true
    );
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      TypeWorkProjectFeasibility__c = 'UFV Mini acima de 300'
    );
    insert viability;

    Decimal latitude = -15.6131249;
    Decimal longitude = -56.0853574;
    String telhado = 'Ao Solo';

    Test.startTest();
    opportunity.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
    update opportunity;
    ViabilityController.updateViability(
      viability.Id,
      latitude,
      longitude,
      telhado
    );
    Test.stopTest();

    ViabilityStudy__c updatedVia = [
      SELECT
        LocalizacaoFixa__Latitude__s,
        LocalizacaoFixa__Longitude__s,
        FixationStructureVerifiedPlace__c
      FROM ViabilityStudy__c
      WHERE Id = :viability.Id
    ];
    Assert.areEqual(
      latitude,
      updatedVia.LocalizacaoFixa__Latitude__s,
      'Latitude não foi atualizada corretamente'
    );
    Assert.areEqual(
      longitude,
      updatedVia.LocalizacaoFixa__Longitude__s,
      'Longitude não foi atualizada corretamente'
    );
    Assert.areEqual(
      telhado,
      updatedVia.FixationStructureVerifiedPlace__c,
      'telhado não foi atualizado corretamente'
    );
  }
}
