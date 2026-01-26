/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-26-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class ClickSignTemplateController {
    public String errorMessage { get; set; }
    public String objectHomeUrl { get; set; }
    public String namespace { get; set; }

    public ClickSignTemplateController(ApexPages.StandardController controller) {
        errorMessage = null;
        objectHomeUrl = '/' + controller.getRecord().getSObjectType().getDescribe().getKeyPrefix();

        Schema.DescribeSObjectResult describeResult = ClickSignTemplate__c.SObjectType.getDescribe();
        namespace = describeResult.getName();
    }
    
    
    // Code we will invoke on page load.
    public PageReference forwardToStartPage() {
        return Network.communitiesLanding();
    }
    
    public ClickSignTemplateController() {}

    @AuraEnabled
    public static Id createClickSignTemplate(String name, String description, String objectName) {
        ClickSignTemplate__c newTemplate = new ClickSignTemplate__c();
        newTemplate.Name = name;
        newTemplate.Description__c = description;
        newTemplate.SourceObject__c = objectName;
        newTemplate.Stage__c = 'Select Source';
        insert newTemplate;
        return newTemplate.Id;
    }

    @AuraEnabled
    public static ContentVersion getVersionData() {
        return [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId = '069Ha000002vkMvIAI' LIMIT 1];
    }

    @AuraEnabled
    public static ClickSignTemplate__c getClickSignTemplateToSend(Id templateId, String recordId) {
        ClickSignTemplate__c clickSignTemplate= [SELECT Id, Name, ContactsMapping__c,Description__c,
        (SELECT id,Email__c,Role__c, RoleLabel__c, ContactsMapping__c,Name,SignerType__c from ClickSignSigners__r),
        SourceObject__c, Stage__c,ObjectMappings__c ,FileName__c,ButtonLabel__c FROM ClickSignTemplate__c WHERE Id = :templateId LIMIT 1];
        
        for(ClickSignSigner__c signer : clickSignTemplate.ClickSignSigners__r) {
            if (signer.SignerType__c == 'object') {
                List<ClickSignSigner__c> signerList = ClickSignUtils.createSignersByJson('['+signer.ContactsMapping__c+']',null, recordId);
                signer.Email__c = signerList[0].Email__c;
                signer.Name = signerList[0].Name;
            }
        }
        return clickSignTemplate;
    }

    @AuraEnabled
    public static ClickSignTemplate__c getClickSignTemplate(Id templateId, String recordId) {
        ClickSignTemplate__c clickSignTemplate= [SELECT Id, Name, ContactsMapping__c,Description__c,
        (SELECT id,Email__c,Role__c, RoleLabel__c, ContactsMapping__c,Name,SignerType__c from ClickSignSigners__r),
        SourceObject__c, Stage__c,ObjectMappings__c ,FileName__c,ButtonLabel__c FROM ClickSignTemplate__c WHERE Id = :templateId LIMIT 1];
        
        return clickSignTemplate;
    }

    @AuraEnabled
    public static void updateClickSignTemplate(ClickSignTemplate__c template) {
        update template;
    }

    @AuraEnabled
    public static void deleteDocument(String templateId) {
        try {
            List<ContentDocument> document = getDocuments(templateId);
            if (!document.isEmpty()) {
                delete document;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting document: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ContentDocument> getDocuments(String templateId) {
        try {
            System.debug('Fetching documents for templateId: ' + templateId);
            return ClickSignUtils.getDocuments(templateId);
        } catch (Exception e) {
            System.debug('Error fetching documents: ' + e.getMessage());
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void activateTemplate( String templateId) {
        try {
            ClickSignTemplate__c template = new ClickSignTemplate__c();
            template.Id = templateId;  
            template.IsActivate__c = true;

            update template;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void uploadDocument(String fileName, String base64Data, String contentType, String templateId) {
            deleteDocument(templateId);
            // Decode the Base64 string
            Blob fileBlob = EncodingUtil.base64Decode(base64Data);
    
            // Create a new ContentVersion record
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = '/' + fileName;
            contentVersion.VersionData = fileBlob;
            contentVersion.Istemplate__c = true;
            insert contentVersion;
    
            // Retrieve the ContentDocumentId
            ContentDocument contentDocument = [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN (
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :contentVersion.Id
                )
                LIMIT 1
            ];

            User guestUser = [SELECT Id,Profile.name,ProfileId FROM User WHERE Name = 'Enerzee Usuário convidado do site'];
            Site site = [SELECT Id, Name FROM Site WHERE Name = 'Enerzee'];

            ContentDocumentLink contentDocumentLinkSite = new ContentDocumentLink();
            contentDocumentLinkSite.ContentDocumentId = contentDocument.Id;
            contentDocumentLinkSite.LinkedEntityId = site.Id;
            contentDocumentLinkSite.ShareType = 'V'; // Viewer permission
            contentDocumentLinkSite.Visibility = 'AllUsers';
    
            // Link the ContentDocument to the specified record
            ContentDocumentLink contentDocumentLinkGuest = new ContentDocumentLink();
            contentDocumentLinkGuest.ContentDocumentId = contentDocument.Id;
            contentDocumentLinkGuest.LinkedEntityId = templateId;
            contentDocumentLinkGuest.ShareType = 'V'; // Viewer permission
            contentDocumentLinkGuest.Visibility = 'AllUsers';

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = contentDocument.Id;
            contentDocumentLink.LinkedEntityId = guestUser.Id;
            contentDocumentLink.ShareType = 'V'; // Viewer permission
            contentDocumentLink.Visibility = 'AllUsers';
            insert new List<ContentDocumentLink> {contentDocumentLink, contentDocumentLinkGuest, contentDocumentLinkSite};
    }
    

    @AuraEnabled
    public static List<ContentDocument> getTemplateClickSign(String templateId) {
        try {
            List<ContentDocumentLink> documentLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :templateId
            ];
    
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink link : documentLinks) {
                documentIds.add(link.ContentDocumentId);
            }
            System.debug('documentIds '+documentIds);
            if (!documentIds.isEmpty()) {
                List<ContentDocument> documents = [
                    SELECT Id, Title, LatestPublishedVersionId,LatestPublishedVersion.versionData
                    FROM ContentDocument
                    WHERE Id IN :documentIds and LatestPublishedVersion.Istemplate__c = false
                ];
                return documents;
            }
            return new List<ContentDocument>();
        } catch (Exception e) {
            System.debug('Error fetching documents: ' + e.getMessage());
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

    public PageReference redirectOnEdit() {
        Id templateId = ApexPages.currentPage().getParameters().get('id');
        if (templateId != null) {
            return new PageReference('/' + templateId + '/e');
        }
        return null;
    }

    public PageReference redirectOnNewTemplate() {
        Id templateId = ApexPages.currentPage().getParameters().get('templateId');
        if (templateId != null) {
            return new PageReference('/' + templateId);
        }
        return null;
    }

    public PageReference redirectOnCancel() {
        return new PageReference(objectHomeUrl);
    }

    public PageReference redirectOnFinish() {
        Id templateId = ApexPages.currentPage().getParameters().get('templateId');
        if (templateId != null) {
            return new PageReference('/' + templateId);
        }
        return new PageReference(objectHomeUrl);
    }


    @AuraEnabled
    public static String generatePreview(String recordId, String templateId){
        System.debug('generatePreview: recordId=' + recordId + ', templateId=' + templateId);
        //change limit ObjectMappings2__c
        ClickSignTemplate__c template = [SELECT Id, Name, Description__c,ExternalId__c, SourceObject__c,ObjectMappings__c,ObjectMappings2__c, Stage__c,fileName__c FROM ClickSignTemplate__c WHERE Id = :templateId LIMIT 1];
        List<ContentDocument> documents = getDocuments(templateId);
        if (documents == null || documents.isEmpty()) {
            throw new AuraHandledException('Nenhum documento encontrado para gerar o preview.');
        }

        ClickSignService.Document document = new ClickSignService.Document(); 
        document.id = templateId;
        if (!template.fileName__c.endsWith('.docx')) {
            document.filename = template.fileName__c + '.docx';
        } else {
            document.filename = template.fileName__c;
        }
        document.externalId  = template.ExternalId__c;
        document.file = EncodingUtil.base64Encode(documents[0].LatestPublishedVersion.versionData);
        System.debug('template.ObjectMappings__c ' + template.ObjectMappings__c);
        document.mergeFields = ClickSignUtils.generateMapFields(recordId,template.ObjectMappings__c,null,null);
        System.debug('document.mergeField ' + document.mergeFields);
        ClickSignService.createTemplatePreview(document);  
        return 'success'; 
    }

    @AuraEnabled
    public static String generateTemplateFromMappings(String templateId){
        ClickSignTemplate__c template = [SELECT Id, ObjectMappings__c FROM ClickSignTemplate__c WHERE Id = :templateId LIMIT 1];
        if (String.isBlank(template.ObjectMappings__c)) {
            return 'no-mappings';
        }
        List<ContentDocument> documents = getDocuments(templateId);
        if (documents == null || documents.isEmpty()) {
            return 'no-document';
        }

        System.enqueueJob(new ClickSignTemplateQueueable(templateId));
        return 'queued';
    }

    @AuraEnabled
    public static String getContentDocumentDownloadUrl(Id recordId) {
        // Find the associated ContentDocumentLinks
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
        
        if (links.isEmpty()) {
            return null;
        }
        Set<id> linkSet = new set<Id>();

        for(ContentDocumentLink link : links) {
            System.debug('Found ContentDocumentLink: ' + JSON.serialize(link));
            linkSet.add(link.ContentDocumentId);
        }

        // Fetch the ContentDocument download URL
        ContentVersion version = [
            SELECT Id, VersionData, Title 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :linkSet
            AND istemplate__c = false
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return version != null ? version.Id : null;
    }

    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        try {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjectType != null) {
                Map<String, Schema.SObjectField> fieldsMap = sObjectType.getDescribe().fields.getMap();
                for (Schema.SObjectField field : fieldsMap.values()) {
                    Schema.DescribeFieldResult fieldResult = field.getDescribe();
                    if (fieldResult.isAccessible() && (fieldResult.getType() == Schema.DisplayType.REFERENCE || fieldResult.getType() == Schema.DisplayType.STRING)) {
                        Map<String, String> fieldInfo = new Map<String, String>();
                        fieldInfo.put('label', fieldResult.getLabel());
                        fieldInfo.put('apiName', fieldResult.getName());
                        fieldList.add(fieldInfo);
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching object fields: ' + e.getMessage());
        }
        return fieldList;
    }

    @AuraEnabled
    public static void createButtonInLayout(Id templateId, String buttonLabel) {
        try {
            ClickSignTemplate__c template = [SELECT Id, SourceObject__c FROM ClickSignTemplate__c WHERE Id = :templateId LIMIT 1];
            template.ButtonLabel__c = buttonLabel;

            update template;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating button in layout: ' + e.getMessage());
        }
    }

}
