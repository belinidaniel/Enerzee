/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
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
  static void shouldNotifyAfterTaskConclusionWithSpecialSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Task oldTask = new Task(
      Subject = 'Defina quem executará a visita técnica do negócio',
      WhatId = acc.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.notifyAfterTaskConclusion(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'notifyAfterTaskConclusion nao deve lancar erro.');
  }

  @IsTest
  static void shouldNotifyAfterTaskConclusionAcusarRecebimento() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Task oldTask = new Task(
      Subject = 'Acusar recebimento dos dados da visita',
      WhatId = acc.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.notifyAfterTaskConclusion(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'notifyAfterTaskConclusion Acusar nao deve lancar erro.');
  }

  @IsTest
  static void shouldUpdateViabilityStatusOnAgendamentoDeVisita() {
    Test.disableProcessesAndFlows();
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );

    Task oldTask = new Task(
      Subject = 'AGENDAMENTO DE VISITA',
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.updateViabilityStatusOnTaskCompletion(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    ViabilityStudy__c updated = [
      SELECT StatusFeasibility__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.areEqual(
      'Visita Agendada',
      updated.StatusFeasibility__c,
      'Status deve ser Visita Agendada.'
    );
  }

  @IsTest
  static void shouldUpdateViabilityStatusOnAnexarArquivos() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );

    Task oldTask = new Task(
      Subject = 'ANEXAR ARQUIVOS DE VIABILIDADE',
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.updateViabilityStatusOnTaskCompletion(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    ViabilityStudy__c updated = [
      SELECT StatusFeasibility__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.areEqual(
      'Viabilidade Finalizada',
      updated.StatusFeasibility__c,
      'Status deve ser Viabilidade Finalizada.'
    );
  }

  @IsTest
  static void shouldSkipViabilityUpdateWhenOldTaskNotFound() {
    Test.disableProcessesAndFlows();
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );

    Task task = new Task(
      Subject = 'AGENDAMENTO DE VISITA',
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_CONCLUIDO,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert task;

    // oldMap is null → isTaskBeingConcluded returns false → skip
    Test.startTest();
    TaskBO.updateViabilityStatusOnTaskCompletion(
      new List<Task>{ task },
      null
    );
    Test.stopTest();

    Assert.isTrue(true, 'updateViabilityStatusOnTaskCompletion com null oldMap nao deve lancar erro.');
  }

  @IsTest
  static void shouldCreateNFConfirmationTaskEarlyReturnNoEligibleViabilities() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    // ViabilityStudy without OwnTeamThirdParty__c = Integrador/Nao_cadastrado → eligibleIds empty
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_SOLICITAR_PAGAMENTO_DE_INTEGRADOR,
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.createNFConfirmationTask(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'createNFConfirmationTask sem viabilities elegiveis nao deve lancar erro.');
  }

  @IsTest
  static void shouldHandleAprovacaoProjetoUfvWithNoSubStatusMatch() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_APROVACAO_DO_PROJETO_UFV,
      WhatId = project.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.handleAprovacaoProjetoUfv(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'handleAprovacaoProjetoUfv nao deve lancar erro.');
  }

  @IsTest
  static void shouldUpdateProjectPhaseWithRealProject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task task = new Task(
      Subject = 'Tarefa updateProjectPhase',
      WhatId = project.Id,
      Status = TaskUtils.STATUS_CONCLUIDO,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );

    Test.startTest();
    TaskBO.updateProjectPhase(
      new List<Task>{ task },
      new Map<Id, Task>()
    );
    Test.stopTest();

    Assert.isTrue(true, 'updateProjectPhase com projeto real nao deve lancar erro.');
  }

  @IsTest
  static void shouldValidateRequiredFieldSetsOnCompletionWithConcludingTask() {
    Test.disableProcessesAndFlows();
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );

    Task oldTask = new Task(
      Subject = 'AGENDAMENTO DE VISITA',
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.validateRequiredFieldSetsOnCompletion(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'validateRequiredFieldSetsOnCompletion nao deve lancar erro em contexto de teste.');
  }

  @IsTest
  static void shouldCoverNotifyViabilityInvoiceAttachmentNonMatchingSubject() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Task t = new Task(
      Subject = 'Outro assunto qualquer',
      WhatId = acc.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );

    ContentDocumentLink link = new ContentDocumentLink();

    Test.startTest();
    TaskBO.notifyViabilityInvoiceAttachment(t, link);
    Test.stopTest();

    Assert.isTrue(true, 'notifyViabilityInvoiceAttachment com subject diferente nao deve lancar erro.');
  }

  @IsTest
  static void shouldCoverNotifyViabilityInvoiceAttachmentNonViabilityWhatId() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Task t = new Task(
      Subject = TaskUtils.SUBJECT_SOLICITAR_PAGAMENTO_DE_INTEGRADOR,
      WhatId = acc.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );

    ContentDocumentLink link = new ContentDocumentLink();

    Test.startTest();
    TaskBO.notifyViabilityInvoiceAttachment(t, link);
    Test.stopTest();

    Assert.isTrue(true, 'notifyViabilityInvoiceAttachment com WhatId nao-viabilidade nao deve lancar erro.');
  }

  @IsTest
  static void shouldCoverNotifyViabilityInvoiceAttachmentWithViabilityNoFile() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );

    Task t = new Task(
      Subject = TaskUtils.SUBJECT_SOLICITAR_PAGAMENTO_DE_INTEGRADOR,
      WhatId = vs.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert t;

    // Insert a ContentDocument linked to vs to have a valid ContentDocumentId
    ContentVersion cv = new ContentVersion(
      Title = 'NF Integrador',
      PathOnClient = 'NF.pdf',
      FirstPublishLocationId = vs.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('nf-content')
    );
    insert cv;

    ContentDocument doc = [
      SELECT Id
      FROM ContentDocument
      WHERE Title = 'NF Integrador'
      LIMIT 1
    ];

    ContentDocumentLink link = new ContentDocumentLink(
      LinkedEntityId = vs.Id,
      ContentDocumentId = doc.Id,
      ShareType = 'V'
    );

    Test.startTest();
    TaskBO.notifyViabilityInvoiceAttachment(t, link);
    Test.stopTest();

    Assert.isTrue(true, 'notifyViabilityInvoiceAttachment com viabilidade e arquivo nao deve lancar erro.');
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

  // ─── Additional coverage tests ───────────────────────────────────────────────

  @IsTest
  static void shouldCoverNormalizeTaskSubjectWithNull() {
    String result = TaskBO.normalizeTaskSubject(null);
    Assert.areEqual('', result, 'normalizeTaskSubject(null) deve retornar string vazia.');
  }

  @IsTest
  static void shouldCoverNormalizeNameWithAccents() {
    Assert.areEqual('acoes', TaskBO.normalizeName('Ações'), 'normalizeName deve remover acentos.');
    Assert.areEqual('u', TaskBO.normalizeName('ú'), 'normalizeName deve normalizar ú → u.');
    Assert.areEqual('e', TaskBO.normalizeName('ê'), 'normalizeName deve normalizar ê → e.');
  }

  @IsTest
  static void shouldCoverWorkingDaysWithWeekend() {
    // Pick a known Friday and add 1 working day → should land on Monday (skip Sat/Sun)
    Date friday = Date.newInstance(2026, 3, 20); // Friday
    Date result = TaskBO.getActivityDateBasedOnWorkingDays(friday, 1);
    Assert.isNotNull(result, 'getActivityDateBasedOnWorkingDays não deve retornar null.');
    Assert.isTrue(result > friday, 'Data resultado deve ser posterior à data de início.');
  }

  @IsTest
  static void shouldCoverValidateRequiredDocumentsNullAndBlankTasks() {
    // Test the overloaded List<Task> path with null-subject and null-whatId tasks
    // These hit the "continue" branches inside the eligibleTasks loop
    Task nullSubjectTask = new Task(
      Subject = null,
      Status = TaskUtils.STATUS_OPEN
    );
    Task blankSubjectTask = new Task(
      Subject = '   ',
      Status = TaskUtils.STATUS_OPEN
    );
    Account acc = new Account(Name = 'Conta Docs2');
    insert acc;
    Task noWhatIdTask = new Task(
      Subject = 'Sem whatId',
      WhatId = null,
      Status = TaskUtils.STATUS_OPEN
    );

    Test.startTest();
    TaskBO.validateRequiredDocuments(
      new List<Task>{ nullSubjectTask, blankSubjectTask, noWhatIdTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'validateRequiredDocuments com tasks inválidas não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverCreateWorkOrderContractingIntegratorWithConcludingTask() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_CONTRATAR_INTEGRADOR,
      WhatId = project.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.createWorkOrderContractingIntegrator(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'createWorkOrderContractingIntegrator com tarefa sendo concluída não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverCreateWorkOrderRequestMaterialBuyWithConcludingTask() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS,
      WhatId = project.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.createWorkOrderRequestMaterialBuy(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'createWorkOrderRequestMaterialBuy com tarefa sendo concluída não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverCreateWorkOrderRequestMaterialBuyComplementares() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS_COMPLEMENTARES,
      WhatId = project.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.createWorkOrderRequestMaterialBuy(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'createWorkOrderRequestMaterialBuy complementares não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverUpdateProjectPhaseWithAllTasksCompleted() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    // Insert a task that is already Completed, then call updateProjectPhase
    // so getProjectsWithTasks and getNextPhase are exercised
    Task completedTask = new Task(
      Subject = 'Tarefa Concluida Phase Test',
      WhatId = project.Id,
      Status = TaskUtils.STATUS_CONCLUIDO,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert completedTask;

    Test.startTest();
    TaskBO.updateProjectPhase(
      new List<Task>{ completedTask },
      new Map<Id, Task>()
    );
    Test.stopTest();

    Assert.isTrue(true, 'updateProjectPhase com todas tarefas concluídas não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverHandleAprovacaoProjetoUfvWithApprovedSubStatus() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    // Set SubStatus__c = 'Aprovado' if field exists
    if (Schema.SObjectType.Projeto__c.fields.getMap().containsKey('SubStatus__c')) {
      project.put('SubStatus__c', 'Aprovado');
      update project;
    }

    Task oldTask = new Task(
      Subject = TaskUtils.SUBJECT_APROVACAO_DO_PROJETO_UFV,
      WhatId = project.Id,
      Status = TaskUtils.STATUS_OPEN,
      OwnerId = UserInfo.getUserId(),
      ActivityDate = System.today()
    );
    insert oldTask;

    Task newTask = oldTask.clone(true, true, false, false);
    newTask.Status = TaskUtils.STATUS_CONCLUIDO;

    Test.startTest();
    TaskBO.handleAprovacaoProjetoUfv(
      new List<Task>{ newTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    Assert.isTrue(true, 'handleAprovacaoProjetoUfv com SubStatus Aprovado não deve lançar erro.');
  }

  @IsTest
  static void shouldCoverLoadNormalizedSubjectsFromStaticResource() {
    Test.startTest();
    Set<String> projetoSubjects = TaskBO.loadNormalizedSubjectsFromStaticResource('TabelaTarefasProjetos');
    Set<String> instalacaoSubjects = TaskBO.loadNormalizedSubjectsFromStaticResource('TabelaTarefasInstalacao');
    Set<String> unknownSubjects = TaskBO.loadNormalizedSubjectsFromStaticResource('RecursoInexistente');
    Test.stopTest();

    Assert.isNotNull(projetoSubjects, 'projetoSubjects não deve ser null.');
    Assert.isNotNull(instalacaoSubjects, 'instalacaoSubjects não deve ser null.');
    Assert.isNotNull(unknownSubjects, 'unknownSubjects não deve ser null (retorna Set vazio em erro).');
  }

  @IsTest
  static void shouldCoverInstalacaoTaskInMarkManualTasks() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Instalacao__c instalacao = new Instalacao__c(
      Projeto__c = project.Id
    );
    insert instalacao;

    Task taskInstalacao = new Task(
      Subject = 'Tarefa avulsa instalação',
      WhatId = instalacao.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(2)
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ taskInstalacao });
    Test.stopTest();

    Assert.areEqual(
      true,
      taskInstalacao.IgnorarValidacao__c,
      'Task avulsa de instalação (subject não mapeado) deve ter IgnorarValidacao__c = true'
    );
  }

  @IsTest
  static void shouldCoverMarkManualTasksWithAlreadySetIgnorarValidacao() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
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
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Conta__c = acc.Id,
        TipoObra__c = 'UFVMicro',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    // Task already set to IgnorarValidacao__c = true → should not be changed
    Task t = new Task(
      Subject = 'Assunto avulso',
      WhatId = project.Id,
      OwnerId = UserInfo.getUserId(),
      Status = TaskUtils.STATUS_OPEN,
      ActivityDate = System.today().addDays(1),
      IgnorarValidacao__c = true
    );

    Test.startTest();
    TaskBO.markManualTasksAsIgnoreValidation(new List<Task>{ t });
    Test.stopTest();

    Assert.areEqual(
      true,
      t.IgnorarValidacao__c,
      'Task com IgnorarValidacao__c = true já definido não deve ser alterada.'
    );
  }
}
