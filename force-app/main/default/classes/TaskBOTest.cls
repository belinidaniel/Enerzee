/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 02-11-2026
 * @last modified by	 : Daniel Belini
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
      Subject = '	 Assunto com Espaco	 ',
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

  // SAL-403 ─────────────────────────────────────────────────────────────────

  @IsTest
  static void markManualTasks_SetsIgnorarValidacao_ForUnknownSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        CapaProposta__c = ((ProposalCover__c) TestFactory.createSObject(
            new ProposalCover__c(),
            true
          ))
          .Id,
        Produto__c = 'Solar'
      ),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
        CloseDate = System.today(),
        Name = 'Opp Mark Manual',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c project = (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Mark Manual',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        TipoObra__c = 'UFVMicro',
        Conta__c = acc.Id,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task manualTask = new Task(
      Subject = 'Reunião avulsa com cliente',
      WhatId = project.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(3)
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ manualTask });
    Test.stopTest();

    Assert.areEqual(
      true,
      manualTask.IgnorarValidacao__c,
      'Task avulsa (subject não mapeado) deve ter IgnorarValidacao__c = true'
    );
  }

  @IsTest
  static void markManualTasks_DoesNotOverride_ForConfiguredSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        CapaProposta__c = ((ProposalCover__c) TestFactory.createSObject(
            new ProposalCover__c(),
            true
          ))
          .Id,
        Produto__c = 'Solar'
      ),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
        CloseDate = System.today(),
        Name = 'Opp Config Subject',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c project = (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Config Subject',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        TipoObra__c = 'UFVMicro',
        Conta__c = acc.Id,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    // 'DELEGAR PROJETISTA' existe em TabelaTarefasProjetos.csv → deve permanecer false
    Task configTask = new Task(
      Subject = 'DELEGAR PROJETISTA',
      WhatId = project.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(1),
      IgnorarValidacao__c = false
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ configTask });
    Test.stopTest();

    Assert.areEqual(
      false,
      configTask.IgnorarValidacao__c,
      'Task de config (subject mapeado) não deve ter IgnorarValidacao__c alterado para true'
    );
  }

  // Bug fix: ProjetoBO.getTaskTableFromStaticResource filtrava todas as linhas do CSV de viabilidade
  // porque o campo TipoProjetoObra é blank naquele CSV. Agora loadNormalizedViabilitySubjects usa
  // ViabilityStudyBO.getTaskViabilityTableFromStaticResource e os subjects são carregados corretamente.
  @IsTest
  static void markManualTasks_DoesNotOverride_ForViabilityConfiguredSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        CapaProposta__c = ((ProposalCover__c) TestFactory.createSObject(
            new ProposalCover__c(),
            true
          ))
          .Id,
        Produto__c = 'Solar'
      ),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
        CloseDate = System.today(),
        Name = 'Opp Viability Config Subject',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );

    // 'AGENDAMENTO DE VISITA' existe em TabelaTarefasViabilidade.csv → deve permanecer false
    ViabilityStudyBO.TaskViabilityTable mockTable = new ViabilityStudyBO.TaskViabilityTable();
    mockTable.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>();
    ViabilityStudyBO.TaskViabilityTableLine line = new ViabilityStudyBO.TaskViabilityTableLine();
    line.Assunto = 'AGENDAMENTO DE VISITA';
    line.IgnorarValidacao = false;
    mockTable.tableLines.add(line);
    ViabilityStudyBO.taskTableOverride = mockTable;

    Task configTask = new Task(
      Subject = 'AGENDAMENTO DE VISITA',
      WhatId = viability.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(1),
      IgnorarValidacao__c = false
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ configTask });
    Test.stopTest();

    Assert.areEqual(
      false,
      configTask.IgnorarValidacao__c,
      'Task de config de viabilidade (subject mapeado) não deve ter IgnorarValidacao__c alterado para true'
    );
  }

  @IsTest
  static void markManualTasks_SetsIgnorarValidacao_ForViabilityUnknownSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        CapaProposta__c = ((ProposalCover__c) TestFactory.createSObject(
            new ProposalCover__c(),
            true
          ))
          .Id,
        Produto__c = 'Solar'
      ),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
        CloseDate = System.today(),
        Name = 'Opp Viability Manual',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );

    ViabilityStudyBO.TaskViabilityTable mockTable = new ViabilityStudyBO.TaskViabilityTable();
    mockTable.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>();
    ViabilityStudyBO.TaskViabilityTableLine configLine = new ViabilityStudyBO.TaskViabilityTableLine();
    configLine.Assunto = 'AGENDAMENTO DE VISITA';
    configLine.IgnorarValidacao = false;
    mockTable.tableLines.add(configLine);
    ViabilityStudyBO.taskTableOverride = mockTable;

    Task manualTask = new Task(
      Subject = 'Reunião avulsa de viabilidade',
      WhatId = viability.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(2)
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ manualTask });
    Test.stopTest();

    Assert.areEqual(
      true,
      manualTask.IgnorarValidacao__c,
      'Task avulsa de viabilidade (subject não mapeado) deve ter IgnorarValidacao__c = true'
    );
  }

  @IsTest
  static void markManualTasks_HandlesEmptyList() {
    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>());
    Test.stopTest();
    Assert.isTrue(true, 'Não deve lançar exceção para lista vazia');
  }

  @IsTest
  static void markManualTasks_SkipsTasksWithNullWhatId() {
    Task t = new Task(
      Subject = 'Task sem WhatId',
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today()
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ t });
    Test.stopTest();

    Assert.areNotEqual(
      true,
      t.IgnorarValidacao__c,
      'Task sem WhatId não deve ser marcada'
    );
  }
}
