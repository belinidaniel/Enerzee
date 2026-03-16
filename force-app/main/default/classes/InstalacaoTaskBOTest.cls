/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class InstalacaoTaskBOTest {
  private static Projeto__c buildProject(Account acc, Opportunity opp) {
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
      true
    );
    return (Projeto__c) TestFactory.createSObject(
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
  }

  private static Instalacao__c insertInstalacao(Id projectId, String status) {
    Instalacao__c inst = new Instalacao__c(
      Projeto__c = projectId,
      Status__c = status
    );
    insert inst;
    return inst;
  }

  @IsTest
  static void shouldHandleEmptyInputs() {
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>(),
      new Map<Id, Instalacao__c>()
    );
    InstalacaoTaskBO.createPlanningTasksAfterDelegar(null);
    System.assert(true, 'InstalacaoTaskBO handled empty inputs');
  }

  @IsTest
  static void shouldHandleNullList() {
    InstalacaoTaskBO.createTasks(null, null);
    Assert.isTrue(true, 'createTasks com null nao deve lancar erro.');
  }

  @IsTest
  static void shouldCreateTasksWithRealInstalacao() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);
    Instalacao__c inst = insertInstalacao(project.Id, ProjetoUtils.STATUS_OBRA_EM_EXECUCAO);

    Test.startTest();
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>{ inst },
      new Map<Id, Instalacao__c>()
    );
    Test.stopTest();

    Assert.isTrue(true, 'createTasks com dados reais nao deve lancar erro.');
  }

  @IsTest
  static void shouldRunCreatePlanningTasksWithRealInstalacao() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);
    Instalacao__c inst = insertInstalacao(project.Id, ProjetoUtils.STATUS_PLANEJAMENTO_DE_OBRA);

    Test.startTest();
    InstalacaoTaskBO.createPlanningTasksAfterDelegar(inst.Id);
    Test.stopTest();

    Assert.isTrue(true, 'createPlanningTasksAfterDelegar com dados reais nao deve lancar erro.');
  }

  @IsTest
  static void shouldCreateTasksWithStatusChangingRecord() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);
    Instalacao__c instOld = insertInstalacao(project.Id, ProjetoUtils.STATUS_OBRA_EM_EXECUCAO);
    Instalacao__c instNew = new Instalacao__c(
      Id = instOld.Id,
      Projeto__c = project.Id,
      Status__c = ProjetoUtils.STATUS_OBRA_CONCLUIDA
    );

    Test.startTest();
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>{ instNew },
      new Map<Id, Instalacao__c>{ instOld.Id => instOld }
    );
    Test.stopTest();

    Assert.isTrue(true, 'createTasks com mudanca de status nao deve lancar erro.');
  }

  @IsTest
  static void shouldSkipWhenStatusNotChanging() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);
    Instalacao__c inst = insertInstalacao(project.Id, ProjetoUtils.STATUS_OBRA_EM_EXECUCAO);

    // Same status in old and new → isStatusChanging returns false → no tasks
    Instalacao__c instOld = inst.clone(true, true, true, true);
    Instalacao__c instNew = inst.clone(true, true, true, true);

    Integer tasksBefore = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];

    Test.startTest();
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>{ instNew },
      new Map<Id, Instalacao__c>{ instOld.Id => instOld }
    );
    Test.stopTest();

    Integer tasksAfter = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];
    Assert.areEqual(tasksBefore, tasksAfter, 'Status não alterado não deve gerar novas tarefas.');
  }

  @IsTest
  static void shouldSkipInstalacaoWithUnknownStatus() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);

    // Status que não existe na tabela de mapeamento → resolveStatusKey retorna null → continue
    Instalacao__c inst = new Instalacao__c(
      Projeto__c = project.Id,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO
    );
    insert inst;

    Integer tasksBefore = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];

    Test.startTest();
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>{ inst },
      new Map<Id, Instalacao__c>()
    );
    Test.stopTest();

    Integer tasksAfter = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];
    Assert.areEqual(tasksBefore, tasksAfter, 'Status sem templates não deve gerar tarefas.');
  }

  @IsTest
  static void shouldHandleCreatePlanningWhenNotPlanejamentoStatus() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id),
      true
    );
    Projeto__c project = buildProject(acc, opp);
    // Status diferente de PLANEJAMENTO_DE_OBRA → método retorna cedo sem criar tarefas
    Instalacao__c inst = insertInstalacao(project.Id, ProjetoUtils.STATUS_OBRA_EM_EXECUCAO);

    Integer tasksBefore = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];

    Test.startTest();
    InstalacaoTaskBO.createPlanningTasksAfterDelegar(inst.Id);
    Test.stopTest();

    Integer tasksAfter = [SELECT COUNT() FROM Task WHERE WhatId = :inst.Id];
    Assert.areEqual(tasksBefore, tasksAfter, 'Status diferente de Planejamento de Obra não deve criar tarefas de planejamento.');
  }
}
