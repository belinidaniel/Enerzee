public with sharing class ClickSignDAO {
    public static ClickSign__c getClickSignById(Id clickSignId) {
        return [SELECT Id, Name, CurrentStep__c, Status__c, ClickSignEnvelope__c, ClickSignTemplate__c 
                FROM ClickSign__c WHERE Id = :clickSignId LIMIT 1];
    }

    public static void updateClickSign(ClickSign__c clickSign) {
        update clickSign;
    }
    
    
    public static void deleteClickSign(ClickSign__c clickSign) {
        delete clickSign;
    }

    public static List<ClickSignTemplate__c> getActiveTemplates() {
        return [SELECT Id, Name FROM ClickSignTemplate__c WHERE IsActivate__c = true];
    }

    public static ClickSign__c getOrCreateClickSign(Id recordId) {
        SObject record = Database.query('SELECT Id FROM ' + recordId.getSObjectType().getDescribe().getName() + ' WHERE Id = :recordId LIMIT 1');
        return ClickSignUtils.getOrCreateClickSign(record);
    }

    public static void saveTemplateId(Id clickSignId, Id templateId) {
        ClickSign__c clickSign = getClickSignById(clickSignId);
        clickSign.ClickSignTemplate__c = templateId;
        update clickSign;
    }

    public static ClickSign__c cancelAndCreateClickSign(Id recordId) {
        
        List<ClickSign__c> clickSigns = [SELECT Id, Status__c FROM ClickSign__c WHERE RecordId__c = :recordId and Status__c ='Draft'];
        for(ClickSign__c clickSign:clickSigns){
            clickSign.Status__c = 'Cancelled';
        }
        update clickSigns;
        return getOrCreateClickSign(recordId);
    }

    @AuraEnabled
    public static List<ClickSign__c> getClickSignRecords(Id recordId) {
        try {
            return [
                SELECT Id, Name,CurrentStep__c,Status__c, ClickSignEnvelope__c,ClickSignTemplate__c
                FROM ClickSign__c
                WHERE RecordId__c = :recordId AND Status__c != 'Cancelled' order by lastmodifieddate desc limit 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching ClickSign records: ' + e.getMessage());
        }
    }

    public static List<ClickSignTemplate__c> getTemplatesByRecordId(Id recordId) {
        try {
            string objectName = recordId.getSObjectType().getDescribe().getName();
            return [
                SELECT Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, Mapping__c, Stage__c, ObjectMappings__c, ObjectMappings2__c, SourceObject__c, Description__c, ClickSignEnvelope__c, ExternalId__c, FileName__c, IsActivate__c, ContactsMapping__c, ButtonLabel__c
                FROM ClickSignTemplate__c
                WHERE SourceObject__c = :objectName
                AND IsActivate__c = true
                AND ButtonLabel__c != null
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching templates: ' + e.getMessage());
        }
    }

    public static List<ClickSignTemplate__c> getTemplatesById(Id recordId) {
        try {
            return [
                SELECT Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, Mapping__c, Stage__c, ObjectMappings__c, ObjectMappings2__c,
                 SourceObject__c, Description__c, ClickSignEnvelope__c,
                  ExternalId__c, FileName__c, IsActivate__c, ContactsMapping__c, ButtonLabel__c,
                  (SELECT Id, Name, Status__c, ClickSignEnvelope__c, ClickSign__c, Email__c, ExternalId__c, Role__c, SFexternalId__c, ClickSignTemplate__c, Contact__c, User__c, fieldName__c, SignerType__c, ContactsMapping__c, RoleLabel__c from ClickSignSigners__r)
                FROM ClickSignTemplate__c
                WHERE IsActivate__c = true
                AND Id =: recordId
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching templates: ' + e.getMessage());
        }
    }
}