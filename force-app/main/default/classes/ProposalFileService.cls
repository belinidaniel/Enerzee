/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-12-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalFileService {
  private static final Integer MAX_TITLE_LENGTH = 200;

  @TestVisible
  private static Map<String, Id> generatedProposalIdsByKey = new Map<String, Id>();

  public class ProposalAvailability {
    public Boolean hasStoredProposal = false;
    public Boolean hasProposalLink = false;

    public Boolean isReady() {
      return hasStoredProposal == true && hasProposalLink == true;
    }
  }

  public static ContentVersion findExistingProposal(
    Id opportunityId,
    String payloadHash
  ) {
    if (opportunityId == null || String.isBlank(payloadHash)) {
      return null;
    }

    String cacheKey = buildCacheKey(opportunityId, payloadHash);
    if (generatedProposalIdsByKey.containsKey(cacheKey)) {
      return new ContentVersion(Id = generatedProposalIdsByKey.get(cacheKey));
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

  public static ContentVersion findLatestProposal(Id opportunityId) {
    if (opportunityId == null) {
      return null;
    }

    List<ContentVersion> matches = [
      SELECT Id, Title, FileExtension, ContentDocumentId
      FROM ContentVersion
      WHERE FirstPublishLocationId = :opportunityId AND IsProposal__c = TRUE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return matches.isEmpty() ? null : matches[0];
  }

  public static Map<Id, ProposalAvailability> getProposalAvailability(
    Set<Id> opportunityIds
  ) {
    Map<Id, ProposalAvailability> availabilityByOpportunityId = new Map<Id, ProposalAvailability>();
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return availabilityByOpportunityId;
    }

    Set<Id> validOpportunityIds = new Set<Id>();
    for (Id opportunityId : opportunityIds) {
      if (opportunityId == null) {
        continue;
      }
      validOpportunityIds.add(opportunityId);
      availabilityByOpportunityId.put(
        opportunityId,
        new ProposalAvailability()
      );
    }

    if (validOpportunityIds.isEmpty()) {
      return availabilityByOpportunityId;
    }

    for (AggregateResult result : [
      SELECT FirstPublishLocationId locationId, COUNT(Id) total
      FROM ContentVersion
      WHERE
        FirstPublishLocationId IN :validOpportunityIds
        AND IsProposal__c = TRUE
      GROUP BY FirstPublishLocationId
    ]) {
      Id opportunityId = (Id) result.get('locationId');
      ProposalAvailability availability = availabilityByOpportunityId.get(
        opportunityId
      );
      if (availability != null) {
        availability.hasStoredProposal = true;
      }
    }

    for (AggregateResult result : [
      SELECT OpportunityId__c opportunityId, COUNT(Id) total
      FROM OpportunityAttachmentLink__c
      WHERE
        OpportunityId__c IN :validOpportunityIds
        AND Type__c = 'Proposal'
        AND (AttachmentURL__c != NULL
        OR InternalAttachmentURL__c != NULL)
      GROUP BY OpportunityId__c
    ]) {
      Id opportunityId = (Id) result.get('opportunityId');
      ProposalAvailability availability = availabilityByOpportunityId.get(
        opportunityId
      );
      if (availability != null) {
        availability.hasProposalLink = true;
      }
    }

    return availabilityByOpportunityId;
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

    String title = buildProposalTitle(context.opportunity);
    String fileName = buildProposalFileName(context.opportunity);

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
    generatedProposalIdsByKey.put(
      buildCacheKey(context.opportunity.Id, payloadHash),
      sanitized[0].Id
    );

    return sanitized[0].Id;
  }

  public static String buildPreviewUrl(Id contentVersionId) {
    return contentVersionId == null
      ? null
      : '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Pdf&versionId=' +
        contentVersionId;
  }

  public static String buildProposalTitle(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return 'Proposta';
    }

    String proposalNumber = normalizeWhitespace(
      (String) opportunityRecord.get('Numeroproposta__c')
    );
    String primaryName = normalizeWhitespace(
      opportunityRecord.Account != null
        ? opportunityRecord.Account.Name
        : opportunityRecord.Name
    );

    List<String> parts = new List<String>();
    if (String.isNotBlank(proposalNumber)) {
      parts.add(proposalNumber);
    }
    if (String.isNotBlank(primaryName)) {
      parts.add(primaryName);
    }

    String title = parts.isEmpty() ? 'Proposta' : String.join(parts, ' ');
    title = normalizeWhitespace(title);

    if (title.length() > MAX_TITLE_LENGTH) {
      title = title.substring(0, MAX_TITLE_LENGTH).trim();
    }

    return title;
  }

  public static String buildProposalFileName(Opportunity opportunityRecord) {
    return sanitizeFileName(buildProposalTitle(opportunityRecord)) + '.pdf';
  }

  public static String sanitizeFileName(String baseTitle) {
    String sanitized = normalizeWhitespace(baseTitle);
    if (String.isBlank(sanitized)) {
      sanitized = 'Proposta';
    }

    sanitized = sanitized.replaceAll('[\\\\/:*?\"<>|]+', ' ');
    sanitized = normalizeWhitespace(sanitized);

    if (sanitized.length() > MAX_TITLE_LENGTH) {
      sanitized = sanitized.substring(0, MAX_TITLE_LENGTH).trim();
    }

    return sanitized;
  }

  public static void deleteStoredProposals(Set<Id> opportunityIds) {
    System.debug(
      '[ProposalFileService.deleteStoredProposals] INPUT opportunityIds=' +
      opportunityIds
    );

    if (opportunityIds == null || opportunityIds.isEmpty()) {
      System.debug(
        '[ProposalFileService.deleteStoredProposals] EARLY RETURN: opportunityIds null or empty'
      );
      return;
    }

    Set<Id> validOpportunityIds = new Set<Id>();
    for (Id opportunityId : opportunityIds) {
      if (opportunityId != null) {
        validOpportunityIds.add(opportunityId);
      }
    }

    System.debug(
      '[ProposalFileService.deleteStoredProposals] validOpportunityIds=' +
      validOpportunityIds
    );

    if (validOpportunityIds.isEmpty()) {
      System.debug(
        '[ProposalFileService.deleteStoredProposals] EARLY RETURN: validOpportunityIds empty after null filter'
      );
      return;
    }

    Set<String> proposalNumberPrefixes = new Set<String>();
    for (Opportunity opp : [
      SELECT Numeroproposta__c
      FROM Opportunity
      WHERE Id IN :validOpportunityIds AND Numeroproposta__c != NULL
    ]) {
      proposalNumberPrefixes.add(opp.Numeroproposta__c + '%');
    }
    System.debug(
      '[ProposalFileService.deleteStoredProposals] proposalNumberPrefixes=' +
      proposalNumberPrefixes
    );

    Set<Id> documentIdsToDelete = new Set<Id>();

    List<ContentVersion> byFlag = [
      SELECT ContentDocumentId, Title, IsProposal__c
      FROM ContentVersion
      WHERE
        FirstPublishLocationId IN :validOpportunityIds
        AND IsProposal__c = TRUE
        AND ContentDocumentId != NULL
    ];
    System.debug(
      '[ProposalFileService.deleteStoredProposals] byFlag count=' +
      byFlag.size()
    );
    for (ContentVersion version : byFlag) {
      System.debug(
        '[ProposalFileService.deleteStoredProposals] byFlag hit: Title=' +
          version.Title +
          ' DocId=' +
          version.ContentDocumentId
      );
      documentIdsToDelete.add(version.ContentDocumentId);
    }

    if (!proposalNumberPrefixes.isEmpty()) {
      // Busca os ContentDocumentIds linkados à oportunidade (independente de FirstPublishLocationId)
      Set<Id> linkedDocumentIds = new Set<Id>();
      for (ContentDocumentLink link : [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :validOpportunityIds
      ]) {
        linkedDocumentIds.add(link.ContentDocumentId);
      }
      System.debug(
        '[ProposalFileService.deleteStoredProposals] linkedDocumentIds count=' +
        linkedDocumentIds.size()
      );

      if (!linkedDocumentIds.isEmpty()) {
        List<String> likeConditions = new List<String>();
        for (String prefix : proposalNumberPrefixes) {
          likeConditions.add(
            'Title LIKE \'' + String.escapeSingleQuotes(prefix) + '\''
          );
        }
        String dynamicQuery =
          'SELECT ContentDocumentId, Title FROM ContentVersion WHERE ' +
          'ContentDocumentId IN :linkedDocumentIds AND ' +
          'IsLatest = TRUE AND (' +
          String.join(likeConditions, ' OR ') +
          ')';
        System.debug(
          '[ProposalFileService.deleteStoredProposals] dynamicQuery=' +
          dynamicQuery
        );
        List<ContentVersion> byPrefix = Database.query(dynamicQuery);
        System.debug(
          '[ProposalFileService.deleteStoredProposals] byPrefix count=' +
          byPrefix.size()
        );
        for (ContentVersion version : byPrefix) {
          System.debug(
            '[ProposalFileService.deleteStoredProposals] byPrefix hit: Title=' +
              version.Title +
              ' DocId=' +
              version.ContentDocumentId
          );
          documentIdsToDelete.add(version.ContentDocumentId);
        }
      }
    }

    System.debug(
      '[ProposalFileService.deleteStoredProposals] documentIdsToDelete=' +
      documentIdsToDelete
    );

    if (documentIdsToDelete.isEmpty()) {
      System.debug(
        '[ProposalFileService.deleteStoredProposals] EARLY RETURN: nothing to delete'
      );
      return;
    }

    try {
      List<ContentDocument> toDelete = [
        SELECT Id
        FROM ContentDocument
        WHERE Id IN :documentIdsToDelete
      ];
      System.debug(
        '[ProposalFileService.deleteStoredProposals] deleting ' +
          toDelete.size() +
          ' ContentDocuments'
      );
      delete toDelete;
      System.debug('[ProposalFileService.deleteStoredProposals] DELETE OK');
    } catch (Exception e) {
      System.debug(
        '[ProposalFileService.deleteStoredProposals] DELETE ERROR: ' +
          e.getMessage() +
          ' | ' +
          e.getStackTraceString()
      );
      Utils.createLog('ProposalFileService', 'deleteStoredProposals', e);
    }
  }

  private static String buildCacheKey(Id opportunityId, String payloadHash) {
    return String.valueOf(opportunityId) + '|' + payloadHash;
  }

  @TestVisible
  private static String normalizeWhitespace(String value) {
    if (String.isBlank(value)) {
      return null;
    }

    return value.replaceAll('\\s+', ' ').trim();
  }
}
