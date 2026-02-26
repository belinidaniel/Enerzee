@IsTest
private class TaskSlaNotificationServiceEmailLimitTest {
  @IsTest
  static void sendEmailsInChunksCapsAtPlatformInvocationLimit() {
    List<Messaging.SingleEmailMessage> messages = buildMessages(105);

    Test.startTest();
    Integer beforeInvocations = Limits.getEmailInvocations();
    TaskSlaNotificationService.sendEmailsInChunks(messages);
    Integer usedInvocations = Limits.getEmailInvocations() - beforeInvocations;
    Test.stopTest();

    System.assertEquals(
      10,
      usedInvocations,
      'Deve respeitar o limite maximo de 10 invocacoes de sendEmail por transacao.'
    );
  }

  @IsTest
  static void processDeadlineNotificationsSkipsWhenNoEmailCapacity() {
    Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
    if (
      !taskFields.containsKey('HoraVencimento__c') ||
      !taskFields.containsKey('NotificadoAntesVencer__c')
    ) {
      return;
    }

    User manager = createUser('manager+capacity@example.com', null);
    User owner = createUser('owner+capacity@example.com', manager.Id);

    DateTime soon = System.now().addMinutes(10);
    Time dueTime = Time.newInstance(
      soon.hour(),
      soon.minute(),
      soon.second(),
      soon.millisecond()
    );

    Task taskRecord = new Task(
      Subject = 'Task SLA Test - Capacity',
      Status = 'Open',
      ActivityDate = soon.date(),
      OwnerId = owner.Id
    );
    taskRecord.put('HoraVencimento__c', dueTime);
    taskRecord.put('NotificadoAntesVencer__c', false);
    insert taskRecord;

    Test.startTest();
    TaskSlaNotificationService.sendEmailsInChunks(buildMessages(100));
    TaskSlaNotificationService.processDeadlineNotifications(
      new List<Task>{ taskRecord }
    );
    Test.stopTest();

    Task refreshed = [
      SELECT Id, NotificadoAntesVencer__c
      FROM Task
      WHERE Id = :taskRecord.Id
    ];
    System.assertEquals(
      false,
      refreshed.NotificadoAntesVencer__c,
      'Nao deve marcar tarefa como notificada quando nao houver capacidade de e-mail.'
    );

    Integer logCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :taskRecord.Id
        AND Type__c = :TaskSlaConfig.TYPE_BEFORE_DUE
    ];
    System.assertEquals(
      0,
      logCount,
      'Nao deve criar log quando notificacao for bloqueada por capacidade.'
    );
  }

  @IsTest
  static void sendEmailsInChunksSkipsWhenInvocationCapacityIsExhausted() {
    Test.startTest();
    TaskSlaNotificationService.sendEmailsInChunks(buildMessages(100));
    Integer beforeInvocations = Limits.getEmailInvocations();
    TaskSlaNotificationService.sendEmailsInChunks(buildMessages(1));
    Integer afterInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.assertEquals(
      beforeInvocations,
      afterInvocations,
      'Nao deve tentar novo sendEmail quando a capacidade de invocacao estiver esgotada.'
    );
  }

  @IsTest
  static void helperMethodsCoverEdgeCases() {
    TaskSlaNotificationService.processDeadlineNotifications(null);
    TaskSlaNotificationService.processDeadlineNotifications(new List<Task>());

    TaskSlaRecipientResolver.RecipientResult recipients = new TaskSlaRecipientResolver.RecipientResult();
    recipients.userIds.add(UserInfo.getUserId());
    recipients.emailAddresses.add('sample@example.com');

    Integer calculated = TaskSlaNotificationService.estimateEmailMessagesForRecipients(
      recipients,
      null
    );
    Integer overrideCalculated = TaskSlaNotificationService.estimateEmailMessagesForRecipients(
      recipients,
      'override@example.com'
    );
    Integer nullCalculated = TaskSlaNotificationService.estimateEmailMessagesForRecipients(
      null,
      null
    );

    System.assertEquals(
      2,
      calculated,
      'Deve contar userId e email separados quando sem override.'
    );
    System.assertEquals(
      1,
      overrideCalculated,
      'Com override deve existir somente uma mensagem.'
    );
    System.assertEquals(
      0,
      nullCalculated,
      'Sem destinatarios deve retornar zero.'
    );
    System.assert(
      TaskSlaNotificationService.getRemainingEmailMessageCapacity() >= 0
    );

    TaskSlaNotificationService.sendEmailsInChunks(
      new List<Messaging.SingleEmailMessage>()
    );
    TaskSlaNotificationService.applySystemSender(
      new Messaging.SingleEmailMessage()
    );
  }

  @IsTest
  static void processDeadlineNotificationsHandlesAfterDuePath() {
    Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
    if (
      !taskFields.containsKey('HoraVencimento__c') ||
      !taskFields.containsKey('NotificadoAposVencer__c')
    ) {
      return;
    }

    User manager = createUser('manager+after@example.com', null);
    User owner = createUser('owner+after@example.com', manager.Id);

    DateTime pastDue = System.now().addMinutes(-20);
    Time dueTime = Time.newInstance(
      pastDue.hour(),
      pastDue.minute(),
      pastDue.second(),
      pastDue.millisecond()
    );

    Task taskRecord = new Task(
      Subject = 'Task SLA Test - After Due',
      Status = 'Open',
      ActivityDate = pastDue.date(),
      OwnerId = owner.Id
    );
    taskRecord.put('HoraVencimento__c', dueTime);
    if (taskFields.containsKey('NotificadoAntesVencer__c')) {
      taskRecord.put('NotificadoAntesVencer__c', true);
    }
    taskRecord.put('NotificadoAposVencer__c', false);
    insert taskRecord;

    Test.startTest();
    TaskSlaNotificationService.processDeadlineNotifications(
      new List<Task>{ taskRecord }
    );
    Test.stopTest();

    Task refreshed = [
      SELECT Id, NotificadoAposVencer__c
      FROM Task
      WHERE Id = :taskRecord.Id
    ];
    System.assertEquals(
      true,
      refreshed.NotificadoAposVencer__c,
      'Deve marcar notificacao apos vencimento.'
    );

    Integer afterLogCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        RelatedId__c = :taskRecord.Id
        AND Type__c = :TaskSlaConfig.TYPE_AFTER_DUE
    ];
    System.assert(
      afterLogCount > 0,
      'Deve registrar log de notificacao apos vencimento.'
    );
  }

  private static User createUser(String email, Id managerId) {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique = String.valueOf(System.currentTimeMillis());
    User userRecord = new User(
      Username = 'user+' + unique + '@example.com',
      Email = email,
      Alias = email.substring(0, 5),
      LastName = 'Tester',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      ProfileId = profileRecord.Id,
      LanguageLocaleKey = 'pt_BR'
    );
    insert userRecord;
    if (managerId != null) {
      userRecord.ManagerId = managerId;
      update userRecord;
    }
    return userRecord;
  }

  private static List<Messaging.SingleEmailMessage> buildMessages(
    Integer total
  ) {
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    for (Integer i = 0; i < total; i++) {
      Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
      message.setToAddresses(
        new List<String>{ 'sla-limit-test+' + i + '@example.com' }
      );
      message.setSubject('SLA Limit Test ' + i);
      message.setPlainTextBody('Body ' + i);
      message.setSaveAsActivity(false);
      messages.add(message);
    }
    return messages;
  }
}
