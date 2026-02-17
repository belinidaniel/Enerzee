@IsTest
private class TaskSlaCoreTest {

    @IsTest
    static void testConfigDefaultsAndStatuses() {
        TaskSlaConfig.NotificationConfig beforeCfg = TaskSlaConfig.getNotificationConfig(
            TaskSlaConfig.TYPE_BEFORE_DUE
        );
        System.assertNotEquals(null, beforeCfg, 'Config deve existir.');
        System.assertEquals(true, beforeCfg.enabled, 'Config before due deve estar habilitada.');
        System.assertEquals(30, beforeCfg.minutesBeforeDue, 'Minutos antes do vencimento deve ser 30.');
        System.assertEquals(true, beforeCfg.notifyManager, 'Deve notificar gestor.');

        Set<String> closed = TaskSlaConfig.getClosedStatusValues();
        System.assert(closed.contains('Completed'), 'Status Completed deve estar como fechado.');

        TaskSlaConfig.QueueRoutingConfig routing = TaskSlaConfig.getQueueRoutingConfig('DEFAULT');
        System.assertEquals(TaskSlaConfig.ROUTE_MEMBERS, routing.routingMode, 'Routing default deve ser MEMBERS.');
        System.assertEquals(TaskSlaConfig.ROUTE_QUEUE_EMAIL, routing.fallbackMode, 'Fallback default deve ser QUEUE_EMAIL.');

        String overrideEmail = TaskSlaConfig.getSandboxEmailOverride();
        if (TaskSlaConfig.isSandbox()) {
            System.assertEquals(
                'daniel.belini@enerzee.com.br',
                overrideEmail,
                'Override sandbox deve usar email configurado.'
            );
        } else {
            System.assertEquals(null, overrideEmail, 'Override deve ser nulo fora de sandbox.');
        }
    }

    @IsTest
    static void testUtilsMatchesConfig() {
        User owner = createUser('owner.util@example.com', null);
        Task taskRecord = new Task(
            Subject = 'Teste SLA',
            Status = 'Open',
            Priority = 'High',
            OwnerId = owner.Id
        );

        TaskSlaConfig.NotificationConfig cfg = new TaskSlaConfig.NotificationConfig();
        cfg.ownerType = TaskSlaConfig.OWNER_TYPE_USER;
        cfg.priorityIn = new Set<String>{ TaskSlaUtils.normalizeToken('High') };
        cfg.taskSubtypeIn = new Set<String>();
        cfg.taskTypeIn = new Set<String>();
        cfg.subjectContains = new Set<String>{ TaskSlaUtils.normalizeToken('SLA') };
        cfg.subjectNotContains = new Set<String>();
        cfg.queueDeveloperNames = new Set<String>();

        Boolean matches = TaskSlaUtils.matchesConfig(taskRecord, cfg, new Map<Id, String>());
        System.assertEquals(true, matches, 'Task deve atender o filtro da config.');

        System.assertEquals(true, TaskSlaUtils.isUserOwner(owner.Id), 'Owner deve ser user.');
        System.assertEquals(false, TaskSlaUtils.isQueueOwner(owner.Id), 'Owner nao deve ser queue.');
    }

    @IsTest
    static void testRecipientResolverForUserAndQueue() {
        User manager = createUser('manager.rec@example.com', null);
        User owner = createUser('owner.rec@example.com', manager.Id);

        Group queue = new Group(
            Name = 'Queue Teste',
            DeveloperName = 'Queue_Test',
            Type = 'Queue',
            Email = 'queue@example.com'
        );
        insert queue;
        insert new GroupMember(GroupId = queue.Id, UserOrGroupId = owner.Id);

        Group queueEmailOnly = new Group(
            Name = 'Queue Email',
            DeveloperName = 'Queue_Email',
            Type = 'Queue',
            Email = 'queueonly@example.com'
        );
        insert queueEmailOnly;

        Set<Id> ownerIds = new Set<Id>{ owner.Id, queue.Id, queueEmailOnly.Id };
        TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(ownerIds, true);

        TaskSlaConfig.NotificationConfig cfg = TaskSlaConfig.getNotificationConfig(TaskSlaConfig.TYPE_BEFORE_DUE);
        cfg.notifyOwner = true;
        cfg.notifyManager = true;
        cfg.notifyQueue = true;

        Task userTask = new Task(OwnerId = owner.Id, Subject = 'Task User', Status = 'Open');
        Task queueTask = new Task(OwnerId = queue.Id, Subject = 'Task Queue', Status = 'Open');
        Task queueEmailTask = new Task(OwnerId = queueEmailOnly.Id, Subject = 'Task Queue Email', Status = 'Open');

        TaskSlaRecipientResolver.RecipientResult userRecipients = TaskSlaRecipientResolver.resolveRecipients(
            userTask,
            cfg,
            context
        );
        System.assert(userRecipients.userIds.contains(owner.Id), 'Deve conter o owner.');
        System.assert(userRecipients.userIds.contains(manager.Id), 'Deve conter o manager.');

        TaskSlaRecipientResolver.RecipientResult queueRecipients = TaskSlaRecipientResolver.resolveRecipients(
            queueTask,
            cfg,
            context
        );
        System.assert(queueRecipients.userIds.contains(owner.Id), 'Deve conter membro da fila.');

        TaskSlaRecipientResolver.RecipientResult queueEmailRecipients = TaskSlaRecipientResolver.resolveRecipients(
            queueEmailTask,
            cfg,
            context
        );
        System.assert(
            queueEmailRecipients.emailAddresses.contains('queueonly@example.com'),
            'Deve usar email da fila quando nao ha membros.'
        );
    }

    @IsTest
    static void testSchedulerScheduleDaily() {
        String cron = '0 0 0 1 1 ? 2099';
        Test.startTest();
        TaskSlaDailySummaryScheduler.scheduleDaily(cron);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Task SLA Daily Summary'
                AND CronExpression = :cron
        ];
        System.assert(!jobs.isEmpty(), 'Cron deve ser o informado.');
    }

    private static User createUser(String email, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(System.currentTimeMillis());
        User u = new User(
            Username = 'user.' + unique + '@example.com',
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
