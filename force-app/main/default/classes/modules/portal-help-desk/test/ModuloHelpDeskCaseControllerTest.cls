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

    @IsTest
    static void testGetCasesOpenClosedAndSearch() {
        User u = createUser();
        insert u;

        System.runAs(u) {
            Case openCase = new Case(Subject = 'Open Case Subject', Status = 'Working', Origin = 'Phone');
            insert openCase;

            Case closedCase = new Case(Subject = 'Closed Case Subject', Status = 'Closed', Origin = 'Phone');
            insert closedCase;

            Test.startTest();
            List<Case> openCases = ModuloHelpDeskCaseController.getCases('open', null);
            List<Case> closedCases = ModuloHelpDeskCaseController.getCases('closed', null);
            List<Case> searchedCases = ModuloHelpDeskCaseController.getCases('open', 'Open Case');
            Test.stopTest();

            System.assertEquals(1, openCases.size(), 'Deve retornar apenas casos abertos do usuário');
            System.assertEquals('Working', openCases[0].Status);
            System.assertEquals(1, closedCases.size(), 'Deve retornar apenas casos fechados do usuário');
            System.assertEquals('Closed', closedCases[0].Status);
            System.assertEquals(1, searchedCases.size(), 'Busca deve filtrar pelo termo informado');
        }
    }

    @IsTest
    static void testGetCaseDetailAndCommentsAndAdd() {
        User u = createUser();
        insert u;

        System.runAs(u) {
            Case c = new Case(Subject = 'Detail Subject', Status = 'Working', Origin = 'Email');
            insert c;

            CaseComment existing = new CaseComment(ParentId = c.Id, CommentBody = 'Existing comment', IsPublished = true);
            insert existing;

            Test.startTest();
            Case detail = ModuloHelpDeskCaseController.getCaseDetail(c.Id);
            List<CaseComment> comments = ModuloHelpDeskCaseController.getCaseComments(c.Id);
            CaseComment created = ModuloHelpDeskCaseController.addComment(c.Id, 'New comment text');
            List<CaseComment> commentsAfter = ModuloHelpDeskCaseController.getCaseComments(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, detail, 'Detalhe deve ser retornado');
            System.assertEquals('Detail Subject', detail.Subject);
            System.assertEquals(1, comments.size(), 'Comentário existente deve ser retornado');
            System.assertNotEquals(null, created.Id, 'Novo comentário deve ser criado');
            System.assertEquals(2, commentsAfter.size(), 'Após inserir, deve haver dois comentários');
        }
    }

    @IsTest
    static void testAccessDeniedForForeignCase() {
        User ownerUser = createUser();
        insert ownerUser;
        User anotherUser = createUser();
        insert anotherUser;

        Case otherCase;
        System.runAs(ownerUser) {
            otherCase = new Case(Subject = 'Other user case', Status = 'Working', Origin = 'Phone');
            insert otherCase;
        }

        System.runAs(anotherUser) {
            Boolean threw = false;
            try {
                ModuloHelpDeskCaseController.getCaseDetail(otherCase.Id);
            } catch (Exception e) {
                threw = true;
            }
            System.assertEquals(true, threw, 'Deve lançar exceção ao tentar acessar caso de outro usuário');
        }
    }
}
