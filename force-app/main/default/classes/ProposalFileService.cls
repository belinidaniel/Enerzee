/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalFileService {
  public static ContentVersion findExistingProposal(
    Id opportunityId,
    String payloadHash
  ) {
    if (opportunityId == null || String.isBlank(payloadHash)) {
      return null;
    }

    List<ContentVersion> matches = [
      SELECT Id, Title, FileExtension, ContentDocumentId
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :opportunityId
        AND IsProposal__c = TRUE
        AND ProposalPayloadHash__c = :payloadHash
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return matches.isEmpty() ? null : matches[0];
  }

  public static Id saveGeneratedProposal(
    ProposalContextResolver.Context context,
    ProposalApiClient.ApiResponse apiResponse,
    String payloadHash
  ) {
    if (context == null || context.opportunity == null || apiResponse == null) {
      throw new AuraHandledException(
        'Nao foi possivel salvar a proposta gerada.'
      );
    }
    if (!Schema.sObjectType.ContentVersion.isCreateable()) {
      throw new AuraHandledException(
        'Voce nao possui permissao para criar arquivos de proposta.'
      );
    }

    String fileName = buildFileName(context.opportunity, apiResponse.fileName);
    String title = fileName.toLowerCase().endsWith('.pdf')
      ? fileName.substring(0, fileName.length() - 4)
      : fileName;

    ContentVersion version = new ContentVersion();
    version.Title = title;
    version.PathOnClient = fileName;
    version.VersionData = apiResponse.fileBlob;
    version.FirstPublishLocationId = context.opportunity.Id;
    version.IsProposal__c = true;
    version.NomePaginaPDF__c = 'API_PPTX';
    version.ProposalPayloadHash__c = payloadHash;
    version.ProposalScenario__c = context.scenario;
    version.ProposalPaymentType__c = context.paymentType;
    version.ProposalCoverKey__c = context.coverKey;

    List<ContentVersion> sanitized = (List<ContentVersion>) Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<ContentVersion>{ version }
      )
      .getRecords();
    insert sanitized;

    return sanitized[0].Id;
  }

  public static String buildPreviewUrl(Id contentVersionId) {
    return contentVersionId == null
      ? null
      : '/sfc/servlet.shepherd/version/download/' + contentVersionId;
  }

  private static String buildFileName(
    Opportunity opportunityRecord,
    String suggestedFileName
  ) {
    if (String.isNotBlank(suggestedFileName)) {
      return suggestedFileName.toLowerCase().endsWith('.pdf')
        ? suggestedFileName
        : suggestedFileName + '.pdf';
    }

    String baseLabel = opportunityRecord.ViabilityStudyFinished__c
      ? 'Readequacao'
      : 'Proposta';
    String accountName = opportunityRecord.Account != null &&
      String.isNotBlank(opportunityRecord.Account.Name)
      ? opportunityRecord.Account.Name
      : opportunityRecord.Name;
    String numero = String.isBlank(opportunityRecord.Numeroproposta__c)
      ? ''
      : opportunityRecord.Numeroproposta__c + ' ';
    String nomeRegistro = (numero + accountName).trim();
    String parceiro = opportunityRecord.Parceiro__r != null
      ? opportunityRecord.Parceiro__r.Name
      : null;

    if (
      opportunityRecord.GrupoTarifario__c == 'Grupo A' ||
      parceiro == 'Enerzee - Grupo A'
    ) {
      return baseLabel + ' A ' + nomeRegistro + '.pdf';
    }
    if (
      opportunityRecord.GrupoTarifario__c == 'Grupo B' ||
      opportunityRecord.GrupoTarifario__c == 'Grupo B Optante' ||
      parceiro == 'Enerzee - Grupo B'
    ) {
      return baseLabel + ' B ' + nomeRegistro + '.pdf';
    }
    return baseLabel + ' ' + nomeRegistro + '.pdf';
  }
}
