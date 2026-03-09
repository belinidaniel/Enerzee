/**
 * @description : Testes para EngineeringDateBackfillBatch.
 *                Verifica que cada modo preenche o campo correto em registros
 *                históricos que não possuem a data preenchida.
 *                Estratégia: inserção direta no status final (flows são Update-only,
 *                portanto não disparam no INSERT) → campo permanece null → batch preenche.
 *                Para ProjetoProtocol e Instalacao, batch.execute() é chamado diretamente
 *                para isolar a lógica do batch de triggers que podem interferir.
 * @author      : Daniel Belini
 **/
@IsTest
private class EngineeringDateBackfillBatchTest {
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
        Name = 'Opp Backfill Test',
        Parceiro__c = parceiro.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId()
      ),
      true
    );
  }

  @IsTest
  static void shouldBackfillViabilityStudyDate() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());

    // INSERT direto no status final — Finish_Viability_Study_Flow não dispara em INSERT
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Viabilidade Finalizada'
      ),
      true
    );

    Assert.isNull(
      [
        SELECT DataConclusaoViabilidade__c
        FROM ViabilityStudy__c
        WHERE Id = :vs.Id
      ]
      .DataConclusaoViabilidade__c,
      'DataConclusaoViabilidade__c deve estar null antes do batch'
    );

    Test.startTest();
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ViabilityStudy'),
      200
    );
    Test.stopTest();

    ViabilityStudy__c result = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.isNotNull(
      result.DataConclusaoViabilidade__c,
      'Batch deve preencher DataConclusaoViabilidade__c'
    );
  }

  @IsTest
  static void shouldNotOverwriteExistingViabilityStudyDate() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    Date originalDate = Date.today().addDays(-10);

    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Viabilidade Finalizada',
        DataConclusaoViabilidade__c = originalDate
      ),
      true
    );

    Test.startTest();
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ViabilityStudy'),
      200
    );
    Test.stopTest();

    ViabilityStudy__c result = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ];
    Assert.areEqual(
      originalDate,
      result.DataConclusaoViabilidade__c,
      'Data existente não deve ser sobrescrita'
    );
  }

  @IsTest
  static void shouldBackfillProjetoProtocolDate() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );

    // INSERT direto no status protocolado — Before-Save flow não dispara em INSERT
    Projeto__c projeto = (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Backfill Test',
        Status__c = 'Projeto protocolado',
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

    Assert.isNull(
      [SELECT DataProtocoloProjeto__c FROM Projeto__c WHERE Id = :projeto.Id]
      .DataProtocoloProjeto__c,
      'DataProtocoloProjeto__c deve estar null antes do batch'
    );

    // Chamar execute diretamente para isolar da cadeia de triggers do Projeto
    Test.startTest();
    EngineeringDateBackfillBatch batch = new EngineeringDateBackfillBatch(
      'ProjetoProtocol'
    );
    List<SObject> scope = [
      SELECT Id, LastModifiedDate
      FROM Projeto__c
      WHERE Id = :projeto.Id
    ];
    batch.execute(null, scope);
    Test.stopTest();

    Projeto__c result = [
      SELECT DataProtocoloProjeto__c
      FROM Projeto__c
      WHERE Id = :projeto.Id
    ];
    Assert.isNotNull(
      result.DataProtocoloProjeto__c,
      'Batch deve preencher DataProtocoloProjeto__c'
    );
  }

  @IsTest
  static void shouldBackfillInstalacaoConclusaoDate() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());
    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      ),
      true
    );
    Projeto__c projeto = (Projeto__c) TestFactory.createSObject(
      new Projeto__c(
        Name = 'Projeto Instalacao Test',
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

    // INSERT direto no status de conclusão sem TestFactory (evita MALFORMED_ID em ConsultorInstalacao__c)
    Instalacao__c inst = new Instalacao__c(
      Projeto__c = projeto.Id,
      Oportunidade__c = opp.Id,
      Status__c = 'Obra concluída - Aguardando troca de medidor'
    );
    insert inst;

    Assert.isNull(
      [SELECT DataConclusao__c FROM Instalacao__c WHERE Id = :inst.Id]
      .DataConclusao__c,
      'DataConclusao__c deve estar null antes do batch'
    );

    // Chamar execute diretamente para isolar de triggers
    Test.startTest();
    EngineeringDateBackfillBatch batch = new EngineeringDateBackfillBatch(
      'Instalacao'
    );
    List<SObject> scope = [
      SELECT Id, LastModifiedDate
      FROM Instalacao__c
      WHERE Id = :inst.Id
    ];
    batch.execute(null, scope);
    Test.stopTest();

    Instalacao__c result = [
      SELECT DataConclusao__c
      FROM Instalacao__c
      WHERE Id = :inst.Id
    ];
    Assert.isNotNull(
      result.DataConclusao__c,
      'Batch deve preencher DataConclusao__c'
    );
  }

  @IsTest
  static void shouldBeIdempotent() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = createOpportunity(account, createPartner());

    ViabilityStudy__c vs = (ViabilityStudy__c) TestFactory.createSObject(
      new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro',
        StatusFeasibility__c = 'Viabilidade Finalizada'
      ),
      true
    );

    // Primeira execução — preenche o campo
    Test.startTest();
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ViabilityStudy'),
      200
    );
    Test.stopTest();

    Date firstRun = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ]
    .DataConclusaoViabilidade__c;
    Assert.isNotNull(firstRun, 'Primeira execução deve preencher a data');

    // Segunda execução — registro já tem data, não é retornado pela query (filtro DataConclusaoViabilidade__c = null)
    Test.startTest();
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ViabilityStudy'),
      200
    );
    Test.stopTest();

    Date secondRun = [
      SELECT DataConclusaoViabilidade__c
      FROM ViabilityStudy__c
      WHERE Id = :vs.Id
    ]
    .DataConclusaoViabilidade__c;
    Assert.areEqual(
      firstRun,
      secondRun,
      'Segunda execução não deve alterar data já preenchida'
    );
  }

  @IsTest
  static void shouldHandleEmptyOrg() {
    Test.startTest();
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ViabilityStudy'),
      200
    );
    Database.executeBatch(
      new EngineeringDateBackfillBatch('ProjetoProtocol'),
      200
    );
    Database.executeBatch(new EngineeringDateBackfillBatch('Instalacao'), 200);
    Test.stopTest();

    Assert.isTrue(true, 'Batch deve completar sem erros com org vazio');
  }

  @IsTest
  static void shouldThrowOnInvalidMode() {
    Boolean exceptionThrown = false;
    try {
      EngineeringDateBackfillBatch batch = new EngineeringDateBackfillBatch(
        'InvalidMode'
      );
      batch.start(null);
    } catch (IllegalArgumentException e) {
      exceptionThrown = true;
    }
    Assert.isTrue(
      exceptionThrown,
      'Modo inválido deve lançar IllegalArgumentException'
    );
  }
}
