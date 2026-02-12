@IsTest
private class TaskSlaNotificationServiceTest {

    @IsTest
    static void beforeDueNotifiesOwnerAndManager() {
        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        if (!taskFields.containsKey('HoraVencimento__c') || !taskFields.containsKey('NotificadoAntesVencer__c')) {
            return;
        }

        User manager = createUser('manager+sla@example.com', null);
        User owner = createUser('owner+sla@example.com', manager.Id);

        DateTime soon = System.now().addMinutes(20);
        Time dueTime = Time.newInstance(soon.hour(), soon.minute(), soon.second(), soon.millisecond());

        Task taskRecord = new Task(
            Subject = 'Task SLA Test - Owner',
            Status = 'Open',
            ActivityDate = soon.date(),
            OwnerId = owner.Id
        );
        taskRecord.put('HoraVencimento__c', dueTime);
        taskRecord.put('NotificadoAntesVencer__c', false);
        insert taskRecord;

        Test.startTest();
        TaskSlaNotificationService.processDeadlineNotifications(new List<Task>{ taskRecord });
        Test.stopTest();

        Integer logCount = [
            SELECT count()
            FROM Log__c
            WHERE RelatedId__c = :taskRecord.Id
            AND Type__c = :TaskSlaConfig.TYPE_BEFORE_DUE
        ];
        System.assertEquals(2, logCount, 'Deve logar owner e manager.');
    }

    @IsTest
    static void beforeDueNotifiesQueueMembers() {
        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        if (!taskFields.containsKey('HoraVencimento__c') || !taskFields.containsKey('NotificadoAntesVencer__c')) {
            return;
        }

        User member = createUser('member+sla@example.com', null);
        Group queue = createQueue('SLA_TEST_QUEUE');
        insert new GroupMember(GroupId = queue.Id, UserOrGroupId = member.Id);

        DateTime soon = System.now().addMinutes(20);
        Time dueTime = Time.newInstance(soon.hour(), soon.minute(), soon.second(), soon.millisecond());

        Task taskRecord = new Task(
            Subject = 'Task SLA Test - Queue',
            Status = 'Open',
            ActivityDate = soon.date(),
            OwnerId = queue.Id
        );
        taskRecord.put('HoraVencimento__c', dueTime);
        taskRecord.put('NotificadoAntesVencer__c', false);
        insert taskRecord;

        Test.startTest();
        TaskSlaNotificationService.processDeadlineNotifications(new List<Task>{ taskRecord });
        Test.stopTest();

        Integer logCount = [
            SELECT count()
            FROM Log__c
            WHERE RelatedId__c = :taskRecord.Id
            AND Type__c = :TaskSlaConfig.TYPE_BEFORE_DUE
        ];
        System.assertEquals(1, logCount, 'Deve logar o membro da fila.');
    }

    private static Group createQueue(String developerName) {
        Group queue = new Group(
            Name = developerName,
            DeveloperName = developerName,
            Type = 'Queue'
        );
        insert queue;
        insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Task');
        return queue;
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