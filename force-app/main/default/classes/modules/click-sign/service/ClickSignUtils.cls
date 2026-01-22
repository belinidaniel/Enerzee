public with sharing class ClickSignUtils {
    
    public Enum METHOD {
        CREATE_ENVELOPE,
        ACTIVATE_ENVELOPE,
        CREATE_DOCUMENT,
        CREATE_TEMPLATE,
        CREATE_SIGNER,
        CREATE_REQUIREMENT,
        GET_TEMPLATES,
        GET_ENVELOPE,
        NOTIFICATION,
        DELETE_DOCUMENT
    }

    public static Integrador__mdt getIntegration(String name){
        return [
            SELECT  LastToken__c, URL__c, ContentType__c, Method__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :name
        ];
    }

    public static ClickSignLog__c createLog(String className, String methodName, Object source){

        ClickSignLog__c lg = new ClickSignLog__c(
            Class__c  = className,
            Method__c = methodName
        );

        //Set additional log fields based on source type
        //General exceptions
        if(source instanceOf Exception){

            Exception e = (Exception) source;

            lg.Message__c          = e.getMessage();
            lg.Type__c             = e.getTypeName();
            lg.LineNumber__c       = String.valueOf(e.getLineNumber());
            lg.StackTraceString__c = e.getStackTraceString();
        }

        //Callouts
        else if(source instanceOf HttpResponse){

            HttpResponse resp = (HttpResponse) source;

            lg.StatusCode__c   = resp.getStatusCode();
            lg.ResponseBody__c = resp.getBody().length() > 131072 ? resp.getBody().substring(0, 131072) : resp.getBody();
            lg.Status__c = resp.getStatus();
        }

        else if(source instanceOf HttpRequest){

            HttpRequest req = (HttpRequest) source;

            lg.RequestBody__c = req.getBody().length() > 131072 ? req.getBody().substring(0, 131072) : req.getBody();
            lg.HTTPMethod__c  = req.getMethod();
            lg.RequestURI__c = req.getEndpoint();
        }

        //Custom Apex REST
        else if(source instanceOf System.RestRequest){
            
            RestRequest req = (RestRequest) source;

            lg.RequestBody__c = req.requestBody.toString().length() > 131072 ? req.requestBody.toString().substring(0, 131072) : req.requestBody.toString();
            lg.HTTPMethod__c  = req.httpMethod;
            lg.RequestURI__c  = req.requestURI;
        }

        // Avoid DML before subsequent callouts in async contexts
        if (System.isQueueable() || System.isBatch()) {
            createLogAsync(JSON.serialize(lg));
        } else if (System.isFuture()) {
            insert lg;
        } else {
            System.enqueueJob(new ClickSignQueueable(lg));
        }
        
        return lg;
    }
    
    // @Future kept for backward compatibility if needed in other flows
    @Future
    public static void createLogAsync(String logJSON){
        ClickSignLog__c log = (ClickSignLog__c) JSON.deserialize(logJSON, ClickSignLog__c.class);
        insert log;
    }

    public static ClickSign__c getOrCreateClickSign(SObject record) {
        ClickSign__c cs;
        Id recordId = (String) record.get('Id');
        String objectType = record.getSObjectType().getDescribe().getName();

        List<ClickSign__c> existingClickSigns = [
            SELECT Id, RecordId__c, ClickSignEnvelope__c, CurrentStep__c, Status__c,ClickSignTemplate__c,ClickSignTemplate__r.Name
            FROM ClickSign__c
            WHERE RecordId__c = :recordId
            AND Status__c = 'Draft' 
            LIMIT 1
        ];
        if (existingClickSigns.isEmpty()) {
            cs = new ClickSign__c(
            RecordId__c = recordId,
            recordType__c = objectType,
            Status__c = 'Draft',
            CurrentStep__c = 'Documents',
            ClickSignTemplate__c = null // Set this to a default value if needed
            );
            insert cs;
        } else {
            cs = existingClickSigns[0];
        }
        return cs;
    }
    
    public static List<ClickSignService.Document> getFilesbyClickSignId(String clickSignId){
        List<ClickSignService.Document> documents = new List<ClickSignService.Document>();
        List<ContentDocumentLink> documentLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :clickSignId
        ];
        for(ContentDocumentLink documentLink : documentLinks){
            ContentVersion version = [
                SELECT Id, Title, PathOnClient, VersionData, ExternalId__c
                FROM ContentVersion
                WHERE ContentDocumentId = :documentLink.ContentDocumentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            ClickSignService.Document doc = new ClickSignService.Document();
            doc.filename = version.Title;
            doc.file = EncodingUtil.base64Encode(version.VersionData);
            doc.fileBlob = version.VersionData;
            doc.id = version.Id;
            doc.externalId = version.ExternalId__c;
            documents.add(doc);
        }
        return documents;
    }

    public static ClickSign__c createClickSign(SObject record) {
        ClickSign__c cs = new ClickSign__c(
            CurrentStep__c          = 'Documents',
            Status__c               = 'Draft',
            RecordId__c             = (String) record.get('Id'),
            RecordType__c           = record.getSObjectType().getDescribe().getName()
        );
        insert cs;
        return cs;
    }

    public static List<ClickSignSigner__c> createSignersByJson(String jsonString, String clickSignId, Id recordId) {
        String objectName = recordId.getSObjectType().getDescribe().getName();
        List<ClickSignSigner__c> signers = new List<ClickSignSigner__c>();
        List<Object> signerList = (List<Object>) JSON.deserializeUntyped(jsonString);
    
        // Collect all fields to query
        Set<String> fieldsToQuery = new Set<String>();
        Map<String, String> relatedFields = new Map<String, String>();
        
        for (Object signerObj : signerList) {
            Map<String, Object> signerMap = (Map<String, Object>) signerObj;
            String fieldName = (String) signerMap.get('fieldName');
            String relatedField = (String) signerMap.get('relatedField'); // e.g., 'email'
            String emailField = (String) signerMap.get('emailField'); // e.g., 'email'
            fieldsToQuery.add(fieldName);
            
            if (fieldName.endsWith('id') || fieldName.endsWith('__c')) {
                String relatedObjectName = fieldName.endsWith('id') ? fieldName.replace('id', '') : fieldName.replace('__c', '__r');
                fieldsToQuery.add(relatedObjectName + '.' + relatedField); // Add related field to query
                fieldsToQuery.add(relatedObjectName + '.' + emailField); // Add related field to query
            } else {
                relatedFields.put(fieldName, relatedField);
            }
        }
        String query = '';
        // Perform a single query to get all necessary fields
        if(objectName == 'Opportunity' && fieldsToQuery.contains('contactid')){
            query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + ' FROM  OpportunityContactRole  WHERE Opportunityid = :recordId  and IsPrimary =true LIMIT 1';
        }else{
            query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';
        }
        System.debug(query);
        SObject record = Database.query(query);
        
        System.debug('query ' + query);
        System.debug('record ' + record);
    
        for (Object signerObj : signerList) {
            Map<String, Object> signerMap = (Map<String, Object>) signerObj;
            String fieldName = (String) signerMap.get('fieldName');
            String relatedField = (String) signerMap.get('relatedField'); // e.g., 'email'
            String emailField = (String) signerMap.get('emailField'); // e.g., 'email'
    
            String name = getRelatedFieldValue(record, fieldName, relatedField);
            String email = getRelatedFieldValue(record, fieldName, emailField);
    
            ClickSignSigner__c signer = new ClickSignSigner__c(
                name =  name,
                Email__c = email, // Extracted email value
                SFexternalId__c = (String) email + '_' + clickSignId, // Assuming ExternalId is based on email and ClickSign ID
                Role__c = (String) signerMap.get('roleValueField'),
                ClickSign__c = clickSignId
            );
    
            signers.add(signer);
        }
    
        return signers;
    }
    
    // Helper method to extract related field values correctly
    private static String getRelatedFieldValue(SObject record, String fieldName, String relatedField) {
        if (fieldName.endsWith('id')) {
            String relatedObjectName = fieldName.replace('id', '');
            SObject relatedRecord = (SObject) record.getSObject(relatedObjectName);
            if (relatedRecord != null && relatedField != null) {
                return (String) relatedRecord.get(relatedField);
            }
        } else if (fieldName.endsWith('__c')) {
            String relatedObjectName = fieldName.replace('__c', '__r');
            SObject relatedRecord = (SObject) record.getSObject(relatedObjectName);
            if (relatedRecord != null && relatedField != null) {
                return (String) relatedRecord.get(relatedField);
            }
        } else {
            return (String) record.get(fieldName);
        }
        return null;
    }

    public static String generateContractNumberString(Integer contractNumber) {
        return String.valueOf(contractNumber) + '/' + String.valueOf(Date.today().year());
    }

    @AuraEnabled
    public static String generateMapFields(Id recordId, String objectMappings, String contractNumber, String jsonContractInformation) {
        Map<String, String> mapFields = new Map<String, String>();
        if (String.isBlank(objectMappings)) {
            return JSON.serialize(mapFields);
        }
        List<Object> mappings = (List<Object>) JSON.deserializeUntyped(objectMappings);
        String query = 'SELECT ';
        List<String> fields = new List<String>();
        Map<String, String> fieldMappings = new Map<String, String>();
        Map<String, String> tagToLabelMap = new Map<String, String>();

        for (Object mappingObj : mappings) {
            Map<String, Object> mapping = (Map<String, Object>) mappingObj;
            String fieldName = (String) mapping.get('fieldName');
            String relationshipField = (String) mapping.get('relationshipField');
            String relatedField = (String) mapping.get('relatedField');
            String tag = (String) mapping.get('tag');
            String tagLabel = (String) mapping.get('tagLabel').toString().replace('{{', '').replace('}}', '');

            if (String.isNotBlank(relationshipField) && String.isNotBlank(relatedField)) {
                String fullPath = relationshipField + '.' + relatedField;
                fields.add(fullPath);
                fieldMappings.put(tag, fullPath);
            } else {
                fields.add(fieldName);
                fieldMappings.put(tag, fieldName);
            }
            tagToLabelMap.put(tag, tagLabel);
        }

        String sObjName = recordId.getSObjectType().getDescribe().getName();
        query += String.join(fields, ', ') + ' FROM ' + sObjName + ' WHERE Id = :recordId';

        System.debug('SOQL Query: ' + query);

        SObject record;
        try {
            record = Database.query(query);
            System.debug('Queried Record: ' + JSON.serialize(record));
        } catch (Exception e) {
            System.debug('Error querying record: ' + e.getMessage());
            return JSON.serialize(mapFields);
        }

        for (String tag : fieldMappings.keySet()) {
            String fieldPath = fieldMappings.get(tag);
            List<String> fieldParts = fieldPath.split('\\.');
            Object fieldValue = record;

            for (Integer i = 0; i < fieldParts.size(); i++) {
                String part = fieldParts[i];
                
                if (fieldValue instanceof SObject) {
                    SObject sObj = (SObject) fieldValue;
                    
                    // If it's the last part, retrieve the actual value
                    if (i == fieldParts.size() - 1) {
                        fieldValue = sObj.get(part);
                    } else {
                        fieldValue = sObj.getSObject(part);
                    }
                    
                    System.debug('Accessing field: ' + part + ', Value: ' + fieldValue);
                } else {
                    fieldValue = null;
                    break;
                }
            }

            String tagLabel = tagToLabelMap.get(tag);
            mapFields.put(tagLabel, fieldValue != null ? String.valueOf(fieldValue) : '');
        }

        // Process JsonContractInformation__c
        if(jsonContractInformation == null || jsonContractInformation == '') {
            return JSON.serialize(mapFields);
        }
        List<Object> contractInfoMappings = (List<Object>) JSON.deserializeUntyped(jsonContractInformation);
        for (Object contractInfoObj : contractInfoMappings) {
            Map<String, Object> contractInfoMap = (Map<String, Object>) contractInfoObj;
            String fieldName = (String) contractInfoMap.get('fieldName');
            String tag = (String) contractInfoMap.get('tag');
            String tagLabel = (String) contractInfoMap.get('tagLabel').toString().replace('{{', '').replace('}}', '');
            mapFields.put(tagLabel, contractNumber != null ? contractNumber : '');
        }

        System.debug('Final mapFields output: ' + JSON.serialize(mapFields));

        return JSON.serialize(mapFields);
    }

    @AuraEnabled
    public static String generateTagMapFromMappings(String objectMappings) {
        Map<String, String> mapFields = new Map<String, String>();
        if (String.isBlank(objectMappings)) {
            return JSON.serialize(mapFields);
        }
        List<Object> mappings = (List<Object>) JSON.deserializeUntyped(objectMappings);
        for (Object mappingObj : mappings) {
            Map<String, Object> mapping = (Map<String, Object>) mappingObj;
            String tagLabel = String.valueOf(mapping.get('tagLabel')).replace('{{', '').replace('}}', '');
            mapFields.put(tagLabel, '{{' + tagLabel + '}}');
        }
        return JSON.serialize(mapFields);
    }

    @AuraEnabled
    public static List<ContentDocument> getDocuments(String templateId) {
        try {
            System.debug('Fetching documents for templateId: ' + templateId);
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
                    WHERE Id IN :documentIds
                    AND  LatestPublishedVersion.Istemplate__c = true
                ];
                return documents;
            }
            return new List<ContentDocument>();
        } catch (Exception e) {
            System.debug('Error fetching documents: ' + e.getMessage());
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

}
