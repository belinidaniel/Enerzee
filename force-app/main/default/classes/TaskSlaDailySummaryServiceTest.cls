@IsTest
private class TaskSlaDailySummaryServiceTest {

    @IsTest
    static void managerOverdueSummaryCreatesLog() {
        User manager = createUser('manager+daily@example.com', null);
        User owner = createUser('owner+daily@example.com', manager.Id);

        Task taskRecord = new Task(
            Subject = 'Task Daily Overdue',
            Status = 'Open',
            ActivityDate = Date.today().addDays(-1),
            OwnerId = owner.Id
        );
        insert taskRecord;

        Test.startTest();
        TaskSlaDailySummaryService.runManagerOverdue();
        Test.stopTest();

        Integer logCount = [
            SELECT count()
            FROM Log__c
            WHERE RelatedId__c = :manager.Id
            AND Type__c = :TaskSlaConfig.TYPE_MANAGER_OVERDUE
        ];
        System.assertEquals(1, logCount, 'Deve registrar resumo para gestor.');
    }

    @IsTest
    static void ownerOpenSummaryCreatesLog() {
        User owner = createUser('owner+open@example.com', null);
        Task taskRecord = new Task(
            Subject = 'Task Daily Open',
            Status = 'Open',
            ActivityDate = Date.today(),
            OwnerId = owner.Id
        );
        insert taskRecord;

        Test.startTest();
        TaskSlaDailySummaryService.runOwnerOpenSummary();
        Test.stopTest();

        Integer logCount = [
            SELECT count()
            FROM Log__c
            WHERE RelatedId__c = :owner.Id
            AND Type__c = :TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
        ];
        System.assertEquals(1, logCount, 'Deve registrar resumo para owner.');
    }

    private static User createUser(String email, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(System.currentTimeMillis());
        User u = new User(
            Username = 'user+' + unique + '@example.com',
            Email = email,
            Alias = email.substring(0, 5),
            LastName = 'Tester',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'pt_BR'
        );
        insert u;
        if (managerId != null) {
            u.ManagerId = managerId;
            update u;
        }
        return u;
    }
}
