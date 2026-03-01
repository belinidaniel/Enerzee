/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 08-13-2025
 * @last modified by	 : Daniel Belini
 **/
public with sharing class OpportunityPDFHelper {
  public OpportunityPDFHelper() {
  }

  public static Boolean generatePDF(
    Opportunity opportunity,
    Opportunity oldOpportunity
  ) {
    if (oldOpportunity == null)
      return false;

    Boolean isEzeeOrSolar =
      opportunity.RecordTypeId ==
      Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('EzeeConnect')
        .getRecordTypeId() ||
      opportunity.RecordTypeId ==
      Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Solar')
        .getRecordTypeId();

    if (
      (opportunity.ValorTotalProposta__c !=
      oldOpportunity.ValorTotalProposta__c) &&
      OpportunityUtils.isStatusProposalGenerated(opportunity)
    ) {
      return true;
    }

    if (isEzeeOrSolar && opportunity != null) {
      // Consider moving this side effect elsewhere if not expected here
      opportunity.PropostaAlterada__c = true;

      Boolean shouldGenerate =
        (OpportunityUtils.isStatusProposalElaboration(opportunity) ||
        OpportunityUtils.isStatusProposalSimulation(opportunity)) &&
        !OpportunityUtils.hasProposal(opportunity) ||
        (opportunity.StageName != oldOpportunity.StageName &&
        !opportunity.PropostaGerada__c) ||
        (opportunity.StageName == oldOpportunity.StageName &&
        opportunity.ReadequacaoSolicitada__c !=
        oldOpportunity.ReadequacaoSolicitada__c &&
        opportunity.ReadequacaoSolicitada__c) ||
        (oldOpportunity.PropostaGerada__c != opportunity.PropostaGerada__c &&
        opportunity.PropostaGerada__c &&
        opportunity.StatusAprovacaoDesconto__c !=
        oldOpportunity.StatusAprovacaoDesconto__c &&
        opportunity.StatusAprovacaoDesconto__c == 'Aprovado') ||
        (oldOpportunity.ValorTotalProposta__c !=
        opportunity.ValorTotalProposta__c);

      if (shouldGenerate) {
        return true;
      }

      // If only record type matches, still return true as before
      return true;
    }

    return false;
  }
}
