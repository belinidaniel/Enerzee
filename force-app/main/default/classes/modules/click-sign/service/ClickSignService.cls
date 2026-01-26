/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-26-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class ClickSignService {

    public static void process(List<EnvelopeInput> envelopesInput,string currentStep){

        EnvelopeInput envelopeInput = envelopesInput[0];

        if(currentStep == 'Documents') addDocuments(envelopeInput);
        if(currentStep== 'Recipients') addRecipients(envelopeInput);
        if(currentStep == 'Prepare & Send') prepareSend(envelopeInput);
    }

    //First Step
    public static void addDocuments(EnvelopeInput envelopeInput){

        List<ClickSignResponseDTO.Document> documentsDTO = new List<ClickSignResponseDTO.Document>();
        List<ContentVersion> versions = new List<ContentVersion>();
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        ClickSignResponseDTO.Envelope envelopeDTO;
        ClickSignResponseDTO.Document documentDTO;
        ClickSignEnvelope__c envelopeSObj;
        String envelopeId;
        ClickSign__c clickSign;

        try{
            clickSign = [SELECT Id, Status__c, CurrentStep__c, ClickSignEnvelope__r.ExternalId__c,ClickSignTemplate__c FROM ClickSign__c WHERE Id = :envelopeInput.clickSignId];
        }catch(Exception ex){
            throw new ClickSignServiceException('Clicksign not found: ' + envelopeInput.clickSignId);
        }
         

        if(String.isNotBlank(clickSign.ClickSignEnvelope__c)){
            envelopeId = clickSign.ClickSignEnvelope__r.ExternalId__c;
        }else{
            envelopeDTO = ClickSignIntegration.createEnvelope('New Envelope');
            envelopeId = envelopeDTO.data.id;
        }

        System.debug('envelopeId: ' + envelopeId);
        System.debug('envelopeInput.documents: ' + envelopeInput.documents);

        if (envelopeInput.documents == null || envelopeInput.documents.isEmpty()) {
            throw new ClickSignServiceException('No documents provided');
        }

        for(Document doc : envelopeInput.documents){

            System.debug('doc: ' + doc);
            
            if(!string.isBlank(clickSign.ClickSignTemplate__c)){
                if(String.isBlank(doc.externalId)) { continue; }
                documentDTO = ClickSignIntegration.createTemplateDocument(envelopeId, doc.filename, doc.externalId, doc.mergeFields);
                Blob fileMerged = ClickSignIntegration.getDocument(documentDTO.data.links.files.original);
                ContentVersion v = uploadDocument(doc.filename, EncodingUtil.base64Encode(fileMerged), '', clickSign.Id, documentDTO.data.id);
                versions.add(v);
            }else{  
                documentDTO = ClickSignIntegration.createDocument(envelopeId, doc.filename, doc.file);
                versions.add(new ContentVersion(
                    Id = doc.id,
                    ExternalId__c = documentDTO?.data?.id != null ? documentDTO?.data?.id : ''
                ));
            }
            
        }

        if(String.isBlank(clickSign.ClickSignEnvelope__c)){
            envelopeSObj = createEnvelope(envelopeDTO);
        }else{
            envelopeSObj = new ClickSignEnvelope__c(Id = clickSign.ClickSignEnvelope__c);
        }

        for(ContentVersion version : versions){
            version.ClickSignEnvelope__c = envelopeSObj.Id;
        }

        update versions;

        clickSign.ClickSignEnvelope__c = envelopeSObj.Id;
        clickSign.CurrentStep__c = 'Recipients';
        update clickSign;
    }

    //Second Step
    public static void addRecipients(EnvelopeInput envelopeInput){

        List<ClickSignSigner__c> signersSObj = [SELECT Id, ExternalId__c, Name, Email__c FROM ClickSignSigner__c WHERE ClickSign__c = :envelopeInput.clickSignId];

        ClickSignEnvelope__c envelope = [SELECT Id, ExternalId__c FROM ClickSignEnvelope__c WHERE Id = :envelopeInput.envelopeId OR ExternalId__c = :envelopeInput.envelopeId];
        
        for(ClickSignSigner__c signer : signersSObj){

            if(String.isNotBlank(signer.ExternalId__c)) { continue; }

            ClickSignResponseDTO.Signer signerDTO = ClickSignIntegration.createSigner(envelope.ExternalId__c, signer.Name, signer.Email__c);
            signer.ExternalId__c = signerDTO.data.id;
        }
        
        update signersSObj;
    }

    //Third Step
    public static void prepareSend(EnvelopeInput envelopeInput){

        ClickSignEnvelope__c envelope = [SELECT Id, ExternalId__c FROM ClickSignEnvelope__c WHERE Id = :envelopeInput.envelopeId OR ExternalId__c = :envelopeInput.envelopeId];

        List<ClickSignSigner__c> signers = [SELECT Id, ExternalId__c, Role__c, Name, Email__c FROM ClickSignSigner__c WHERE ClickSign__c = :envelopeInput.clickSignId];
        List<ClickSignService.Document> docs = ClickSignUtils.getFilesbyClickSignId(envelopeInput.clickSignId);

        for(ClickSignService.Document doc : docs){
            System.debug('doc requirement: ' + doc);
            for(ClickSignSigner__c signer : signers){
                System.debug('signer: ' + signer);
                createRequirements(envelope.ExternalId__c, signer.ExternalId__c, doc.externalId, signer.Role__c, signer.Email__c);
            }
        }
        
        activate(envelope.ExternalId__c);
        notification(envelope.ExternalId__c);

        for(ClickSignSigner__c signer : signers){
            signer.Status__c = 'Notificado';
        }

        ClickSign__c clickSign = new ClickSign__c ();
        clickSign.Id = envelopeInput.clickSignId;
        clickSign.status__c = 'Document Send to Assign';
        update clickSign;
        update signers;
    }

    public static void createRequirements(String envelopeId, String signerId, String documentId, String role, String email){
        ClickSignIntegration.createRequirementQualification(envelopeId, signerId, documentId, role);
        ClickSignIntegration.createRequirementAutentication(envelopeId, signerId, documentId, email);
    }

    public static void activate(String envelopeId){
        ClickSignIntegration.activateEnvelope(envelopeId);
    }

    public static void notification(String envelopeId){
        ClickSignIntegration.notification(envelopeId);
    }

    //Create Template
    public static void createTemplate(Document document){
        createTemplate(document, false);
    }

    //Create Template with optional force creation
    public static void createTemplate(Document document, Boolean forceCreate){

        ClickSignResponseDTO.Envelope envelopeDTO;
        ClickSignEnvelope__c envelopeSObj;
        String envelopeId;

        ClickSignTemplate__c clickSignTemplate = [SELECT Id, ClickSignEnvelope__c, ClickSignEnvelope__r.ExternalId__c, ExternalId__c FROM ClickSignTemplate__c WHERE Id = :document.id];

        if(String.isNotBlank(clickSignTemplate.ExternalId__c)){

            envelopeId = clickSignTemplate.ClickSignEnvelope__r.ExternalId__c;
            try {
                envelopeDTO = ClickSignIntegration.getEnvelope(envelopeId);
            } catch (Exception ex) {
                envelopeDTO = null;
            }

            try {
                ClickSignIntegration.deleteDocument(envelopeId, clickSignTemplate.ExternalId__c);
            } catch (Exception ex) {
                // Ignore delete failures; template may not exist or was removed externally.
            }

            if(envelopeDTO == null || envelopeDTO?.data?.attributes?.status != 'draft'){
                envelopeDTO = ClickSignIntegration.createEnvelope('Template Envelope');
            }

        }else{
            envelopeDTO = ClickSignIntegration.createEnvelope('Template Envelope');
        }

        String templateId;
        if (!forceCreate && String.isNotBlank(document.externalId)) {
            templateId = document.externalId;
        } else {
            ClickSignResponseDTO.Document templateDTO = ClickSignIntegration.createTemplate(document.filename, document.file);
            templateId = templateDTO.data.id;
        }

        ClickSignResponseDTO.Document documentDTO = ClickSignIntegration.createTemplateDocument(
            envelopeDTO.data.id,
            document.filename,
            templateId,
            document.mergeFields
        );

        Blob fileMerged = ClickSignIntegration.getDocument(documentDTO.data.links.files.original);

        if (String.isBlank(clickSignTemplate.ExternalId__c)) {
            clickSignTemplate.ExternalId__c = templateId;
        }

        if(String.isBlank(clickSignTemplate.ClickSignEnvelope__c)){
            envelopeSObj = createEnvelope(envelopeDTO);
        }else{
            envelopeSObj = new ClickSignEnvelope__c(Id = clickSignTemplate.ClickSignEnvelope__c, ExternalId__c = envelopeDTO.data.id );
            update envelopeSObj;
        }

        clickSignTemplate.ClickSignEnvelope__c = envelopeSObj.Id;
        update clickSignTemplate;

        List<ContentDocumentLink> links = [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :clickSignTemplate.Id AND ContentDocument.LatestPublishedVersion.IsTemplate__c = false];

        if(!links?.isEmpty()){
            delete new ContentDocument(
                Id = links[0].ContentDocumentId
            );
        }

        uploadDocument(document.filename, EncodingUtil.base64Encode(fileMerged), '', clickSignTemplate.Id, documentDTO.data.id);
    }

    public static void createTemplateFromMappings(Id templateId){
        ClickSignTemplate__c template = [
            SELECT Id, Name, Description__c, ExternalId__c, SourceObject__c, ObjectMappings__c, ObjectMappings2__c,
                Stage__c, fileName__c, ClickSignEnvelope__c, ClickSignEnvelope__r.ExternalId__c
            FROM ClickSignTemplate__c
            WHERE Id = :templateId
            LIMIT 1
        ];

        if (String.isBlank(template.ObjectMappings__c)) {
            return;
        }

        List<ContentDocument> documents = ClickSignUtils.getDocuments(templateId);
        if (documents == null || documents.isEmpty()) {
            return;
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
        document.mergeFields = ClickSignUtils.generateTagMapFromMappings(template.ObjectMappings__c);

        // Force create a new template when uploading documents
        ClickSignService.createTemplate(document, true);  
    }

    // Preview should reuse existing template id when available
    public static void createTemplatePreview(Document document){
        ClickSignService.createTemplate(document, false);
    }

    /*Criação e enriquecimento de SObjects*/
    public static ClickSignEnvelope__c createEnvelope(ClickSignResponseDTO.Envelope envelopeDTO){

        ClickSignEnvelope__c envelopeSObj = new ClickSignEnvelope__c();
        envelopeSObj.ExternalId__c = envelopeDTO.data.id;
        envelopeSObj.Name = envelopeDTO.data.attributes.name;
        if(String.isNotBlank(envelopeDTO?.data?.attributes?.status)) envelopeSObj.Status__c = envelopeDTO.data.attributes.status;
        if(String.isNotBlank(envelopeDTO?.data?.links?.self)) envelopeSObj.Link__c = envelopeDTO.data.links.self;
        
        insert envelopeSObj;
        return envelopeSObj;
    }

    public static ContentVersion uploadDocument(String fileName, String base64Data, String contentType, String recordId) {
        return uploadDocument(fileName, base64Data, contentType, recordId, null);
    }
    
    public static ContentVersion uploadDocument(String fileName, String base64Data, String contentType, String recordId, String externalId) {
        // Decode the Base64 string
        Blob fileBlob = EncodingUtil.base64Decode(base64Data);

        // Create a new ContentVersion record
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = fileName;
        contentVersion.PathOnClient = '/' + fileName;
        contentVersion.VersionData = fileBlob;
        if(String.isNotBlank(externalId)) contentVersion.ExternalId__c = externalId;
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
        contentDocumentLinkGuest.LinkedEntityId = recordId;
        contentDocumentLinkGuest.ShareType = 'V'; // Viewer permission
        contentDocumentLinkGuest.Visibility = 'AllUsers';

        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentDocument.Id;
        contentDocumentLink.LinkedEntityId = guestUser.Id;
        contentDocumentLink.ShareType = 'V'; // Viewer permission
        contentDocumentLink.Visibility = 'AllUsers';
        insert new List<ContentDocumentLink> {contentDocumentLink, contentDocumentLinkGuest, contentDocumentLinkSite};
        return contentVersion;
    }
    
    public class EnvelopeInput {
        public String envelopeId; 
        public String clickSignId;
        public String documentType; // Template or Document
        public List<Document> documents;
        public List<Signer> signers; 
    }

    public class Document {
        public String id; 
        public String externalId; 
        public String filename; 
        public String file; 
        public Blob   fileBlob; 
        public String Type; 
        public String mergeFields;
    }

    public class Signer {
        public String name; 
        public String email; 
        public String role; 
    }

    public class ClickSignServiceException extends Exception {}
}
