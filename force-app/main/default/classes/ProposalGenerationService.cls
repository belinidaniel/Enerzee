/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-17-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalConsoleControllerTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalGenerationService {
  public class ProposalGenerationException extends Exception {
  }

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
      throw new ProposalGenerationException(
        'A capa selecionada nao possui configuracao valida para geracao via API.'
      );
    }

    List<ProposalConfigurationService.TagConfig> tagConfigs = ProposalConfigurationService.getTagConfigs(
      context.coverKey,
      context.scenario,
      context.paymentType
    );
    if (tagConfigs.isEmpty()) {
      throw new ProposalGenerationException(
        'Nenhuma tag configurada para a capa selecionada e o cenario atual.'
      );
    }

    List<String> sectionsToShow = ProposalConfigurationService.getSectionsToShow(
      context.coverKey,
      context.scenario,
      context.paymentType
    );
    if (sectionsToShow.isEmpty()) {
      throw new ProposalGenerationException(
        'Nenhuma secao configurada para a capa selecionada e o cenario atual.'
      );
    }

    ContentVersion templateVersion = ProposalTemplateResolver.resolveTemplate(
      context
    );
    if (templateVersion == null) {
      throw new ProposalGenerationException(
        'Nenhum arquivo PPTX configurado para a capa e contexto selecionados.'
      );
    }

    Opportunity dataOpportunity = ProposalPayloadBuilder.queryOpportunityForTags(
      context.opportunity.Id,
      tagConfigs
    );

    // Adiciona a seção "Viabilidade" dinamicamente quando TextStudy__c estiver preenchido
    String viabilityText = null;
    if (dataOpportunity.MainViability__r != null) {
      viabilityText = (String) dataOpportunity.MainViability__r.get(
        'TextStudy__c'
      );
    }
    if (String.isNotBlank(viabilityText)) {
      sectionsToShow.add('Viabilidade');
    }

    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      dataOpportunity,
      tagConfigs,
      sectionsToShow,
      templateVersion.Id
    );

    // Extrai imagens do Rich Text e injeta como tags de imagem (_img)
    if (String.isNotBlank(viabilityText)) {
      String imagesBase64 = extractImagesFromRichText(viabilityText);
      if (String.isNotBlank(imagesBase64)) {
        payload.tags.put('{{estudoViabilidade_img__c}}', imagesBase64);
        payload.tagsJson = JSON.serialize(payload.tags);
      }
    }

    // Busca imagem "Layout" anexada à Opportunity para enviar à API
    String layoutBase64 = fetchLayoutAttachment(context.opportunity.Id);

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
      context.cover,
      layoutBase64
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

  /**
   * Extrai URLs de imagens do Rich Text e retorna como JSON com as URLs absolutas
   * e o session token para que a API Python faça o download autenticado.
   * Formato retornado: {"sessionToken":"...","urls":["https://...","https://..."]}
   * A API Python usa essas informacoes para baixar as imagens e injetar no PPTX.
   */
  @TestVisible
  private static String extractImagesFromRichText(String richTextHtml) {
    if (String.isBlank(richTextHtml)) {
      return null;
    }

    Pattern imgPattern = Pattern.compile(
      '<img[^>]+src=["\']([^"\']+)["\'][^>]*>'
    );
    Matcher imgMatcher = imgPattern.matcher(richTextHtml);

    String orgBaseUrl = URL.getOrgDomainUrl().toExternalForm();
    List<String> imageUrls = new List<String>();
    while (imgMatcher.find()) {
      String imgUrl = imgMatcher.group(1);
      if (String.isBlank(imgUrl)) {
        continue;
      }
      if (imgUrl.startsWith('/')) {
        imgUrl = orgBaseUrl + imgUrl;
      }
      imageUrls.add(imgUrl);
    }

    if (imageUrls.isEmpty()) {
      return null;
    }

    Map<String, Object> payload = new Map<String, Object>{
      'sessionToken' => UserInfo.getSessionId(),
      'urls' => imageUrls
    };
    return JSON.serialize(payload);
  }

  @TestVisible
  private static String fetchLayoutAttachment(Id opportunityId) {
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :opportunityId AND ContentDocument.Title = 'Layout'
      ORDER BY ContentDocument.CreatedDate DESC
      LIMIT 1
    ];
    if (links.isEmpty()) {
      return null;
    }
    List<ContentVersion> versions = [
      SELECT VersionData, FileType
      FROM ContentVersion
      WHERE ContentDocumentId = :links[0].ContentDocumentId AND IsLatest = TRUE
      LIMIT 1
    ];
    if (versions.isEmpty()) {
      return null;
    }
    String mimeType = versions[0].FileType != null
      ? 'image/' + versions[0].FileType.toLowerCase()
      : 'image/png';
    return 'data:' +
      mimeType +
      ';base64,' +
      EncodingUtil.base64Encode(versions[0].VersionData);
  }
}
