/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-25-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityBOPaymentConfirmationTaskTest {
  private static User createTestUser(String emailPrefix) {
    Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()]
    .ProfileId;
    String unique =
      String.valueOf(System.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
    User usr = new User(
      Alias = (emailPrefix + unique).left(8),
      Email = emailPrefix + '@enerzee.test',
      Username = emailPrefix + '.' + unique + '@enerzee.test',
      LastName = 'Test User',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profileId
    );
    insert usr;
    return usr;
  }

  private static Group createQueue(String devName, String queueName) {
    Group q = new Group(
      Name = queueName,
      DeveloperName = devName,
      Type = 'Queue'
    );
    insert q;
    insert new QueueSobject(QueueId = q.Id, SobjectType = 'Task');
    return q;
  }

  private static Opportunity createOpportunity(Id ownerId, String stage) {
    Account acc = (Account) TestFactory.createSObject(
      new Account(Name = 'Conta PC Test ' + stage),
      true
    );
    return (Opportunity) TestFactory.createSObject(
      new Opportunity(
        Name = 'Opp PC Test ' + stage,
        AccountId = acc.Id,
        OwnerId = ownerId,
        StageName = stage
      ),
      true
    );
  }

  // Happy path: Task criada ao entrar na fase "Confirmação de Pagamento"
  @IsTest
  static void shouldCreateTaskOnEnterPaymentConfirmationStage() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createTestUser('pc.owner');
    String queueDevName =
      'FIN_PC_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    createQueue(queueDevName, 'Financeiro PC Test');

    Opportunity oldOpp = createOpportunity(
      owner.Id,
      OpportunityUtils.STATUS_PROPOSTA_GERADA
    );
    Opportunity newOpp = oldOpp.clone(true, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO;

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = queueDevName;
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.user.pc@enerzee.test';

    Test.startTest();
    OpportunityBO.createPaymentConfirmationTask(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    List<Task> tasks = [
      SELECT Id, Subject, OwnerId
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject = :TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO
    ];
    Assert.areEqual(
      1,
      tasks.size(),
      'Uma Task deve ser criada ao entrar na fase Confirmação de Pagamento.'
    );
  }

  // Dedup (REQ-002): não criar nova Task se já existe uma aberta com o mesmo assunto
  @IsTest
  static void shouldNotCreateDuplicateTaskWhenOpenTaskAlreadyExists() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createTestUser('pc.dedup');
    Opportunity oldOpp = createOpportunity(
      owner.Id,
      OpportunityUtils.STATUS_PROPOSTA_GERADA
    );
    Opportunity newOpp = oldOpp.clone(true, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO;

    insert new Task(
      WhatId = oldOpp.Id,
      Subject = TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO,
      Status = TaskUtils.STATUS_NAO_INICIADO,
      OwnerId = owner.Id,
      ActivityDate = Date.today()
    );

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = 'QUEUE_NOT_FOUND_PC_DEDUP';
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.user.dedup@enerzee.test';

    Test.startTest();
    OpportunityBO.createPaymentConfirmationTask(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject = :TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO
        AND IsDeleted = FALSE
    ];
    Assert.areEqual(
      1,
      count,
      'Não deve criar Task duplicada quando já existe uma aberta.'
    );
  }

  // Cenário negativo: mudança de fase para valor diferente de "Confirmação de Pagamento"
  @IsTest
  static void shouldNotCreateTaskWhenStageChangesToOtherValue() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createTestUser('pc.negative');
    Opportunity oldOpp = createOpportunity(
      owner.Id,
      OpportunityUtils.STATUS_PROPOSTA_GERADA
    );
    Opportunity newOpp = oldOpp.clone(true, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_NEGOCIACAO;

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = 'QUEUE_NOT_FOUND_PC_NEG';
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.user.neg@enerzee.test';

    Test.startTest();
    OpportunityBO.createPaymentConfirmationTask(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject = :TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO
    ];
    Assert.areEqual(
      0,
      count,
      'Nenhuma Task deve ser criada para outras mudanças de fase.'
    );
  }

  // Bulk: 200 registros entrando na fase simultaneamente
  @IsTest
  static void shouldBulkify200Records() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createTestUser('pc.bulk');
    String queueDevName =
      'FIN_BULK_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    createQueue(queueDevName, 'Financeiro Bulk Test');

    Account acc = (Account) TestFactory.createSObject(
      new Account(Name = 'Bulk Account PC'),
      true
    );

    List<Opportunity> oldOpps = new List<Opportunity>();
    for (Integer i = 0; i < 200; i++) {
      oldOpps.add(
        new Opportunity(
          Name = 'Bulk Opp PC ' + i,
          AccountId = acc.Id,
          OwnerId = owner.Id,
          StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA,
          CloseDate = Date.today().addDays(30)
        )
      );
    }
    insert oldOpps;

    List<Opportunity> newOpps = new List<Opportunity>();
    Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
    for (Opportunity opp : oldOpps) {
      Opportunity newOpp = opp.clone(true, true, true, true);
      newOpp.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO;
      newOpps.add(newOpp);
      oldMap.put(opp.Id, opp);
    }

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = queueDevName;
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.user.bulk@enerzee.test';

    Test.startTest();
    OpportunityBO.createPaymentConfirmationTask(newOpps, oldMap);
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId IN :oldMap.keySet()
        AND Subject = :TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO
    ];
    Assert.areEqual(200, count, '200 Tasks devem ser criadas em bulk.');
  }

  // Task atribuída à fila financeiro quando ela existe
  @IsTest
  static void shouldAssignTaskToFinanceQueue() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createTestUser('pc.queue.owner');
    String queueDevName =
      'FIN_ASSIGN_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    Group financeQueue = createQueue(queueDevName, 'Financeiro Assign Test');

    Opportunity oldOpp = createOpportunity(
      owner.Id,
      OpportunityUtils.STATUS_PROPOSTA_GERADA
    );
    Opportunity newOpp = oldOpp.clone(true, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO;

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = queueDevName;
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.user.assign@enerzee.test';

    Test.startTest();
    OpportunityBO.createPaymentConfirmationTask(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Task t = [
      SELECT OwnerId
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject = :TaskUtils.SUBJECT_CONFIRMACAO_PAGAMENTO
      LIMIT 1
    ];
    Assert.areEqual(
      financeQueue.Id,
      t.OwnerId,
      'A Task deve ser atribuída à fila financeiro.'
    );
  }
}
