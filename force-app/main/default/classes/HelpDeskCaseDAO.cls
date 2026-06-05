/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Belini
 * @test              : HelpDeskCaseDAOTest
 **/
public without sharing class HelpDeskCaseDAO {
  public static List<Case> queryCases(
    String ownershipFilter,
    Boolean closed,
    String searchTerm
  ) {
    String statusFilter = closed ? 'IsClosed = TRUE' : 'IsClosed = FALSE';
    String query =
      'SELECT Id, CaseNumber, Subject, Status, LastModifiedDate, Contact.Name, ContactId ' +
      'FROM Case WHERE ' +
      ownershipFilter +
      ' AND ' +
      statusFilter;
    if (String.isNotBlank(searchTerm)) {
      String pattern = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
      query += ' AND (Subject LIKE :pattern OR CaseNumber LIKE :pattern)';
    }
    query += ' ORDER BY LastModifiedDate DESC';
    return Database.query(query);
  }

  public static Case queryCaseDetail(Id caseId) {
    return [
      SELECT
        Id,
        CaseNumber,
        Subject,
        Status,
        StatusAprovacao__c,
        Supervisor__c,
        Gerente__c,
        HelpDesk_Status__c,
        CreatedDate,
        LastModifiedDate,
        Contact.Name,
        ContactId,
        Description,
        Description_Rich__c,
        HelpDesk_Sistema__c,
        JiraIssueKey__c,
        JiraIssueUrl__c,
        JiraStatus__c,
        Oportunidade_Pai__c,
        Oportunidade_Pai__r.IdVirtualOffice__c
      FROM Case
      WHERE Id = :caseId
    ];
  }

  public static List<CaseComment> queryComments(Id caseId) {
    return [
      SELECT
        Id,
        ParentId,
        CommentBody,
        IsPublished,
        CreatedDate,
        CreatedById,
        CreatedBy.Name
      FROM CaseComment
      WHERE ParentId = :caseId AND (IsPublished = TRUE OR IsPublished = NULL)
      ORDER BY CreatedDate DESC
    ];
  }

  public static List<ContentDocumentLink> queryAttachments(Id caseId) {
    return [
      SELECT
        Id,
        ContentDocumentId,
        ContentDocument.LatestPublishedVersionId,
        ContentDocument.Title,
        ContentDocument.FileExtension,
        ContentDocument.ContentSize,
        ContentDocument.CreatedDate,
        ContentDocument.CreatedBy.Name
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :caseId
      ORDER BY ContentDocument.CreatedDate DESC
    ];
  }

  public static void insertComment(CaseComment comment) {
    insert comment;
  }

  public static void insertCase(Case c) {
    insert c;
  }

  public static void insertVersions(List<ContentVersion> versions) {
    insert versions;
  }

  public static List<ContentVersion> queryVersionsById(Set<Id> versionIds) {
    if (versionIds == null || versionIds.isEmpty()) {
      return new List<ContentVersion>();
    }
    return [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id IN :versionIds
    ];
  }

  public static void insertLinks(List<ContentDocumentLink> links) {
    if (links == null || links.isEmpty()) {
      return;
    }
    insert links;
  }

  public static List<HelpDeskMessage__c> queryMessages(Id caseId) {
    return [
      SELECT
        Id,
        Name,
        Body__c,
        IsPublic__c,
        AuthorName__c,
        AuthorType__c,
        CreatedDate,
        CreatedById,
        CreatedBy.Name,
        (
          SELECT
            Id,
            ContentDocumentId,
            ContentDocument.LatestPublishedVersionId,
            ContentDocument.Title,
            ContentDocument.FileExtension,
            ContentDocument.ContentSize
          FROM ContentDocumentLinks
          ORDER BY ContentDocument.CreatedDate ASC
        )
      FROM HelpDeskMessage__c
      WHERE Case__c = :caseId AND IsPublic__c = TRUE
      ORDER BY CreatedDate DESC
    ];
  }

  public static List<HelpDeskMessage__c> queryAllMessages(Id caseId) {
    return [
      SELECT
        Id,
        Name,
        Body__c,
        IsPublic__c,
        AuthorName__c,
        AuthorType__c,
        CreatedDate,
        CreatedById,
        CreatedBy.Name,
        (
          SELECT
            Id,
            ContentDocumentId,
            ContentDocument.LatestPublishedVersionId,
            ContentDocument.Title,
            ContentDocument.FileExtension,
            ContentDocument.ContentSize
          FROM ContentDocumentLinks
          ORDER BY ContentDocument.CreatedDate ASC
        )
      FROM HelpDeskMessage__c
      WHERE Case__c = :caseId
      ORDER BY CreatedDate DESC
    ];
  }

  public static List<HelpDeskMessage__c> queryMessageByIdAndCase(
    Id messageId,
    Id caseId
  ) {
    return [
      SELECT Id, Case__c, IsPublic__c
      FROM HelpDeskMessage__c
      WHERE Id = :messageId AND Case__c = :caseId
      LIMIT 1
    ];
  }

  public static Case queryApprovalDetail(Id caseId) {
    return [
      SELECT
        Id,
        StatusAprovacao__c,
        ContactId,
        Supervisor__c,
        Gerente__c,
        SupervisorNome__c,
        GerenteNome__c,
        Contact.Supervisor__c,
        Contact.Supervisor__r.Name,
        Contact.Gerente__c,
        Contact.Gerente__r.Name
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
  }

  public static List<ProcessInstanceWorkitem> queryPendingApprovalWorkitems(
    Id caseId
  ) {
    return [
      SELECT Id, ActorId, Actor.Name, CreatedDate
      FROM ProcessInstanceWorkitem
      WHERE
        ProcessInstance.TargetObjectId = :caseId
        AND ProcessInstance.Status = 'Pending'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }

  public static HelpDeskMessage__c insertMessage(HelpDeskMessage__c msg) {
    insert msg;
    return msg;
  }

  public static List<AttachmentLink__c> queryAttachmentLinksByParents(
    Set<Id> parentIds
  ) {
    Set<String> parentKeys = new Set<String>();
    for (Id pid : parentIds) {
      parentKeys.add(String.valueOf(pid));
    }
    return [
      SELECT
        Id,
        SObjectId__c,
        SObjectType__c,
        AttachmentURL__c,
        InternalAttachmentURL__c,
        FileName__c,
        FileType__c,
        AttachmentDescription__c
      FROM AttachmentLink__c
      WHERE SObjectId__c IN :parentKeys
      ORDER BY CreatedDate ASC
    ];
  }

  public static Id resolveRecordTypeId(
    String sObjectName,
    String developerName
  ) {
    Map<String, Schema.RecordTypeInfo> infos = Schema.getGlobalDescribe()
      .get(sObjectName)
      .getDescribe()
      .getRecordTypeInfosByDeveloperName();
    Schema.RecordTypeInfo info = infos.get(developerName);
    if (info == null) {
      throw new AuraHandledException(
        'Record Type não encontrado: ' + developerName
      );
    }
    return info.getRecordTypeId();
  }
}
