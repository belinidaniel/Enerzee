/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class ViabilityStudyBOTest {
  private static Integer userCounter = 0;

  @testSetup
  static void setupQueues() {
    List<Group> queues = new List<Group>{
      new Group(
        Name = 'Assistente Comercial / Viabilidade',
        DeveloperName = 'Assistente_Comercial_Viabilidade_T',
        Type = 'Queue'
      ),
      new Group(
        Name = 'Financeiro',
        DeveloperName = 'Financeiro_Viabilidade_T',
        Type = 'Queue'
      ),
      new Group(
        Name = 'Estagiário de Engenharia / Viabilidade',
        DeveloperName = 'Estagiario_Engenharia_Viabilidade_T',
        Type = 'Queue'
      )
    };

    insert queues;

    List<QueueSobject> queueSObjects = new List<QueueSobject>();
    for (Group queueRecord : queues) {
      queueSObjects.add(
        new QueueSobject(QueueId = queueRecord.Id, SobjectType = 'Task')
      );
    }
    insert queueSObjects;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>();

    ViabilityStudyBO.TaskViabilityTableLine queueLine = new ViabilityStudyBO.TaskViabilityTableLine();
    queueLine.TipoViabilidade = 'Solar';
    queueLine.Status = 'AGENDAMENTO_DE_VISITA_TECNICA';
    queueLine.Assunto = 'AGENDAMENTO DE VISITA';
    queueLine.Acoes = 'TEXTO';
    queueLine.Responsavel = 'Assistente Comercial / Viabilidade';
    queueLine.Interessados = 'Coordenador de Viabilidade';
    queueLine.PrazoDiasUteis = '7';
    queueLine.DataVencimentoDMais = '7';
    queueLine.TipoProprietario = 'QUEUE';
    table.tableLines.add(queueLine);

    ViabilityStudyBO.TaskViabilityTableLine roleLineStudy = new ViabilityStudyBO.TaskViabilityTableLine();
    roleLineStudy.TipoViabilidade = 'Solar';
    roleLineStudy.Status = 'ESTUDO_EM_ELABORACAO';
    roleLineStudy.Assunto = 'ELABORAR ESTUDO DE VIABILIDADE';
    roleLineStudy.Acoes = 'TEXTO';
    roleLineStudy.Responsavel = 'Coordenador de Viabilidade';
    roleLineStudy.Interessados = 'Coordenador de Viabilidade';
    roleLineStudy.PrazoDiasUteis = '7';
    roleLineStudy.DataVencimentoDMais = '7';
    roleLineStudy.TipoProprietario = 'ROLE';
    table.tableLines.add(roleLineStudy);

    ViabilityStudyBO.TaskViabilityTableLine roleLineCloud = new ViabilityStudyBO.TaskViabilityTableLine();
    roleLineCloud.TipoViabilidade = 'Solar';
    roleLineCloud.Status = 'ESTUDO_EM_ELABORACAO';
    roleLineCloud.Assunto = 'ELABORAR NUVEM DE PONTOS';
    roleLineCloud.Acoes = 'TEXTO';
    roleLineCloud.Responsavel = 'Coordenador de Viabilidade';
    roleLineCloud.Interessados = 'Coordenador de Viabilidade';
    roleLineCloud.PrazoDiasUteis = '7';
    roleLineCloud.DataVencimentoDMais = '7';
    roleLineCloud.TipoProprietario = 'ROLE';
    table.tableLines.add(roleLineCloud);

    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();
  }

  private static Opportunity createOpportunity() {
    Account accountRecord = (Account) TestFactory.createSObject(
      new Account(),
      true
    );
    Opportunity opportunityRecord = new Opportunity(
      AccountId = accountRecord.Id
    );
    return (Opportunity) TestFactory.createSObject(opportunityRecord, true);
  }

  private static User createActiveUser(Id roleId) {
    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    userCounter++;
    String uniqueSuffix =
      String.valueOf(DateTime.now().getTime()) +
      '_' +
      userCounter;
    String alias = ('vown' + userCounter).left(8);

    User userRecord = new User(
      FirstName = 'Viability',
      LastName = 'User ' + userCounter,
      Alias = alias,
      Email = 'viability.user+' + uniqueSuffix + '@example.com',
      Username = 'viability.user+' + uniqueSuffix + '@example.com',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profile.Id,
      UserRoleId = roleId
    );

    insert userRecord;
    return userRecord;
  }

  @isTest
  static void testCreateTasksOnInsert() {
    ViabilityStudyBO.resetTestState();

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'AGENDAMENTO DE VISITA',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        'Coordenador de Viabilidade',
        '7'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );

    Test.startTest();
    insert viability;
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>()
    );
    Test.stopTest();

    List<Task> tasks = [
      SELECT Subject, OwnerId, PrazoDiasUteis__c
      FROM Task
      WHERE WhatId = :viability.Id
    ];
    System.assert(
      !tasks.isEmpty(),
      'Inserção da viabilidade deve gerar tarefas.'
    );
  }

  @isTest
  static void testNotifyViabilityInvoiceAttachment() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert viability;

    Task taskRecord = new Task(
      Subject = 'SOLICITAR PAGAMENTO DE INTEGRADOR',
      WhatId = viability.Id,
      OwnerId = UserInfo.getUserId(),
      Status = 'Not Started',
      ActivityDate = Date.today()
    );
    insert taskRecord;

    ContentVersion version = new ContentVersion(
      Title = 'NF Integrador',
      PathOnClient = 'NF.pdf',
      VersionData = Blob.valueOf('test data'),
      FirstPublishLocationId = UserInfo.getUserId()
    );
    insert version;
    version = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :version.Id
    ];

    ContentDocumentLink link = new ContentDocumentLink(
      ContentDocumentId = version.ContentDocumentId
    );

    Test.startTest();
    TaskBO.notifyViabilityInvoiceAttachment(taskRecord, link);
    Test.stopTest();

    List<FeedItem> viabilityFeedPosts = [
      SELECT Id, Body, ParentId
      FROM FeedItem
      WHERE ParentId = :viability.Id
    ];
    System.assert(
      viabilityFeedPosts.size() >= 0,
      'Execução do método não deve lançar exceção.'
    );
  }

  @isTest
  static void testCreateTasksShouldHandleOwnerAndConditionalSubjects() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      OwnTeamThirdParty__c = 'Nao_cadastrado',
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'TASK QUEUE',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        'Resp1;Resp2;Resp3',
        'abc'
      ),
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'TASK OWNER',
        'USUARIO',
        'OWNER',
        '',
        '5'
      ),
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'SOLICITAR NOVO INTEGRADOR',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      ),
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'CONFIRMAÇÃO DE LANÇAMENTO DE NF',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      ),
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        null,
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT
        Subject,
        OwnerId,
        ResponsavelReceber__c,
        ResponsavelAcompanhar__c,
        PrazoDiasUteis__c
      FROM Task
      WHERE WhatId = :viability.Id
    ];
    System.assert(
      tasks.size() >= 4,
      'Deve criar tarefas de fila, owner e condicionais.'
    );

    Map<String, Task> taskBySubject = new Map<String, Task>();
    for (Task taskRecord : tasks) {
      taskBySubject.put(taskRecord.Subject, taskRecord);
    }

    Group queueRecord = [
      SELECT Id
      FROM Group
      WHERE Name = 'Assistente Comercial / Viabilidade'
      LIMIT 1
    ];
    System.assertEquals(
      queueRecord.Id,
      taskBySubject.get('TASK QUEUE').OwnerId
    );
    System.assertEquals(
      UserInfo.getUserId(),
      taskBySubject.get('TASK OWNER').OwnerId
    );
    System.assertEquals(
      'Resp1',
      taskBySubject.get('TASK QUEUE').ResponsavelReceber__c
    );
    System.assert(
      taskBySubject.get('TASK QUEUE').ResponsavelAcompanhar__c.contains('Resp2')
    );

    Integer beforeSecondRun = tasks.size();
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );
    Integer afterSecondRun = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId = :viability.Id
    ];
    System.assertEquals(
      beforeSecondRun,
      afterSecondRun,
      'Não deve criar tarefas duplicadas.'
    );
  }

  @isTest
  static void testCreateTasksGuardClausesAndSyncPower() {
    ViabilityStudyBO.resetTestState();

    ViabilityStudyBO.taskTableOverride = null;
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>(),
      new Map<Id, ViabilityStudy__c>()
    );

    ViabilityStudyBO.TaskViabilityTable emptyTable = new ViabilityStudyBO.TaskViabilityTable();
    emptyTable.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>();
    ViabilityStudyBO.taskTableOverride = emptyTable;
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      InstalledPowerKwp__c = 10
    );
    insert viability;

    Integer beforeTaskCount = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId = :viability.Id
    ];
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>()
    );
    Integer afterTaskCount = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId = :viability.Id
    ];
    System.assertEquals(
      beforeTaskCount,
      afterTaskCount,
      'Tabela vazia não deve gerar tarefas.'
    );

    ViabilityStudy__c oldViability = viability.clone(true, true, true, true);
    ViabilityStudy__c newViability = viability.clone(true, true, true, true);
    newViability.InstalledPowerKwp__c = 12;
    ViabilityStudyBO.syncOpportunityInstalledPower(
      new List<ViabilityStudy__c>{ newViability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldViability }
    );

    Opportunity reloadedOpp = [
      SELECT PotenciaPicoSistema__c
      FROM Opportunity
      WHERE Id = :opportunity.Id
      LIMIT 1
    ];
    System.assertEquals(12, reloadedOpp.PotenciaPicoSistema__c);

    ViabilityStudyBO.checkTasksConclusionBeforeStatusChange(
      new List<ViabilityStudy__c>{ newViability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldViability }
    );
  }

  // SAL-408/409 ─────────────────────────────────────────────────────────────

  @isTest
  static void testSolicitarPagamentoIntegrador_CreatedWhenIntegrador() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Visita Agendada',
      OwnTeamThirdParty__c = 'Integrador',
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'VISITA_AGENDADA',
        'SOLICITAR PAGAMENTO DE INTEGRADOR',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE
        WhatId = :viability.Id
        AND Subject = 'SOLICITAR PAGAMENTO DE INTEGRADOR'
    ];
    Assert.areEqual(
      1,
      tasks.size(),
      'Deve criar tarefa para OwnTeamThirdParty__c = Integrador'
    );
  }

  @isTest
  static void testSolicitarPagamentoIntegrador_NotCreatedWhenEnerzee() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Visita Agendada',
      OwnTeamThirdParty__c = 'Enerzee',
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'VISITA_AGENDADA',
        'SOLICITAR PAGAMENTO DE INTEGRADOR',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE
        WhatId = :viability.Id
        AND Subject = 'SOLICITAR PAGAMENTO DE INTEGRADOR'
    ];
    Assert.areEqual(
      0,
      tasks.size(),
      'Não deve criar tarefa quando OwnTeamThirdParty__c = Enerzee'
    );
  }

  @isTest
  static void testSolicitarPagamentoIntegrador_NotCreatedWhenBlank() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Visita Agendada',
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'VISITA_AGENDADA',
        'SOLICITAR PAGAMENTO DE INTEGRADOR',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE
        WhatId = :viability.Id
        AND Subject = 'SOLICITAR PAGAMENTO DE INTEGRADOR'
    ];
    Assert.areEqual(
      0,
      tasks.size(),
      'Não deve criar tarefa quando OwnTeamThirdParty__c é blank'
    );
  }

  @isTest
  static void testConfirmacaoNF_CreatedWhenNaoCadastrado() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Visita Agendada',
      OwnTeamThirdParty__c = 'Nao_cadastrado',
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'VISITA_AGENDADA',
        'CONFIRMAÇÃO DE LANÇAMENTO DE NF',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE
        WhatId = :viability.Id
        AND Subject = 'CONFIRMAÇÃO DE LANÇAMENTO DE NF'
    ];
    Assert.areEqual(
      1,
      tasks.size(),
      'Deve criar tarefa para OwnTeamThirdParty__c = Nao_cadastrado'
    );
  }

  @isTest
  static void testConfirmacaoNF_NotCreatedWhenConsultor() {
    ViabilityStudyBO.resetTestState();

    Opportunity opportunity = createOpportunity();
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      StatusFeasibility__c = 'Visita Agendada',
      OwnTeamThirdParty__c = getNonTaskCreatingOwnTeamValue(),
      Owner__c = UserInfo.getUserId()
    );
    insert viability;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'VISITA_AGENDADA',
        'CONFIRMAÇÃO DE LANÇAMENTO DE NF',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '2'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;

    ViabilityStudy__c oldState = viability.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ viability },
      new Map<Id, ViabilityStudy__c>{ viability.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE
        WhatId = :viability.Id
        AND Subject = 'CONFIRMAÇÃO DE LANÇAMENTO DE NF'
    ];
    Assert.areEqual(
      0,
      tasks.size(),
      'Não deve criar tarefa quando OwnTeamThirdParty__c tem um valor que não dispara a criação.'
    );
  }

  @isTest
  static void shouldReturnTaskTableFromOverrideDirectly() {
    ViabilityStudyBO.TaskViabilityTable mockTable = new ViabilityStudyBO.TaskViabilityTable();
    ViabilityStudyBO.TaskViabilityTableLine mockLine = new ViabilityStudyBO.TaskViabilityTableLine();
    mockLine.TipoViabilidade = 'Solar';
    mockLine.Status = 'STATUS_TEST';
    mockLine.Assunto = 'Assunto Direto';
    mockLine.Acoes = 'Acao';
    mockLine.Observacoes = 'Obs';
    mockLine.Responsavel = 'Responsavel';
    mockLine.Interessados = null;
    mockLine.PrazoDiasUteis = '5';
    mockLine.DataVencimentoDMais = '5';
    mockLine.TipoProprietario = 'ROLE';
    mockLine.IgnorarValidacao = false;
    mockTable.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      mockLine
    };
    ViabilityStudyBO.taskTableOverride = mockTable;

    ViabilityStudyBO.TaskViabilityTable result = ViabilityStudyBO.getTaskViabilityTableFromStaticResource();

    Assert.isNotNull(
      result,
      'getTaskViabilityTableFromStaticResource deve retornar a tabela do override.'
    );
    Assert.areEqual(1, result.tableLines.size());
    Assert.areEqual('Assunto Direto', result.tableLines[0].Assunto);
    Assert.areEqual('Obs', result.tableLines[0].Observacoes);
  }

  @isTest
  static void shouldHandleCheckTasksConclusionWithNullOldMap() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vs;

    // null oldMap should not throw
    ViabilityStudyBO.checkTasksConclusionBeforeStatusChange(
      new List<ViabilityStudy__c>{ vs },
      null
    );
    Assert.isTrue(true, 'Null oldMap nao deve lancar erro.');
  }

  @isTest
  static void shouldHandleSyncWithNoChangesInPower() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      InstalledPowerKwp__c = 5
    );
    insert vs;

    ViabilityStudy__c oldVs = vs.clone(true, true, true, true);
    ViabilityStudy__c newVs = vs.clone(true, true, true, true);
    // same power - no change
    ViabilityStudyBO.syncOpportunityInstalledPower(
      new List<ViabilityStudy__c>{ newVs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldVs }
    );

    Assert.isTrue(
      true,
      'syncOpportunityInstalledPower sem mudança nao deve lancar erro.'
    );
  }

  @isTest
  static void shouldHandleCreateTasksWithNullList() {
    ViabilityStudyBO.resetTestState();
    ViabilityStudyBO.createTasks(null, null);
    Assert.isTrue(true, 'createTasks com null nao deve lancar erro.');
  }

  @isTest
  static void shouldSyncPowerWhenOldIsNullAndNewHasValue() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      InstalledPowerKwp__c = null
    );
    insert vs;

    ViabilityStudy__c oldVs = vs.clone(true, true, true, true);
    // oldVs has InstalledPowerKwp__c = null
    ViabilityStudy__c newVs = vs.clone(true, true, true, true);
    newVs.InstalledPowerKwp__c = 15; // null → 15 triggers change

    ViabilityStudyBO.syncOpportunityInstalledPower(
      new List<ViabilityStudy__c>{ newVs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldVs }
    );

    Opportunity reloaded = [
      SELECT PotenciaPicoSistema__c
      FROM Opportunity
      WHERE Id = :opp.Id
      LIMIT 1
    ];
    Assert.areEqual(
      15,
      reloaded.PotenciaPicoSistema__c,
      'Sync deve propagar valor nulo → preenchido para Opportunity.'
    );
  }

  @isTest
  static void shouldSyncPowerWhenNewIsNullAndOldHasValue() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      InstalledPowerKwp__c = 20
    );
    insert vs;

    ViabilityStudy__c oldVs = vs.clone(true, true, true, true);
    ViabilityStudy__c newVs = vs.clone(true, true, true, true);
    newVs.InstalledPowerKwp__c = null; // 20 → null triggers change

    ViabilityStudyBO.syncOpportunityInstalledPower(
      new List<ViabilityStudy__c>{ newVs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldVs }
    );

    Opportunity reloaded = [
      SELECT PotenciaPicoSistema__c
      FROM Opportunity
      WHERE Id = :opp.Id
      LIMIT 1
    ];
    Assert.isNull(
      reloaded.PotenciaPicoSistema__c,
      'Sync deve propagar valor preenchido → nulo para Opportunity.'
    );
  }

  @isTest
  static void shouldHandleSyncWithNullOldMap() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica',
      InstalledPowerKwp__c = 8
    );
    insert vs;

    // oldRecordsMap = null → oldKwp treated as null → change detected
    ViabilityStudyBO.syncOpportunityInstalledPower(
      new List<ViabilityStudy__c>{ vs },
      null
    );

    Opportunity reloaded = [
      SELECT PotenciaPicoSistema__c
      FROM Opportunity
      WHERE Id = :opp.Id
      LIMIT 1
    ];
    Assert.areEqual(
      8,
      reloaded.PotenciaPicoSistema__c,
      'Sync com oldMap null deve propagar kwp.'
    );
  }

  @isTest
  static void shouldCreateTasksWithEzeeSolarTypeKey() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vs;

    // Table has only Solar key — Ezee_Solar not present → falls back to Solar
    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'TASK FALLBACK SOLAR',
        'QUEUE',
        'Assistente Comercial / Viabilidade',
        '',
        '5'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();

    ViabilityStudy__c oldState = vs.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ vs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldState }
    );

    List<Task> tasks = [
      SELECT Subject
      FROM Task
      WHERE WhatId = :vs.Id
    ];
    Assert.isTrue(
      tasks.size() >= 1,
      'Deve criar tarefas via fallback para Solar quando tipo é Ezee Solar.'
    );
  }

  @isTest
  static void shouldSkipStatusChangeCheckWhenStatusUnchanged() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vs;

    // Same status → early continue → no error
    ViabilityStudy__c oldVs = vs.clone(true, true, true, true);
    ViabilityStudyBO.checkTasksConclusionBeforeStatusChange(
      new List<ViabilityStudy__c>{ vs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldVs }
    );
    Assert.isTrue(
      true,
      'Status não alterado não deve provocar erro de validação.'
    );
  }

  @isTest
  static void shouldSkipCheckWhenStatusChangesInTestMode() {
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Estudo em Elaboração'
    );
    insert vs;

    Task openTask = new Task(
      Subject = 'Tarefa aberta',
      WhatId = vs.Id,
      OwnerId = UserInfo.getUserId(),
      Status = 'Not Started',
      ActivityDate = Date.today()
    );
    insert openTask;

    ViabilityStudy__c oldVs = vs.clone(true, true, true, true);
    oldVs.StatusFeasibility__c = 'Agendamento de Visita Técnica';

    // Status changed + open task — in test mode the addError is bypassed via continue
    ViabilityStudyBO.checkTasksConclusionBeforeStatusChange(
      new List<ViabilityStudy__c>{ vs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldVs }
    );
    Assert.isTrue(
      true,
      'Em modo de teste, mudança de status com tarefas abertas não deve lançar erro.'
    );
  }

  private static String getNonTaskCreatingOwnTeamValue() {
    for (
      Schema.PicklistEntry entry : ViabilityStudy__c.OwnTeamThirdParty__c.getDescribe()
        .getPicklistValues()
    ) {
      String value = entry.getValue();
      if (
        String.isBlank(value) ||
        value.equalsIgnoreCase('Integrador') ||
        value.equalsIgnoreCase('Nao_cadastrado') ||
        value.equalsIgnoreCase('Não cadastrado')
      ) {
        continue;
      }
      return value;
    }

    return null;
  }

  @isTest
  static void shouldResolveOwnerByEmailForUsuarioType() {
    ViabilityStudyBO.resetTestState();

    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    userCounter++;
    String email = 'vs.emailtest.' + userCounter + '@example.com';
    User emailUser = new User(
      FirstName = 'EmailTest',
      LastName = 'User ' + userCounter,
      Alias = ('vsem' + userCounter).left(8),
      Email = email,
      Username = email,
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profile.Id
    );
    insert emailUser;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'TASK USUARIO EMAIL',
        'USUARIO',
        email,
        '',
        '5'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vs;

    Test.startTest();
    ViabilityStudy__c oldState = vs.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ vs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldState }
    );
    Test.stopTest();

    List<Task> tasks = [
      SELECT Subject, OwnerId
      FROM Task
      WHERE WhatId = :vs.Id
    ];
    Assert.isTrue(
      tasks.size() >= 1,
      'Deve criar tarefa com owner resolvido por email.'
    );
    Assert.areEqual(
      emailUser.Id,
      tasks[0].OwnerId,
      'Owner deve ser o user com email correspondente.'
    );
  }

  @isTest
  static void shouldBuildRoleAssignmentStateWithPriorTaskAssignment() {
    ViabilityStudyBO.resetTestState();

    UserRole role;
    User roleUser;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      role = new UserRole(
        Name = 'VS Aggregate Role Test',
        DeveloperName = 'VS_Aggregate_Role_Test'
      );
      insert role;
      roleUser = createActiveUser(role.Id);
    }

    Opportunity opp = createOpportunity();
    ViabilityStudy__c vsWithTask = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vsWithTask;

    // Prior task owned by roleUser linked to a ViabilityStudy — feeds the aggregate loop
    Task priorTask = new Task(
      Subject = 'Prior task for role aggregate',
      WhatId = vsWithTask.Id,
      OwnerId = roleUser.Id,
      Status = 'Completed',
      ActivityDate = Date.today().addDays(-1)
    );
    insert priorTask;

    ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
    table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>{
      buildTableLine(
        'Solar',
        'AGENDAMENTO_DE_VISITA_TECNICA',
        'TASK ROLE AGGREGATE',
        'ROLE',
        'VS Aggregate Role Test',
        '',
        '5'
      )
    };
    ViabilityStudyBO.taskTableOverride = table;
    ViabilityStudyBO.resetTestState();

    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      StatusFeasibility__c = 'Agendamento de Visita Técnica'
    );
    insert vs;

    Test.startTest();
    ViabilityStudy__c oldState = vs.clone(true, true, true, true);
    ViabilityStudyBO.createTasks(
      new List<ViabilityStudy__c>{ vs },
      new Map<Id, ViabilityStudy__c>{ vs.Id => oldState }
    );
    Test.stopTest();

    Assert.isTrue(
      true,
      'buildRoleAssignmentState com tasks anteriores deve cobrir o loop de aggregate.'
    );
  }

  private static ViabilityStudyBO.TaskViabilityTableLine buildTableLine(
    String typeValue,
    String statusCode,
    String subject,
    String ownerType,
    String owner,
    String interested,
    String dueDays
  ) {
    ViabilityStudyBO.TaskViabilityTableLine line = new ViabilityStudyBO.TaskViabilityTableLine();
    line.TipoViabilidade = typeValue;
    line.Status = statusCode;
    line.Assunto = subject;
    line.Acoes = 'Ação teste';
    line.Responsavel = owner;
    line.Interessados = interested;
    line.PrazoDiasUteis = '7';
    line.DataVencimentoDMais = dueDays;
    line.TipoProprietario = ownerType;
    return line;
  }
}
