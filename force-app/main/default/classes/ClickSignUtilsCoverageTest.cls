/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignUtilsCoverageTest {
  @IsTest
  static void shouldHandleLogsAndIntegrationLookups() {
    Integrador__mdt integration = ClickSignUtils.getIntegration(
      'CREATE_ENVELOPE'
    );
    System.assertNotEquals(null, integration);

    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint('https://example.test/documents');
    req.setBody('{"hello":"world"}');

    RestRequest restReq = new RestRequest();
    restReq.requestBody = Blob.valueOf('rest-body');
    restReq.httpMethod = 'PATCH';
    restReq.requestURI = '/services/apexrest/clicksign';

    Test.startTest();
    ClickSignLog__c requestLog = ClickSignUtils.createLog(
      'ClickSignUtilsCoverageTest',
      'request',
      req
    );
    ClickSignLog__c restLog = ClickSignUtils.createLog(
      'ClickSignUtilsCoverageTest',
      'rest',
      restReq
    );
    ClickSignUtils.createLogAsync(
      JSON.serialize(
        new ClickSignLog__c(
          Class__c = 'ClickSignUtilsCoverageTest',
          Method__c = 'async'
        )
      )
    );
    Test.stopTest();

    System.assertEquals('POST', requestLog.HTTPMethod__c);
    System.assertEquals('/services/apexrest/clicksign', restLog.RequestURI__c);
    System.assert(
      [
        SELECT COUNT()
        FROM ClickSignLog__c
        WHERE Class__c = 'ClickSignUtilsCoverageTest'
      ] > 0
    );
  }

  @IsTest
  static void shouldManageClickSignsFilesAndMappings() {
    Account accountRecord = new Account(Name = 'ClickSign Utils Account');
    insert accountRecord;

    Consultor__c consultorRecord = new Consultor__c(
      Name = 'Consultor Utils',
      Ativo__c = true,
      Usuario__c = UserInfo.getUserId()
    );
    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultorRecord;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    Opportunity opportunityRecord = new Opportunity(
      Name = 'ClickSign Utils Opportunity',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(20),
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = 'vo-utils-' + String.valueOf(System.now().getTime()),
      ConsultorOportunidade__c = consultorRecord.Id
    );
    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    ClickSign__c clickSign = ClickSignUtils.getOrCreateClickSign(accountRecord);
    ClickSign__c createdClickSign = ClickSignUtils.createClickSign(
      opportunityRecord
    );
    System.assertEquals('Draft', clickSign.Status__c);
    System.assertEquals('Documents', createdClickSign.CurrentStep__c);

    ContentVersion clickDoc = new ContentVersion(
      Title = 'ClickDoc',
      PathOnClient = 'ClickDoc.pdf',
      VersionData = Blob.valueOf('clicksign-file'),
      FirstPublishLocationId = clickSign.Id,
      ExternalId__c = 'ext-doc-1'
    );
    insert clickDoc;

    ClickSignTemplate__c template = new ClickSignTemplate__c(
      Name = 'Utils Template',
      ExternalId__c = 'tmpl-utils',
      SourceObject__c = 'Account',
      IsActivate__c = true,
      FileName__c = 'UtilsTemplate'
    );
    insert template;

    ContentVersion templateDoc = new ContentVersion(
      Title = 'TemplateDoc',
      PathOnClient = 'TemplateDoc.docx',
      VersionData = Blob.valueOf('template-file'),
      FirstPublishLocationId = template.Id,
      Istemplate__c = true
    );
    insert templateDoc;

    List<ClickSignService.Document> files = ClickSignUtils.getFilesbyClickSignId(
      clickSign.Id
    );
    List<ContentDocument> templateDocuments = ClickSignUtils.getDocuments(
      template.Id
    );

    String objectMappings = JSON.serialize(
      new List<Object>{
        new Map<String, Object>{
          'fieldName' => 'Name',
          'relationshipField' => null,
          'relatedField' => null,
          'tag' => '{{account_name}}',
          'tagLabel' => '{{account_name}}'
        },
        new Map<String, Object>{
          'fieldName' => null,
          'relationshipField' => 'Owner',
          'relatedField' => 'Name',
          'tag' => '{{owner_name}}',
          'tagLabel' => '{{owner_name}}'
        }
      }
    );
    String contractInfo = JSON.serialize(
      new List<Object>{
        new Map<String, Object>{
          'fieldName' => 'ContractNumber',
          'tag' => '{{contract}}',
          'tagLabel' => '{{contract}}'
        }
      }
    );

    String generatedFields = ClickSignUtils.generateMapFields(
      accountRecord.Id,
      objectMappings,
      '123/2026',
      contractInfo
    );
    String blankFields = ClickSignUtils.generateMapFields(
      accountRecord.Id,
      null,
      null,
      null
    );
    String invalidFields = ClickSignUtils.generateMapFields(
      accountRecord.Id,
      '[{"fieldName":"NoSuchField__c","tag":"{{x}}","tagLabel":"{{x}}"}]',
      null,
      null
    );
    String tagMap = ClickSignUtils.generateTagMapFromMappings(objectMappings);
    List<ClickSignSigner__c> signers = ClickSignUtils.createSignersByJson(
      '[{"fieldName":"ConsultorOportunidade__c","relatedField":"Name","emailField":"Usuario__c","roleValueField":"Signer"}]',
      clickSign.Id,
      opportunityRecord.Id
    );

    System.assertEquals(1, files.size());
    System.assertEquals('ClickDoc', files[0].filename);
    System.assertEquals('ext-doc-1', files[0].externalId);
    System.assertEquals(1, templateDocuments.size());
    System.assert(
      generatedFields.contains('"account_name":"ClickSign Utils Account"')
    );
    System.assert(generatedFields.contains('"contract":"123/2026"'));
    System.assertEquals('{}', blankFields);
    System.assertEquals('{}', invalidFields);
    System.assert(tagMap.contains('{{account_name}}'));
    System.assertEquals(1, signers.size());
    System.assertEquals('Consultor Utils', signers[0].Name);
    System.assertEquals(
      String.valueOf(UserInfo.getUserId()),
      signers[0].Email__c
    );
    System.assertEquals(
      String.valueOf(Date.today().year()),
      ClickSignUtils.generateContractNumberString(123).split('/')[1]
    );
  }
}
