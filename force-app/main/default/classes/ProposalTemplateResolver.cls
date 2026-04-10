/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalConsoleControllerTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalTemplateResolver {
  private static final String TEMPLATE_ROLE_API = 'API_PPTX_TEMPLATE';

  public static ContentVersion resolveTemplate(
    ProposalContextResolver.Context context
  ) {
    if (context == null || context.cover == null) {
      throw new AuraHandledException('Contexto de proposta invalido.');
    }

    List<ContentDocumentLink> links = [
      SELECT ContentDocument.LatestPublishedVersionId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :context.cover.Id
    ];

    Set<Id> versionIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      if (
        link.ContentDocument != null &&
        link.ContentDocument.LatestPublishedVersionId != null
      ) {
        versionIds.add(link.ContentDocument.LatestPublishedVersionId);
      }
    }

    if (versionIds.isEmpty()) {
      return null;
    }

    List<ContentVersion> candidates = [
      SELECT
        Id,
        Title,
        PathOnClient,
        FileExtension,
        FileType,
        VersionData,
        ContentDocumentId,
        IsTemplate__c,
        ProposalTemplateRole__c,
        TipoKitPromocional__c
      FROM ContentVersion
      WHERE Id IN :versionIds
      ORDER BY CreatedDate DESC
    ];

    List<ContentVersion> matches = new List<ContentVersion>();
    for (ContentVersion version : candidates) {
      if (
        version.IsTemplate__c != true ||
        version.ProposalTemplateRole__c != TEMPLATE_ROLE_API
      ) {
        continue;
      }

      if (context.isPromotional == true) {
        if (
          version.TipoKitPromocional__c ==
          context.opportunity.TipoKitPromocional__c
        ) {
          matches.add(version);
        }
      } else if (String.isBlank(version.TipoKitPromocional__c)) {
        matches.add(version);
      }
    }

    if (matches.size() > 1) {
      throw new AuraHandledException(
        'Configuracao ambigua: existe mais de um template PPTX valido para a capa selecionada.'
      );
    }

    return matches.isEmpty() ? null : matches[0];
  }
}
