@isTest
public class ClickSignRequestDTOTest {
    @isTest
    static void testEnvelopeRequestDTO() {
        Test.startTest();
        ClickSignRequestDTO dto = new ClickSignRequestDTO();
        ClickSignRequestDTO.Envelope envelope = new ClickSignRequestDTO.Envelope();
        envelope.data = new ClickSignRequestDTO.EnvelopeData();
        envelope.data.type_replaced = 'envelope';
        envelope.data.attributes = new ClickSignRequestDTO.EnvelopeAttributes();
        envelope.data.attributes.name = 'Test Envelope';
        envelope.data.attributes.locale = 'en-US';
        Test.stopTest();
        System.assertEquals('envelope', envelope.data.type_replaced);
        System.assertEquals('Test Envelope', envelope.data.attributes.name);
        System.assertEquals('en-US', envelope.data.attributes.locale);
    }

    @isTest
    static void testDocumentRequestDTO() {
        ClickSignRequestDTO.Document document = new ClickSignRequestDTO.Document();
        document.data = new ClickSignRequestDTO.DocumentData();
        document.data.type_replaced = 'document';
        document.data.attributes = new ClickSignRequestDTO.DocumentAttributes();
        document.data.attributes.filename = 'Test Document';
        document.data.attributes.content_base64 = 'dGVzdA==';
        
        System.assertEquals('document', document.data.type_replaced);
        System.assertEquals('Test Document', document.data.attributes.filename);
        System.assertEquals('dGVzdA==', document.data.attributes.content_base64);
    }

    @isTest
    static void testSignerRequestDTO() {
        ClickSignRequestDTO.Signer signer = new ClickSignRequestDTO.Signer();
        signer.data = new ClickSignRequestDTO.SignerData();
        signer.data.type_replaced = 'signer';
        signer.data.attributes = new ClickSignRequestDTO.SignerAttributes();
        signer.data.attributes.name = 'Test Signer';
        signer.data.attributes.email = 'test@example.com';
        
        System.assertEquals('signer', signer.data.type_replaced);
        System.assertEquals('Test Signer', signer.data.attributes.name);
        System.assertEquals('test@example.com', signer.data.attributes.email);
    }

    @isTest
    static void testTemplateRequestDTO() {
        ClickSignRequestDTO.Template template = new ClickSignRequestDTO.Template();
        template.data = new ClickSignRequestDTO.TemplateData();
        template.data.type_replaced = 'template';
        template.data.attributes = new ClickSignRequestDTO.TemplateAttributes();
        template.data.attributes.name = 'Test Template';
        template.data.attributes.content_base64 = 'dGVzdA==';
        
        System.assertEquals('template', template.data.type_replaced);
        System.assertEquals('Test Template', template.data.attributes.name);
        System.assertEquals('dGVzdA==', template.data.attributes.content_base64);
    }

    @isTest
    static void testRequirementQualificationRequestDTO() {
        ClickSignRequestDTO.RequirementQualification requirement = new ClickSignRequestDTO.RequirementQualification();
        requirement.data = new ClickSignRequestDTO.RequirementQualificationData();
        requirement.data.type_replaced = 'requirement';
        requirement.data.attributes = new ClickSignRequestDTO.RequirementQualificationAttributes();
        requirement.data.attributes.action = 'sign';
        requirement.data.attributes.role = 'signer';
        requirement.data.relationships = new ClickSignRequestDTO.RequirementRelationships();
        requirement.data.relationships.document = new ClickSignRequestDTO.RequirementRelatedData();
        requirement.data.relationships.document.data = new ClickSignRequestDTO.RequirementDataReference();
        requirement.data.relationships.document.data.type_replaced = 'document';
        requirement.data.relationships.document.data.id = '1';
        requirement.data.relationships.signer = new ClickSignRequestDTO.RequirementRelatedData();
        requirement.data.relationships.signer.data = new ClickSignRequestDTO.RequirementDataReference();
        requirement.data.relationships.signer.data.type_replaced = 'signer';
        requirement.data.relationships.signer.data.id = '1';
        
        System.assertEquals('requirement', requirement.data.type_replaced);
        System.assertEquals('sign', requirement.data.attributes.action);
        System.assertEquals('signer', requirement.data.attributes.role);
        System.assertEquals('document', requirement.data.relationships.document.data.type_replaced);
        System.assertEquals('1', requirement.data.relationships.document.data.id);
        System.assertEquals('signer', requirement.data.relationships.signer.data.type_replaced);
        System.assertEquals('1', requirement.data.relationships.signer.data.id);
    }

    @isTest
    static void testRequirementAutenticationRequestDTO() {
        ClickSignRequestDTO.RequirementAutentication requirement = new ClickSignRequestDTO.RequirementAutentication();
        requirement.data = new ClickSignRequestDTO.RequirementAutenticationData();
        requirement.data.type_replaced = 'requirement';
        requirement.data.attributes = new ClickSignRequestDTO.RequirementAutenticationAttributes();
        requirement.data.attributes.action = 'authenticate';
        requirement.data.attributes.auth = 'email';
        requirement.data.relationships = new ClickSignRequestDTO.RequirementRelationships();
        requirement.data.relationships.document = new ClickSignRequestDTO.RequirementRelatedData();
        requirement.data.relationships.document.data = new ClickSignRequestDTO.RequirementDataReference();
        requirement.data.relationships.document.data.type_replaced = 'document';
        requirement.data.relationships.document.data.id = '1';
        requirement.data.relationships.signer = new ClickSignRequestDTO.RequirementRelatedData();
        requirement.data.relationships.signer.data = new ClickSignRequestDTO.RequirementDataReference();
        requirement.data.relationships.signer.data.type_replaced = 'signer';
        requirement.data.relationships.signer.data.id = '1';
        
        System.assertEquals('requirement', requirement.data.type_replaced);
        System.assertEquals('authenticate', requirement.data.attributes.action);
        System.assertEquals('email', requirement.data.attributes.auth);
        System.assertEquals('document', requirement.data.relationships.document.data.type_replaced);
        System.assertEquals('1', requirement.data.relationships.document.data.id);
        System.assertEquals('signer', requirement.data.relationships.signer.data.type_replaced);
        System.assertEquals('1', requirement.data.relationships.signer.data.id);
    }

    @isTest
    static void testEnvelopeNotificationRequestDTO() {
        ClickSignRequestDTO.EnvelopeNotification notification = new ClickSignRequestDTO.EnvelopeNotification();
        notification.data = new ClickSignRequestDTO.EnvelopeNotificationData();
        notification.data.type_replaced = 'notification';
        notification.data.attributes = new ClickSignRequestDTO.EnvelopeNotificationAttributes();
        notification.data.attributes.message = 'Test Notification';
        
        System.assertEquals('notification', notification.data.type_replaced);
        System.assertEquals('Test Notification', notification.data.attributes.message);
    }
}