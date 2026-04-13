/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalConsoleControllerTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalGenerationService {
  public class ProposalResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id contentVersionId;
    @AuraEnabled
    public String previewUrl;
    @AuraEnabled
    public Boolean reusedExistingFile;
  }

  public static ProposalResult generatePreview(Id opportunityId, Id coverId) {
    return generate(opportunityId, coverId);
  }

  public static ProposalResult generateProposal(Id opportunityId, Id coverId) {
    return generate(opportunityId, coverId);
  }

  private static ProposalResult generate(Id opportunityId, Id coverId) {
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityId,
      coverId
    );
    if (String.isBlank(context.coverKey)) {
      throw new AuraHandledException(
        'A capa selecionada nao possui configuracao valida para geracao via API.'
      );
    }

    List<ProposalConfigurationService.TagConfig> tagConfigs = ProposalConfigurationService.getTagConfigs(
      context.coverKey,
      context.scenario,
      context.paymentType
    );
    if (tagConfigs.isEmpty()) {
      throw new AuraHandledException(
        'Nenhuma tag configurada para a capa selecionada e o cenario atual.'
      );
    }

    List<String> sectionsToShow = ProposalConfigurationService.getSectionsToShow(
      context.coverKey,
      context.scenario,
      context.paymentType
    );
    if (sectionsToShow.isEmpty()) {
      throw new AuraHandledException(
        'Nenhuma secao configurada para a capa selecionada e o cenario atual.'
      );
    }

    ContentVersion templateVersion = ProposalTemplateResolver.resolveTemplate(
      context
    );
    if (templateVersion == null) {
      throw new AuraHandledException(
        'Nenhum arquivo PPTX configurado para a capa e contexto selecionados.'
      );
    }

    Opportunity dataOpportunity = ProposalPayloadBuilder.queryOpportunityForTags(
      context.opportunity.Id,
      tagConfigs
    );
    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      dataOpportunity,
      tagConfigs,
      sectionsToShow,
      templateVersion.Id
    );

    ContentVersion existingProposal = ProposalFileService.findExistingProposal(
      context.opportunity.Id,
      payload.payloadHash
    );
    if (existingProposal != null) {
      ProposalResult reusedResult = new ProposalResult();
      reusedResult.success = true;
      reusedResult.message = 'Proposta reutilizada com sucesso.';
      reusedResult.contentVersionId = existingProposal.Id;
      reusedResult.previewUrl = ProposalFileService.buildPreviewUrl(
        existingProposal.Id
      );
      reusedResult.reusedExistingFile = true;
      return reusedResult;
    }

    ProposalApiClient.ApiResponse apiResponse = ProposalApiClient.convertProposal(
      templateVersion,
      payload.tagsJson,
      payload.sectionsJson,
      context.cover
    );
    Id contentVersionId = ProposalFileService.saveGeneratedProposal(
      context,
      apiResponse,
      payload.payloadHash
    );

    ProposalResult result = new ProposalResult();
    result.success = true;
    result.message = 'Proposta gerada com sucesso.';
    result.contentVersionId = contentVersionId;
    result.previewUrl = ProposalFileService.buildPreviewUrl(contentVersionId);
    result.reusedExistingFile = false;
    return result;
  }
}
