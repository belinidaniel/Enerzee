@IsTest
private class ModuloHelpDeskCaseControllerTest {
    private static User createUser() {
        Profile p = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' LIMIT 1];
        String unique = String.valueOf(System.currentTimeMillis());
        return new User(
            FirstName = 'Test',
            LastName = 'HelpDesk' + unique,
            Alias = 'tst' + unique.substring(unique.length() - 2),
            Email = 'test' + unique + '@example.com',
            Username = 'test' + unique + '@example.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
    }

    private static Contact createContact() {
        Account a = new Account(Name = 'Enerzee');
        insert a;
        Contact c = new Contact(FirstName = 'Portal', LastName = 'Tester', Email = 'tester@example.com', AccountId = a.Id);
        insert c;
        return c;
    }

    @IsTest
    static void testGetCasesAndDetailWithContact() {
        User u = createUser();
        insert u;
        Contact c = createContact();

        System.runAs(u) {
            Case openCase = new Case(Subject = 'Open Case', Status = 'Novo', Origin = 'Phone', ContactId = c.Id);
            insert openCase;
            Case closedCase = new Case(Subject = 'Closed Case', Status = 'Fechado', Origin = 'Phone', ContactId = c.Id);
            insert closedCase;

            Test.startTest();
            List<Case> openCases = ModuloHelpDeskCaseController.getCases('open', null, c.Id);
            List<Case> closedCases = ModuloHelpDeskCaseController.getCases('closed', null, c.Id);
            Case detail = ModuloHelpDeskCaseController.getCaseDetail(openCase.Id, c.Id);
            Test.stopTest();

            System.assertEquals(1, openCases.size());
            System.assertEquals('Novo', openCases[0].Status);
            System.assertEquals(1, closedCases.size());
            System.assertEquals('Fechado', closedCases[0].Status);
            System.assertEquals(openCase.Id, detail.Id);
        }
    }

    @IsTest
    static void testCommentsAttachmentsAndUpload() {
        User u = createUser();
        insert u;
        Contact c = createContact();
        Case cs = new Case(Subject = 'Case with files', Status = 'Novo', Origin = 'Email', ContactId = c.Id);
        insert cs;

        System.runAs(u) {
            CaseComment existing = new CaseComment(ParentId = cs.Id, CommentBody = 'Existing', IsPublished = true);
            insert existing;

            Test.startTest();
            List<CaseComment> comments = ModuloHelpDeskCaseController.getCaseComments(cs.Id, c.Id);
            CaseComment created = ModuloHelpDeskCaseController.addComment(cs.Id, 'New comment', c.Id);
            List<ContentDocumentLink> beforeLinks = ModuloHelpDeskCaseController.getCaseAttachments(cs.Id, c.Id);
            HelpDeskFilePayload fp = new HelpDeskFilePayload();
            fp.fileName = 'test.txt';
            fp.base64Data = EncodingUtil.base64Encode(Blob.valueOf('hello'));
            ModuloHelpDeskCaseController.uploadFiles(cs.Id, new List<HelpDeskFilePayload>{ fp }, c.Id);
            List<ContentDocumentLink> afterLinks = ModuloHelpDeskCaseController.getCaseAttachments(cs.Id, c.Id);
            Test.stopTest();

            System.assertEquals(1, comments.size());
            System.assertNotEquals(null, created.Id);
            System.assertEquals(0, beforeLinks.size());
            System.assertEquals(1, afterLinks.size());
        }
    }

    @IsTest
    static void testAccessCodeFlow() {
        System.runAs(createUser()) {
            Test.startTest();
            ModuloHelpDeskCaseController.requestAccessCode('newguest@example.com', 'Guest', 'User', null);
            Id cid = ModuloHelpDeskCaseController.validateAccessCode('newguest@example.com', [SELECT Verification_Code__c FROM Contact WHERE Email = 'newguest@example.com' LIMIT 1].Verification_Code__c);
            Test.stopTest();
            System.assertNotEquals(null, cid);
        }
    }
}
