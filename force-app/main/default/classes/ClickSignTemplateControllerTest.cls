@IsTest
private class ClickSignTemplateControllerTest {
    @IsTest
    static void shouldManageTemplates() {
        Id templateId = ClickSignTemplateController.createClickSignTemplate('Teste', 'Desc', 'Account');
        ClickSignTemplate__c template = [SELECT Id, Name, Stage__c FROM ClickSignTemplate__c WHERE Id = :templateId];

        ClickSignSigner__c signer = new ClickSignSigner__c(
            Name = 'Signer',
            SignerType__c = 'Any',
            ClickSignTemplate__c = templateId
        );
        insert signer;

        ContentVersion cv = new ContentVersion(
            Title = 'TemplateDoc',
            PathOnClient = 'template.docx',
            VersionData = Blob.valueOf('conteudo'),
            Istemplate__c = true,
            FirstPublishLocationId = templateId
        );
        insert cv;

        ApexPages.StandardController sc = new ApexPages.StandardController(template);
        ClickSignTemplateController controller = new ClickSignTemplateController(sc);
        System.assertNotEquals(null, controller.namespace);

        ClickSignTemplate__c loaded = ClickSignTemplateController.getClickSignTemplate(templateId, null);
        System.assertEquals(templateId, loaded.Id);

        ClickSignTemplate__c loadedSend = ClickSignTemplateController.getClickSignTemplateToSend(templateId, null);
        System.assertEquals(templateId, loadedSend.Id);

        template.Description__c = 'Atualizado';
        ClickSignTemplateController.updateClickSignTemplate(template);
        ClickSignTemplate__c updated = [SELECT Description__c FROM ClickSignTemplate__c WHERE Id = :templateId];
        System.assertEquals('Atualizado', updated.Description__c);

        List<ContentDocument> documents = ClickSignTemplateController.getDocuments(templateId);
        System.assertEquals(1, documents.size());

        List<Map<String, String>> fields = ClickSignTemplateController.getObjectFields('Account');
        System.assert(fields.size() > 0);

        PageReference pageRef = new PageReference('/' + templateId + '/e');
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', templateId);
        System.assertNotEquals(null, controller.redirectOnEdit());
    }
}