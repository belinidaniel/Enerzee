@IsTest
private class HelpDeskCaseServiceTest {
    @IsTest
    static void shouldHandleCasesFlow() {
        Account acc = new Account(Name = 'Enerzee Support');
        insert acc;

        Contact c = new Contact(LastName = 'Contato', Email = 'helpdesk@teste.com', AccountId = acc.Id);
        insert c;

        Case cs = new Case(Subject = 'Ajuda', Status = 'New', Origin = 'Phone', ContactId = c.Id, AccountId = acc.Id);
        insert cs;

        HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
        ctx.userId = UserInfo.getUserId();
        ctx.contactId = c.Id;
        ctx.email = c.Email;

        List<Case> cases = HelpDeskCaseService.getCases('open', null, c.Id, ctx);
        System.assertEquals(1, cases.size());

        Case detail = HelpDeskCaseService.getCaseDetail(cs.Id, c.Id, ctx);
        System.assertEquals(cs.Id, detail.Id);

        CaseComment comment = HelpDeskCaseService.addComment(cs.Id, 'Teste', c.Id, ctx);
        System.assertEquals(cs.Id, comment.ParentId);

        List<CaseComment> comments = HelpDeskCaseService.getCaseComments(cs.Id, c.Id, ctx);
        System.assertEquals(1, comments.size());

        HelpDeskFilePayload payload = new HelpDeskFilePayload();
        payload.fileName = 'arquivo.txt';
        payload.base64Data = EncodingUtil.base64Encode(Blob.valueOf('conteudo'));

        HelpDeskCaseService.uploadFiles(cs.Id, new List<HelpDeskFilePayload>{ payload }, c.Id, ctx);
        System.assertEquals(1, [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :cs.Id]);

        HelpDeskCaseService.uploadFilesBypassLicense(cs.Id, new List<HelpDeskFilePayload>{ payload }, c.Id, ctx);
        System.assertEquals(2, [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :cs.Id]);

        HelpDeskCaseService.DefaultEntitiesDTO defaults = HelpDeskCaseService.getDefaultEntities(c.Id);
        System.assertEquals(acc.Id, defaults.accountId);
        System.assertEquals(c.Id, defaults.contactId);
        System.assertEquals(c.Email, defaults.contactEmail);

        List<HelpDeskCaseService.CaseCategoryOptionDTO> categoryOptions = HelpDeskCaseService.getCaseCategoryOptions();
        System.assertNotEquals(null, categoryOptions);

        if (Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().containsKey('Help_Desk_Salesforce')) {
            Id newCaseId = HelpDeskCaseService.createCase('Novo caso', 'Desc', null, 'Salesforce', 'Acesso', 'Login', 'Medium', c.Email, '1199', c.Id, acc.Id);
            System.assertNotEquals(null, newCaseId);
            if (Schema.SObjectType.Case.fields.getMap().containsKey('HelpDesk_Sistema__c')) {
                Case createdCase = [SELECT HelpDesk_Sistema__c, Reason, Type FROM Case WHERE Id = :newCaseId LIMIT 1];
                System.assertEquals('Salesforce', (String) createdCase.get('HelpDesk_Sistema__c'));
                System.assertEquals('Acesso', createdCase.Type);
                System.assertEquals('Login', createdCase.Reason);
            }
        }
    }
}
