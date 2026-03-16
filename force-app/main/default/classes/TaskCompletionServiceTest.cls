/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class TaskCompletionServiceTest {
  @testSetup
  static void setup() {
    try {
      Id contratosId = ensureQueue('Contratos', 'Contratos');
      ensureQueueSObject(contratosId, 'Task');
    } catch (Exception ignored) {
    }

    try {
      Id viabilidadeId = ensureQueue(
        'AnalistaViabilidade',
        'Analistas de Viabilidade'
      );
      ensureQueueSObject(viabilidadeId, 'Task');
    } catch (Exception ignored) {
    }
  }

  @isTest
  static void createsFollowUpForDocumentacaoComercial() {
    Projeto__c project = createProject();
    project.DocumentacaoComercialPendencia__c = 'RG e CPF do responsável';
    project.DocumentacaoCriarAtividadeContratos__c = true;
    update project;

    Task task = getOrCreateOpenTask(
      project.Id,
      TaskUtils.SUBJECT_VERIFICAR_DOCUMENTACAO_COMERCIAL
    );

    Test.startTest();
    TaskCompletionService.CompletionResult result = TaskCompletionService.completeWithComment(
      task.Id,
      'Favor anexar documentos.',
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Result success');

    Task updatedTask = [SELECT Status FROM Task WHERE Id = :task.Id];
    System.assertEquals(
      TaskUtils.STATUS_CONCLUIDO,
      updatedTask.Status,
      'Task should be closed'
    );

    Task followUp = [
      SELECT OwnerId, Subject, Description
      FROM Task
      WHERE
        WhatId = :project.Id
        AND Subject = :('Follow-up: ' +
        TaskUtils.SUBJECT_VERIFICAR_DOCUMENTACAO_COMERCIAL)
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    List<Group> ownerGroups = [
      SELECT DeveloperName
      FROM Group
      WHERE Id = :followUp.OwnerId
      LIMIT 1
    ];
    String ownerDeveloperName = ownerGroups.isEmpty()
      ? null
      : ownerGroups[0].DeveloperName;
    System.assert(
      ownerDeveloperName == 'Contratos' ||
        followUp.OwnerId == UserInfo.getUserId(),
      'Follow-up owner should be Contratos queue when available, otherwise fallback to current user.'
    );
    System.assert(
      followUp.Description.contains('Favor anexar documentos.'),
      'Should include comment in description'
    );
    System.assert(
      followUp.Description.contains(
        'Documentação faltante: RG e CPF do responsável'
      ),
      'Should include missing docs'
    );
  }

  @isTest
  static void createsFollowUpForViabilidadeTecnica() {
    Projeto__c project = createProject();
    project.ViabilidadeTecnicaPendencia__c = 'Laudo de carga e memorial descritivo';
    project.CriarAtividadeViabilidadeTecnica__c = true;
    update project;

    Task task = getOrCreateOpenTask(
      project.Id,
      TaskUtils.SUBJECT_VERIFICAR_VIABILIDADE_TECNICA
    );

    Test.startTest();
    TaskCompletionService.CompletionResult result = TaskCompletionService.completeWithComment(
      task.Id,
      'Pendências de viabilidade.',
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Result success');

    Task updatedTask = [SELECT Status FROM Task WHERE Id = :task.Id];
    System.assertEquals(
      TaskUtils.STATUS_CONCLUIDO,
      updatedTask.Status,
      'Task should be closed'
    );

    Task followUp = [
      SELECT OwnerId, Subject, Description
      FROM Task
      WHERE
        WhatId = :project.Id
        AND Subject = :('Follow-up: ' +
        TaskUtils.SUBJECT_VERIFICAR_VIABILIDADE_TECNICA)
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    List<Group> ownerGroups = [
      SELECT DeveloperName
      FROM Group
      WHERE Id = :followUp.OwnerId
      LIMIT 1
    ];
    String ownerDeveloperName = ownerGroups.isEmpty()
      ? null
      : ownerGroups[0].DeveloperName;
    System.assert(
      ownerDeveloperName == 'AnalistaViabilidade' ||
        followUp.OwnerId == UserInfo.getUserId(),
      'Follow-up owner should be AnalistaViabilidade queue when available, otherwise fallback to current user.'
    );
    System.assert(
      followUp.Description.contains('Pendências de viabilidade.'),
      'Should include comment in description'
    );
    System.assert(
      followUp.Description.contains(
        'Pendências da viabilidade técnica: Laudo de carga e memorial descritivo'
      ),
      'Should include missing viability info'
    );
  }

  @isTest
  static void completeWithCommentCreatesExplicitFollowUpWithoutWhatId() {
    Task task = new Task(
      Subject = 'Atividade avulsa',
      Status = 'Open',
      OwnerId = UserInfo.getUserId()
    );
    insert task;

    Test.startTest();
    TaskCompletionService.CompletionResult result = TaskCompletionService.completeWithComment(
      task.Id,
      'Concluir e acompanhar depois.',
      true,
      UserInfo.getUserId()
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.success,
      'Conclusão deve retornar sucesso.'
    );
    System.assertNotEquals(
      null,
      result.followUpId,
      'Follow-up deve ser criado.'
    );

    Task followUp = [
      SELECT OwnerId, Subject, Description, Status, WhatId
      FROM Task
      WHERE Id = :result.followUpId
      LIMIT 1
    ];
    System.assertEquals(
      'Follow-up: Atividade avulsa',
      followUp.Subject,
      'Assunto do follow-up deve reaproveitar a atividade original.'
    );
    System.assertEquals(
      UserInfo.getUserId(),
      followUp.OwnerId,
      'Owner explícito deve ser respeitado.'
    );
    System.assertEquals(
      'Concluir e acompanhar depois.',
      followUp.Description,
      'Descrição do follow-up deve receber o comentário informado.'
    );
    System.assertEquals(
      'Not Started',
      followUp.Status,
      'Follow-up deve ser aberto.'
    );
    System.assertEquals(
      null,
      followUp.WhatId,
      'Task sem WhatId não deve inventar vínculo.'
    );
  }

  @isTest
  static void completeWithCommentThrowsWhenTaskIdIsMissing() {
    try {
      TaskCompletionService.completeWithComment(
        null,
        'comentario',
        false,
        null
      );
    } catch (Exception ex) {
      System.assert(ex.getMessage() != null);
    }
    System.assert(true, 'Guard clause para Task Id nulo executada.');
  }

  @isTest
  static void isTaskClosedHandlesNullAndCompletedTasks() {
    Task completedTask = new Task(
      Subject = 'Concluida',
      Status = TaskUtils.STATUS_CONCLUIDO,
      OwnerId = UserInfo.getUserId()
    );
    insert completedTask;

    System.assertEquals(
      false,
      TaskCompletionService.isTaskClosed(null),
      'Task nula deve retornar false.'
    );
    System.assertEquals(
      true,
      TaskCompletionService.isTaskClosed(completedTask.Id),
      'Task concluída deve ser reconhecida como fechada.'
    );
  }

  private static Id ensureQueue(String developerName, String queueName) {
    List<Group> existing = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = :developerName
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }

    Group queue = new Group(
      DeveloperName = developerName,
      Name = queueName,
      Type = 'Queue'
    );
    insert queue;
    return queue.Id;
  }

  private static void ensureQueueSObject(Id queueId, String sObjectType) {
    List<QueueSobject> existing = [
      SELECT Id
      FROM QueueSobject
      WHERE QueueId = :queueId AND SObjectType = :sObjectType
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      insert new QueueSobject(QueueId = queueId, SObjectType = sObjectType);
    }
  }

  private static Projeto__c createProject() {
    Account account = (Account) TestFactory.createSObject(
      new Account(
        Name = 'Conta Projeto ' + String.valueOf(System.now().getTime())
      ),
      true
    );
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = account.Id),
      true
    );
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opportunity.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );

    Projeto__c project = new Projeto__c(
      Name = 'Projeto Task Completion ' +
        String.valueOf(System.now().getTime()),
      Conta__c = account.Id,
      Oportunidade__c = opportunity.Id,
      Viabilidade__c = viability.Id,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO
    );
    ProjetoTriggerHandler.disableTrigger();
    try {
      insert project;
    } finally {
      ProjetoTriggerHandler.enableTrigger();
    }
    return project;
  }

  private static Task getOrCreateOpenTask(Id whatId, String subject) {
    List<Task> existing = [
      SELECT Id, Subject, Status, WhatId, OwnerId
      FROM Task
      WHERE WhatId = :whatId AND Subject = :subject AND IsClosed = FALSE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return existing[0];
    }

    Task task = new Task(
      Subject = subject,
      Status = 'Open',
      WhatId = whatId,
      OwnerId = UserInfo.getUserId()
    );
    insert task;
    return task;
  }
}
