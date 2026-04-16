/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalTemplateResolver {
  public class TemplateResolverException extends Exception {
  }

  public static ContentVersion resolveTemplate(
    ProposalContextResolver.Context context
  ) {
    if (
      context == null ||
      context.opportunity == null ||
      context.cover == null
    ) {
      throw new TemplateResolverException('Contexto de proposta invalido.');
    }

    Id coverId = context.cover.Id;
    String tipoKit = context.opportunity.TipoKitPromocional__c;

    System.debug(
      '[ProposalTemplateResolver] coverId=' + coverId + ' tipoKit=' + tipoKit
    );

    List<ContentDocumentLink> links = [
      SELECT ContentDocument.LatestPublishedVersionId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :coverId
    ];

    System.debug(
      '[ProposalTemplateResolver] ContentDocumentLinks encontrados: ' +
      links.size()
    );

    Set<Id> versionIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      if (
        link.ContentDocument != null &&
        link.ContentDocument.LatestPublishedVersionId != null
      ) {
        versionIds.add(link.ContentDocument.LatestPublishedVersionId);
      }
    }

    System.debug('[ProposalTemplateResolver] versionIds: ' + versionIds);

    if (versionIds.isEmpty()) {
      // No fluxo API sem arquivos físicos: usa template sintético (a API resolve pelo TemplateUrl__c)
      if (ProposalCoverRoutingService.usesApiFlow(context.cover)) {
        ContentVersion urlTemplate = new ContentVersion();
        urlTemplate.Title = context.cover.Name;
        return urlTemplate;
      }
      throw new TemplateResolverException(
        'Nenhum arquivo encontrado na Capa de Proposta selecionada.'
      );
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
        TipoKitPromocional__c
      FROM ContentVersion
      WHERE Id IN :versionIds AND FileExtension = 'pptx'
      ORDER BY CreatedDate DESC
    ];

    System.debug(
      '[ProposalTemplateResolver] candidates PPTX encontrados: ' +
      candidates.size()
    );
    for (ContentVersion cv : candidates) {
      System.debug(
        '[ProposalTemplateResolver] candidate => Id=' +
          cv.Id +
          ' Title=' +
          cv.Title +
          ' TipoKitPromocional__c=' +
          cv.TipoKitPromocional__c
      );
    }

    if (candidates.size() == 1) {
      System.debug(
        '[ProposalTemplateResolver] unico PPTX encontrado, usando o arquivo anexado sem desambiguacao adicional.'
      );
      return candidates[0];
    }

    List<ContentVersion> matches = new List<ContentVersion>();
    for (ContentVersion version : candidates) {
      if (String.isBlank(tipoKit)) {
        if (String.isBlank(version.TipoKitPromocional__c)) {
          System.debug(
            '[ProposalTemplateResolver] MATCH (sem kit): ' + version.Title
          );
          matches.add(version);
        } else {
          System.debug(
            '[ProposalTemplateResolver] SKIP (opp sem kit, template tem kit): ' +
            version.Title
          );
        }
      } else {
        if (
          String.isBlank(version.TipoKitPromocional__c) ||
          version.TipoKitPromocional__c == tipoKit
        ) {
          System.debug(
            '[ProposalTemplateResolver] MATCH (com kit): ' +
              version.Title +
              ' templateKit=' +
              version.TipoKitPromocional__c
          );
          matches.add(version);
        } else {
          System.debug(
            '[ProposalTemplateResolver] SKIP (kit diferente): ' +
              version.Title +
              ' templateKit=' +
              version.TipoKitPromocional__c +
              ' oppKit=' +
              tipoKit
          );
        }
      }
    }

    System.debug(
      '[ProposalTemplateResolver] matches finais: ' + matches.size()
    );

    if (matches.size() > 1) {
      throw new TemplateResolverException(
        'Configuracao ambigua: existe mais de um template PPTX valido para a Capa e kit selecionados.'
      );
    }

    if (matches.isEmpty()) {
      throw new TemplateResolverException(
        'Nenhum arquivo PPTX configurado para a Capa e kit selecionados.'
      );
    }

    return matches[0];
  }
}
