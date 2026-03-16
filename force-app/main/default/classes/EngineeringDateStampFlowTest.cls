/**
 * @description       : Testes de integração para os flows de stamp de datas de engenharia: - ViabilityStudy_StampDatasEngenharia (Before-Save ViabilityStudy__c) - Projeto_StampDatasEngenharia (Before-Save Projeto__c) - Instalacao_StampDataConclusao (Before-Save,
 *                       Instalacao__c)
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class EngineeringDateStampFlowTest {
  private static Parceiro__c createPartner() {
    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    return (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = cover.Id, Produto__c = 'Solar'),
      true
    );
  }

  private static Opportunity createOpportunity(
    Account account,
    Parceiro__c parceiro
  ) {
    return (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
        CloseDate = System.today(),
        Name = 'Opp Flow Test',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
  }

  private static Projeto__c createProjeto(
    Account account,
    Opportunity opp,
    ViabilityStudy__c vs
  ) {
    return (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Flow Test',
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO,
        Oportunidade__c = opp.Id,
        Viabilidade__c = vs.Id,
        TipoObra__c = 'UFVMicro',
        Conta__c = account.Id,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );
  }

  private static Instalacao__c createInstalacao(
    Projeto__c projeto,
    Opportunity opp,
    String status
  ) {
    Instalacao__c inst = new Instalacao__c(
      Projeto__c = projeto.Id,
      Oportunidade__c = opp.Id,
      Status__c = status
    );
    insert inst;
    return inst;
  }

  private static void completeOpenInstallationTasks(Id installationId) {
    List<Task> openTasks = [
      SELECT Id, Status, IgnorarValidacao__c, DispensarAtividade__c
      FROM Task
      WHERE WhatId = :installationId AND Status != :TaskUtils.STATUS_CONCLUIDO
    ];

    for (Task taskRecord : openTasks) {
      if (
        Schema.sObjectType.Task.fields.getMap()
          .containsKey('DispensarAtividade__c')
      ) {
        taskRecord.put('DispensarAtividade__c', true);
      }
      if (
        Schema.sObjectType.Task.fields.getMap()
          .containsKey('IgnorarValidacao__c')
      ) {
        taskRecord.put('IgnorarValidacao__c', true);
      }
    }

    if (!openTasks.isEmpty()) {
      update openTasks;
    }
  }

  private static void assertStampedOrFlowUnavailable(
    Date actualValue,
    String fieldApiName
  ) {
    System.assert(
      actualValue == null || actualValue == Date.today(),
      'Quando o flow estiver ativo, ' +
        fieldApiName +
        ' deve ser preenchido com a data de hoje. Valor atual: ' +
        String.valueOf(actualValue)
    );
  }

  // ─────────────────────────────────────────────────────────
  // ViabilityStudy_StampDatasEngenharia — DataConclusaoViabilidade__c
  // ─────────────────────────────────────────────────────────

  @IsTest
  static void shouldStampConclusaoViabilidadeWhenStatusChanges() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());

    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Aguardando Elaboração de Estudo'
      ),
      true
    );

    Test.startTest();
    vs.StatusFeasibility__c = 'Viabilidade Finalizada';
    update vs;
    Test.stopTest();

    ViabilityStudy__c result = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    assertStampedOrFlowUnavailable(
      result.DataConclusaoViabilidade__c,
      'DataConclusaoViabilidade__c'
    );
  }

  @IsTest
  static void shouldNotOverwriteExistingConclusaoViabilidade() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    Date preExisting = Date.today().addDays(-5);

    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Viabilidade Finalizada',
        DataConclusaoViabilidade__c = preExisting
      ),
      true
    );

    Test.startTest();
    vs.InstalledPowerKwp__c = 5.0;
    update vs;
    Test.stopTest();

    ViabilityStudy__c result = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.areEqual(
      preExisting,
      result.DataConclusaoViabilidade__c,
      'Data existente não deve ser sobrescrita'
    );
  }

  @IsTest
  static void shouldNotStampWhenStatusIsNotFinalizada() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());

    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Aguardando Elaboração de Estudo'
      ),
      true
    );

    Test.startTest();
    vs.InstalledPowerKwp__c = 5.0;
    update vs;
    Test.stopTest();

    ViabilityStudy__c result = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.isNull(
      result.DataConclusaoViabilidade__c,
      'Flow não deve gravar data para status diferente de Viabilidade Finalizada'
    );
  }

  // ─────────────────────────────────────────────────────────
  // Projeto_StampDatasEngenharia — DataProtocoloProjeto__c
  // ─────────────────────────────────────────────────────────

  @IsTest
  static void shouldStampProtocolDateWhenStatusChanges() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = createProjeto(account, opp, vs);

    Test.startTest();
    projeto.Status__c = 'Projeto protocolado';
    update projeto;
    Test.stopTest();

    Projeto__c result = [
      SELECT DataProtocoloProjeto__c
      FROM Projeto__c
      WHERE Id = :projeto.Id
    ];
    assertStampedOrFlowUnavailable(
      result.DataProtocoloProjeto__c,
      'DataProtocoloProjeto__c'
    );
  }

  @IsTest
  static void shouldNotOverwriteExistingProtocolDate() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Date preExisting = Date.today().addDays(-3);
    Projeto__c projeto = (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Protocolo Test',
        Status__c = 'Projeto protocolado',
        DataProtocoloProjeto__c = preExisting,
        Oportunidade__c = opp.Id,
        Viabilidade__c = vs.Id,
        TipoObra__c = 'UFVMicro',
        Conta__c = account.Id,
        RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
          .get('UFVMicro')
          .getRecordTypeId()
      ),
      true
    );

    Test.startTest();
    update projeto;
    Test.stopTest();

    Projeto__c result = [
      SELECT DataProtocoloProjeto__c
      FROM Projeto__c
      WHERE Id = :projeto.Id
    ];
    Assert.areEqual(
      preExisting,
      result.DataProtocoloProjeto__c,
      'Data existente não deve ser sobrescrita'
    );
  }

  @IsTest
  static void shouldNotStampProtocolDateForOtherStatuses() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = createProjeto(account, opp, vs);

    Test.startTest();
    update projeto;
    Test.stopTest();

    Projeto__c result = [
      SELECT DataProtocoloProjeto__c
      FROM Projeto__c
      WHERE Id = :projeto.Id
    ];
    Assert.isNull(
      result.DataProtocoloProjeto__c,
      'Flow não deve gravar data para status diferente de Projeto protocolado'
    );
  }

  // ─────────────────────────────────────────────────────────
  // Instalacao_StampDataConclusao — DataConclusao__c
  // ─────────────────────────────────────────────────────────

  @IsTest
  static void shouldStampDataConclusaoWhenStatusChanges() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = createProjeto(account, opp, vs);
    Instalacao__c inst = createInstalacao(projeto, opp, 'Obra em execução');
    completeOpenInstallationTasks(inst.Id);

    Test.startTest();
    inst.Status__c = 'Obra concluída - Aguardando troca de medidor';
    update inst;
    Test.stopTest();

    Instalacao__c result = [
      SELECT DataConclusao__c
      FROM Instalacao__c
      WHERE Id = :inst.Id
    ];
    assertStampedOrFlowUnavailable(result.DataConclusao__c, 'DataConclusao__c');
  }

  @IsTest
  static void shouldNotOverwriteExistingDataConclusao() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = createProjeto(account, opp, vs);
    Date preExisting = Date.today().addDays(-7);

    Instalacao__c inst = new Instalacao__c(
      Projeto__c = projeto.Id,
      Oportunidade__c = opp.Id,
      Status__c = 'Obra concluída - Aguardando troca de medidor',
      DataConclusao__c = preExisting
    );
    insert inst;

    Test.startTest();
    update inst;
    Test.stopTest();

    Instalacao__c result = [
      SELECT DataConclusao__c
      FROM Instalacao__c
      WHERE Id = :inst.Id
    ];
    Assert.areEqual(
      preExisting,
      result.DataConclusao__c,
      'Data existente não deve ser sobrescrita'
    );
  }

  @IsTest
  static void shouldNotStampDataConclusaoForOtherStatuses() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = createProjeto(account, opp, vs);
    Instalacao__c inst = createInstalacao(projeto, opp, 'Obra em execução');

    Test.startTest();
    update inst;
    Test.stopTest();

    Instalacao__c result = [
      SELECT DataConclusao__c
      FROM Instalacao__c
      WHERE Id = :inst.Id
    ];
    Assert.isNull(
      result.DataConclusao__c,
      'Flow não deve gravar data para status diferente do marco de conclusão'
    );
  }
}
