/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class TaskSlaCoreTest {
  @IsTest
  static void testConfigDefaultsAndStatuses() {
    TaskSlaConfig.NotificationConfig beforeCfg = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_BEFORE_DUE
    );
    System.assertNotEquals(null, beforeCfg, 'Config deve existir.');
    System.assertEquals(
      true,
      beforeCfg.enabled,
      'Config before due deve estar habilitada.'
    );
    System.assertEquals(
      30,
      beforeCfg.minutesBeforeDue,
      'Minutos antes do vencimento deve ser 30.'
    );
    System.assertEquals(
      true,
      beforeCfg.notifyManager,
      'Deve notificar gestor.'
    );

    Set<String> closed = TaskSlaConfig.getClosedStatusValues();
    System.assert(
      closed.contains('Completed'),
      'Status Completed deve estar como fechado.'
    );

    TaskSlaConfig.QueueRoutingConfig routing = TaskSlaConfig.getQueueRoutingConfig(
      'DEFAULT'
    );
    System.assertEquals(
      TaskSlaConfig.ROUTE_MEMBERS,
      routing.routingMode,
      'Routing default deve ser MEMBERS.'
    );
    System.assertEquals(
      TaskSlaConfig.ROUTE_QUEUE_EMAIL,
      routing.fallbackMode,
      'Fallback default deve ser QUEUE_EMAIL.'
    );

    String overrideEmail = TaskSlaConfig.getSandboxEmailOverride();
    System.assertEquals(
      null,
      overrideEmail,
      'Override de sandbox deve estar desabilitado.'
    );
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

    Boolean matches = TaskSlaUtils.matchesConfig(
      taskRecord,
      cfg,
      new Map<Id, String>()
    );
    System.assertEquals(true, matches, 'Task deve atender o filtro da config.');

    System.assertEquals(
      true,
      TaskSlaUtils.isUserOwner(owner.Id),
      'Owner deve ser user.'
    );
    System.assertEquals(
      false,
      TaskSlaUtils.isQueueOwner(owner.Id),
      'Owner nao deve ser queue.'
    );
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
    TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(
      ownerIds,
      true
    );

    TaskSlaConfig.NotificationConfig cfg = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_BEFORE_DUE
    );
    cfg.notifyOwner = true;
    cfg.notifyManager = true;
    cfg.notifyQueue = true;

    Task userTask = new Task(
      OwnerId = owner.Id,
      Subject = 'Task User',
      Status = 'Open'
    );
    Task queueTask = new Task(
      OwnerId = queue.Id,
      Subject = 'Task Queue',
      Status = 'Open'
    );
    Task queueEmailTask = new Task(
      OwnerId = queueEmailOnly.Id,
      Subject = 'Task Queue Email',
      Status = 'Open'
    );

    TaskSlaRecipientResolver.RecipientResult userRecipients = TaskSlaRecipientResolver.resolveRecipients(
      userTask,
      cfg,
      context
    );
    System.assert(
      userRecipients.userIds.contains(owner.Id),
      'Deve conter o owner.'
    );
    System.assert(
      userRecipients.userIds.contains(manager.Id),
      'Deve conter o manager.'
    );

    TaskSlaRecipientResolver.RecipientResult queueRecipients = TaskSlaRecipientResolver.resolveRecipients(
      queueTask,
      cfg,
      context
    );
    System.assert(
      queueRecipients.userIds.contains(owner.Id),
      'Deve conter membro da fila.'
    );

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
    String updatedCron = '0 15 1 1 1 ? 2099';
    Test.startTest();
    TaskSlaDailySummaryScheduler.scheduleDaily(cron);
    TaskSlaDailySummaryScheduler.scheduleDaily(updatedCron);
    Test.stopTest();

    List<CronTrigger> jobs = [
      SELECT CronExpression, CronJobDetail.Name, State
      FROM CronTrigger
      WHERE CronJobDetail.Name = 'Task SLA Daily Summary' AND State != 'DELETED'
    ];
    System.assertEquals(
      1,
      jobs.size(),
      'Deve existir apenas um agendamento ativo.'
    );
    System.assertEquals(
      updatedCron,
      jobs[0].CronExpression,
      'O agendamento mais recente deve substituir o anterior.'
    );
  }

  @IsTest
  static void testAdditionalUtilityAndConfigBranches() {
    TaskSlaConfig.NotificationConfig afterCfg = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_AFTER_DUE
    );
    System.assertEquals(true, afterCfg.enabled, 'After due deve estar ativo.');
    System.assertEquals(
      false,
      afterCfg.notifyManager,
      'After due não deve notificar gestor por padrão.'
    );

    TaskSlaConfig.NotificationConfig ownerTypeCfg = new TaskSlaConfig.NotificationConfig();
    ownerTypeCfg.ownerType = TaskSlaConfig.OWNER_TYPE_USER;
    System.assertEquals(
      true,
      ownerTypeCfg.isOwnerTypeUser(),
      'Owner type USER deve ser reconhecido.'
    );
    ownerTypeCfg.ownerType = TaskSlaConfig.OWNER_TYPE_QUEUE;
    System.assertEquals(
      true,
      ownerTypeCfg.isOwnerTypeQueue(),
      'Owner type QUEUE deve ser reconhecido.'
    );

    System.assertEquals(
      true,
      TaskSlaUtils.isClosedOrCanceled('Canceled'),
      'Canceled deve ser tratado como encerrado/cancelado.'
    );
    System.assertEquals(
      false,
      TaskSlaUtils.isClosedOrCanceled(null),
      'Valor nulo não pode ser tratado como encerrado.'
    );
    System.assertEquals(
      '&lt;teste&gt; &amp; &quot;ok&quot;',
      TaskSlaUtils.escapeHtml('<teste> & "ok"'),
      'escapeHtml deve proteger caracteres especiais.'
    );

    User owner = createUser('owner.filter@example.com', null);
    Task queueTask = new Task(
      OwnerId = owner.Id,
      Subject = 'Sem match',
      Status = 'Open',
      Priority = 'Low'
    );
    TaskSlaConfig.NotificationConfig filterCfg = new TaskSlaConfig.NotificationConfig();
    filterCfg.ownerType = TaskSlaConfig.OWNER_TYPE_QUEUE;
    filterCfg.priorityIn = new Set<String>{
      TaskSlaUtils.normalizeToken('High')
    };
    filterCfg.subjectContains = new Set<String>{
      TaskSlaUtils.normalizeToken('SLA')
    };
    filterCfg.subjectNotContains = new Set<String>{
      TaskSlaUtils.normalizeToken('bloqueado')
    };
    filterCfg.taskSubtypeIn = new Set<String>();
    filterCfg.taskTypeIn = new Set<String>();
    filterCfg.queueDeveloperNames = new Set<String>{ 'queue_x' };

    System.assertEquals(
      false,
      TaskSlaUtils.matchesConfig(queueTask, filterCfg, new Map<Id, String>()),
      'Task fora dos filtros não deve casar com a configuração.'
    );

    TaskSlaConfig.QueueRoutingConfig unknownRouting = TaskSlaConfig.getQueueRoutingConfig(
      'UNKNOWN_QUEUE'
    );
    System.assertEquals(
      TaskSlaConfig.ROUTE_MEMBERS,
      unknownRouting.routingMode,
      'Fila sem configuração deve herdar o roteamento default.'
    );

    Test.startTest();
    TaskSlaDailySummaryScheduler.scheduleDaily(null);
    Test.stopTest();
  }

  @IsTest
  static void testUtilsAndResolverGuardClauses() {
    TaskSlaRecipientResolver.Context emptyContext = TaskSlaRecipientResolver.buildContext(
      null,
      true
    );
    System.assertEquals(
      0,
      emptyContext.ownersById.size(),
      'Contexto vazio não deve carregar owners.'
    );

    Group queue = new Group(
      Name = 'Queue Guard',
      DeveloperName = 'Queue_Guard',
      Type = 'Queue',
      Email = 'queue.guard@example.com'
    );
    insert queue;

    Task queueTask = new Task(
      OwnerId = queue.Id,
      Subject = 'Fila SLA Guard',
      Status = 'Open',
      Priority = 'High'
    );

    TaskSlaConfig.NotificationConfig cfg = new TaskSlaConfig.NotificationConfig();
    cfg.ownerType = TaskSlaConfig.OWNER_TYPE_QUEUE;
    cfg.priorityIn = new Set<String>{ TaskSlaUtils.normalizeToken('High') };
    cfg.taskSubtypeIn = new Set<String>();
    cfg.taskTypeIn = new Set<String>();
    cfg.subjectContains = new Set<String>{ TaskSlaUtils.normalizeToken('SLA') };
    cfg.subjectNotContains = new Set<String>{
      TaskSlaUtils.normalizeToken('bloqueado')
    };
    cfg.queueDeveloperNames = new Set<String>{
      TaskSlaUtils.normalizeToken(queue.DeveloperName)
    };

    System.assertEquals(
      true,
      TaskSlaUtils.matchesConfig(
        queueTask,
        cfg,
        new Map<Id, String>{ queue.Id => queue.DeveloperName }
      ),
      'Fila com developer name mapeado deve casar com a configuração.'
    );
    System.assertEquals(
      false,
      TaskSlaUtils.matchesConfig(queueTask, cfg, null),
      'Sem mapa de filas o filtro da fila deve falhar.'
    );

    TaskSlaRecipientResolver.RecipientResult emptyRecipients = TaskSlaRecipientResolver.resolveRecipients(
      null,
      cfg,
      new TaskSlaRecipientResolver.Context()
    );
    System.assertEquals(
      0,
      emptyRecipients.userIds.size(),
      'Fluxo nulo não deve adicionar usuários.'
    );
    System.assertEquals(
      0,
      emptyRecipients.emailAddresses.size(),
      'Fluxo nulo não deve adicionar emails.'
    );

    System.assertEquals('', TaskSlaUtils.normalizeToken(null));
    System.assertEquals('', TaskSlaUtils.escapeHtml(null));
  }

  private static User createUser(String email, Id managerId) {
    return createUser(email, managerId, null);
  }

  private static User createUser(String email, Id managerId, Id roleId) {
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
      LanguageLocaleKey = 'pt_BR',
      UserRoleId = roleId
    );
    insert u;
    if (managerId != null) {
      u.ManagerId = managerId;
      update u;
    }
    return u;
  }

  @IsTest
  static void testRecipientResolverLoadsNestedGroupAndRoleMembers() {
    User roleUser = createUser('role.member@example.com', null);

    Group queue = new Group(
      Name = 'Queue Nested Members',
      DeveloperName = 'Queue_Nested_Members',
      Type = 'Queue',
      Email = 'nested.queue@example.com'
    );
    insert queue;

    Group publicGroup = new Group(
      Name = 'Public Group Nested',
      DeveloperName = 'Public_Group_Nested',
      Type = 'Regular'
    );
    insert publicGroup;

    insert new GroupMember(GroupId = queue.Id, UserOrGroupId = publicGroup.Id);
    insert new GroupMember(
      GroupId = publicGroup.Id,
      UserOrGroupId = roleUser.Id
    );

    TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(
      new Set<Id>{ queue.Id },
      true
    );

    System.assert(
      context.queueMembersById.containsKey(queue.Id),
      'A fila deve carregar membros calculados.'
    );
    System.assert(
      context.queueMembersById.get(queue.Id).contains(roleUser.Id),
      'Usuário vindo de grupo público e papel deve ser expandido para a fila.'
    );
  }
}
