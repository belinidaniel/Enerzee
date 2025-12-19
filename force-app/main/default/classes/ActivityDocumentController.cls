public with sharing class ActivityDocumentController {

    public class RequiredDoc {
        @AuraEnabled public String name;
        @AuraEnabled public String observation;
    }

    public class AttachmentItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String activityName;
        @AuraEnabled public DateTime createdDate;
    }

    public class TaskContext {
        @AuraEnabled public String subject;
        @AuraEnabled public Id whatId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String idVirtualOffice;
    }

    @AuraEnabled(cacheable=true)
    public static List<RequiredDoc> getRequiredDocuments(String activitySubject) {
        if (String.isBlank(activitySubject)) {
            return new List<RequiredDoc>();
        }
        List<RequiredDoc> docs = new List<RequiredDoc>();
        for (ActivityRequiredDocument__mdt rec : [
            SELECT ActivitySubject__c, RequiredFiles__c, Observation__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :activitySubject
        ]) {
            if (!String.isBlank(rec.RequiredFiles__c)) {
                for (String name : rec.RequiredFiles__c.split(';')) {
                    if (String.isBlank(name)) {
                        continue;
                    }
                    RequiredDoc d = new RequiredDoc();
                    d.name = name.trim();
                    d.observation = rec.Observation__c;
                    docs.add(d);
                }
            }
        }
        return docs;
    }

    @AuraEnabled(cacheable=true)
    public static List<AttachmentItem> getAttachments(Id sobjectId) {
        if (sobjectId == null) {
            return new List<AttachmentItem>();
        }
        List<AttachmentItem> results = new List<AttachmentItem>();
        for (OpportunityAttachmentLink__c link : [
            SELECT Id, AttachmentDescription__c, ActivityName__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
            ORDER BY CreatedDate DESC
        ]) {
            AttachmentItem item = new AttachmentItem();
            item.id = link.Id;
            item.name = link.AttachmentDescription__c;
            item.activityName = link.ActivityName__c;
            item.createdDate = link.CreatedDate;
            results.add(item);
        }
        return results;
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
                    SELECT Projeto__c, Projeto__r.Oportunidade__c, Projeto__r.Oportunidade__r.IdVirtualOffice__c
                    FROM Instalacao__c
                    WHERE Id = :t.WhatId
                    LIMIT 1
                ];
                ctx.opportunityId = inst.Projeto__r != null ? inst.Projeto__r.Oportunidade__c : null;
                ctx.idVirtualOffice = (inst.Projeto__r != null && inst.Projeto__r.Oportunidade__r != null)
                    ? inst.Projeto__r.Oportunidade__r.IdVirtualOffice__c : null;
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

}
