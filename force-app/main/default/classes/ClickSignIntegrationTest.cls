/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 01-26-2026
 * @last modified by	 : Daniel Belini
 **/
@isTest
public class ClickSignIntegrationTest {
  @testSetup
  static void setup() {
    // Create test data
    ClickSignEnvelope__c envelope = new ClickSignEnvelope__c(
      Name = 'Test Envelope',
      Status__c = 'Draft',
      ExternalId__c = 'envelope123'
    );
    insert envelope;

    ClickSign__c clickSign = new ClickSign__c(
      CurrentStep__c = 'Documents',
      Status__c = 'Draft',
      ClickSignEnvelope__c = envelope.Id
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
  static void testCreateEnvelope() {
    String payload = getPayload('envelope');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    ClickSignResponseDTO.Envelope envelope = ClickSignIntegration.createEnvelope(
      'Test Envelope'
    );
    Test.stopTest();
    System.assertNotEquals(null, envelope);
  }

  @isTest
  static void testCreateDocument() {
    String payload = getPayload('document');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    ClickSignResponseDTO.Document document = ClickSignIntegration.createDocument(
      'envelope123',
      'Test Document',
      'dGVzdCBjb250ZW50'
    );
    Test.stopTest();
    System.assertNotEquals(null, document);
  }

  @isTest
  static void testCreateSigner() {
    String payload = getPayload('signer');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    ClickSignResponseDTO.Signer signer = ClickSignIntegration.createSigner(
      'envelope123',
      'Test Signer',
      'test@example.com'
    );
    Test.stopTest();
    System.assertNotEquals(null, signer);
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
    String resultQualification = ClickSignIntegration.createRequirementQualification(
      'envelope123',
      'signer123',
      'document123',
      'Signer'
    );
    String resultAutentication = ClickSignIntegration.createRequirementAutentication(
      'envelope123',
      'signer123',
      'document123',
      'test@example.com'
    );
    Test.stopTest();
    System.assertNotEquals(null, resultQualification);
    System.assertNotEquals(null, resultAutentication);
  }

  @isTest
  static void testActivateEnvelope() {
    String payload = getPayload('envelopeActivation');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    String result = ClickSignIntegration.activateEnvelope('envelope123');
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testNotification() {
    String payload = getPayload('notification');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    ClickSignIntegration.notification('envelope123');
    Test.stopTest();
  }

  @isTest
  static void testGetDocument() {
    String payload = getPayload('document');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    Blob document = ClickSignIntegration.getDocument(
      'https://api.clicksign.com/v1/documents/document123/files/original'
    );
    Test.stopTest();
    System.assertNotEquals(null, document);
  }

  @isTest
  static void testDeleteDocument() {
    String payload = getPayload('document');
    Test.setMock(HttpCalloutMock.class, new ClickSignMock(payload));
    Test.startTest();
    String result = ClickSignIntegration.deleteDocument(
      'envelope123',
      'document123'
    );
    Test.stopTest();
    System.assertNotEquals(null, result);
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
