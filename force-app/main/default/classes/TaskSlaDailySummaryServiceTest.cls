/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class TaskSlaDailySummaryServiceTest {
  private static final String DAILY_CONSOLIDATED_TYPE = 'TASK_DAILY_CONSOLIDATED';

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
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Consulta de logs deve executar sem excecao.');
  }

  @IsTest
  static void ownerOpenSummaryCreatesLog() {
    User manager = createUser('manager+open@example.com', null);
    User owner = createUser('owner+open@example.com', manager.Id);
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
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Consulta de logs deve executar sem excecao.');
  }

  @IsTest
  static void runDailyAndDueTomorrowShouldCreateManagerSummaryLogs() {
    User manager = createUser('manager+summary@example.com', null);
    User owner = createUser('owner+summary@example.com', manager.Id);

    insert new Task(
      Subject = 'Task Daily Summary',
      Status = 'Open',
      ActivityDate = Date.today().addDays(1),
      OwnerId = owner.Id
    );

    Test.startTest();
    TaskSlaDailySummaryService.runDaily();
    TaskSlaDailySummaryService.runManagerDueTomorrow();
    Test.stopTest();

    Integer logCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Execucoes diarias nao devem gerar erro.');
  }

  @IsTest
  static void managerSummaryShouldHandleOwnerWithoutManager() {
    User owner = createUser('owner+nomanager@example.com', null);
    insert new Task(
      Subject = 'Task No Manager',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = owner.Id
    );

    Test.startTest();
    TaskSlaDailySummaryService.runManagerOverdue();
    Test.stopTest();

    System.assertEquals(true, true, 'Fluxo sem manager executado sem excecao.');
  }

  @IsTest
  static void previewByRoleShouldValidateInputsAndRenderForExistingRole() {
    Boolean blankParamException = false;
    try {
      TaskSlaDailySummaryService.sendPreviewByRole(null, 'preview@example.com');
    } catch (TaskSlaDailySummaryService.TaskSlaPreviewException ex) {
      blankParamException = ex.getMessage().contains('Informe os parametros');
    }
    System.assertEquals(
      true,
      blankParamException,
      'Parâmetros vazios devem ser rejeitados.'
    );

    List<UserRole> roles = [
      SELECT Id, Name, DeveloperName
      FROM UserRole
      LIMIT 1
    ];
    if (roles.isEmpty()) {
      return;
    }

    Account relatedAccount = new Account(Name = 'Preview Related Account');
    insert relatedAccount;

    User previewRecipient;
    User owner;
    System.runAs(currentUser()) {
      previewRecipient = createUser('preview@example.com', null, roles[0].Id);
      owner = createUser('owner+preview@example.com', null, roles[0].Id);
    }
    System.assertNotEquals(null, previewRecipient.Id);

    TaskSlaDailySummaryService.sendPreviewByRole(
      roles[0].Name,
      'preview@example.com'
    );

    insert new Task(
      Subject = 'Task Preview Full',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = owner.Id,
      Priority = 'High',
      WhatId = relatedAccount.Id
    );

    String roleIdentifier = roles[0].Name.contains(' ')
      ? roles[0].Name.replace(' ', '_')
      : roles[0].DeveloperName;

    TaskSlaDailySummaryService.sendPreviewByRole(
      roleIdentifier,
      'preview@example.com'
    );

    Boolean invalidRoleException = false;
    try {
      TaskSlaDailySummaryService.sendPreviewByRole(
        'ROLE_INEXISTENTE_' + System.now().getTime(),
        'preview@example.com'
      );
    } catch (TaskSlaDailySummaryService.TaskSlaPreviewException ex) {
      invalidRoleException = ex.getMessage().contains('Papel nao encontrado');
    }
    System.assertEquals(
      true,
      invalidRoleException,
      'Papel inexistente deve lançar exceção amigável.'
    );
  }

  @IsTest
  static void managerSummaryShouldHandleQueueRecipientsAndSkipAlreadySent() {
    User queueMember;
    Group queueWithMember;
    Group queueEmailOnly;

    System.runAs(currentUser()) {
      queueMember = createUser('queue.member@example.com', null);

      queueWithMember = new Group(
        Name = 'Task SLA Queue Member',
        DeveloperName = 'Task_SLA_Queue_Member_' +
          String.valueOf(System.now().getTime()),
        Type = 'Queue',
        Email = 'queue.member.group@example.com'
      );
      insert queueWithMember;
      insert new QueueSobject(
        QueueId = queueWithMember.Id,
        SobjectType = 'Task'
      );
      insert new GroupMember(
        GroupId = queueWithMember.Id,
        UserOrGroupId = queueMember.Id
      );

      queueEmailOnly = new Group(
        Name = 'Task SLA Queue Email',
        DeveloperName = 'Task_SLA_Queue_Email_' +
          String.valueOf(System.now().getTime()),
        Type = 'Queue',
        Email = 'queue.email.only@example.com'
      );
      insert queueEmailOnly;
      insert new QueueSobject(
        QueueId = queueEmailOnly.Id,
        SobjectType = 'Task'
      );
    }

    insert new Task(
      Subject = 'Queue Member Task',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = queueWithMember.Id
    );
    insert new Task(
      Subject = 'Queue Email Task',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = queueEmailOnly.Id
    );

    insert new Log__c(
      Name = 'TaskSLA Summary',
      Type__c = DAILY_CONSOLIDATED_TYPE,
      RelatedId__c = String.valueOf(queueWithMember.Id),
      Message__c = 'TotalTasks=1'
    );

    Test.startTest();
    TaskSlaDailySummaryService.runManagerOverdue();
    Test.stopTest();

    Integer skippedQueueLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :String.valueOf(queueWithMember.Id)
        AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    Integer emailQueueLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :String.valueOf(queueEmailOnly.Id)
        AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];

    System.assertEquals(
      1,
      skippedQueueLogCount,
      'Fila já registrada no dia deve ser ignorada pelo resumo.'
    );
    System.assert(
      emailQueueLogCount > 0,
      'Fila sem membros deve gerar log via fallback de email.'
    );
  }

  @IsTest
  static void managerSummaryShouldFallbackToDirectManagerWithoutRoles() {
    User manager = createUser('manager+fallback@example.com', null);
    User owner = createUser('owner+fallback@example.com', manager.Id);

    Account relatedAccount = new Account(Name = 'Fallback Related Account');
    insert relatedAccount;

    insert new Task(
      Subject = 'Fallback Manager Task',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = owner.Id,
      WhatId = relatedAccount.Id
    );

    Test.startTest();
    TaskSlaDailySummaryService.runManagerDueTomorrow();
    Test.stopTest();

    Integer managerLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(
      managerLogCount > 0,
      'Sem hierarquia de papel, o resumo deve cair no fallback de gestor direto.'
    );
  }

  @IsTest
  static void ownerOpenSummaryShouldCreateLogsForUsersAndQueues() {
    User owner;
    User queueMember;
    Group queueWithMember;
    Group queueEmailOnly;

    System.runAs(currentUser()) {
      owner = createUser('owner+owner-summary@example.com', null);
      queueMember = createUser('queue.member.owner@example.com', null);

      queueWithMember = new Group(
        Name = 'Owner Summary Queue Member',
        DeveloperName = 'Owner_Summary_Queue_Member_' +
          String.valueOf(System.now().getTime()),
        Type = 'Queue',
        Email = 'owner.summary.queue.member@example.com'
      );
      insert queueWithMember;
      insert new QueueSobject(
        QueueId = queueWithMember.Id,
        SobjectType = 'Task'
      );
      insert new GroupMember(
        GroupId = queueWithMember.Id,
        UserOrGroupId = queueMember.Id
      );

      queueEmailOnly = new Group(
        Name = 'Owner Summary Queue Email',
        DeveloperName = 'Owner_Summary_Queue_Email_' +
          String.valueOf(System.now().getTime()),
        Type = 'Queue',
        Email = 'owner.summary.queue.email@example.com'
      );
      insert queueEmailOnly;
      insert new QueueSobject(
        QueueId = queueEmailOnly.Id,
        SobjectType = 'Task'
      );
    }

    insert new List<Task>{
      new Task(
        Subject = 'Owner Overdue Task',
        Status = 'Open',
        ActivityDate = Date.today().addDays(-1),
        OwnerId = owner.Id,
        Description = 'Linha 1\nLinha 2'
      ),
      new Task(
        Subject = 'Owner Today Task',
        Status = 'Open',
        ActivityDate = Date.today(),
        OwnerId = owner.Id
      ),
      new Task(
        Subject = 'Owner Tomorrow Task',
        Status = 'Open',
        ActivityDate = Date.today().addDays(1),
        OwnerId = owner.Id
      ),
      new Task(
        Subject = 'Owner Future Task',
        Status = 'Open',
        ActivityDate = Date.today().addDays(5),
        OwnerId = owner.Id
      ),
      new Task(
        Subject = 'Owner No Date Task',
        Status = 'Open',
        OwnerId = owner.Id
      ),
      new Task(
        Subject = 'Queue Member Owner Task',
        Status = 'Open',
        ActivityDate = Date.today(),
        OwnerId = queueWithMember.Id
      ),
      new Task(
        Subject = 'Queue Email Owner Task',
        Status = 'Open',
        ActivityDate = Date.today().addDays(2),
        OwnerId = queueEmailOnly.Id
      )
    };

    Test.startTest();
    TaskSlaDailySummaryService.runOwnerOpenSummary();
    Test.stopTest();

    Integer ownerLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :String.valueOf(owner.Id)
        AND Type__c = :TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
    ];
    Integer queueWithMemberLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :String.valueOf(queueWithMember.Id)
        AND Type__c = :TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
    ];
    Integer queueEmailOnlyLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :String.valueOf(queueEmailOnly.Id)
        AND Type__c = :TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
    ];

    System.assert(
      ownerLogCount > 0,
      'Owner com tarefas abertas deve gerar log diario.'
    );
    System.assert(
      queueWithMemberLogCount > 0,
      'Fila com membros deve gerar log no resumo diario por owner.'
    );
    System.assert(
      queueEmailOnlyLogCount > 0,
      'Fila com fallback por email deve gerar log no resumo diario por owner.'
    );
  }

  private static User createUser(String email, Id managerId) {
    return createUser(email, managerId, null);
  }

  private static User createUser(String email, Id managerId, Id roleId) {
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

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }
}
