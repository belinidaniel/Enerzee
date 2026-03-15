/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignControllerCoverageTest {
  @TestSetup
  static void setupData() {
    Account accountRecord = new Account(Name = 'ClickSign Controller Account');
    insert accountRecord;

    ClickSignEnvelope__c envelope = new ClickSignEnvelope__c(
      Name = 'Envelope Controller',
      Status__c = 'Draft',
      ExternalId__c = 'env-controller'
    );
    insert envelope;

    ClickSignTemplate__c template = new ClickSignTemplate__c(
      Name = 'Template Controller',
      ExternalId__c = 'tmpl-controller',
      SourceObject__c = 'Account',
      IsActivate__c = true,
      ButtonLabel__c = 'Enviar Contrato',
      FileName__c = 'ControllerDoc',
      ObjectMappings__c = '[{"fieldName":"Name","relationshipField":null,"relatedField":null,"tag":"{{account_name}}","tagLabel":"{{account_name}}"}]'
    );
    insert template;

    insert new List<ClickSignSigner__c>{
      new ClickSignSigner__c(
        Name = 'Template Manual',
        Email__c = 'manual@test.com',
        Role__c = 'Signer',
        ClickSignTemplate__c = template.Id,
        SignerType__c = 'manual'
      ),
      new ClickSignSigner__c(
        Name = 'Template Object',
        Email__c = 'object@test.com',
        Role__c = 'Signer',
        ClickSignTemplate__c = template.Id,
        SignerType__c = 'object',
        ContactsMapping__c = '{"fieldName":"Name","relatedField":"Name","emailField":"Name","roleValueField":"Signer"}'
      )
    };

    ClickSign__c clickSign = new ClickSign__c(
      CurrentStep__c = 'Recipients',
      Status__c = 'Draft',
      RecordId__c = accountRecord.Id,
      RecordType__c = 'Account',
      ClickSignEnvelope__c = envelope.Id
    );
    insert clickSign;

    insert new ClickSignSigner__c(
      Name = 'Recipient Existing',
      Email__c = 'recipient@test.com',
      Role__c = 'Signer',
      ClickSign__c = clickSign.Id
    );
  }

  @IsTest
  static void shouldPrepareSendProcessAndManageCrud() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    ClickSignTemplate__c template = [
      SELECT Id
      FROM ClickSignTemplate__c
      WHERE ExternalId__c = 'tmpl-controller'
      LIMIT 1
    ];
    ClickSign__c clickSign = [
      SELECT Id, ClickSignEnvelope__c, CurrentStep__c
      FROM ClickSign__c
      LIMIT 1
    ];

    Test.setMock(
      HttpCalloutMock.class,
      new ClickSignMock(getPayload('signer'))
    );
    Test.startTest();
    ClickSign__c prepared = ClickSignController.prepareToSend(
      template.Id,
      accountRecord.Id
    );
    String processResult = ClickSignController.process(
      clickSign,
      accountRecord.Id,
      'Recipients'
    );
    Test.stopTest();

    List<ClickSignSigner__c> preparedSigners = [
      SELECT Id, ClickSign__c, ClickSignTemplate__c, Email__c, Name
      FROM ClickSignSigner__c
      WHERE ClickSign__c = :prepared.Id
    ];

    System.assertEquals('success', processResult);
    System.assert(preparedSigners.size() >= 2);
    System.assertEquals(null, preparedSigners[0].ClickSignTemplate__c);
  }

  @IsTest
  static void shouldManageDocumentsRecipientsAndTemplateSelection() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    ClickSign__c clickSign = [
      SELECT Id
      FROM ClickSign__c
      LIMIT 1
    ];
    ClickSignTemplate__c template = [
      SELECT Id
      FROM ClickSignTemplate__c
      WHERE ExternalId__c = 'tmpl-controller'
      LIMIT 1
    ];

    ClickSignController.uploadGuestUserIdOverride = UserInfo.getUserId();
    ClickSignController.uploadSiteIdOverride = null;

    Test.startTest();
    ClickSign__c fetched = ClickSignController.getOrCreateClickSign(
      accountRecord.Id
    );
    ClickSign__c created = ClickSignController.createNewClickSign(
      accountRecord.Id
    );
    ClickSign__c cancelled = ClickSignController.cancelAndCreateClickSign(
      accountRecord.Id
    );
    ClickSignController.uploadDocument(
      'ControllerUpload.pdf',
      EncodingUtil.base64Encode(Blob.valueOf('controller-upload')),
      'application/pdf',
      clickSign.Id
    );
    ClickSignSigner__c savedSigner = ClickSignController.saveRecipient(
      new Map<String, Object>{
        'name' => 'Recipient New',
        'email' => 'new-recipient@test.com',
        'role' => 'Signer',
        'userId' => String.valueOf(UserInfo.getUserId()),
        'roleLabel' => 'Assinante'
      },
      clickSign.Id,
      null
    );
    List<ClickSignSigner__c> recipients = ClickSignController.getRecipients(
      clickSign.Id
    );
    ClickSignController.updateClickSignCurrentStep(
      clickSign.Id,
      'Prepare & Send'
    );
    List<ClickSign__c> records = ClickSignController.getClickSignRecords(
      accountRecord.Id
    );
    List<String> objectList = ClickSignController.getObjectList();
    List<SObject> recordList = ClickSignController.getRecordList('Account');
    List<ClickSignTemplate__c> activeTemplates = ClickSignController.getActiveTemplates();
    ClickSignController.saveTemplateId(clickSign.Id, template.Id);
    List<ClickSignTemplate__c> visibleTemplates = ClickSignController.getTemplates(
      accountRecord.Id
    );
    Test.stopTest();

    List<ContentDocument> documents = ClickSignController.getDocuments(
      clickSign.Id
    );
    ClickSignController.deleteDocument(documents[0].Id);
    ClickSignController.deleteRecipient(savedSigner.Id);

    System.assertNotEquals(null, fetched);
    System.assertNotEquals(null, created);
    System.assertNotEquals(null, cancelled);
    System.assertEquals(true, recipients.size() > 0);
    System.assertEquals(true, records.size() > 0);
    System.assertEquals(true, objectList.contains('Account'));
    System.assertEquals(true, recordList.size() > 0);
    System.assertEquals(true, activeTemplates.size() > 0);
    System.assertEquals(true, visibleTemplates.size() > 0);
  }

  private static String getPayload(String node) {
    StaticResource payload = [
      SELECT Body
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
