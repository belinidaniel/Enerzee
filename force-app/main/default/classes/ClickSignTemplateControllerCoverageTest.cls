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
