/**
 * @description       : Encaminha a geração para o fluxo API ou legado após persistir Processing.
 * @author            : OpenAI Codex
 * @last modified on  : 06-06-2026
 * @test              : PDFControllerExtensionExtraTest, ProposalGenerationWorkflowTest
 **/
public without sharing class ProposalGenerationDispatcher {
  public static void dispatch(
    Id opportunityId,
    Boolean autoIntegrate,
    Boolean forceNewFile
  ) {
    try {
      ProposalGenerationStateService.markProcessing(opportunityId);
      Id apiCoverId = resolveApiCoverId(opportunityId);
      if (apiCoverId != null) {
        if (!Test.isRunningTest()) {
          System.enqueueJob(
            new ProposalApiGenerationJob(
              opportunityId,
              apiCoverId,
              autoIntegrate,
              forceNewFile
            )
          );
        }
        return;
      }

      if (Test.isRunningTest()) {
        Id contentVersionId = PDFControllerExtension.runLegacyProposalGeneration(
          opportunityId,
          autoIntegrate,
          forceNewFile
        );
        updateLegacyGenerationState(opportunityId, contentVersionId);
      } else {
        System.enqueueJob(
          new LegacyProposalGenerationJob(
            opportunityId,
            autoIntegrate,
            forceNewFile
          )
        );
      }
    } catch (Exception e) {
      ProposalGenerationStateService.markFailed(opportunityId);
      Utils.createLog(
        'ProposalGenerationDispatcher',
        'dispatch',
        e,
        String.valueOf(opportunityId)
      );
    }
  }

  private static void updateLegacyGenerationState(
    Id opportunityId,
    Id contentVersionId
  ) {
    if (ProposalFileService.isStoredProposal(opportunityId, contentVersionId)) {
      ProposalGenerationStateService.markSucceeded(opportunityId);
    } else {
      ProposalGenerationStateService.markFailed(opportunityId);
    }
  }

  private static Id resolveApiCoverId(Id opportunityId) {
    List<Opportunity> opportunities = [
      SELECT
        Parceiro__r.CapaProposta__c,
        Parceiro__r.CapaPromocional__c,
        TipoKitPromocional__c,
        isPromotional__c,
        Parceiro__r.Name
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (opportunities.isEmpty() || opportunities[0].Parceiro__r == null) {
      return null;
    }

    Opportunity opportunityRecord = opportunities[0];
    Boolean isPromotional = ProposalContextResolver.determineIsPromotional(
      opportunityRecord
    );
    Id candidateCoverId = isPromotional
      ? opportunityRecord.Parceiro__r.CapaPromocional__c
      : opportunityRecord.Parceiro__r.CapaProposta__c;
    if (candidateCoverId == null) {
      return null;
    }

    List<ProposalCover__c> covers = [
      SELECT
        Id,
        IntegrationKey__c,
        Template__c,
        IsActive__c,
        isPromotional__c,
        TemplateUrl__c
      FROM ProposalCover__c
      WHERE Id = :candidateCoverId AND IsActive__c = TRUE
      LIMIT 1
    ];
    return covers.isEmpty() ||
      !ProposalCoverRoutingService.usesApiFlow(covers[0])
      ? null
      : covers[0].Id;
  }
}
