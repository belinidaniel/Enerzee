/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class ClickSignServiceTest {
  private static Integer mockSequence = 0;

  private class MultiPayloadClickSignMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(200);

      if (req.getMethod() == 'GET') {
        res.setBody('merged-file');
        return res;
      }

      String body = req.getBody();
      if (body != null && body.contains('"notifications"')) {
        res.setBody('{"status":"success"}');
      } else if (body != null && body.contains('"running"')) {
        res.setBody('{"status":"running"}');
      } else if (body != null && body.contains('"requirements"')) {
        res.setBody('{"status":"requirement-created"}');
      } else if (body != null && body.contains('"signers"')) {
        mockSequence++;
        res.setBody(
          '{"data":{"id":"signer-' +
            mockSequence +
            '","type":"signers","attributes":{"email":"test@example.com"}}}'
        );
      } else if (body != null && body.contains('"templates"')) {
        mockSequence++;
        res.setBody(
          '{"data":{"id":"template-' +
            mockSequence +
            '","type":"templates","links":{"files":{"original":"https://example.com/template-' +
            mockSequence +
            '"}}}}'
        );
      } else if (body != null && body.contains('"documents"')) {
        mockSequence++;
        res.setBody(
          '{"data":{"id":"document-' +
            mockSequence +
            '","type":"documents","links":{"files":{"original":"https://example.com/document-' +
            mockSequence +
            '"}}}}'
        );
      } else {
        mockSequence++;
        res.setBody(
          '{"data":{"id":"envelope-' +
            mockSequence +
            '","type":"envelopes","links":{"self":"https://example.com/envelope-' +
            mockSequence +
            '"},"attributes":{"name":"Envelope ' +
            mockSequence +
            '","status":"draft"}}}'
        );
      }
      return res;
    }
  }

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
      ClickSign__c = clickSign.Id,
      ExternalId__c = 'signer-external-123'
    );
    insert signer;

    insert new ContentVersion(
      Title = 'Setup Contract',
      PathOnClient = '/setup-contract.pdf',
      VersionData = Blob.valueOf('contract'),
      FirstPublishLocationId = clickSign.Id,
      ExternalId__c = 'setup-document'
    );
  }

  @isTest
  static void testProcess() {
    ClickSign__c clickSign = [
      SELECT Id, CurrentStep__c, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

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
    try {
      ClickSignService.process(envelopesInput, clickSign.CurrentStep__c);
    } catch (Exception e) {
    }
    Test.stopTest();
  }

  @isTest
  static void testAddDocuments() {
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

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
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

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
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

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
    ClickSignTemplate__c template = [
      SELECT Id, ExternalId__c
      FROM ClickSignTemplate__c
      LIMIT 1
    ];
    ClickSignService.Document document = new ClickSignService.Document();
    document.id = template.Id;
    document.filename = 'Test Template';
    document.file = 'dGVzdCBjb250ZW50';

    String payload = getPayload('document');
    String payloadEnv = getPayload('envelope');

    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadEnv));
    Test.startTest();
    try {
      ClickSignService.createTemplate(document);
    } catch (Exception e) {
    }
    Test.stopTest();
  }

  @isTest
  static void testCreateNewTemplate() {
    ClickSignTemplate__c template = [
      SELECT Id, ExternalId__c
      FROM ClickSignTemplate__c
      LIMIT 1
    ];
    template.ExternalId__c = null;
    update template;

    ClickSignService.Document document = new ClickSignService.Document();
    document.id = template.Id;
    document.filename = 'Test Template';
    document.file = 'dGVzdCBjb250ZW50';

    String payloadEnv = getPayload('envelope');

    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payloadEnv));
    Test.startTest();
    try {
      ClickSignService.createTemplate(document);
    } catch (Exception e) {
    }
    Test.stopTest();
  }

  @isTest
  static void testCreateRequirements() {
    String payloadQualification = getPayload('requirementQualification');
    String payloadAutentication = getPayload('requirementAutentication');
    Test.setMock(
      HttpCalloutMock.class,
      new ClickSignMock(payloadQualification)
    );
    Test.setMock(
      HttpCalloutMock.class,
      new ClickSignMock(payloadAutentication)
    );
    Test.startTest();
    ClickSignService.createRequirements(
      'envelope123',
      'signer123',
      'document123',
      'Signer',
      'test@example.com'
    );
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
    try {
      ClickSignService.createEnvelope(env);
    } catch (Exception e) {
    }

    Test.stopTest();
  }

  @isTest
  static void testUploadDocument() {
    ClickSign__c clickSign = [
      SELECT Id, CurrentStep__c, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];
    String payload = getPayload('document');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    ClickSignService.uploadDocument(
      'Test Document',
      clickSign.Id,
      'application/pdf',
      clickSign.Id
    );
    Test.stopTest();
  }

  @isTest
  static void testProcessRecipientsStep() {
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

    ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
    envelopeInput.clickSignId = clickSign.Id;
    envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

    List<ClickSignService.EnvelopeInput> envelopesInput = new List<ClickSignService.EnvelopeInput>{
      envelopeInput
    };

    Test.setMock(HttpCalloutMock.class, new MultiPayloadClickSignMock());
    Test.startTest();
    ClickSignService.process(envelopesInput, 'Recipients');
    Test.stopTest();

    ClickSignSigner__c signer = [
      SELECT ExternalId__c
      FROM ClickSignSigner__c
      WHERE ClickSign__c = :clickSign.Id
      LIMIT 1
    ];
    System.assertNotEquals(null, signer.ExternalId__c);
  }

  @isTest
  static void testProcessPrepareSendStep() {
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

    ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
    envelopeInput.clickSignId = clickSign.Id;
    envelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;

    List<ClickSignService.EnvelopeInput> envelopesInput = new List<ClickSignService.EnvelopeInput>{
      envelopeInput
    };

    Test.setMock(HttpCalloutMock.class, new MultiPayloadClickSignMock());
    Test.startTest();
    ClickSignService.process(envelopesInput, 'Prepare & Send');
    Test.stopTest();

    ClickSign__c updatedClickSign = [
      SELECT Status__c
      FROM ClickSign__c
      WHERE Id = :clickSign.Id
    ];
    ClickSignSigner__c signer = [
      SELECT Status__c
      FROM ClickSignSigner__c
      WHERE ClickSign__c = :clickSign.Id
      LIMIT 1
    ];
    System.assertEquals('Document Send to Assign', updatedClickSign.Status__c);
    System.assertEquals('Notificado', signer.Status__c);
  }

  @isTest
  static void testAddDocumentsWithoutEnvelopeAndTemplate() {
    ClickSign__c clickSign = new ClickSign__c(
      CurrentStep__c = 'Documents',
      Status__c = 'Draft'
    );
    insert clickSign;

    ContentVersion version = new ContentVersion(
      Title = 'local-source',
      PathOnClient = '/local-source.pdf',
      VersionData = Blob.valueOf('source')
    );
    insert version;

    ClickSignService.Document document = new ClickSignService.Document();
    document.id = version.Id;
    document.filename = 'Generated Document';
    document.file = EncodingUtil.base64Encode(Blob.valueOf('payload'));

    ClickSignService.EnvelopeInput envelopeInput = new ClickSignService.EnvelopeInput();
    envelopeInput.clickSignId = clickSign.Id;
    envelopeInput.documents = new List<ClickSignService.Document>{ document };

    Test.setMock(HttpCalloutMock.class, new MultiPayloadClickSignMock());
    Test.startTest();
    ClickSignService.addDocuments(envelopeInput);
    Test.stopTest();

    ClickSign__c updated = [
      SELECT ClickSignEnvelope__c, CurrentStep__c
      FROM ClickSign__c
      WHERE Id = :clickSign.Id
    ];
    ContentVersion updatedVersion = [
      SELECT ExternalId__c, ClickSignEnvelope__c
      FROM ContentVersion
      WHERE Id = :version.Id
    ];

    System.assertNotEquals(null, updated.ClickSignEnvelope__c);
    System.assertEquals('Recipients', updated.CurrentStep__c);
    System.assert(updatedVersion.ExternalId__c.startsWith('document-'));
    System.assertEquals(
      updated.ClickSignEnvelope__c,
      updatedVersion.ClickSignEnvelope__c
    );
  }

  @isTest
  static void testAddDocumentsWithTemplateDocumentAndMissingInput() {
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];

    ClickSignService.Document templateDoc = new ClickSignService.Document();
    templateDoc.filename = 'Template Doc';
    templateDoc.externalId = 'template-123';
    templateDoc.mergeFields = '{"field":"value"}';

    ClickSignService.EnvelopeInput validEnvelopeInput = new ClickSignService.EnvelopeInput();
    validEnvelopeInput.clickSignId = clickSign.Id;
    validEnvelopeInput.envelopeId = clickSign.ClickSignEnvelope__c;
    validEnvelopeInput.documents = new List<ClickSignService.Document>{
      templateDoc
    };

    Test.setMock(HttpCalloutMock.class, new MultiPayloadClickSignMock());
    Test.startTest();
    ClickSignService.addDocuments(validEnvelopeInput);
    Test.stopTest();

    Integer generatedFiles = [
      SELECT COUNT()
      FROM ContentVersion
      WHERE ClickSignEnvelope__c = :clickSign.ClickSignEnvelope__c
    ];
    System.assert(generatedFiles > 0);

    ClickSignService.EnvelopeInput invalidEnvelopeInput = new ClickSignService.EnvelopeInput();
    invalidEnvelopeInput.clickSignId = clickSign.Id;

    Boolean missingDocuments = false;
    try {
      ClickSignService.addDocuments(invalidEnvelopeInput);
    } catch (ClickSignService.ClickSignServiceException ex) {
      missingDocuments = ex.getMessage().contains('No documents provided');
    }
    System.assertEquals(true, missingDocuments);
  }

  @isTest
  static void testCreateTemplateFromMappingsEarlyReturns() {
    ClickSignTemplate__c blankTemplate = new ClickSignTemplate__c(
      Name = 'Blank Mapping Template',
      FileName__c = 'blank-template',
      IsActivate__c = true
    );
    insert blankTemplate;

    ClickSignTemplate__c noDocumentTemplate = new ClickSignTemplate__c(
      Name = 'No Document Template',
      FileName__c = 'mapping-template',
      ObjectMappings__c = '[{\"fieldName\":\"Name\",\"tag\":\"{{Account.Name}}\"}]',
      IsActivate__c = true
    );
    insert noDocumentTemplate;

    Test.startTest();
    ClickSignService.createTemplateFromMappings(blankTemplate.Id);
    ClickSignService.createTemplateFromMappings(noDocumentTemplate.Id);
    Test.stopTest();

    System.assertEquals(
      null,
      [
        SELECT ExternalId__c
        FROM ClickSignTemplate__c
        WHERE Id = :blankTemplate.Id
      ]
      .ExternalId__c
    );
    System.assertEquals(
      null,
      [
        SELECT ExternalId__c
        FROM ClickSignTemplate__c
        WHERE Id = :noDocumentTemplate.Id
      ]
      .ExternalId__c
    );
  }

  // Mock class for HttpCallout
  private static String getPayload(String node) {
    StaticResource payload = [
      SELECT Id, Body
      FROM StaticResource
      WHERE Name = 'ClickSignMock'
      LIMIT 1
    ];

    Map<String, Object> mapPayload = (Map<String, Object>) JSON.deserializeUntyped(
      payload.Body.toString()
    );

    return JSON.serialize(mapPayload.get(node));
  }
}
