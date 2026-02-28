/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-11-2026
 * @last modified by  : Daniel Belini
 **/
@IsTest
private class TaskBOTest {
  @IsTest
  static void testCreateTaskAndHasOpenTasks() {
    Account acc = new Account(Name = 'Conta Teste TaskBO');
    insert acc;

    Task t = TaskBO.createTask(
      acc.Id,
      'Assunto Teste',
      'Descricao',
      UserInfo.getUserId(),
      Date.today().addDays(3),
      '3'
    );
    t.Status = TaskUtils.STATUS_OPEN;
    insert t;

    System.assertEquals(acc.Id, t.WhatId);
    System.assertEquals('Assunto Teste', t.Subject);
    System.assertEquals('Descricao', t.Description);
    System.assertEquals(
      true,
      TaskBO.hasOpenTasks(acc.Id),
      'Deve identificar tarefa aberta.'
    );
  }

  @IsTest
  static void testHasOpenTasksSkipDispensa() {
    Account acc = new Account(Name = 'Conta Dispensa');
    insert acc;

    Task t1 = new Task(
      WhatId = acc.Id,
      Subject = 'T1',
      Status = TaskUtils.STATUS_OPEN
    );
    if (
      Schema.sObjectType.Task.fields.getMap()
        .containsKey('DispensarAtividade__c')
    ) {
      t1.put('DispensarAtividade__c', true);
    }
    insert t1;

    System.assertEquals(
      false,
      TaskBO.hasOpenTasks(acc.Id),
      'Tarefa dispensada nao conta como aberta.'
    );

    Task t2 = new Task(
      WhatId = acc.Id,
      Subject = 'T2',
      Status = TaskUtils.STATUS_OPEN
    );
    if (
      Schema.sObjectType.Task.fields.getMap()
        .containsKey('DispensarAtividade__c')
    ) {
      t2.put('DispensarAtividade__c', false);
    }
    insert t2;

    System.assertEquals(
      true,
      TaskBO.hasOpenTasks(acc.Id),
      'Tarefa nao dispensada conta como aberta.'
    );
  }

  @IsTest
  static void testPreventDuplicateOpenTasks() {
    Account acc = new Account(Name = 'Conta Duplicada');
    insert acc;

    Task existing = new Task(
      WhatId = acc.Id,
      Subject = 'Duplicada',
      Status = TaskUtils.STATUS_OPEN
    );
    insert existing;

    Task newTask = new Task(
      WhatId = acc.Id,
      Subject = 'Duplicada',
      Status = TaskUtils.STATUS_OPEN
    );
    List<Task> newTasks = new List<Task>{ newTask };
    TaskBO.preventDuplicateOpenTasks(newTasks);

    try {
      insert newTask;
      System.assert(false, 'Deveria lançar erro por duplicidade.');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains('Já existe uma atividade em aberto'),
        'Mensagem de duplicidade esperada.'
      );
    }
  }

  @IsTest
  static void testValidateRequiredDocuments() {
    Account acc = new Account(Name = 'Conta Docs');
    insert acc;

    Map<String, ActivityRequiredDocument__mdt> cfgs = ActivityRequiredDocument__mdt.getAll();
    ActivityRequiredDocument__mdt cfg;
    for (ActivityRequiredDocument__mdt record : cfgs.values()) {
      if (
        !String.isBlank(record.ActivitySubject__c) &&
        !String.isBlank(record.RequiredFiles__c)
      ) {
        cfg = record;
        break;
      }
    }

    Task taskMissing = new Task(
      WhatId = acc.Id,
      Subject = cfg != null ? cfg.ActivitySubject__c : 'Sem Config',
      Status = TaskUtils.STATUS_OPEN
    );
    TaskBO.validateRequiredDocuments(taskMissing);

    if (cfg == null) {
      System.assertEquals(
        0,
        cfgs.size(),
        'Sem configuracao de documentos obrigatorios.'
      );
      return;
    }

    Database.SaveResult sr = Database.insert(taskMissing, false);
  }

  @IsTest
  static void testNormalizeAndWorkingDays() {
    System.assertEquals(
      '',
      TaskBO.normalizeName(null),
      'Normalize null deve retornar vazio.'
    );
    System.assertEquals(
      'doc_1',
      TaskBO.normalizeName('Doc 1'),
      'Normalize deve padronizar.'
    );

    Date startDate = Date.today();
    Date endDate = TaskBO.getActivityDateBasedOnWorkingDays(startDate, 1);
    System.assert(endDate != null, 'Data calculada nao deve ser nula.');
  }

  @IsTest
  static void testWorkOrderBuildersAndSubjectHelpers() {
    Account acc = new Account(Name = 'Conta WorkOrder');
    insert acc;

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        CEP__c = '02925130',
        Logradouro__c = 'Rua Teste',
        MunicipioInstalacao__c = 'Sao Paulo',
        EstadoInstalacao__c = 'São Paulo'
      ),
      true
    );

    Projeto__c project = new Projeto__c(
      Name = 'Projeto Builder',
      Conta__c = acc.Id,
      Oportunidade__c = opp.Id
    );

    WorkOrder woFromProject = TaskBO.createWorkOrder(project, null, null, null);
    WorkOrder woFromOpp = TaskBO.createWorkOrder(opp, null, null, null);

    System.assertEquals(acc.Id, woFromProject.AccountId);
    System.assertEquals(opp.Id, woFromOpp.Oportunidade__c);

    Task existing = new Task(
      WhatId = acc.Id,
      Subject = '  Assunto com Espaco  ',
      Status = TaskUtils.STATUS_OPEN
    );
    insert existing;

    System.assertEquals(
      true,
      TaskBO.taskSubjectExists(acc.Id, 'assunto com espaco')
    );
    System.assertEquals(false, TaskBO.taskSubjectExists(acc.Id, 'inexistente'));

    Map<Id, Set<String>> subjectMap = TaskBO.getExistingTaskSubjectSetByWhatIds(
      new Set<Id>{ acc.Id }
    );
    System.assert(
      subjectMap.containsKey(acc.Id),
      'Deve retornar mapa por WhatId.'
    );
    System.assert(subjectMap.get(acc.Id).contains('assunto com espaco'));
  }

  @IsTest
  static void testHeavyMethodsWithSafeEarlyPaths() {
    TaskBO.createWorkOrderContractingIntegrator(
      new List<Task>(),
      new Map<Id, Task>()
    );
    TaskBO.createWorkOrderRequestMaterialBuy(
      new List<Task>(),
      new Map<Id, Task>()
    );
    TaskBO.notifyAfterTaskConclusion(new List<Task>(), new Map<Id, Task>());
    TaskBO.updateProjectPhase(new List<Task>(), new Map<Id, Task>());
    TaskBO.handleAprovacaoProjetoUfv(new List<Task>(), new Map<Id, Task>());
    TaskBO.checkTaskCloser(new List<Task>(), new Map<Id, Task>());
    TaskBO.validateRequiredFieldSetsOnCompletion(
      new List<Task>(),
      new Map<Id, Task>()
    );
    TaskBO.updateViabilityStatusOnTaskCompletion(
      new List<Task>(),
      new Map<Id, Task>()
    );
    TaskBO.notifyViabilityInvoiceAttachment(null, null);

    System.assertEquals(
      0,
      TaskBO.getExistingTaskSubjectSetByWhatIds(new Set<Id>()).size()
    );
  }
}
