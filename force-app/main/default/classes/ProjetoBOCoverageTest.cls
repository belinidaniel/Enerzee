/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProjetoBOCoverageTest {
  @IsTest
  static void shouldPopulateDefaultsAndOpportunityData() {
    Opportunity opportunityRecord = createOpportunity('Populate');

    Projeto__c projectRecord = new Projeto__c(
      Oportunidade__c = opportunityRecord.Id
    );

    ProjetoBO.userEmailToUser.clear();
    ProjetoBO.populateUserEmailMap();
    ProjetoBO.initializeStatusStartDate(new List<Projeto__c>{ projectRecord });
    ProjetoBO.populateFromOpportunity(new List<Projeto__c>{ projectRecord });
    ProjetoBO.setDefaultStatus(new List<Projeto__c>{ projectRecord });

    System.assert(
      ProjetoBO.userEmailToUser.containsKey(
        [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email
      )
    );
    System.assertNotEquals(null, projectRecord.StatusAtualDesde__c);
    System.assertEquals(opportunityRecord.AccountId, projectRecord.Conta__c);
    System.assertEquals(
      opportunityRecord.PotenciaNominalSistema__c,
      Decimal.valueOf(projectRecord.PotenciaSistema__c)
    );
    System.assertEquals(
      ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
      projectRecord.Status__c
    );
  }

  @IsTest
  static void shouldUpdateStatusDurationsAcrossRelevantPhases() {
    Id fakeProjectId1 = buildProjetoId(1);
    Id fakeProjectId2 = buildProjetoId(2);
    Id fakeProjectId3 = buildProjetoId(3);

    Projeto__c oldPlanning = new Projeto__c(
      Id = fakeProjectId1,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO,
      StatusAtualDesde__c = System.now().addDays(-2)
    );
    Projeto__c newPlanning = new Projeto__c(
      Id = fakeProjectId1,
      Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO
    );

    Projeto__c oldElaboration = new Projeto__c(
      Id = fakeProjectId2,
      Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO,
      StatusAtualDesde__c = System.now().addDays(-1)
    );
    Projeto__c newElaboration = new Projeto__c(
      Id = fakeProjectId2,
      Status__c = ProjetoUtils.STATUS_PROJETO_EM_ANALISE
    );

    Projeto__c oldAnalysis = new Projeto__c(
      Id = fakeProjectId3,
      Status__c = ProjetoUtils.STATUS_PROJETO_EM_ANALISE,
      StatusAtualDesde__c = System.now().addDays(-3)
    );
    Projeto__c newAnalysis = new Projeto__c(
      Id = fakeProjectId3,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO
    );

    ProjetoBO.updateStatusDurations(
      new List<Projeto__c>{ newPlanning, newElaboration, newAnalysis },
      new Map<Id, Projeto__c>{
        fakeProjectId1 => oldPlanning,
        fakeProjectId2 => oldElaboration,
        fakeProjectId3 => oldAnalysis
      }
    );

    System.assert(newPlanning.ContagemPrazo__c > 0);
    System.assert(newPlanning.ContagemPrazoPlanejamento__c > 0);
    System.assertNotEquals(null, newPlanning.StatusAtualDesde__c);

    System.assert(newElaboration.ContagemPrazo__c > 0);
    System.assert(newElaboration.ContagemPrazoProjetoElaboracao__c > 0);
    System.assertNotEquals(null, newElaboration.StatusAtualDesde__c);

    System.assert(newAnalysis.ContagemPrazo__c > 0);
    System.assert(newAnalysis.ContagemPrazoProjetoAnalise__c > 0);
    System.assertNotEquals(null, newAnalysis.StatusAtualDesde__c);
  }

  @IsTest
  static void shouldSyncOpportunityStatusFromProject() {
    Opportunity opportunityRecord = createOpportunity('Sync');
    Projeto__c insertedProject = createProject(opportunityRecord);

    Projeto__c oldProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO,
      MotivoSubStatus__c = 'Motivo antigo'
    );
    Projeto__c newProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO,
      MotivoSubStatus__c = 'Motivo novo'
    );

    OpportunityTriggerHandler.disableTrigger();
    try {
      ProjetoBO.syncOpportunityStatusFromProject(
        new List<Projeto__c>{ newProject },
        new Map<Id, Projeto__c>{ insertedProject.Id => oldProject }
      );
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    Id opportunityId = opportunityRecord.Id;
    String query =
      'SELECT Id, Status__c' +
      (Schema.SObjectType.Opportunity.fields.getMap()
          .containsKey('ProjectStatusReason__c')
        ? ', ProjectStatusReason__c'
        : '') +
      ' FROM Opportunity WHERE Id = :opportunityId';
    Opportunity refreshedOpportunity = Database.query(query);

    System.assertEquals(
      ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO,
      refreshedOpportunity.Status__c
    );
    if (
      Schema.SObjectType.Opportunity.fields.getMap()
        .containsKey('ProjectStatusReason__c')
    ) {
      System.assertEquals(
        'Motivo novo',
        (String) refreshedOpportunity.get('ProjectStatusReason__c')
      );
    }
  }

  @IsTest
  static void shouldUpdateFinishProjectTaskDate() {
    Opportunity opportunityRecord = createOpportunity('Finish');
    Projeto__c insertedProject = createProject(opportunityRecord);
    Case caseRecord = createJourneyCase(opportunityRecord);

    TaskTriggerHandler.disableTrigger();
    try {
      insert new Task(
        Subject = 'Instalação - Vistoria',
        WhatId = caseRecord.Id,
        ActivityDate = Date.today(),
        Status = 'Not Started'
      );
    } finally {
      TaskTriggerHandler.enableTrigger();
    }

    Date finishDate = Date.today().addDays(7);
    Projeto__c oldProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id
    );
    Projeto__c newProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      FinishProjectDate__c = finishDate
    );

    ProjetoBO.createTaskFinishProject(
      new List<Projeto__c>{ newProject },
      new Map<Id, Projeto__c>{ insertedProject.Id => oldProject }
    );

    Task refreshedTask = [
      SELECT FinishProjectDate__c
      FROM Task
      WHERE WhatId = :caseRecord.Id AND Subject = 'Instalação - Vistoria'
      LIMIT 1
    ];

    System.assertEquals(finishDate, refreshedTask.FinishProjectDate__c);
  }

  @IsTest
  static void shouldLoadTaskTableAndEvaluateHelperRules() {
    ProjetoBO.TaskProjectTable emptyTable = ProjetoBO.getTaskTableFromStaticResource(
      null
    );
    ProjetoBO.TaskProjectTable taskTable = ProjetoBO.getTaskProjectTableFromStaticResource();

    System.assertEquals(0, emptyTable.tableLines.size());
    System.assert(taskTable.tableLines.size() > 0);
    System.assertEquals(
      'RT_UFV_MICRO',
      taskTable.tableLines[0].TipoProjetoObra
    );
    System.assertEquals(
      'STATUS_PLANEJAMENTO_DE_PROJETO',
      taskTable.tableLines[0].Status
    );
    System.assertEquals('DELEGAR PROJETISTA', taskTable.tableLines[0].Assunto);
    System.assertEquals(false, taskTable.tableLines[0].IgnorarValidacao);

    System.assertEquals(
      ProjetoUtils.RT_UFV_MICRO,
      ProjetoBO.getRecordTypeCodeToIdMap().get('RT_UFV_MICRO')
    );
    System.assertEquals(
      'RT_UFV_MICRO',
      ProjetoBO.getRecordTypeIdToCodeMap().get(ProjetoUtils.RT_UFV_MICRO)
    );
    System.assertEquals(
      ProjetoUtils.STATUS_PROJETO_APROVADO,
      ProjetoBO.getStatusCodeToStatusMap().get('STATUS_PROJETO_APROVADO')
    );
    System.assertEquals(
      'STATUS_PROJETO_APROVADO',
      ProjetoBO.getStatusToStatusCodeMap()
        .get(ProjetoUtils.STATUS_PROJETO_APROVADO)
    );

    Opportunity opportunityRecord = createOpportunity('HelperRules');
    Projeto__c ufvProject = new Projeto__c(
      Id = buildProjetoId(10),
      Oportunidade__c = opportunityRecord.Id,
      RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO
    );
    Projeto__c oldProject = new Projeto__c(
      Id = ufvProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
      Status__c = ProjetoUtils.STATUS_NAO_DEFINIDO
    );

    System.assert(
      !ProjetoBO.shouldUFVPhaseBeCreated(
        ufvProject,
        'PROTOCOLO PROJETO UFV',
        new Set<Id>{ ProjetoUtils.RT_UFV_MICRO },
        new Set<Id>{ opportunityRecord.Id }
      )
    );
    System.assert(
      ProjetoBO.shouldUFVPhaseBeCreated(
        ufvProject,
        'FASE NÃO FINANCIAMENTO',
        new Set<Id>{ ProjetoUtils.RT_UFV_MICRO },
        new Set<Id>{ opportunityRecord.Id }
      )
    );
    System.assert(
      ProjetoBO.shouldUFVPhaseBeCreated(
        new Projeto__c(
          Id = buildProjetoId(11),
          Oportunidade__c = opportunityRecord.Id,
          RecordTypeId = getAvailableProjetoRecordTypeId()
        ),
        'PROTOCOLO PROJETO UFV',
        new Set<Id>{ ProjetoUtils.RT_UFV_MICRO },
        new Set<Id>{ opportunityRecord.Id }
      )
    );

    ProjetoBO.checkTasksConclusionBeforeStatusChange(
      new List<Projeto__c>{ ufvProject },
      new Map<Id, Projeto__c>{ ufvProject.Id => oldProject }
    );
  }

  @IsTest
  static void shouldCreateOnboardingTaskAndUpdateJourneyCase() {
    Opportunity opportunityRecord = createOpportunity('Onboarding');
    Projeto__c insertedProject = createProject(opportunityRecord);
    Case caseRecord = createJourneyCase(opportunityRecord);
    Consultor__c consultorRecord = createConsultor('Onboarding');

    Projeto__c oldProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id
    );
    insertedProject.GestorObra__c = UserInfo.getUserId();
    insertedProject.Consultor__c = consultorRecord.Id;

    ProjetoTriggerHandler.disableTrigger();
    try {
      update insertedProject;
    } finally {
      ProjetoTriggerHandler.enableTrigger();
    }

    Projeto__c newProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      GestorObra__c = insertedProject.GestorObra__c,
      Consultor__c = insertedProject.Consultor__c
    );

    ProjetoBO.createTaskOnboarding(
      new List<Projeto__c>{ newProject },
      new Map<Id, Projeto__c>{ insertedProject.Id => oldProject }
    );

    Case refreshedCase = [
      SELECT ManagerName__c, Nome_do_Consultor__c, KWP__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    Task onboardingTask = [
      SELECT
        Subject,
        WhatId,
        WhoId,
        NextNotification__c,
        Manager__c,
        Type,
        CreateNewTaskAutomatically__c
      FROM Task
      WHERE WhatId = :caseRecord.Id AND Subject = 'Informações Iniciais'
      LIMIT 1
    ];

    System.assertEquals(UserInfo.getUserId(), refreshedCase.ManagerName__c);
    System.assertEquals(consultorRecord.Id, refreshedCase.Nome_do_Consultor__c);
    System.assertEquals(caseRecord.Id, onboardingTask.WhatId);
    System.assertEquals(opportunityRecord.ContactId, onboardingTask.WhoId);
    System.assertEquals('15 dias', onboardingTask.NextNotification__c);
    System.assertEquals('Jornada do Projeto', onboardingTask.Type);
    System.assertEquals(false, onboardingTask.CreateNewTaskAutomatically__c);
  }

  @IsTest
  static void shouldCreateApprovedProjectTaskAndUpdateJourneyCaseStatus() {
    Opportunity opportunityRecord = createOpportunity('Approved');
    Projeto__c insertedProject = createProject(opportunityRecord);
    Case caseRecord = createJourneyCase(opportunityRecord);

    Date approvalDate = Date.today().addDays(3);
    Projeto__c oldProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id
    );
    Projeto__c newProject = new Projeto__c(
      Id = insertedProject.Id,
      Oportunidade__c = opportunityRecord.Id,
      ApprovalDate__c = approvalDate
    );

    ProjetoBO.createTaskProjectApproved(
      new List<Projeto__c>{ newProject },
      new Map<Id, Projeto__c>{ insertedProject.Id => oldProject }
    );

    Case refreshedCase = [SELECT Status FROM Case WHERE Id = :caseRecord.Id];
    Task approvedTask = [
      SELECT
        Subject,
        WhatId,
        WhoId,
        ActivityDate,
        NextNotification__c,
        Type,
        CreateNewTaskAutomatically__c,
        ProjectApprovalDate__c
      FROM Task
      WHERE WhatId = :caseRecord.Id AND Subject = 'Projeto Aprovado'
      LIMIT 1
    ];

    System.assertEquals('Projeto Aprovado', refreshedCase.Status);
    System.assertEquals(caseRecord.Id, approvedTask.WhatId);
    System.assertEquals(opportunityRecord.ContactId, approvedTask.WhoId);
    System.assertEquals(approvalDate, approvedTask.ActivityDate);
    System.assertEquals('5 dias', approvedTask.NextNotification__c);
    System.assertEquals('Jornada do Projeto', approvedTask.Type);
    System.assertEquals(true, approvedTask.CreateNewTaskAutomatically__c);
    System.assertEquals(approvalDate, approvedTask.ProjectApprovalDate__c);
  }

  private static Opportunity createOpportunity(String suffix) {
    Account accountRecord = new Account(Name = 'ProjetoBO ' + suffix);
    insert accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Contato ' + suffix,
      Email = 'projetobo.' + suffix.toLowerCase() + '@teste.com',
      AccountId = accountRecord.Id
    );
    insert contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opportunity ' + suffix,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = accountRecord.Id,
      ContactId = contactRecord.Id,
      PotenciaNominalSistema__c = 12.5,
      IdVirtualOffice__c = '00000000-0000-0000-0000-000000000010'
    );

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    return opportunityRecord;
  }

  private static Projeto__c createProject(Opportunity opportunityRecord) {
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viability;

    Projeto__c projectRecord = new Projeto__c(
      Name = 'Projeto Coverage',
      Oportunidade__c = opportunityRecord.Id,
      Viabilidade__c = viability.Id,
      Conta__c = opportunityRecord.AccountId
    );

    Id recordTypeId = getAvailableProjetoRecordTypeId();
    if (recordTypeId != null) {
      projectRecord.RecordTypeId = recordTypeId;
    }

    insert projectRecord;
    return projectRecord;
  }

  private static Consultor__c createConsultor(String suffix) {
    Consultor__c consultorRecord = new Consultor__c(
      Name = 'Consultor Projeto ' + suffix,
      Ativo__c = true
    );

    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultorRecord;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    return consultorRecord;
  }

  private static Case createJourneyCase(Opportunity opportunityRecord) {
    Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Jornada_do_Cliente')
      .getRecordTypeId();

    CaseTriggerHandler.enabled = false;
    try {
      Case caseRecord = new Case(
        Subject = 'Jornada Projeto',
        Status = 'New',
        RecordTypeId = caseRecordTypeId,
        Nome_da_Oportunidade__c = opportunityRecord.Id,
        OwnerId = UserInfo.getUserId(),
        ContactId = opportunityRecord.ContactId
      );
      insert caseRecord;
      return caseRecord;
    } finally {
      CaseTriggerHandler.enabled = true;
    }
  }

  private static Id getAvailableProjetoRecordTypeId() {
    for (
      Schema.RecordTypeInfo rti : Projeto__c.SObjectType.getDescribe()
        .getRecordTypeInfos()
    ) {
      if (rti.isAvailable() && !rti.isMaster()) {
        return rti.getRecordTypeId();
      }
    }
    return null;
  }

  private static Id buildProjetoId(Integer sequence) {
    String keyPrefix = Projeto__c.SObjectType.getDescribe().getKeyPrefix();
    return (Id) (keyPrefix + String.valueOf(sequence).leftPad(15, '0'));
  }
}
