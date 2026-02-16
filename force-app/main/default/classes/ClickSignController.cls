public with sharing class ClickSignController {

    @AuraEnabled
    public static ClickSign__c prepareToSend(Id templateId, Id recordId){
            ClickSignTemplate__c template = ClickSignDAO.getTemplatesById(templateId)[0];
            ClickSign__c clicksign = ClickSignDAO.getOrCreateClickSign(recordId);
            clicksign.ClickSignTemplate__c = templateId;
            update clicksign;

            list<ClickSignSigner__c> signerToCreateList = new list<ClickSignSigner__c> ();

            for(ClickSignSigner__c signer : template.ClickSignSigners__r) {                
                signer.ClickSignTemplate__c = templateId;
                signer.Id = null;
                signer.SFexternalId__c = signer.Email__c + '_' + clicksign.Id;
                signer.clickSign__c = clicksign.Id;
                signer.ClickSignTemplate__c = null;
                if (signer.SignerType__c == 'object') {
                    List<ClickSignSigner__c> signerList = ClickSignUtils.createSignersByJson('['+signer.ContactsMapping__c+']',null, recordId);
                    signer.Email__c = signerList[0].Email__c;
                    signer.Name = signerList[0].Name;
                }
                signerToCreateList.add(signer);
            }

            upsert signerToCreateList SFexternalId__c ;
            return clicksign;
    }
 
    @AuraEnabled
    public static string process( ClickSign__c clickSign, Id recordId, String currentStep){
            clickSign = [
                SELECT Id, Name,CurrentStep__c,Status__c, ClickSignEnvelope__c,ClickSignTemplate__c,
                ClickSignTemplate__r.FileName__c,ClickSignTemplate__r.ObjectMappings__c,
                clickSignTemplate__r.JsonContractInformation__c, ClickSignTemplate__r.ExternalId__c,ContractNumberFml__c,ContractNumber__c
                FROM ClickSign__c
                WHERE Id = :clickSign.Id
            ];
            if(currentStep != null){
                clickSign.CurrentStep__c = currentStep;
            }
            Integer contractNumber;
            if(currentStep == 'Documents'){
                contractNumber = generateNextContractNumber(clickSign.Id);
                // saveContract(contractNumber, clickSign.Id);
            }
            
            List<ClickSignService.EnvelopeInput> envelopesInput = new List<ClickSignService.EnvelopeInput>();
            ClickSignService.EnvelopeInput envelope = new ClickSignService.EnvelopeInput();
            envelope.clickSignId = clickSign.Id;
            envelope.envelopeId = clickSign.ClickSignEnvelope__c;
            if(clickSign.CurrentStep__c == 'Documents'){
                if(clickSign.ClickSignTemplate__c != null){
                    ClickSignService.Document document = new ClickSignService.Document();
                    document.externalId = clickSign.ClickSignTemplate__r.ExternalId__c;
                    document.filename = clickSign.ClickSignTemplate__r.FileName__c;
                    document.mergeFields = ClickSignUtils.generateMapFields(recordId, clickSign.ClickSignTemplate__r.ObjectMappings__c,ClickSignUtils.generateContractNumberString(contractNumber),clickSign.clickSignTemplate__r.JsonContractInformation__c);
                    List<clickSignService.Document> documents = new List<clickSignService.Document>();
                    documents.add(document);
                    envelope.documents = documents;
                }else{
                    envelope.documents = ClickSignUtils.getFilesbyClickSignId(clickSign.Id); 
                }
            }
            envelopesInput.add(envelope);
            ClickSignService.process(envelopesInput,clickSign.CurrentStep__c);
            
            
            return 'success';
    }

    @future
    public static void saveContract(Integer contractNumber,Id clickSignId){
        ClickSign__c click = New ClickSign__c();
        click.Id = clickSignId;
        click.ContractNumber__c = ContractNumber;
    }

    private static Integer generateNextContractNumber(Id clickSignId) {
        // Get all contracts with status 'Document Send to Assign' and 'Document Assign'
        List<contract> contracts = [
            SELECT id,ContractNumber__c from Contract WHERE ContractNumber__c != null ORDER BY ContractNumber__c DESC
            LIMIT 1
        ];
        if (!contracts.isEmpty()) {
            Integer lastContractNumber = Integer.valueOf(contracts[0].ContractNumber__c);
            return Integer.valueOf(lastContractNumber + 1);
        } else {
            return 1;
        }
    }

    @AuraEnabled
    public static ClickSign__c getOrCreateClickSign(Id recordId) {
        try {
            return ClickSignDAO.getOrCreateClickSign(recordId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static ClickSign__c cancelAndCreateClickSign(Id recordId) {
        try {
            return ClickSignDAO.cancelAndCreateClickSign(recordId);
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting ClickSign: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ClickSign__c createNewClickSign(Id recordId) {
        SObject record = Database.query('SELECT Id FROM ' + recordId.getSObjectType().getDescribe().getName() + ' WHERE Id = :recordId LIMIT 1');
        return ClickSignUtils.createClickSign(record);
    }

    @AuraEnabled
    public static void deleteDocument(String documentId) {
        try {
            ContentDocument document = [SELECT Id FROM ContentDocument WHERE Id = :documentId LIMIT 1];
            delete document;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ContentDocument> getDocuments(String clickSignId) {
        try {
            // Fetch ContentDocumentLink records associated with the clickSignId
            List<ContentDocumentLink> documentLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :clickSignId
            ];
    
            // Extract ContentDocument IDs from the links
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink link : documentLinks) {
                documentIds.add(link.ContentDocumentId);
            }
    
            // Fetch ContentDocument records using the IDs
            if (!documentIds.isEmpty()) {
                return [
                    SELECT Id, Title,LatestPublishedVersionId
                    FROM ContentDocument
                    WHERE Id IN :documentIds
                ];
            } else {
                return new List<ContentDocument>(); // Return an empty list if no documents are found
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void uploadDocument(String fileName, String base64Data, String contentType, String clickSignId) {
            // Decode the Base64 string
            Blob fileBlob = EncodingUtil.base64Decode(base64Data);
    
            // Create a new ContentVersion record
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = '/' + fileName;
            contentVersion.VersionData = fileBlob;
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
            contentDocumentLinkGuest.LinkedEntityId = clickSignId;
            contentDocumentLinkGuest.ShareType = 'V'; // Viewer permission
            contentDocumentLinkGuest.Visibility = 'AllUsers';

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = contentDocument.Id;
            contentDocumentLink.LinkedEntityId = guestUser.Id;
            contentDocumentLink.ShareType = 'V'; // Viewer permission
            contentDocumentLink.Visibility = 'AllUsers';
            insert new List<ContentDocumentLink> {contentDocumentLink, contentDocumentLinkGuest, contentDocumentLinkSite};
            ClickSign__c clickSign = new clickSign__c();
            clickSign.Id = clickSignId;
            clickSign.clickSignTemplate__c = null;
            update clickSign;
    }
    
    // Save a recipient (Add/Edit functionality)
    @AuraEnabled
    public static ClickSignSigner__c saveRecipient(Map<String, Object> recipient, String clickSignId,String templateId) {
        if (recipient == null) {
            throw new AuraHandledException('Recipient data is required.');
        }

        // Create or update the ClickSignSigner record
        ClickSignSigner__c signer = new ClickSignSigner__c();
        signer.Name = (String) recipient.get('name');
        signer.Email__c = (String) recipient.get('email');
        signer.Role__c = (String) recipient.get('role');
        signer.User__c = (String) recipient.get('userId');
        signer.Contact__c = (String) recipient.get('contactId');
        signer.SignerType__c = (String) recipient.get('signerType');
        signer.ContactsMapping__c = (String) recipient.get('contactsMapping');
        signer.RoleLabel__c = (String) recipient.get('roleLabel');

        if(templateId != null){
            signer.ClickSignTemplate__c = templateId;
            signer.SFExternalId__c = (String) recipient.get('email') + '_' + templateId; // Assuming ExternalId is based on email and ClickSign ID
        }
        system.debug('clickSignId----------------: ' + clickSignId);
        if(clickSignId != null){
            signer.ClickSign__c = clickSignId;
            signer.SFExternalId__c = (String) recipient.get('email') + '_' + clickSignId; // Assuming ExternalId is based on email and ClickSign ID
        }
        insert signer;
        return signer;
    }

    // Fetch all recipients associated with a ClickSign record
    @AuraEnabled
    public static List<ClickSignSigner__c> getRecipients(String recordId) {
        System.debug('recordId: ' + recordId);
        if (String.isEmpty(recordId)) {
            throw new AuraHandledException('ClickSign or Tempalte ID is required.');
        }

        return [
            SELECT Id, Name, Email__c, Role__c,Contact__r.Name,Contact__r.Id,contact__r.Email,
            User__r.Name,User__r.Id,User__r.Email,signerType__c
            FROM ClickSignSigner__c
            WHERE ClickSign__c = :recordId OR ClickSignTemplate__c = :recordId
        ];
    }

    // Delete a recipient
    @AuraEnabled
    public static void deleteRecipient(String recipientId) {
        System.debug('recipientId: ' + recipientId);
        if (String.isEmpty(recipientId)) {
            throw new AuraHandledException('Recipient ID is required.');
        }

        try {
            ClickSignSigner__c signer = [SELECT Id FROM ClickSignSigner__c WHERE Id = :recipientId];
            delete signer;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting recipient: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateClickSignCurrentStep(String clickSignId, String currentStep) {
        try {
            ClickSign__c clickSign = new ClickSign__c();
            clickSign.Id = clickSignId;
            clickSign.CurrentStep__c = currentStep;
            update clickSign;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating ClickSign status: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ClickSign__c> getClickSignRecords(Id recordId) {
        try {
            return ClickSignDAO.getClickSignRecords(recordId);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching ClickSign records: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getObjectList() {
        List<String> objectNames = new List<String>();
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        for (String objectName : schemaMap.keySet()) {
            objectNames.add(objectName);
        }
        return objectNames;
    }

    @AuraEnabled
    public static List<SObject> getRecordList(String objectName) {
        String query = 'SELECT Id FROM ' + objectName + ' LIMIT 100';
        return Database.query(query);
    }

    @AuraEnabled
    public static List<ClickSignTemplate__c> getActiveTemplates() {
        try {
            return [
                SELECT Id, Name
                FROM ClickSignTemplate__c
                WHERE IsActivate__c = true
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching active templates: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveTemplateId(Id clickSignId, Id templateId) {
        try {
            ClickSign__c clickSign = ClickSignDAO.getClickSignById(clickSignId);
            clickSign.ClickSignTemplate__c = templateId;
            update clickSign;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving template ID: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ClickSignTemplate__c> getTemplates(Id recordId) {
        try {
            List<ClickSignTemplate__c> templates = ClickSignDAO.getTemplatesByRecordId(recordId);
            return filterTemplatesByVisibilityRule(recordId, templates);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching templates: ' + e.getMessage());
        }
    }

    private static List<ClickSignTemplate__c> filterTemplatesByVisibilityRule(Id recordId, List<ClickSignTemplate__c> templates) {
        if (recordId == null || templates == null || templates.isEmpty()) {
            return templates;
        }

        Boolean hasVisibilityRule = false;
        Set<String> requiredFields = new Set<String>();
        for (ClickSignTemplate__c template : templates) {
            if (!String.isBlank(template.VisibilityRule__c)) {
                hasVisibilityRule = true;
                requiredFields.addAll(ClickSignVisibilityRuleService.collectRequiredFields(template.VisibilityRule__c));
            }
        }

        if (!hasVisibilityRule) {
            return templates;
        }

        Map<String, Object> recordMap = new Map<String, Object>();
        if (!requiredFields.isEmpty()) {
            String query = ClickSignVisibilityRuleService.buildRecordQuery(
                recordId.getSObjectType().getDescribe().getName(),
                new List<String>(requiredFields)
            );
            if (String.isBlank(query)) {
                return templates;
            }

            try {
                SObject sourceRecord = Database.query(query);
                for (String fieldApiName : requiredFields) {
                    recordMap.put(fieldApiName, sourceRecord.get(fieldApiName));
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Failed to load fields for ClickSign visibility rule: ' + ex.getMessage());
                return templates;
            }
        }

        List<ClickSignTemplate__c> visibleTemplates = new List<ClickSignTemplate__c>();
        for (ClickSignTemplate__c template : templates) {
            if (String.isBlank(template.VisibilityRule__c) ||
                ClickSignVisibilityRuleService.evaluate(template.VisibilityRule__c, recordMap)) {
                visibleTemplates.add(template);
            }
        }

        return visibleTemplates;
    }
}
