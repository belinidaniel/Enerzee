/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-05-2026
 * @last modified by  : Daniel Belini
**/
public without sharing class HelpDeskCaseService {
    public class DefaultEntitiesDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String contactPhone;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
    }

    public static List<Case> getCases(String filterType, String searchTerm, Id contactId, UserContext ctx) {
        String ownershipFilter = buildOwnershipFilter(ctx, contactId);
        Boolean closed = (filterType != null && filterType.toLowerCase() == 'closed');
        List<Case> raw = HelpDeskCaseDAO.queryCases(ownershipFilter, closed, searchTerm);
        return (List<Case>) Security.stripInaccessible(AccessType.READABLE, raw).getRecords();
    }

    public static Case getCaseDetail(Id caseId, Id contactId, UserContext ctx) {
        enforceVisibility(caseId, contactId, ctx);
        Case detail = HelpDeskCaseDAO.queryCaseDetail(caseId);
        List<Case> sanitized = (List<Case>) Security.stripInaccessible(AccessType.READABLE, new List<Case>{ detail }).getRecords();
        return sanitized.isEmpty() ? null : sanitized[0];
    }

    public static List<CaseComment> getCaseComments(Id caseId, Id contactId, UserContext ctx) {
        enforceVisibility(caseId, contactId, ctx);
        List<CaseComment> comments = HelpDeskCaseDAO.queryComments(caseId);
        return (List<CaseComment>) Security.stripInaccessible(AccessType.READABLE, comments).getRecords();
    }

    public static List<ContentDocumentLink> getCaseAttachments(Id caseId, Id contactId, UserContext ctx) {
        enforceVisibility(caseId, contactId, ctx);
        List<ContentDocumentLink> links = HelpDeskCaseDAO.queryAttachments(caseId);
        return (List<ContentDocumentLink>) Security.stripInaccessible(AccessType.READABLE, links).getRecords();
    }

    public static CaseComment addComment(Id caseId, String commentBody, Id contactId, UserContext ctx) {
        enforceVisibility(caseId, contactId, ctx);
        if (String.isBlank(commentBody)) {
            throw new AuraHandledException('O comentário não pode estar vazio.');
        }
        CaseComment comment = new CaseComment();
        comment.ParentId = caseId;
        comment.CommentBody = commentBody;
        comment.IsPublished = true;
        List<CaseComment> sanitized = (List<CaseComment>) Security.stripInaccessible(AccessType.CREATABLE, new List<CaseComment>{ comment }).getRecords();
        if (sanitized.isEmpty()) {
            throw new AuraHandledException('Você não tem permissão para criar comentários.');
        }
        HelpDeskCaseDAO.insertComment(sanitized[0]);
        return sanitized[0];
    }

    public static Id createCase(String subject, String description, String richDescription, String typeValue, String reasonValue, String priorityValue, String suppliedEmail, String suppliedPhone, Id contactId, Id accountId) {
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject é obrigatório.');
        }
        Case newCase = new Case();
        newCase.Subject = subject;
        newCase.Description = description;
        if (String.isNotBlank(richDescription)) {
            newCase.Description_Rich__c = richDescription;
        }
        if (String.isNotBlank(typeValue)) {
            newCase.Type = typeValue;
        }
        if (String.isNotBlank(reasonValue)) {
            newCase.Reason = reasonValue;
        }
        if (String.isNotBlank(priorityValue)) {
            newCase.Priority = priorityValue;
        }
        newCase.SuppliedEmail = suppliedEmail;
        newCase.SuppliedPhone = suppliedPhone;
        newCase.Origin = 'Help Desk Salesforce';
        newCase.RecordTypeId = HelpDeskCaseDAO.resolveRecordTypeId('Case', 'Help_Desk_Salesforce');
        if (contactId != null) {
            newCase.ContactId = contactId;
        }
        if (accountId != null) {
            newCase.AccountId = accountId;
        }
        List<Case> sanitized = (List<Case>) Security.stripInaccessible(AccessType.CREATABLE, new List<Case>{ newCase }).getRecords();
        if (sanitized.isEmpty()) {
            throw new AuraHandledException('Você não tem permissão para criar casos.');
        }
        HelpDeskCaseDAO.insertCase(sanitized[0]);
        return sanitized[0].Id;
    }

    public static void uploadFiles(Id caseId, List<HelpDeskFilePayload> files, Id contactId, UserContext ctx) {
        if (caseId == null) {
            throw new AuraHandledException('caseId é obrigatório para anexar arquivos.');
        }
        if (files == null || files.isEmpty()) {
            return;
        }
        enforceVisibility(caseId, contactId, ctx);
        List<ContentVersion> versions = new List<ContentVersion>();
        for (HelpDeskFilePayload file : files) {
            if (file == null || String.isBlank(file.fileName) || String.isBlank(file.base64Data)) {
                continue;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = file.fileName;
            cv.PathOnClient = '/' + file.fileName;
            cv.VersionData = EncodingUtil.base64Decode(file.base64Data);
            cv.FirstPublishLocationId = caseId;
            versions.add(cv);
        }
        if (!versions.isEmpty()) {
            List<ContentVersion> sanitized = (List<ContentVersion>) Security.stripInaccessible(AccessType.CREATABLE, versions).getRecords();
            HelpDeskCaseDAO.insertVersions(sanitized);
        }
    }

    public static DefaultEntitiesDTO getDefaultEntities(Id contactId) {
        DefaultEntitiesDTO dto = new DefaultEntitiesDTO();
        Account a = HelpDeskContactDAO.findEnerzeeAccount();
        Contact c = HelpDeskContactDAO.findById(contactId);
        if (a != null) {
            dto.accountId = a.Id;
            dto.accountName = a.Name;
        }
        if (c != null) {
            dto.contactId = c.Id;
            dto.contactName = c.Name;
            dto.contactEmail = c.Email;
            dto.contactPhone = c.MobilePhone;
        }
        return dto;
    }

    public class UserContext {
        public Id userId;
        public Id contactId;
        public String email;
    }

    public static UserContext loadUserContext() {
        UserContext ctx = new UserContext();
        ctx.userId = UserInfo.getUserId();
        User u = [
            SELECT Id, ContactId, Email
            FROM User
            WHERE Id = :ctx.userId
        ];
        ctx.contactId = u.ContactId;
        ctx.email = u.Email;
        return ctx;
    }

    private static String buildOwnershipFilter(UserContext ctx, Id overrideContactId) {
        if (overrideContactId != null) {
            return 'ContactId = \'' + String.escapeSingleQuotes(String.valueOf(overrideContactId)) + '\'';
        }
        if (ctx.contactId != null) {
            return 'ContactId = \'' + String.escapeSingleQuotes(String.valueOf(ctx.contactId)) + '\'';
        }
        if (String.isNotBlank(ctx.email)) {
            String emailEscaped = String.escapeSingleQuotes(ctx.email);
            String userIdEscaped = String.escapeSingleQuotes(String.valueOf(ctx.userId));
            return '(SuppliedEmail = \'' + emailEscaped + '\' OR CreatedById = \'' + userIdEscaped + '\')';
        }
        return 'CreatedById = \'' + String.escapeSingleQuotes(String.valueOf(ctx.userId)) + '\'';
    }

    private static void enforceVisibility(Id caseId, Id overrideContactId, UserContext ctx) {
        String ownershipFilter = buildOwnershipFilter(ctx, overrideContactId);
        String query = 'SELECT Id FROM Case WHERE Id = :caseId AND ' + ownershipFilter + ' LIMIT 1';
        List<Case> rows = Database.query(query);
        if (rows.isEmpty()) {
            throw new AuraHandledException('Caso não encontrado ou sem permissão de acesso.');
        }
    }
}
