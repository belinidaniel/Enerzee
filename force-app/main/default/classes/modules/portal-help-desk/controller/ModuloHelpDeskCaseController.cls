/**
 * Módulo Help Desk - controlador Apex para lista e detalhes de casos.
 * Localização lógica: modulo/helpDesk.
 */
public with sharing class ModuloHelpDeskCaseController {
    private class UserContext {
        Id userId;
        Id contactId;
        String email;
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getCases(String filterType, String searchTerm) {
        UserContext ctx = loadUserContext();
        String ownershipFilter = buildOwnershipFilter(ctx);
        String statusFilter = (filterType != null && filterType.toLowerCase() == 'closed') ? 'Status = \'Closed\'' : 'Status != \'Closed\'';
        String query = 'SELECT Id, CaseNumber, Subject, Status, LastModifiedDate, Contact.Name, ContactId ' +
            'FROM Case WHERE ' + ownershipFilter + ' AND ' + statusFilter;

        if (String.isNotBlank(searchTerm)) {
            String pattern = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (Subject LIKE :pattern OR CaseNumber LIKE :pattern)';
        }

        query += ' ORDER BY LastModifiedDate DESC';
        List<Case> results = Database.query(query);
        return (List<Case>) Security.stripInaccessible(AccessType.READABLE, results).getRecords();
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseDetail(Id caseId) {
        enforceVisibility(caseId);
        Case detail = [
            SELECT Id, CaseNumber, Subject, Status, CreatedDate, LastModifiedDate, Contact.Name, ContactId
            FROM Case
            WHERE Id = :caseId
        ];
        List<Case> sanitized = (List<Case>) Security.stripInaccessible(AccessType.READABLE, new List<Case>{ detail }).getRecords();
        return sanitized.isEmpty() ? null : sanitized[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<CaseComment> getCaseComments(Id caseId) {
        enforceVisibility(caseId);
        List<CaseComment> comments = [
            SELECT Id, ParentId, CommentBody, IsPublished, CreatedDate, CreatedById, CreatedBy.Name
            FROM CaseComment
            WHERE ParentId = :caseId AND (IsPublished = TRUE OR IsPublished = NULL)
            ORDER BY CreatedDate DESC
        ];
        return (List<CaseComment>) Security.stripInaccessible(AccessType.READABLE, comments).getRecords();
    }

    @AuraEnabled
    public static CaseComment addComment(Id caseId, String commentBody) {
        enforceVisibility(caseId);
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

        insert sanitized;
        return sanitized[0];
    }

    public class DefaultEntitiesDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
    }

    @AuraEnabled(cacheable=true)
    public static DefaultEntitiesDTO getDefaultEntities() {
        DefaultEntitiesDTO dto = new DefaultEntitiesDTO();
        try {
            Contact c = [
                SELECT Id, Name
                FROM Contact
                WHERE Name LIKE '%Enerzee%'
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            dto.contactId = c.Id;
            dto.contactName = c.Name;
        } catch (Exception e) {
            // Sem contato padrão
        }
        try {
            Account a = [
                SELECT Id, Name
                FROM Account
                WHERE Name LIKE '%Enerzee%'
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            dto.accountId = a.Id;
            dto.accountName = a.Name;
        } catch (Exception e) {
            // Sem conta padrão
        }
        return dto;
    }

    @AuraEnabled
    public static Id createCase(String subject, String description, String typeValue, String reasonValue, String priorityValue, String suppliedEmail, String suppliedPhone, Id contactId, Id accountId) {
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject é obrigatório.');
        }

        Case newCase = new Case();
        newCase.Subject = subject;
        newCase.Description = description;
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
        newCase.RecordTypeId = resolveRecordTypeId('Case', 'Help_Desk_Salesforce');

        if (contactId != null) {
            newCase.ContactId = contactId;
        } else {
            UserContext ctx = loadUserContext();
            if (ctx.contactId != null) {
                newCase.ContactId = ctx.contactId;
            }
        }
        if (accountId != null) {
            newCase.AccountId = accountId;
        }

        List<Case> sanitized = (List<Case>) Security.stripInaccessible(AccessType.CREATABLE, new List<Case>{ newCase }).getRecords();
        if (sanitized.isEmpty()) {
            throw new AuraHandledException('Você não tem permissão para criar casos.');
        }

        insert sanitized;
        return sanitized[0].Id;
    }

    private static UserContext loadUserContext() {
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

    private static String buildOwnershipFilter(UserContext ctx) {
        if (ctx.contactId != null) {
            return 'ContactId = :ctx.contactId';
        }
        if (String.isNotBlank(ctx.email)) {
            return '(SuppliedEmail = :ctx.email OR CreatedById = :ctx.userId)';
        }
        return 'CreatedById = :ctx.userId';
    }

    private static Id resolveRecordTypeId(String sObjectName, String developerName) {
        Map<String, Schema.RecordTypeInfo> infos = Schema.getGlobalDescribe().get(sObjectName).getDescribe().getRecordTypeInfosByDeveloperName();
        Schema.RecordTypeInfo info = infos.get(developerName);
        if (info == null) {
            throw new AuraHandledException('Record Type não encontrado: ' + developerName);
        }
        return info.getRecordTypeId();
    }

    private static void enforceVisibility(Id caseId) {
        UserContext ctx = loadUserContext();
        String ownershipFilter = buildOwnershipFilter(ctx);
        String query = 'SELECT Id FROM Case WHERE Id = :caseId AND ' + ownershipFilter + ' LIMIT 1';
        List<Case> rows = Database.query(query);
        if (rows.isEmpty()) {
            throw new AuraHandledException('Caso não encontrado ou sem permissão de acesso.');
        }
    }
}
