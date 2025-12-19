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
}
