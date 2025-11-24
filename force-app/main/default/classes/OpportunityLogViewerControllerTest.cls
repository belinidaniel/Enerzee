@IsTest
private class OpportunityLogViewerControllerTest {
    private static Opportunity createOpportunity() {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;
        return opp;
    }

    private static Log__c insertLog(Id opportunityId) {
        Log__c logRecord = new Log__c(
            Name = 'Log for Opp',
            RelatedId__c = opportunityId,
            StatusCode__c = 500,
            Status__c = 'Erro ao integrar',
            Class__c = 'MyClass',
            Method__c = 'myMethod',
            HTTPMethod__c = 'POST',
            RequestURI__c = '/endpoint',
            Message__c = 'Something went wrong',
            RequestBody__c = '{"payload":true}',
            ResponseBody__c = '{"error":"failure"}',
            StackTraceString__c = 'Class.MyClass: line 42, column 1',
            LineNumber__c = 42,
            Type__c = 'Integration'
        );
        insert logRecord;
        return logRecord;
    }

    private static User createNonAdminUser() {
        Profile nonAdminProfile = [
            SELECT Id
            FROM Profile
            WHERE PermissionsModifyAllData = false
            LIMIT 1
        ];

        User standardUser = new User(
            Alias = 'stdusr',
            Email = 'stduser' + System.currentTimeMillis() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = nonAdminProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'stduser' + System.currentTimeMillis() + '@example.com'
        );

        insert standardUser;
        return standardUser;
    }

    @IsTest
    static void adminCanFetchLogsAndDetails() {
        Opportunity opp = createOpportunity();
        Log__c logRecord = insertLog(opp.Id);

        Test.startTest();
        List<Log__c> results = OpportunityLogViewerController.getLogsByOpportunity(opp.Id, 50);
        Log__c detail = OpportunityLogViewerController.getLogDetail(logRecord.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return a single log for the opportunity');
        System.assertEquals(logRecord.Id, results[0].Id, 'Returned log should match inserted log');
        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertEquals(logRecord.Id, detail.Id, 'Detail should match the requested log');
        System.assertEquals(42, detail.LineNumber__c);
    }

    @IsTest
    static void nonAdminCannotAccessLogs() {
        Opportunity opp = createOpportunity();
        insertLog(opp.Id);
        User nonAdmin = createNonAdminUser();

        Test.startTest();
        System.runAs(nonAdmin) {
            System.assertEquals(false, OpportunityLogViewerController.isCurrentUserAdmin(), 'User should not be admin');
            try {
                OpportunityLogViewerController.getLogsByOpportunity(opp.Id, 10);
                System.assert(false, 'Expected an exception for non-admin users');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('administradores'), 'Exception should indicate admin only access');
            }
        }
        Test.stopTest();
    }
}
