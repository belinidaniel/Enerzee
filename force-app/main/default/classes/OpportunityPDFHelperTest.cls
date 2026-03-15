/**
 * @description       : Classe de testes para OpportunityPDFHelper
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityPDFHelperTest {
  private static Opportunity buildOpportunity(
    Id recordTypeId,
    String stageName
  ) {
    return new Opportunity(
      Name = 'Opportunity PDF Helper Test',
      CloseDate = Date.today().addDays(10),
      RecordTypeId = recordTypeId,
      StageName = stageName,
      PropostaGerada__c = false,
      ReadequacaoSolicitada__c = false,
      ValorTotalProdutos__c = 100,
      StatusAprovacaoDesconto__c = 'Pendente'
    );
  }

  private static Id getRequiredRecordTypeId(String developerName) {
    Schema.RecordTypeInfo info = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get(developerName);
    Assert.isNotNull(
      info,
      'Record type esperado não encontrado: ' + developerName
    );
    return info.getRecordTypeId();
  }

  private static Id getNonSolarOrEzeeConnectRecordTypeId() {
    Map<String, Schema.RecordTypeInfo> infos = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
    for (String developerName : infos.keySet()) {
      if (developerName != 'Solar' && developerName != 'EzeeConnect') {
        return infos.get(developerName).getRecordTypeId();
      }
    }

    Assert.fail('Nenhum record type alternativo encontrado para Opportunity.');
    return null;
  }

  @IsTest
  static void shouldReturnFalseWhenOldOpportunityIsNull() {
    Opportunity opportunity = buildOpportunity(
      getRequiredRecordTypeId('Solar'),
      OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA
    );

    Assert.isFalse(OpportunityPDFHelper.generatePDF(opportunity, null));
  }

  @IsTest
  static void shouldReturnTrueWhenGeneratedProposalValueChanges() {
    Id solarRecordTypeId = getRequiredRecordTypeId('Solar');
    Opportunity oldOpportunity = buildOpportunity(
      solarRecordTypeId,
      OpportunityUtils.STATUS_PROPOSTA_GERADA
    );
    Opportunity newOpportunity = oldOpportunity.clone(true, true, false, false);
    newOpportunity.ValorTotalProdutos__c = 250;

    Assert.isTrue(
      OpportunityPDFHelper.generatePDF(newOpportunity, oldOpportunity)
    );
  }

  @IsTest
  static void shouldFlagProposalChangedAndReturnTrueForTargetRecordType() {
    Id ezeeConnectRecordTypeId = getRequiredRecordTypeId('EzeeConnect');
    Opportunity oldOpportunity = buildOpportunity(
      ezeeConnectRecordTypeId,
      OpportunityUtils.STATUS_NEGOCIACAO
    );
    Opportunity newOpportunity = oldOpportunity.clone(true, true, false, false);
    newOpportunity.StageName = OpportunityUtils.STATUS_APRESENTACAO_COMERCIAL;
    newOpportunity.PropostaAlterada__c = false;

    Boolean result = OpportunityPDFHelper.generatePDF(
      newOpportunity,
      oldOpportunity
    );

    Assert.isTrue(result);
    Assert.isTrue(newOpportunity.PropostaAlterada__c);
  }

  @IsTest
  static void shouldReturnFalseForNonTargetRecordTypeWithoutRelevantChanges() {
    Id otherRecordTypeId = getNonSolarOrEzeeConnectRecordTypeId();
    Opportunity oldOpportunity = buildOpportunity(
      otherRecordTypeId,
      OpportunityUtils.STATUS_NEGOCIACAO
    );
    Opportunity newOpportunity = oldOpportunity.clone(true, true, false, false);

    Assert.isFalse(
      OpportunityPDFHelper.generatePDF(newOpportunity, oldOpportunity)
    );
    Assert.areEqual(false, newOpportunity.PropostaAlterada__c);
  }
}
