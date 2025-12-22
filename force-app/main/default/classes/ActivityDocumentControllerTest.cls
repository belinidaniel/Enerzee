@IsTest
private class ActivityDocumentControllerTest {

    @IsTest
    static void shouldReturnEmptyWhenNoSubjectOrId() {
        System.assertEquals(0, ActivityDocumentController.getRequiredDocuments(null).size());
        System.assertEquals(0, ActivityDocumentController.getAttachments(null, null).size());
    }

    @IsTest
    static void shouldReturnTaskContextForOpportunity() {
        Account acc = new Account(Name = 'ACC');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            IdVirtualOffice__c = 'test-vo'
        );
        insert opp;
        Task t = new Task(Subject = 'Teste', WhatId = opp.Id, Status = 'Not Started');
        insert t;

        Test.startTest();
        ActivityDocumentController.TaskContext ctx = ActivityDocumentController.getTaskContext(t.Id);
        Test.stopTest();

        System.assertEquals('Teste', ctx.subject);
        System.assertEquals(opp.Id, ctx.whatId);
        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assertEquals('test-vo', ctx.idVirtualOffice);
    }
}
