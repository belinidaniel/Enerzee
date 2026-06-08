/**
 * @description       : Executa a geração legada em transação separada do dispatcher.
 * @author            : OpenAI Codex
 * @last modified on  : 06-06-2026
 * @test              : PDFControllerExtensionExtraTest
 **/
public without sharing class LegacyProposalGenerationJob implements Queueable, Database.AllowsCallouts {
  private Id opportunityId;
  private Boolean autoIntegrate;
  private Boolean forceNewFile;

  public LegacyProposalGenerationJob(
    Id opportunityId,
    Boolean autoIntegrate,
    Boolean forceNewFile
  ) {
    this.opportunityId = opportunityId;
    this.autoIntegrate = autoIntegrate;
    this.forceNewFile = forceNewFile;
  }

  public void execute(QueueableContext ctx) {
    try {
      Id contentVersionId = PDFControllerExtension.runLegacyProposalGeneration(
        opportunityId,
        autoIntegrate,
        forceNewFile
      );
      if (
        ProposalFileService.isStoredProposal(opportunityId, contentVersionId)
      ) {
        ProposalGenerationStateService.markSucceeded(opportunityId);
      } else {
        ProposalGenerationStateService.markFailed(opportunityId);
      }
    } catch (Exception e) {
      ProposalGenerationStateService.markFailed(opportunityId);
      Utils.createLog(
        'LegacyProposalGenerationJob',
        'execute',
        e,
        String.valueOf(opportunityId)
      );
    }
  }
}
