@isTest
public class ClickSignControllerTest {

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
            Name = 'Test Envelope',
            ExternalId__c = 'envelope123',
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

        Case caseRecord = new Case(Status='Novo',Origin='Web To Case Integrador',NomeIntegradorWeb__c='Darth Vader2',EmailIntegradorWeb__c='darth.vader2@teste.com',RecordTypeId='012U500000015IbIAI');
        insert caseRecord;
    }

    @IsTest
    static void testPrepareToSend(){

        ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c FROM ClickSign__c LIMIT 1];

        String payload = getPayload('document');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        try{
            clickSign = ClickSignController.prepareToSend(clickSign.ClickSignEnvelope__c, clickSign.Id);
        }catch(Exception ex){
            
        }
        
        Test.stopTest();
    }

    @isTest
    static void testProcess() {
        ClickSign__c clickSign = [SELECT Id, CurrentStep__c FROM ClickSign__c LIMIT 1];
        Case c = [SELECT Id FROM Case LIMIT 1];

        String payload = getPayload('documents');

        Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
        Test.startTest();
        try{
            String result = ClickSignController.process(clickSign, c.Id, clickSign.CurrentStep__c);
        }catch(Exception ex){

        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetOrCreateClickSign() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        ClickSign__c result = ClickSignController.getOrCreateClickSign(clickSign.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testCreateNewClickSign() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        ClickSign__c newClickSign = ClickSignController.createNewClickSign(clickSign.Id);
        Test.stopTest();
        System.assertNotEquals(null, newClickSign);
    }

    @isTest
    static void testGetDocuments() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        List<ContentDocument> documents = ClickSignController.getDocuments(clickSign.Id);
        Test.stopTest();
        System.assertNotEquals(null, documents);
    }

    @isTest
    static void testUploadDocument() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        ClickSignController.uploadDocument('Test Document', 'dGVzdCBjb250ZW50', 'application/pdf', clickSign.Id);
        Test.stopTest();
        List<ContentDocument> documents = ClickSignController.getDocuments(clickSign.Id);
        ClickSignController.deleteDocument(documents[0].Id);
    }

    @isTest
    static void testSaveRecipient() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Map<String, Object> recipient = new Map<String, Object>{
            'name' => 'New Signer',
            'email' => 'new@example.com',
            'role' => 'Signer'
        };
        Test.startTest();
        ClickSignSigner__c signer = ClickSignController.saveRecipient(recipient, clickSign.Id,null);
        Test.stopTest();
        System.assertNotEquals(null, signer);
    }

    @isTest
    static void testGetRecipients() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        List<ClickSignSigner__c> signers = ClickSignController.getRecipients(clickSign.Id);
        Test.stopTest();
        System.assertNotEquals(0, signers.size());
    }

    @isTest
    static void testDeleteRecipient() {
        ClickSignSigner__c signer = [SELECT Id FROM ClickSignSigner__c LIMIT 1];
        Test.startTest();
        try{
            ClickSignController.deleteRecipient(signer.Id);
        }catch(Exception ex){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateClickSignCurrentStep() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        ClickSignController.updateClickSignCurrentStep(clickSign.Id, 'Recipients');
        Test.stopTest();
        ClickSign__c updatedClickSign = [SELECT CurrentStep__c FROM ClickSign__c WHERE Id = :clickSign.Id];
        System.assertEquals('Recipients', updatedClickSign.CurrentStep__c);
    }

    @isTest
    static void testGetClickSignRecords() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        Test.startTest();
        try{
            List<ClickSign__c> clickSignRecords = ClickSignController.getClickSignRecords(clickSign.Id);
        }catch(Exception ex){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testGetObjectList() {
        Test.startTest();
        List<String> objectList = ClickSignController.getObjectList();
        Test.stopTest();
        System.assertNotEquals(0, objectList.size());
    }

    @isTest
    static void testGetRecordList() {
        Test.startTest();
        try{
            List<SObject> recordList = ClickSignController.getRecordList('Account');
        }catch(Exception ex){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveTemplates() {
        Test.startTest();
        try{
            List<ClickSignTemplate__c> templates = ClickSignController.getActiveTemplates();
        }catch(Exception ex){
            
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveTemplateId() {
        ClickSign__c clickSign = [SELECT Id FROM ClickSign__c LIMIT 1];
        ClickSignTemplate__c template = new ClickSignTemplate__c(
            Name = 'Test Template',
            IsActivate__c = true
        );
        insert template;
        Test.startTest();
        ClickSignController.saveTemplateId(clickSign.Id, template.Id);
        Test.stopTest();
        ClickSign__c updatedClickSign = [SELECT ClickSignTemplate__c FROM ClickSign__c WHERE Id = :clickSign.Id];
        System.assertEquals(template.Id, updatedClickSign.ClickSignTemplate__c);
    }

    // Mock class for HttpCallout
    private static String getPayload(String node){

        StaticResource payload = [SELECT Id, Body FROM StaticResource WHERE Name = 'ClickSignMock' LIMIT 1];
        
        Map<String, Object> mapPayload = (Map<String, Object>)JSON.deserializeUntyped(payload.Body.toString());

        return JSON.serialize(mapPayload.get(node));
    }
}