/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityPDFHelperTest {
  @IsTest
  static void shouldReturnFalseWhenOldOpportunityIsNull() {
    Opportunity currentOpportunity = new Opportunity();

    System.assertEquals(
      false,
      OpportunityPDFHelper.generatePDF(currentOpportunity, null)
    );
  }

  @IsTest
  static void shouldGeneratePdfForSolarProposalChanges() {
    Id solarRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('Solar')
      .getRecordTypeId();

    Opportunity oldOpportunity = new Opportunity(
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      PropostaGerada__c = false,
      ValorTotalProposta__c = 100
    );
    Opportunity currentOpportunity = new Opportunity(
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
      PropostaGerada__c = false,
      ValorTotalProposta__c = 100
    );

    Boolean shouldGenerate = OpportunityPDFHelper.generatePDF(
      currentOpportunity,
      oldOpportunity
    );

    System.assertEquals(true, shouldGenerate);
    System.assertEquals(true, currentOpportunity.PropostaAlterada__c);
  }

  @IsTest
  static void shouldNotGeneratePdfForUnrelatedRecordTypeWithoutChanges() {
    Id productsRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('Produtos')
      .getRecordTypeId();

    Opportunity oldOpportunity = new Opportunity(
      RecordTypeId = productsRecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      PropostaGerada__c = false,
      ValorTotalProposta__c = 100
    );
    Opportunity currentOpportunity = new Opportunity(
      RecordTypeId = productsRecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      PropostaGerada__c = false,
      ValorTotalProposta__c = 100
    );

    Boolean shouldGenerate = OpportunityPDFHelper.generatePDF(
      currentOpportunity,
      oldOpportunity
    );

    System.assertEquals(false, shouldGenerate);
    System.assertEquals(false, currentOpportunity.PropostaAlterada__c);
  }
}
