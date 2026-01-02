public with sharing class ClickSignIntegration {

    private static final String CLASS_NAME = 'ClickSignIntegration';
    
    public static ClickSignResponseDTO.Envelope createEnvelope(String filename){

        ClickSignRequestDTO.Envelope envelope = new ClickSignRequestDTO.Envelope();
        ClickSignRequestDTO.EnvelopeData envelopeData = new ClickSignRequestDTO.EnvelopeData();
        ClickSignRequestDTO.EnvelopeAttributes attributes = new ClickSignRequestDTO.EnvelopeAttributes();
        
        attributes.name = filename;
        attributes.locale = 'pt-BR';
        attributes.auto_close = true;
        attributes.remind_interval = 3;
        attributes.deadline_at = getDate();
        attributes.default_subject = 'Solicitação de assinatura do contrato: ' + filename;
        attributes.default_message = 'Solicitação de assinatura do contrato: ' + filename;
        envelopeData.type_replaced = 'envelopes';
        envelopeData.attributes = attributes;
        envelope.data = envelopeData;

        String integrationName = ClickSignUtils.METHOD.CREATE_ENVELOPE.name();
        
        String response = send(integrationName, JSON.serialize(envelope));

        ClickSignResponseDTO.Envelope envelopeDTO = (ClickSignResponseDTO.Envelope) JSON.deserialize(response, ClickSignResponseDTO.Envelope.class);

        return envelopeDTO;
    }

    public static ClickSignResponseDTO.Document createDocument(String envelopeId, String filename, String file){

        ClickSignRequestDTO.Document document = new ClickSignRequestDTO.Document();
        ClickSignRequestDTO.DocumentData documentData = new ClickSignRequestDTO.DocumentData();
        ClickSignRequestDTO.DocumentAttributes attributes = new ClickSignRequestDTO.DocumentAttributes();

        attributes.filename = filename;
        attributes.content_base64 = 'data:application/pdf;base64,' + file;
        documentData.type_replaced = 'documents';
        documentData.attributes = attributes;
        document.data = documentData;

        String integrationName = ClickSignUtils.METHOD.CREATE_DOCUMENT.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(document), params);
        
        ClickSignResponseDTO.Document documentDTO = (ClickSignResponseDTO.Document) JSON.deserialize(response, ClickSignResponseDTO.Document.class);

        return documentDTO; 
    }

    public static ClickSignResponseDTO.Document createTemplateDocument(String envelopeId, String filename, String key, String data){

        ClickSignRequestDTO.TemplateDocument document = new ClickSignRequestDTO.TemplateDocument();
        ClickSignRequestDTO.TemplateDocumentData documentData = new ClickSignRequestDTO.TemplateDocumentData();
        ClickSignRequestDTO.TemplateDocumentAttributes attributes = new ClickSignRequestDTO.TemplateDocumentAttributes();
        ClickSignRequestDTO.TemplateDocumentAttributesTemplate attributesTemplate = new ClickSignRequestDTO.TemplateDocumentAttributesTemplate();
        attributesTemplate.key = key;
        attributesTemplate.data = JSON.deserializeUntyped(data);
        attributes.filename = filename;
        attributes.template = attributesTemplate;
        documentData.type_replaced = 'documents';
        documentData.attributes = attributes;
        document.data = documentData;

        String integrationName = ClickSignUtils.METHOD.CREATE_DOCUMENT.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(document), params);
        
        ClickSignResponseDTO.Document documentDTO = (ClickSignResponseDTO.Document) JSON.deserialize(response, ClickSignResponseDTO.Document.class);

        return documentDTO; 
    }

    public static ClickSignResponseDTO.Signer createSigner(String envelopeId, String name, String email){

        ClickSignRequestDTO.Signer signer = new ClickSignRequestDTO.Signer();
        ClickSignRequestDTO.SignerData signerData = new ClickSignRequestDTO.SignerData();
        ClickSignRequestDTO.SignerAttributes attributes = new ClickSignRequestDTO.SignerAttributes();
        ClickSignRequestDTO.SignerCommunicateEvents events = new ClickSignRequestDTO.SignerCommunicateEvents();

        events.signature_request = 'email';
        events.signature_reminder = 'email';
        events.document_signed = 'email';
        attributes.communicate_events = events;
        attributes.name = name;
        attributes.email = email;
        attributes.has_documentation = false;
        attributes.refusable = false;
        signerData.type_replaced = 'signers';
        signerData.attributes = attributes;
        signer.data = signerData;

        String integrationName = ClickSignUtils.METHOD.CREATE_SIGNER.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(signer), params);
        
        ClickSignResponseDTO.Signer signerDTO = (ClickSignResponseDTO.Signer) JSON.deserialize(response, ClickSignResponseDTO.Signer.class);

        return signerDTO;
    }

    public static String createRequirementQualification(String envelopeId, String signerId, String documentId, String role){

        ClickSignRequestDTO.RequirementQualification qualification = new ClickSignRequestDTO.RequirementQualification();
        ClickSignRequestDTO.RequirementQualificationData qualificationData = new ClickSignRequestDTO.RequirementQualificationData();
        ClickSignRequestDTO.RequirementQualificationAttributes attributes = new ClickSignRequestDTO.RequirementQualificationAttributes();
        ClickSignRequestDTO.RequirementDataReference relationshipSigner = new ClickSignRequestDTO.RequirementDataReference();
        ClickSignRequestDTO.RequirementDataReference relationshipDocument = new ClickSignRequestDTO.RequirementDataReference();
        ClickSignRequestDTO.RequirementRelatedData relationShipSignerData = new ClickSignRequestDTO.RequirementRelatedData();
        ClickSignRequestDTO.RequirementRelatedData relationshipDocumentData = new ClickSignRequestDTO.RequirementRelatedData();
        ClickSignRequestDTO.RequirementRelationships relationships = new ClickSignRequestDTO.RequirementRelationships();

        relationshipSigner.type_replaced = 'signers';
        relationshipSigner.id = signerId;
        relationShipSignerData.data = relationshipSigner;

        relationshipDocument.type_replaced = 'documents';
        relationshipDocument.id = documentId;
        relationshipDocumentData.data = relationshipDocument;

        relationships.signer = relationShipSignerData;
        relationships.document = relationshipDocumentData;

        attributes.action = 'agree';
        attributes.role = role;
        
        qualificationData.type_replaced = 'requirements';
        qualificationData.attributes = attributes;
        qualificationData.relationships = relationships;
        qualification.data = qualificationData;

        String integrationName = ClickSignUtils.METHOD.CREATE_REQUIREMENT.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(qualification), params);

        System.debug('requirements qualification: ' + response);
        
        return response;
    }

    public static String createRequirementAutentication(String envelopeId, String signerId, String documentId, String email){

        ClickSignRequestDTO.RequirementAutentication autentication = new ClickSignRequestDTO.RequirementAutentication();
        ClickSignRequestDTO.RequirementAutenticationData autenticationData = new ClickSignRequestDTO.RequirementAutenticationData();
        ClickSignRequestDTO.RequirementAutenticationAttributes attributes = new ClickSignRequestDTO.RequirementAutenticationAttributes();
        ClickSignRequestDTO.RequirementDataReference relationshipSigner = new ClickSignRequestDTO.RequirementDataReference();
        ClickSignRequestDTO.RequirementDataReference relationshipDocument = new ClickSignRequestDTO.RequirementDataReference();
        ClickSignRequestDTO.RequirementRelatedData relationShipSignerData = new ClickSignRequestDTO.RequirementRelatedData();
        ClickSignRequestDTO.RequirementRelatedData relationshipDocumentData = new ClickSignRequestDTO.RequirementRelatedData();
        ClickSignRequestDTO.RequirementRelationships relationships = new ClickSignRequestDTO.RequirementRelationships();

        relationshipSigner.type_replaced = 'signers';
        relationshipSigner.id = signerId;
        relationShipSignerData.data = relationshipSigner;

        relationshipDocument.type_replaced = 'documents';
        relationshipDocument.id = documentId;
        relationshipDocumentData.data = relationshipDocument;

        relationships.signer = relationShipSignerData;
        relationships.document = relationshipDocumentData;

        attributes.action = 'provide_evidence';
        attributes.auth = 'email';
        
        autenticationData.type_replaced = 'requirements';
        autenticationData.attributes = attributes;
        autenticationData.relationships = relationships;
        autentication.data = autenticationData;

        String integrationName = ClickSignUtils.METHOD.CREATE_REQUIREMENT.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(autentication), params);

        System.debug('requirements: ' + response);
        
        return response;
    }

    public static String activateEnvelope(String envelopeId){

        ClickSignRequestDTO.EnvelopeActivation activation = new ClickSignRequestDTO.EnvelopeActivation();
        ClickSignRequestDTO.EnvelopeActivationData activationData = new ClickSignRequestDTO.EnvelopeActivationData();
        ClickSignRequestDTO.EnvelopeActivationAttributes attributes = new ClickSignRequestDTO.EnvelopeActivationAttributes();

        attributes.status = 'running';
        activationData.id = envelopeId;
        activationData.type_replaced = 'envelopes';
        activationData.attributes = attributes;
        activation.data = activationData;

        String integrationName = ClickSignUtils.METHOD.ACTIVATE_ENVELOPE.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(activation), params);

        System.debug('activate: ' + response);
        
        return response;
    }

    public static void notification(String envelopeId){

        ClickSignRequestDTO.EnvelopeNotification envelope = new ClickSignRequestDTO.EnvelopeNotification();
        ClickSignRequestDTO.EnvelopeNotificationData envelopeData = new ClickSignRequestDTO.EnvelopeNotificationData();
        ClickSignRequestDTO.EnvelopeNotificationAttributes attributes = new ClickSignRequestDTO.EnvelopeNotificationAttributes();
        
        attributes.message = 'Segue os documentos para assinatura.';
        envelopeData.type_replaced = 'notifications';
        envelopeData.attributes = attributes;
        envelope.data = envelopeData;

        String integrationName = ClickSignUtils.METHOD.NOTIFICATION.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, JSON.serialize(envelope), params);

        System.debug('notification: ' + response);
    }

    public static ClickSignResponseDTO.Document createTemplate(String filename, String file){

        ClickSignRequestDTO.Template template = new ClickSignRequestDTO.Template();
        ClickSignRequestDTO.TemplateData templateData = new ClickSignRequestDTO.TemplateData();
        ClickSignRequestDTO.TemplateAttributes attributes = new ClickSignRequestDTO.TemplateAttributes();

        attributes.name = filename;
        attributes.content_base64 = 'data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,' + file;
        templateData.type_replaced = 'templates';
        templateData.attributes = attributes;
        template.data = templateData;

        String integrationName = ClickSignUtils.METHOD.CREATE_TEMPLATE.name();

        String response = send(integrationName, JSON.serialize(template));
        
        ClickSignResponseDTO.Document documentDTO = (ClickSignResponseDTO.Document) JSON.deserialize(response, ClickSignResponseDTO.Document.class);

        return documentDTO; 
    }

    public static ClickSignResponseDTO.Template getTemplates(){

        String integrationName = ClickSignUtils.METHOD.CREATE_TEMPLATE.name();

        String response = send(integrationName);
        
        ClickSignResponseDTO.Template templateDTO = (ClickSignResponseDTO.Template) JSON.deserialize(response, ClickSignResponseDTO.Template.class);

        return templateDTO; 
    }

    public static ClickSignResponseDTO.Envelope getEnvelope(String envelopeId){

        String integrationName = ClickSignUtils.METHOD.GET_ENVELOPE.name();

        Map<String, String> params = new Map<String, String> {
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, params);

        ClickSignResponseDTO.Envelope envelopeDTO = (ClickSignResponseDTO.Envelope) JSON.deserialize(response, ClickSignResponseDTO.Envelope.class);

        return envelopeDTO;
    }

    public static String deleteDocument(String envelopeId, String documentId){

        String integrationName = ClickSignUtils.METHOD.DELETE_DOCUMENT.name();

        Map<String, String> params = new Map<String, String> {
            'document_id' => documentId,
            'envelope_id' => envelopeId
        };
        
        String response = send(integrationName, params);

        return response;
    }

    public static String send(String integrationName){
        return send(integrationName, null, null);
    }

    public static String send(String integrationName, Map<String, String> params){
        return send(integrationName, null, params);
    }

    public static String send(String integrationName, String body){
        return send(integrationName, body, null);
    }

    public static String send(String integrationName, String body, Map<String, String> params){

        String responseBody;

        try{

            Integrador__mdt integration = ClickSignUtils.getIntegration(integrationName);

            if(params != null){
                for(String key : params.keySet()){
                    if(integration.URL__c.contains(key)) integration.URL__c = integration.URL__c.replace(key, params.get(key));
                }
            }

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            request.setEndpoint(integration.URL__c);
            request.setMethod(integration.Method__c);
            request.setHeader('Content-Type', integration.ContentType__c);
            request.setHeader('Authorization', integration.LastToken__c);
            request.setTimeout(120000);

            if(String.isNotBlank(body)) {
                body = body.replace('_replaced', '');
                System.debug('@@body: ' + body);
                request.setBody(body);
            }
            
            HttpResponse response = http.send(request);

            System.debug('response: ' + response);

            if(response.getStatusCode() != 200 && response.getStatusCode() != 201){
                ClickSignUtils.createLog(CLASS_NAME, integrationName, response);
                throw new ClickSignIntegrationException(response.getBody());
            }

            responseBody = response.getBody();

        }catch(CalloutException calloutException){
            ClickSignUtils.createLog(CLASS_NAME, integrationName, calloutException);
            //throw new ClickSignIntegrationException(calloutException.getMessage());
        }catch(ClickSignIntegrationException customException){
            ClickSignUtils.createLog(CLASS_NAME, integrationName, customException);
            //throw new ClickSignIntegrationException(customException.getMessage());
        }catch(Exception ex){
            ClickSignUtils.createLog(CLASS_NAME, integrationName, ex);
            //throw new ClickSignIntegrationException(ex.getMessage());
        }

        return responseBody;
    }

    public static Blob getDocument(String endpoint){

        try{

            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setTimeout(120000);

            HttpResponse response = http.send(request);

            return response.getBodyAsBlob();

        }catch(Exception ex){
            ClickSignUtils.createLog(CLASS_NAME, 'Get Document', ex);
            throw new ClickSignIntegrationException(ex.getMessage());
        }
    }

    private static String getDate(){

        String strNow = String.valueOf(System.now().addDays(7));

        strNow = strNow.replace(' ', 'T');
        strNow += '-03:00';

        return strNow;
    }

    public class ClickSignIntegrationException extends Exception {}
}