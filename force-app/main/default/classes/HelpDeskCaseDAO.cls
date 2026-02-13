/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-05-2026
 * @last modified by  : Daniel Belini
**/
public without sharing class HelpDeskCaseDAO {
    public static List<Case> queryCases(String ownershipFilter, Boolean closed, String searchTerm) {
        String statusFilter = closed ? 'IsClosed = TRUE' : 'IsClosed = FALSE';
        String query = 'SELECT Id, CaseNumber, Subject, Status, LastModifiedDate, Contact.Name, ContactId ' +
            'FROM Case WHERE ' + ownershipFilter + ' AND ' + statusFilter;
        if (String.isNotBlank(searchTerm)) {
            String pattern = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (Subject LIKE :pattern OR CaseNumber LIKE :pattern)';
        }
        query += ' ORDER BY LastModifiedDate DESC';
        return Database.query(query);
    }

    public static Case queryCaseDetail(Id caseId) {
        return [
            SELECT Id, CaseNumber, Subject, Status, CreatedDate, LastModifiedDate, Contact.Name, ContactId, Description, Description_Rich__c
            FROM Case
            WHERE Id = :caseId
        ];
    }

    public static List<CaseComment> queryComments(Id caseId) {
        return [
            SELECT Id, ParentId, CommentBody, IsPublished, CreatedDate, CreatedById, CreatedBy.Name
            FROM CaseComment
            WHERE ParentId = :caseId AND (IsPublished = TRUE OR IsPublished = NULL)
            ORDER BY CreatedDate DESC
        ];
    }

    public static List<ContentDocumentLink> queryAttachments(Id caseId) {
        return [
            SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.ContentSize, ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name
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

    public static Id resolveRecordTypeId(String sObjectName, String developerName) {
        Map<String, Schema.RecordTypeInfo> infos = Schema.getGlobalDescribe().get(sObjectName).getDescribe().getRecordTypeInfosByDeveloperName();
        Schema.RecordTypeInfo info = infos.get(developerName);
        if (info == null) {
            throw new AuraHandledException('Record Type não encontrado: ' + developerName);
        }
        return info.getRecordTypeId();
    }
}
