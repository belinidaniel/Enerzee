/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignTemplateControllerCoverageTest {
  @TestSetup
  static void setupData() {
    Account accountRecord = new Account(Name = 'Template Coverage Account');
    insert accountRecord;

    ClickSignTemplate__c template = new ClickSignTemplate__c(
      Name = 'Template Coverage',
      Description__c = 'Descricao',
      ExternalId__c = 'tmpl-coverage',
      SourceObject__c = 'Account',
      Stage__c = 'Select Source',
      ObjectMappings__c = '[{"fieldName":"Name","relationshipField":null,"relatedField":null,"tag":"{{account_name}}","tagLabel":"{{account_name}}"}]',
      FileName__c = 'CoverageTemplate',
      ButtonLabel__c = 'Assinar',
      IsActivate__c = true
    );
    insert template;

    insert new ClickSignSigner__c(
      Name = 'Template Object Signer',
      SignerType__c = 'object',
      ContactsMapping__c = '{"fieldName":"Name","relatedField":"Name","emailField":"Name","roleValueField":"Signer"}',
      ClickSignTemplate__c = template.Id
    );

    insert new ContentVersion(
      Title = 'TemplateDoc',
      PathOnClient = 'TemplateDoc.docx',
      VersionData = Blob.valueOf('template-content'),
      FirstPublishLocationId = template.Id,
      Istemplate__c = true
    );

    insert new ContentVersion(
      Title = 'PreviewDoc',
      PathOnClient = 'PreviewDoc.docx',
      VersionData = Blob.valueOf('preview-content'),
      FirstPublishLocationId = template.Id,
      Istemplate__c = false
    );
  }

  @IsTest
  static void shouldManageNavigationCrudAndMetadataHelpers() {
    ClickSignTemplate__c template = [
      SELECT Id, Name, Description__c
      FROM ClickSignTemplate__c
      WHERE ExternalId__c = 'tmpl-coverage'
      LIMIT 1
    ];

    ApexPages.StandardController standardController = new ApexPages.StandardController(
      template
    );
    ClickSignTemplateController controller = new ClickSignTemplateController(
      standardController
    );

    PageReference currentPage = new PageReference('/apex/template');
    Test.setCurrentPage(currentPage);
    currentPage.getParameters().put('id', template.Id);
    currentPage.getParameters().put('templateId', template.Id);

    Id createdId = ClickSignTemplateController.createClickSignTemplate(
      'Nova Template',
      'Nova Desc',
      'Account'
    );
    ClickSignTemplate__c loaded = ClickSignTemplateController.getClickSignTemplate(
      template.Id,
      null
    );
    ClickSignTemplate__c loadedToSend = ClickSignTemplateController.getClickSignTemplateToSend(
      template.Id,
      [SELECT Id FROM Account LIMIT 1].Id
    );

    template.Description__c = 'Descricao Atualizada';
    ClickSignTemplateController.updateClickSignTemplate(template);
    ClickSignTemplateController.activateTemplate(template.Id);
    ClickSignTemplateController.createButtonInLayout(template.Id, 'Botao Novo');

    controller.forwardToStartPage();
    System.assertNotEquals(null, controller.redirectOnEdit());
    System.assertNotEquals(null, controller.redirectOnNewTemplate());
    System.assertNotEquals(null, controller.redirectOnCancel());
    System.assertNotEquals(null, controller.redirectOnFinish());
    System.assertNotEquals(null, createdId);
    System.assertEquals(template.Id, loaded.Id);
    System.assertEquals(template.Id, loadedToSend.Id);
    System.assertEquals(1, loadedToSend.ClickSignSigners__r.size());
  }

  @IsTest
  static void shouldHandleDocumentsPreviewAndVisibilityRules() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    ClickSignTemplate__c template = [
      SELECT Id, ObjectMappings__c
      FROM ClickSignTemplate__c
      WHERE ExternalId__c = 'tmpl-coverage'
      LIMIT 1
    ];

    ContentVersion templateVersion = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE FirstPublishLocationId = :template.Id AND Istemplate__c = TRUE
      LIMIT 1
    ];

    ClickSignTemplateController.uploadGuestUserIdOverride = UserInfo.getUserId();
    ClickSignTemplateController.uploadSiteIdOverride = null;
    ClickSignTemplateController.versionDataDocumentIdOverride = templateVersion.ContentDocumentId;

    String validRuleJson = JSON.serialize(
      new Map<String, Object>{
        'version' => 2,
        'mode' => 'expression',
        'logicMode' => 'ALL',
        'conditions' => new List<Object>{
          new Map<String, Object>{
            'id' => '1',
            'type' => 'picklist',
            'field' => 'Industry',
            'op' => 'IN',
            'values' => new List<Object>{ 'Banking' }
          }
        }
      }
    );

    Test.setMock(
      HttpCalloutMock.class,
      new ClickSignMock(getPayload('document'))
    );
    Test.startTest();
    ContentVersion versionData = ClickSignTemplateController.getVersionData();
    List<ContentDocument> templateDocs = ClickSignTemplateController.getDocuments(
      template.Id
    );
    ClickSignTemplateController.uploadDocument(
      'UploadedTemplate.docx',
      EncodingUtil.base64Encode(Blob.valueOf('uploaded-template')),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      template.Id
    );
    List<ContentDocument> generatedDocs = ClickSignTemplateController.getTemplateClickSign(
      template.Id
    );
    String previewResult = ClickSignTemplateController.generatePreview(
      accountRecord.Id,
      template.Id
    );
    String templateQueueResult = ClickSignTemplateController.generateTemplateFromMappings(
      template.Id
    );
    String downloadUrl = ClickSignTemplateController.getContentDocumentDownloadUrl(
      template.Id
    );
    List<Map<String, String>> fields = ClickSignTemplateController.getObjectFields(
      'Account'
    );
    List<Map<String, String>> picklistFields = ClickSignTemplateController.getPicklistFields(
      'Opportunity'
    );
    List<String> picklistValues = ClickSignTemplateController.getPicklistValues(
      'Opportunity',
      'StageName'
    );
    List<Map<String, String>> recordTypes = ClickSignTemplateController.getRecordTypes(
      'Opportunity'
    );
    List<String> validationErrors = ClickSignTemplateController.validateVisibilityRules(
      validRuleJson
    );
    ClickSignTemplateController.saveVisibilityRules(template.Id, validRuleJson);
    Test.stopTest();

    ClickSignTemplate__c updatedTemplate = [
      SELECT VisibilityRules__c, ButtonLabel__c, IsActivate__c
      FROM ClickSignTemplate__c
      WHERE Id = :template.Id
    ];

    ClickSignTemplate__c noMappingsTemplate = new ClickSignTemplate__c(
      Name = 'NoMappings',
      SourceObject__c = 'Account',
      Stage__c = 'Select Source'
    );
    insert noMappingsTemplate;

    ClickSignTemplate__c noDocumentTemplate = new ClickSignTemplate__c(
      Name = 'NoDocument',
      SourceObject__c = 'Account',
      Stage__c = 'Select Source',
      ObjectMappings__c = template.ObjectMappings__c
    );
    insert noDocumentTemplate;

    System.assertNotEquals(null, versionData);
    System.assertEquals(true, templateDocs.size() > 0);
    System.assertEquals(true, generatedDocs.size() > 0);
    System.assertEquals('success', previewResult);
    System.assertEquals('queued', templateQueueResult);
    System.assertNotEquals(null, downloadUrl);
    System.assertEquals(true, fields.size() > 0);
    System.assertEquals(true, picklistFields.size() > 0);
    System.assertEquals(true, picklistValues.size() > 0);
    System.assertEquals(true, recordTypes.size() > 0);
    System.assertEquals(0, validationErrors.size());
    System.assertEquals(validRuleJson, updatedTemplate.VisibilityRules__c);
    System.assertEquals(
      'no-mappings',
      ClickSignTemplateController.generateTemplateFromMappings(
        noMappingsTemplate.Id
      )
    );
    System.assertEquals(
      'no-document',
      ClickSignTemplateController.generateTemplateFromMappings(
        noDocumentTemplate.Id
      )
    );

    Boolean invalidRuleThrown = false;
    try {
      ClickSignTemplateController.saveVisibilityRules(
        template.Id,
        '{"version":2,"mode":"expression","logicExpression":"(1","conditions":[{"id":"1","type":"picklist","field":"StageName","op":"IN","values":["Prospecting"]}]}'
      );
    } catch (AuraHandledException ex) {
      invalidRuleThrown = true;
    }
    System.assertEquals(true, invalidRuleThrown);
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
