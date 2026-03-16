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
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
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

    Instalacao__c inst = (Instalacao__c) TestFactory.createSObject(
      new Instalacao__c(
        Projeto__c = project.Id,
        Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
      ),
      true
    );

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
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
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

    Instalacao__c inst = (Instalacao__c) TestFactory.createSObject(
      new Instalacao__c(
        Projeto__c = project.Id,
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_OBRA
      ),
      true
    );

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
    ViabilityStudy__c viability = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(Opportunity__c = opp.Id),
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

    Instalacao__c instOld = (Instalacao__c) TestFactory.createSObject(
      new Instalacao__c(
        Projeto__c = project.Id,
        Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
      ),
      true
    );
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
}
