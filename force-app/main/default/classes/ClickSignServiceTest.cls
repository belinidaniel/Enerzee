@isTest
public class ClickSignServiceTest {

    @testSetup
    static void setup() {
        // Create test data
        ClickSignEnvelope__c envelope = new ClickSignEnvelope__c(
            Name = 'Test Envelope',
            Status__c = 'Draft',
            ExternalId__c = 'envelope123'
        );
        insert envelope;

        ClickSignTemplate__c template = new ClickSignTemplate__c(
            Name = 'Test Template',
            ExternalId__c = 'template123',
            ObjectMappings__c = '[{"id":"field-1738590601283","fieldName":"certidaonegativacriminal__c","relationshipField":null,"relatedField":null,"tag":"{{/case/certidaonegativacriminal__c}}","tagLabel":"{{casecertidaonegativacriminal__c}}","labelFieldName":"Certidão Negativa Criminal","labelRelatedField":null},{"id":"field-1738590604586","fieldName":"nome_do_consultor__c","relationshipField":"Consultor__c","relatedField":null,"tag":"{{/case/nome_do_consultor__c}}","tagLabel":"{{casenome_do_consultor__c}}","labelFieldName":"Nome do Consultor","labelRelatedField":null}]'
        );
        insert template;

        ClickSign__c clickSign = new ClickSign__c(
            CurrentStep__c = 'Documents',
            Status__c = 'Draft', 
            ClickSignEnvelope__c = envelope.Id,
            ClickSignTemplate__c = template.Id
        );
        insert clickSign;

        ClickSignSigner__c signer = new ClickSignSigner__c(
            Name = 'Test Signer',
            Email__c = 'test@example.com',
            Role__c = 'Signer',
            ClickSign__c = clickSign.Id
        );
        insert signer;
    }

    @isTest
    static void testProcess() {
        ClickSign__c clickSign = [SELECT Id, CurrentStep__c, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];

        ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
        envelopeInput.clickSignId = clickSign.Id;
        envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

        List<ClickSignService.EnvelopeInput> envelopesInput = new List<ClickSignService.EnvelopeInput>();
        envelopesInput.add(envelopeInput);

        String payload = getPayload('documents');
        String payloadEnv = getPayload('envelope');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadEnv));
        Test.startTest();
        try{
            ClickSignService.process(envelopesInput, clickSign.CurrentStep__c);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testAddDocuments() {
        ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];

        ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
        envelopeInput.clickSignId = clickSign.Id;
        envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

        ClickSignService.Document document = new ClickSignService.Document();
        document.filename = 'Test Document';
        document.file = 'dGVzdCBjb250ZW50';
        envelopeInput.documents = new List<ClickSignService.Document>{ document };

        String payload = getPayload('documents');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.addDocuments(envelopeInput);
        Test.stopTest();
    }

    @isTest
    static void testAddRecipients() {
        ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];

        ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
        envelopeInput.clickSignId = clickSign.Id;
        envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

        String payload = getPayload('signer');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.addRecipients(envelopeInput);
        Test.stopTest();
    }

    @isTest
    static void testPrepareSend() {
        ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];

        ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
        envelopeInput.clickSignId = clickSign.Id;
        envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

        String payload = getPayload('documents');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.prepareSend(envelopeInput);
        Test.stopTest();
    }

    @isTest
    static void testCreateTemplate() {
        ClickSignTemplate__c template = [SELECT Id, ExternalId__c FROM ClickSignTemplate__c LIMIT 1];
        ClickSignService.Document document = new ClickSignService.Document();
        document.id = template.Id;
        document.filename = 'Test Template';
        document.file = 'dGVzdCBjb250ZW50';

        String payload = getPayload('document');
        String payloadEnv = getPayload('envelope');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadEnv));
        Test.startTest();
        try{
            ClickSignService.createTemplate(document);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateNewTemplate() {
        ClickSignTemplate__c template = [SELECT Id, ExternalId__c FROM ClickSignTemplate__c LIMIT 1];
        template.ExternalId__c = null;
        update template;

        ClickSignService.Document document = new ClickSignService.Document();
        document.id = template.Id;
        document.filename = 'Test Template';
        document.file = 'dGVzdCBjb250ZW50';

        String payloadEnv = getPayload('envelope');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadEnv));
        Test.startTest();
        try{
            ClickSignService.createTemplate(document);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateRequirements() {
        String payloadQualification = getPayload('requirementQualification');
        String payloadAutentication = getPayload('requirementAutentication');
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadQualification));
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadAutentication));
        Test.startTest();
        ClickSignService.createRequirements('envelope123', 'signer123', 'document123', 'Signer', 'test@example.com');
        Test.stopTest();
    }

    @isTest
    static void testActivate() {
        String payload = getPayload('envelopeActivation');
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.activate('envelope123');
        Test.stopTest();
    }

    @isTest
    static void testNotification() {
        String payload = getPayload('notification');
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.notification('envelope123');
        Test.stopTest();
    }

    @isTest
    static void testCreateEnvelope() {
        String payload = getPayload('envelope');
        ClickSignResponseDTO.Envelope env = new ClickSignResponseDTO.Envelope();
        ClickSignResponseDTO.EnvelopeAttributes att = new ClickSignResponseDTO.EnvelopeAttributes();
        att.name = 'Test Envelope';
        att.status = 'draft';
        env.data = new ClickSignResponseDTO.EnvelopeData();
        env.data.id = 'testclass';
        env.data.attributes = att;
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        try{
            ClickSignService.createEnvelope(env);
        }catch(Exception e){
            
        }
        
        Test.stopTest();
    }

    @isTest
    static void testUploadDocument() {
        ClickSign__c clickSign = [SELECT Id, CurrentStep__c, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];
        String payload = getPayload('document');
        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        ClickSignService.uploadDocument('Test Document', clickSign.Id, 'application/pdf', clickSign.Id);
        Test.stopTest();
    }

    // Mock class for HttpCallout
    private static String getPayload(String node){

        StaticResource payload = [SELECT Id, Body FROM StaticResource WHERE Name = 'ClickSignMock' LIMIT 1];
        
        Map<String, Object> mapPayload = (Map<String, Object>)JSON.deserializeUntyped(payload.Body.toString());

        return JSON.serialize(mapPayload.get(node));
    }

}