public with sharing class ActivityDocumentController {

    public class RequiredDoc {
        @AuraEnabled public String name;
        @AuraEnabled public String observation;
    }

    public class AttachmentItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String activityName;
        @AuraEnabled public String docRequiredName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String url;
        @AuraEnabled public String downloadUrl;
    }

    public class CompletionStateItem {
        @AuraEnabled public String docRequiredName;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public DateTime completedDate;
        @AuraEnabled public Id completedById;
        @AuraEnabled public String completedByName;
    }

    public class TaskContext {
        @AuraEnabled public String subject;
        @AuraEnabled public Id whatId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String idVirtualOffice;
    }

    @AuraEnabled(cacheable=true)
    public static List<RequiredDoc> getRequiredDocuments(String activitySubject) {
        List<String> subjects = resolveActivitySubjects(activitySubject);
        if (subjects.isEmpty()) {
            return new List<RequiredDoc>();
        }

        Map<String, ActivityRequiredDocument__mdt> bySubject = new Map<String, ActivityRequiredDocument__mdt>();
        for (ActivityRequiredDocument__mdt rec : [
            SELECT ActivitySubject__c, RequiredFiles__c, Observation__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c IN :subjects
        ]) {
            bySubject.put(rec.ActivitySubject__c, rec);
        }

        List<RequiredDoc> docs = new List<RequiredDoc>();
        Set<String> seen = new Set<String>();
        for (String subject : subjects) {
            ActivityRequiredDocument__mdt rec = bySubject.get(subject);
            if (rec == null || String.isBlank(rec.RequiredFiles__c)) {
                continue;
            }
            for (String rawName : rec.RequiredFiles__c.split(';')) {
                String name = rawName != null ? rawName.trim() : null;
                if (String.isBlank(name)) {
                    continue;
                }
                String key = normalizeName(name);
                if (seen.contains(key)) {
                    continue;
                }
                RequiredDoc doc = new RequiredDoc();
                doc.name = name;
                doc.observation = rec.Observation__c;
                docs.add(doc);
                seen.add(key);
            }
        }
        return docs;
    }

    @AuraEnabled
    public static List<AttachmentItem> getAttachments(Id sobjectId, String activitySubject) {
        if (sobjectId == null) {
            return new List<AttachmentItem>();
        }

        List<String> subjects = resolveActivitySubjects(activitySubject);
        List<OpportunityAttachmentLink__c> links;
        if (subjects.isEmpty()) {
            links = [
                SELECT Id, AttachmentDescription__c, ActivityName__c, AttachmentURL__c,
                    InternalAttachmentURL__c, CreatedDate, DocRequiredName__c
                FROM OpportunityAttachmentLink__c
                WHERE SObjectId__c = :String.valueOf(sobjectId)
                    AND (IsChecklistState__c = false OR IsChecklistState__c = null)
                ORDER BY CreatedDate DESC
            ];
        } else {
            links = [
                SELECT Id, AttachmentDescription__c, ActivityName__c, AttachmentURL__c,
                    InternalAttachmentURL__c, CreatedDate, DocRequiredName__c
                FROM OpportunityAttachmentLink__c
                WHERE SObjectId__c = :String.valueOf(sobjectId)
                    AND ActivityName__c IN :subjects
                    AND (IsChecklistState__c = false OR IsChecklistState__c = null)
                ORDER BY CreatedDate DESC
            ];
        }

        List<AttachmentItem> results = new List<AttachmentItem>();
        for (OpportunityAttachmentLink__c link : links) {
            AttachmentItem item = new AttachmentItem();
            item.id = link.Id;
            item.name = link.AttachmentDescription__c;
            item.activityName = link.ActivityName__c;
            item.docRequiredName = link.DocRequiredName__c;
            item.createdDate = link.CreatedDate;
            item.url = String.isNotBlank(link.InternalAttachmentURL__c)
                ? link.InternalAttachmentURL__c
                : link.AttachmentURL__c;
            item.downloadUrl = item.url;
            results.add(item);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<CompletionStateItem> getDocumentCompletionStates(Id sobjectId, String activitySubject) {
        if (sobjectId == null) {
            return new List<CompletionStateItem>();
        }

        List<String> subjects = resolveActivitySubjects(activitySubject);
        if (subjects.isEmpty()) {
            return new List<CompletionStateItem>();
        }

        Map<String, CompletionStateItem> byDoc = new Map<String, CompletionStateItem>();
        for (OpportunityAttachmentLink__c rec : [
            SELECT Id, DocRequiredName__c, AttachmentDescription__c, Completed__c, CompletedDate__c,
                CompletedBy__c, CompletedBy__r.Name, LastModifiedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
                AND ActivityName__c IN :subjects
                AND IsChecklistState__c = true
            ORDER BY LastModifiedDate DESC
        ]) {
            String docName = String.isNotBlank(rec.DocRequiredName__c)
                ? rec.DocRequiredName__c
                : rec.AttachmentDescription__c;
            if (String.isBlank(docName)) {
                continue;
            }
            String key = normalizeName(docName);
            if (byDoc.containsKey(key)) {
                continue;
            }
            byDoc.put(key, toCompletionState(docName, rec));
        }

        return byDoc.values();
    }

    @AuraEnabled
    public static CompletionStateItem setDocumentCompleted(
        Id sobjectId,
        String activitySubject,
        String docRequiredName,
        Boolean completed
    ) {
        if (sobjectId == null) {
            throw new AuraHandledException('Registro relacionado é obrigatório.');
        }
        if (String.isBlank(activitySubject)) {
            throw new AuraHandledException('Atividade é obrigatória.');
        }
        if (String.isBlank(docRequiredName)) {
            throw new AuraHandledException('Documento obrigatório é obrigatório.');
        }

        String targetSubject = activitySubject.trim();
        List<String> subjects = resolveActivitySubjects(targetSubject);
        Boolean markAsCompleted = completed == true;

        if (markAsCompleted && !hasEvidence(sobjectId, subjects, docRequiredName)) {
            throw new AuraHandledException('Só é possível concluir após anexar ao menos uma evidência.');
        }

        OpportunityAttachmentLink__c stateRecord = findChecklistStateRecord(
            sobjectId,
            subjects,
            docRequiredName
        );
        if (stateRecord == null) {
            stateRecord = new OpportunityAttachmentLink__c(
                Name = buildChecklistStateName(docRequiredName),
                SObjectId__c = String.valueOf(sobjectId),
                ActivityName__c = targetSubject,
                DocRequiredName__c = docRequiredName.trim(),
                IsChecklistState__c = true
            );
        }

        stateRecord.Completed__c = markAsCompleted;
        stateRecord.CompletedDate__c = markAsCompleted ? System.now() : null;
        stateRecord.CompletedBy__c = markAsCompleted ? UserInfo.getUserId() : null;
        upsert stateRecord;

        OpportunityAttachmentLink__c saved = [
            SELECT Id, DocRequiredName__c, AttachmentDescription__c, Completed__c, CompletedDate__c,
                CompletedBy__c, CompletedBy__r.Name
            FROM OpportunityAttachmentLink__c
            WHERE Id = :stateRecord.Id
            LIMIT 1
        ];
        String resolvedDoc = String.isNotBlank(saved.DocRequiredName__c)
            ? saved.DocRequiredName__c
            : docRequiredName.trim();
        return toCompletionState(resolvedDoc, saved);
    }

    @AuraEnabled
    public static Boolean deleteAttachment(Id attachmentId) {
        if (attachmentId == null) {
            return false;
        }
        if (!Schema.sObjectType.OpportunityAttachmentLink__c.isDeletable()) {
            throw new AuraHandledException('Usuário sem permissão para remover anexos.');
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT Id, SObjectId__c, ActivityName__c, DocRequiredName__c, AttachmentDescription__c,
                AttachmentURL__c, InternalAttachmentURL__c, ContentDocumentId__c, IsChecklistState__c
            FROM OpportunityAttachmentLink__c
            WHERE Id = :attachmentId
            LIMIT 1
        ];
        if (links.isEmpty()) {
            return false;
        }

        OpportunityAttachmentLink__c link = links[0];
        Id parentId = parseSalesforceId(link.SObjectId__c);
        Id contentDocumentId = resolveContentDocumentId(link);
        Id classicAttachmentId = resolveClassicAttachmentId(link);

        if (contentDocumentId != null) {
            deleteContentDocumentAssets(contentDocumentId, parentId);
        }
        if (classicAttachmentId != null) {
            deleteClassicAttachment(classicAttachmentId);
        }

        delete link;

        if (link.IsChecklistState__c != true) {
            clearCompletionWhenNoEvidence(
                link.SObjectId__c,
                link.ActivityName__c,
                link.DocRequiredName__c
            );
        }
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static TaskContext getTaskContext(Id taskId) {
        TaskContext ctx = new TaskContext();
        if (taskId == null) {
            return ctx;
        }
        Task t = [
            SELECT Id, Subject, WhatId
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];
        ctx.subject = t.Subject;
        ctx.whatId = t.WhatId;

        if (t.WhatId != null) {
            String sobj = t.WhatId.getSObjectType().getDescribe().getName();
            if (sobj == 'Projeto__c') {
                Projeto__c proj = [
                    SELECT Oportunidade__c, Oportunidade__r.IdVirtualOffice__c
                    FROM Projeto__c
                    WHERE Id = :t.WhatId
                    LIMIT 1
                ];
                ctx.opportunityId = proj.Oportunidade__c;
                ctx.idVirtualOffice = proj.Oportunidade__r != null ? proj.Oportunidade__r.IdVirtualOffice__c : null;
            } else if (sobj == 'Instalacao__c') {
                Instalacao__c inst = [
                    SELECT Projeto__c,
                        Projeto__r.Oportunidade__c,
                        Projeto__r.Oportunidade__r.IdVirtualOffice__c,
                        Oportunidade__c,
                        Oportunidade__r.IdVirtualOffice__c
                    FROM Instalacao__c
                    WHERE Id = :t.WhatId
                    LIMIT 1
                ];
                ctx.opportunityId = inst.Oportunidade__c != null
                    ? inst.Oportunidade__c
                    : (inst.Projeto__r != null ? inst.Projeto__r.Oportunidade__c : null);
                ctx.idVirtualOffice = inst.Oportunidade__r != null
                    ? inst.Oportunidade__r.IdVirtualOffice__c
                    : (
                        inst.Projeto__r != null && inst.Projeto__r.Oportunidade__r != null
                            ? inst.Projeto__r.Oportunidade__r.IdVirtualOffice__c
                            : null
                    );
            } else if (sobj == 'Opportunity') {
                Opportunity opp = [
                    SELECT IdVirtualOffice__c
                    FROM Opportunity
                    WHERE Id = :t.WhatId
                    LIMIT 1
                ];
                ctx.opportunityId = opp.Id;
                ctx.idVirtualOffice = opp.IdVirtualOffice__c;
            }
        }
        return ctx;
    }

    private static CompletionStateItem toCompletionState(String docName, OpportunityAttachmentLink__c stateRecord) {
        CompletionStateItem item = new CompletionStateItem();
        item.docRequiredName = docName;
        item.completed = stateRecord.Completed__c;
        item.completedDate = stateRecord.CompletedDate__c;
        item.completedById = stateRecord.CompletedBy__c;
        item.completedByName = stateRecord.CompletedBy__r != null ? stateRecord.CompletedBy__r.Name : null;
        return item;
    }

    private static List<String> resolveActivitySubjects(String activitySubject) {
        if (String.isBlank(activitySubject)) {
            return new List<String>();
        }
        String subject = activitySubject.trim();
        if (TaskUtils.isRelatorioExecucaoDeObraSubject(subject)) {
            return TaskUtils.getRelatorioExecucaoDeObraSubjects();
        }
        return new List<String>{ subject };
    }

    private static Boolean hasEvidence(Id sobjectId, List<String> subjects, String docRequiredName) {
        String docName = docRequiredName != null ? docRequiredName.trim() : null;
        Integer evidenceCount = [
            SELECT COUNT()
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
                AND ActivityName__c IN :subjects
                AND DocRequiredName__c = :docName
                AND (IsChecklistState__c = false OR IsChecklistState__c = null)
                AND (
                    AttachmentURL__c != null
                    OR InternalAttachmentURL__c != null
                    OR ContentDocumentId__c != null
                )
        ];
        return evidenceCount > 0;
    }

    private static OpportunityAttachmentLink__c findChecklistStateRecord(
        Id sobjectId,
        List<String> subjects,
        String docRequiredName
    ) {
        String docName = docRequiredName != null ? docRequiredName.trim() : null;
        List<OpportunityAttachmentLink__c> records = [
            SELECT Id, Completed__c, CompletedDate__c, CompletedBy__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
                AND ActivityName__c IN :subjects
                AND DocRequiredName__c = :docName
                AND IsChecklistState__c = true
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    private static String buildChecklistStateName(String docRequiredName) {
        String base = 'Checklist - ' + docRequiredName.trim();
        Integer max = OpportunityAttachmentLink__c.Name.getDescribe().getLength();
        return base.length() > max ? base.substring(0, max) : base;
    }

    private static void clearCompletionWhenNoEvidence(String sobjectId, String activityName, String docRequiredName) {
        if (String.isBlank(sobjectId) || String.isBlank(activityName) || String.isBlank(docRequiredName)) {
            return;
        }

        Integer evidenceCount = [
            SELECT COUNT()
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :sobjectId
                AND ActivityName__c = :activityName
                AND DocRequiredName__c = :docRequiredName
                AND (IsChecklistState__c = false OR IsChecklistState__c = null)
                AND (
                    AttachmentURL__c != null
                    OR InternalAttachmentURL__c != null
                    OR ContentDocumentId__c != null
                )
        ];
        if (evidenceCount > 0) {
            return;
        }

        List<OpportunityAttachmentLink__c> statesToUpdate = [
            SELECT Id, Completed__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :sobjectId
                AND ActivityName__c = :activityName
                AND DocRequiredName__c = :docRequiredName
                AND IsChecklistState__c = true
                AND Completed__c = true
        ];

        for (OpportunityAttachmentLink__c state : statesToUpdate) {
            state.Completed__c = false;
            state.CompletedDate__c = null;
            state.CompletedBy__c = null;
        }
        if (!statesToUpdate.isEmpty()) {
            update statesToUpdate;
        }
    }

    private static void deleteContentDocumentAssets(Id contentDocumentId, Id parentId) {
        if (!Schema.sObjectType.ContentDocumentLink.isDeletable()) {
            throw new AuraHandledException('Usuário sem permissão para remover arquivos.');
        }

        List<ContentDocumentLink> docLinks = new List<ContentDocumentLink>();
        if (parentId != null) {
            docLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
                    AND LinkedEntityId = :parentId
            ];
        } else {
            docLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
            ];
        }

        if (!docLinks.isEmpty()) {
            delete docLinks;
        }

        Integer remainingLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
        ];
        if (remainingLinks == 0) {
            if (!Schema.sObjectType.ContentDocument.isDeletable()) {
                throw new AuraHandledException('Usuário sem permissão para remover arquivos.');
            }
            List<ContentDocument> docs = [
                SELECT Id
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];
            if (!docs.isEmpty()) {
                delete docs[0];
            }
        }
    }

    private static void deleteClassicAttachment(Id attachmentId) {
        if (!Schema.sObjectType.Attachment.isDeletable()) {
            throw new AuraHandledException('Usuário sem permissão para remover anexos.');
        }
        List<Attachment> attachments = [
            SELECT Id
            FROM Attachment
            WHERE Id = :attachmentId
            LIMIT 1
        ];
        if (!attachments.isEmpty()) {
            delete attachments[0];
        }
    }

    private static Id resolveContentDocumentId(OpportunityAttachmentLink__c link) {
        Id fileId = parseSalesforceId(link.ContentDocumentId__c);
        if (fileId == null) {
            fileId = parseSalesforceId(link.InternalAttachmentURL__c);
        }
        if (fileId == null) {
            fileId = parseSalesforceId(link.AttachmentURL__c);
        }
        if (fileId == null) {
            return null;
        }

        String prefix = String.valueOf(fileId).left(3);
        if (prefix == '069') {
            return fileId;
        }
        if (prefix == '068') {
            List<ContentVersion> versions = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :fileId
                LIMIT 1
            ];
            return versions.isEmpty() ? null : versions[0].ContentDocumentId;
        }
        return null;
    }

    private static Id resolveClassicAttachmentId(OpportunityAttachmentLink__c link) {
        Id attachmentId = parseSalesforceId(link.AttachmentURL__c);
        if (attachmentId == null) {
            attachmentId = parseSalesforceId(link.InternalAttachmentURL__c);
        }
        if (attachmentId == null) {
            return null;
        }
        return String.valueOf(attachmentId).left(3) == '00P' ? attachmentId : null;
    }

    private static Id parseSalesforceId(String source) {
        if (String.isBlank(source)) {
            return null;
        }

        Id direct = tryParseId(source.trim());
        if (direct != null) {
            return direct;
        }

        String normalized = source.replaceAll('[^A-Za-z0-9]', ' ');
        for (String token : normalized.split('\\s+')) {
            if (token == null || (token.length() != 15 && token.length() != 18)) {
                continue;
            }
            Id parsed = tryParseId(token);
            if (parsed != null) {
                return parsed;
            }
        }
        return null;
    }

    private static Id tryParseId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static String normalizeName(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.toLowerCase();
        normalized = normalized
            .replaceAll('[áàãâä]', 'a')
            .replaceAll('[éèêë]', 'e')
            .replaceAll('[íìîï]', 'i')
            .replaceAll('[óòõôö]', 'o')
            .replaceAll('[úùûü]', 'u')
            .replaceAll('[ç]', 'c');
        normalized = normalized.replaceAll('[^a-z0-9]+', '_');
        normalized = normalized.replaceAll('^_+|_+$', '');
        return normalized;
    }
}
