/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-03-2026
 * @last modified by  : Daniel Belini
 **/
@IsTest
private class OpportunityBOPaymentReminderTaskTest {
  private static User createUser(String email, String aliasPrefix) {
    Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()]
    .ProfileId;
    String unique =
      String.valueOf(System.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));

    User usr = new User(
      Alias = (aliasPrefix + unique).substring(0, 8),
      Email = email,
      Username = 'user.' + unique + '@enerzee.test',
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

  private static Group createTaskQueue(String developerName, String name) {
    Group queueRecord = new Group(
      Name = name,
      DeveloperName = developerName,
      Type = 'Queue'
    );
    insert queueRecord;
    insert new QueueSobject(QueueId = queueRecord.Id, SobjectType = 'Task');
    return queueRecord;
  }

  private static Opportunity createOpportunity(Id ownerId, String nameSuffix) {
    Account acc = (Account) TestFactory.createSObject(
      new Account(Name = 'Conta Pagamento ' + nameSuffix),
      true
    );

    return (Opportunity) TestFactory.createSObject(
      new Opportunity(
        Name = 'Opp Pagamento ' + nameSuffix,
        AccountId = acc.Id,
        OwnerId = ownerId,
        StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA
      ),
      true
    );
  }

  private static Opportunity buildUpdatedOpportunity(
    Opportunity oldOpp,
    String newSubStatus
  ) {
    Opportunity newOpp = oldOpp.clone(true, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_NEGOCIACAO;
    newOpp.Status__c = newSubStatus;
    return newOpp;
  }

  @IsTest
  static void shouldKeepContractBranchOwnerUnchanged() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createUser('owner.contract@test.com', 'ownc');
    User contractUser = createUser('contrato@enerzee.com.br.test', 'contu');

    Opportunity oldOpp = createOpportunity(owner.Id, 'Contract');
    Opportunity newOpp = buildUpdatedOpportunity(
      oldOpp,
      OpportunityUtils.SUB_STATUS_CONTRATO_ENVIADO
    );

    String queueDevName =
      'FINANCEIRO_TST_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    createTaskQueue(queueDevName, 'Financeiro Teste Queue Contract');
    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = queueDevName;
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.finance.user.contract@test.com';

    Test.startTest();
    OpportunityBO.createRequiredFieldsReminderTasks(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Task contractTask = [
      SELECT Id, OwnerId
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject LIKE 'É necessário anexar o contrato Assinado referente a oportunidade%'
      LIMIT 1
    ];

    List<User> contractOwners = [
      SELECT Id
      FROM User
      WHERE Email LIKE 'contrato@enerzee.com.br%' AND IsActive = TRUE
      LIMIT 1
    ];
    Id expectedContractOwner = !contractOwners.isEmpty()
      ? contractOwners[0].Id
      : owner.Id;
    System.assertEquals(
      expectedContractOwner,
      contractTask.OwnerId,
      'O ramo de contrato deve manter owner de contrato e não usar owner de pagamento.'
    );
  }

  @IsTest
  static void shouldNotChangeExistingOpenPaymentTask() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    User owner = createUser('owner.existing.payment@test.com', 'owne');
    User existingTaskOwner = createUser('existing.task.owner@test.com', 'exto');
    Opportunity oldOpp = createOpportunity(owner.Id, 'ExistingTask');
    Opportunity newOpp = buildUpdatedOpportunity(
      oldOpp,
      OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO
    );

    Task existingTask = new Task(
      WhatId = oldOpp.Id,
      Subject = 'É necessário	 confirmar o pagamento da oportunidade ' +
        oldOpp.Name,
      Status = TaskUtils.STATUS_NAO_INICIADO,
      OwnerId = existingTaskOwner.Id,
      ActivityDate = Date.today()
    );
    insert existingTask;

    OpportunityBO.PAYMENT_REMINDER_FINANCE_QUEUE_DEVELOPER_NAME = 'QUEUE_NOT_FOUND_FOR_TEST_3';
    OpportunityBO.PAYMENT_REMINDER_FINANCE_USER_EMAIL_LIKE = 'missing.finance.user.existing@test.com';

    Test.startTest();
    OpportunityBO.createRequiredFieldsReminderTasks(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    List<Task> paymentTasks = [
      SELECT Id, OwnerId
      FROM Task
      WHERE
        WhatId = :oldOpp.Id
        AND Subject = :existingTask.Subject
        AND IsDeleted = FALSE
    ];

    System.assert(
      paymentTasks.size() >= 1,
      'A task pré-existente de pagamento deve permanecer disponível.'
    );
    Map<Id, Task> tasksById = new Map<Id, Task>(paymentTasks);
    System.assert(
      tasksById.containsKey(existingTask.Id),
      'A task de pagamento criada no setup precisa continuar existindo.'
    );
    System.assertEquals(
      existingTaskOwner.Id,
      tasksById.get(existingTask.Id).OwnerId,
      'A task existente não deve ser reatribuída.'
    );
  }
}
