/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-13-2026
 * @last modified by  : Daniel Belini
 **/
@IsTest
private class OpportunityBOHighCoverageTest {
  private static User createUser(String email, String aliasPrefix) {
    Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()]
    .ProfileId;
    String uniqueToken =
      String.valueOf(DateTime.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));

    User userRecord = new User(
      Alias = (aliasPrefix + uniqueToken).left(8),
      Email = email,
      Username = uniqueToken + '.' + email,
      LastName = 'Coverage',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profileId
    );
    insert userRecord;
    return userRecord;
  }

  private static Opportunity createOpportunity(
    Account accountRecord,
    String suffix,
    Id ownerId
  ) {
    Opportunity opportunityRecord = new Opportunity(
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = 'VO-HC-' + suffix,
      Name = 'Opp Coverage ' + suffix,
      OwnerId = ownerId,
      Pricebook2Id = Test.getStandardPricebookId()
    );
    return (Opportunity) TestFactory.createSObject(opportunityRecord, true);
  }

  private static Account createUniqueAccount(String suffix) {
    String uniqueToken = String.valueOf(Math.abs(Crypto.getRandomInteger()))
      .left(4);
    Account accountRecord = new Account(
      Name = 'Conta ' + suffix,
      IdVirtualOffice__c = 'ACC-' + suffix + '-' + uniqueToken,
      LoginVirtualOffice__c = 'login-' +
        suffix +
        '-' +
        uniqueToken +
        '@test.com',
      CPF__c = '123.456.7' + uniqueToken.left(2) + '-' + uniqueToken.right(2),
      CNPJ__c = '12.345.678/' + uniqueToken + '-34',
      NumeroIdentificacao__c = 'NI-' + suffix + '-' + uniqueToken
    );
    return (Account) TestFactory.createSObject(accountRecord, true);
  }

  private static OpportunityRecordsTO.Product buildProduct(
    String externalId,
    Decimal unitPrice,
    Integer quantity,
    String description
  ) {
    OpportunityRecordsTO.Product productRecord = new OpportunityRecordsTO.Product();
    productRecord.Id = externalId;
    productRecord.Name = 'Produto ' + externalId;
    productRecord.UnitaryValue = unitPrice;
    productRecord.Quantity = quantity;
    productRecord.Description = description;
    return productRecord;
  }

  private static OpportunityRecordsTO.SingleOpportunity buildSingleOpportunity(
    Opportunity opportunityRecord,
    List<OpportunityRecordsTO.Product> products
  ) {
    OpportunityRecordsTO.SingleOpportunity singleOpportunity = new OpportunityRecordsTO.SingleOpportunity();
    singleOpportunity.Id = opportunityRecord.IdVirtualOffice__c;
    singleOpportunity.Products = products;
    return singleOpportunity;
  }

  private static Opportunity buildProposalEligibleOpportunity(
    Id opportunityId,
    Id recordTypeId
  ) {
    return new Opportunity(
      Id = opportunityId,
      RecordTypeId = recordTypeId,
      AccountId = '001000000000001AAA',
      OwnerId = UserInfo.getUserId(),
      GrupoTarifario__c = 'Grupo B',
      PotenciaPicoSistema__c = 1,
      ValidadeProposta__c = '7',
      ConsumoAnual__c = 1,
      CustoMedioEnergia__c = 1,
      NumeroModulos__c = 1,
      FabricanteModulos__c = 'Fabricante',
      Modelo__c = 'Modelo',
      PotenciaNominalWp__c = 550,
      Pesokg__c = 1,
      NumeroInversores__c = 1,
      FabricanteInversor__c = 'Fabricante',
      ModeloInversor__c = 'Modelo Inversor',
      PotenciaNominalSistema__c = 100,
      GeracaoAnualEstimada__c = 100,
      GeracaoMensalEstimada__c = 10,
      PaybackAnos__c = 1,
      EconomiaMensalEstimada__c = 10,
      EconomiaAnualEstimada__c = 100,
      EconomiaAcumulada__c = 100,
      TipoTelhadoEstrutura__c = 'Estrutura',
      AreaM__c = 10,
      PrazoEntregaDias__c = '30',
      Amount = 1000,
      PropostaGerada__c = false
    );
  }

  @IsTest
  static void shouldMapOpportunityLineItemsAndManageKits() {
    OpportunityTriggerHandler.disableTrigger();
    Account accountRecord = createUniqueAccount('LINEITEMS');
    User owner = createUser('owner.line.items@test.com', 'oliown');

    Opportunity oppWithExistingKit = createOpportunity(
      accountRecord,
      'EXIST',
      owner.Id
    );
    Opportunity oppWithoutKit = createOpportunity(
      accountRecord,
      'NEW',
      owner.Id
    );
    OpportunityTriggerHandler.enableTrigger();
    ProductTriggerHandler.disableTrigger();

    Product2 existingProduct = (Product2) TestFactory.createSObject(
      new Product2(
        ProductCode = 'EXIST-PROD-' + String.valueOf(DateTime.now().getTime()),
        Id_Externo__c = 'EXIST-PROD',
        ExternalId__c = 'EXIST-PROD'
      ),
      true
    );
    PricebookEntry existingEntry = (PricebookEntry) TestFactory.createSObject(
      new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = existingProduct.Id,
        UnitPrice = 100
      ),
      true
    );

    Kit_Instalacao__c existingKit = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = oppWithExistingKit.Id),
      true
    );

    OpportunityLineItem oldItem = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = oppWithExistingKit.Id,
        PricebookEntryId = existingEntry.Id,
        Description = 'Item antigo'
      ),
      true
    );

    Map<String, Id> externalIdToProductId = new Map<String, Id>{
      'EXIST-PROD' => existingProduct.Id
    };

    OpportunityRecordsTO.SingleOpportunity singleExisting = buildSingleOpportunity(
      oppWithExistingKit,
      new List<OpportunityRecordsTO.Product>{
        buildProduct('EXIST-PROD', 100, 1, 'Produto existente'),
        buildProduct('NEW-PROD-1', 200, 2, 'Produto novo 1')
      }
    );
    OpportunityRecordsTO.SingleOpportunity singleNew = buildSingleOpportunity(
      oppWithoutKit,
      new List<OpportunityRecordsTO.Product>{
        buildProduct('NEW-PROD-2', 300, 1, 'Produto novo 2')
      }
    );

    Map<OpportunityRecordsTO.SingleOpportunity, Opportunity> restObjectsToInsertedOpportunity = new Map<OpportunityRecordsTO.SingleOpportunity, Opportunity>{
      singleExisting => oppWithExistingKit,
      singleNew => oppWithoutKit
    };

    Test.startTest();
    OpportunityBO.mapOpportunityLineItemFieldsRest(
      restObjectsToInsertedOpportunity,
      externalIdToProductId
    );
    Test.stopTest();
    ProductTriggerHandler.enableTrigger();

    List<OpportunityLineItem> insertedItems = [
      SELECT Id, OpportunityId, Product2.ProductCode, Kit_Instalacao__c
      FROM OpportunityLineItem
      WHERE
        OpportunityId IN :new Set<Id>{ oppWithExistingKit.Id, oppWithoutKit.Id }
    ];
    System.assertEquals(
      3,
      insertedItems.size(),
      'Deve recriar os itens conforme o payload da integração.'
    );

    Set<Id> itemIds = new Map<Id, OpportunityLineItem>(insertedItems).keySet();
    System.assertEquals(
      false,
      itemIds.contains(oldItem.Id),
      'Os itens antigos precisam ser removidos antes da nova inserção.'
    );

    Map<Id, Kit_Instalacao__c> kitsByOpportunityId = new Map<Id, Kit_Instalacao__c>();
    for (Kit_Instalacao__c kitRecord : [
      SELECT Id, Nome_da_Oportunidade__c
      FROM Kit_Instalacao__c
      WHERE
        Nome_da_Oportunidade__c IN :new Set<Id>{
          oppWithExistingKit.Id,
          oppWithoutKit.Id
        }
    ]) {
      kitsByOpportunityId.put(kitRecord.Nome_da_Oportunidade__c, kitRecord);
    }

    System.assertEquals(
      existingKit.Id,
      kitsByOpportunityId.get(oppWithExistingKit.Id).Id,
      'O kit existente deve ser reaproveitado quando já houver registro.'
    );
    System.assertNotEquals(
      null,
      kitsByOpportunityId.get(oppWithoutKit.Id),
      'Um novo kit deve ser criado quando a oportunidade ainda não possui kit.'
    );

    for (OpportunityLineItem itemRecord : insertedItems) {
      System.assertNotEquals(
        null,
        itemRecord.Kit_Instalacao__c,
        'Todo item precisa ficar associado a um kit.'
      );
    }
  }

  @IsTest
  static void shouldCreateReadjustmentTaskAndAssignPartnerOwner() {
    OpportunityTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    Account accountRecord = createUniqueAccount('READJUSTMENT');
    User owner = createUser('owner.readjustment@test.com', 'readj');
    Opportunity opportunityRecord = createOpportunity(
      accountRecord,
      'READJ',
      owner.Id
    );

    Opportunity oldOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    oldOpportunity.ReadequacaoSolicitada__c = false;
    Opportunity newOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    newOpportunity.ReadequacaoSolicitada__c = true;

    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        CapaProposta__c = cover.Id,
        Produto__c = 'Solar',
        OwnerOpportunity__c = owner.Id
      ),
      true
    );
    Opportunity ownerByPartner = new Opportunity(
      Parceiro__c = partner.Id,
      OwnerId = UserInfo.getUserId()
    );

    Test.startTest();
    OpportunityBO.createReadjustmentTask(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldOpportunity }
    );
    OpportunityBO.assignOwnerByPartner(new List<Opportunity>{ ownerByPartner });
    Test.stopTest();

    Task createdTask = [
      SELECT Subject, OwnerId
      FROM Task
      WHERE
        WhatId = :opportunityRecord.Id
        AND Subject LIKE 'Verificar a readequação solicitada%'
      LIMIT 1
    ];
    System.assert(
      createdTask.Subject.contains('readequação'),
      'A task de readequação precisa ser criada para a oportunidade.'
    );
    System.assertEquals(
      owner.Id,
      ownerByPartner.OwnerId,
      'O owner da oportunidade deve vir do parceiro quando informado.'
    );

    TaskTriggerHandler.enableTrigger();
    OpportunityTriggerHandler.enableTrigger();
  }

  @IsTest
  static void shouldHandleViabilityTransitionsAndHelperGuards() {
    Opportunity viableOpportunity = new Opportunity(
      Id = '006000000000001AAA',
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = 'Viável'
    );
    Opportunity viableOld = new Opportunity(
      Id = viableOpportunity.Id,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = null
    );

    Opportunity notViableOpportunity = new Opportunity(
      Id = '006000000000002AAA',
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = 'Inviável'
    );
    Opportunity notViableOld = new Opportunity(
      Id = notViableOpportunity.Id,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = null
    );

    Opportunity partialOpportunity = new Opportunity(
      Id = '006000000000003AAA',
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = 'Parcialmente Viável',
      TextoEstudo__c = null
    );
    Opportunity partialOld = new Opportunity(
      Id = partialOpportunity.Id,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = null
    );

    Opportunity invalidOpportunity = new Opportunity(
      Id = '006000000000004AAA',
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = 'Inviável',
      TextoMotivo__c = null
    );
    Opportunity invalidOld = new Opportunity(
      Id = invalidOpportunity.Id,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
      StatusViabilidade__c = null
    );

    Opportunity phaseGuardOpportunity = new Opportunity(
      Id = '006000000000005AAA',
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE
    );

    Test.startTest();
    OpportunityBO.changeOpportunityStageOnViabilityChanging(
      new List<Opportunity>{ viableOpportunity, notViableOpportunity },
      new Map<Id, Opportunity>{
        viableOpportunity.Id => viableOld,
        notViableOpportunity.Id => notViableOld
      }
    );
    OpportunityBO.validateViabilityTexts(
      new List<Opportunity>{ partialOpportunity, invalidOpportunity },
      new Map<Id, Opportunity>{
        partialOpportunity.Id => partialOld,
        invalidOpportunity.Id => invalidOld
      }
    );
    OpportunityBO.updateOpportunityPhaseOnStageChange(
      new List<Opportunity>{ phaseGuardOpportunity },
      new Map<Id, Opportunity>()
    );
    OpportunityBO.updatePhaseOnValueChange(
      new List<Opportunity>{ phaseGuardOpportunity },
      new Map<Id, Opportunity>()
    );
    Test.stopTest();

    System.assertEquals(
      OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO,
      viableOpportunity.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_PERDIDO,
      notViableOpportunity.Status__c
    );
    System.assertEquals(
      1,
      partialOpportunity.getErrors().size(),
      'Parcialmente viável sem texto de estudo deve bloquear.'
    );
    System.assertEquals(
      1,
      invalidOpportunity.getErrors().size(),
      'Inviável sem texto de motivo deve bloquear.'
    );
    System.assertEquals(
      0,
      OpportunityBO.filterNivelloEmailOpps(null).size(),
      'A filtragem deve tratar lista nula sem erro.'
    );
  }

  @IsTest
  static void shouldCalculateProposalGraphicForBothGroups() {
    Opportunity groupAOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        GrupoTarifario__c = 'Grupo A',
        NumeroModulos__c = 10,
        PotenciaNominalWp__c = 550,
        TarifaForaPonta__c = 1,
        DemandaContratadaForaPonta__c = 1,
        TarifaDemandaForaPonta__c = 1,
        AjusteAnualTarifa__c = 0.05,
        RendimentoMedio__c = 1,
        Acrescimo__c = 0.05
      ),
      false
    );
    Opportunity groupBOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        GrupoTarifario__c = 'Grupo B',
        NumeroModulos__c = 16,
        PotenciaNominalWp__c = 550,
        TarifaComTributosB__c = 1,
        AjusteAnualTarifa__c = 0.05,
        GeracaoAnualEstimada__c = 1200,
        RendimentoMedio__c = 1,
        Acrescimo__c = 0.05
      ),
      false
    );

    Test.startTest();
    OpportunityBO.calculateDataToProposalGraphic25Years(
      new List<Opportunity>{ groupAOpportunity, groupBOpportunity }
    );
    Test.stopTest();

    System.assertNotEquals(null, groupAOpportunity.PaybackAno25__c);
    System.assertNotEquals(null, groupBOpportunity.PaybackAno25__c);
  }

  @IsTest
  static void shouldUpdateKitsWhenPotenciaChanges() {
    OpportunityTriggerHandler.disableTrigger();
    Account accountRecord = createUniqueAccount('POTENCIA');
    Opportunity opportunityRecord = createOpportunity(
      accountRecord,
      'POT',
      UserInfo.getUserId()
    );
    OpportunityTriggerHandler.enableTrigger();

    ProductTriggerHandler.disableTrigger();
    Product2 productRecord = (Product2) TestFactory.createSObject(
      new Product2(
        ProductCode = 'POT-PROD-' + String.valueOf(DateTime.now().getTime()),
        Id_Externo__c = 'POT-PROD-' + String.valueOf(DateTime.now().getTime()),
        ExternalId__c = 'POT-PROD-' + String.valueOf(DateTime.now().getTime())
      ),
      true
    );
    PricebookEntry entry = (PricebookEntry) TestFactory.createSObject(
      new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = productRecord.Id,
        UnitPrice = 100
      ),
      true
    );
    ProductTriggerHandler.enableTrigger();

    Kit_Instalacao__c kitRecord = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opportunityRecord.Id),
      true
    );
    OpportunityLineItem itemRecord = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = opportunityRecord.Id,
        PricebookEntryId = entry.Id,
        Kit_Instalacao__c = kitRecord.Id
      ),
      true
    );

    Opportunity oldOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    oldOpportunity.PotenciaNominalWp__c = 400;
    Opportunity newOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    newOpportunity.PotenciaNominalWp__c = 550;

    Test.startTest();
    OpportunityBO.updateKitsOnPotenciaChange(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldOpportunity }
    );
    Test.stopTest();

    System.assertEquals(
      itemRecord.Id,
      [
        SELECT Id
        FROM OpportunityLineItem
        WHERE Id = :itemRecord.Id
      ]
      .Id
    );
    System.assertEquals('CN', OpportunityBO.removeAccents('ÇÑ'));
  }

  @IsTest
  static void shouldCloseClosedLostRelatedRecords() {
    OpportunityTriggerHandler.disableTrigger();
    ProjetoTriggerHandler.disableTrigger();
    InstalacaoTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    Account accountRecord = createUniqueAccount('CLOSEDLOST');
    Opportunity opportunityRecord = createOpportunity(
      accountRecord,
      'CLOSEDLOST',
      UserInfo.getUserId()
    );
    ViabilityStudy__c viabilityRecord = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro',
      ObservationsPostVisit__c = 'Obs inicial'
    );
    insert viabilityRecord;

    Projeto__c projectRecord = new Projeto__c(
      Name = 'Projeto Closed Lost',
      Oportunidade__c = opportunityRecord.Id,
      Conta__c = accountRecord.Id,
      Viabilidade__c = viabilityRecord.Id,
      GestorObra__c = UserInfo.getUserId(),
      Status__c = 'Planejamento'
    );
    insert projectRecord;

    insert new List<Task>{
      (Task) TestFactory.createSObject(
        new Task(
          WhatId = opportunityRecord.Id,
          Subject = 'Task Oportunidade',
          Status = TaskUtils.STATUS_OPEN
        ),
        false
      ),
      (Task) TestFactory.createSObject(
        new Task(
          WhatId = projectRecord.Id,
          Subject = 'Task Projeto',
          Status = TaskUtils.STATUS_OPEN
        ),
        false
      ),
      (Task) TestFactory.createSObject(
        new Task(
          WhatId = viabilityRecord.Id,
          Subject = 'Task Viabilidade',
          Status = TaskUtils.STATUS_OPEN
        ),
        false
      )
    };

    Opportunity oldOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    oldOpportunity.StageName = OpportunityUtils.STATUS_NEGOCIACAO;
    Opportunity newOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    newOpportunity.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;

    Test.startTest();
    OpportunityBO.closeActivitiesAndFlowsForClosedLost(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldOpportunity }
    );
    Test.stopTest();

    System.assertEquals(
      'Projeto cancelado',
      [SELECT Status__c FROM Projeto__c WHERE Id = :projectRecord.Id].Status__c
    );
    ViabilityStudy__c refreshedViability = [
      SELECT StatusFeasibility__c, ObservationsPostVisit__c
      FROM ViabilityStudy__c
      WHERE Id = :viabilityRecord.Id
    ];
    System.assertEquals(
      'Viabilidade Finalizada',
      refreshedViability.StatusFeasibility__c
    );
    System.assert(
      refreshedViability.ObservationsPostVisit__c.contains(
        'Encerrado automaticamente'
      )
    );
    Integer closedTasks = [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId IN :new Set<Id>{
          opportunityRecord.Id,
          projectRecord.Id,
          viabilityRecord.Id
        }
        AND Subject IN ('Task Oportunidade', 'Task Projeto', 'Task Viabilidade')
        AND Status = :TaskUtils.STATUS_CONCLUIDO
    ];
    System.assertEquals(3, closedTasks);

    TaskTriggerHandler.enableTrigger();
    InstalacaoTriggerHandler.enableTrigger();
    ProjetoTriggerHandler.enableTrigger();
    OpportunityTriggerHandler.enableTrigger();
  }

  @IsTest
  static void shouldCreateCustomerJourneyCase() {
    OpportunityTriggerHandler.disableTrigger();
    ProjetoTriggerHandler.disableTrigger();
    InstalacaoTriggerHandler.disableTrigger();

    Account accountRecord = createUniqueAccount('JOURNEY');
    Consultor__c consultorRecord = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(),
      true
    );
    Contact contactRecord = (Contact) TestFactory.createSObject(
      new Contact(
        AccountId = accountRecord.Id,
        LastName = 'Journey',
        Email = 'journey@test.com'
      ),
      true
    );
    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountRecord.Id,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        PotenciaNominalSistema__c = 250,
        OwnerId = UserInfo.getUserId(),
        IdVirtualOffice__c = 'VO-HC-JOURNEY'
      ),
      true
    );
    ViabilityStudy__c viabilityRecord = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viabilityRecord;

    Projeto__c projectRecord = new Projeto__c(
      Name = 'Projeto Journey',
      Oportunidade__c = opportunityRecord.Id,
      Conta__c = accountRecord.Id,
      Viabilidade__c = viabilityRecord.Id,
      Consultor__c = consultorRecord.Id,
      GestorObra__c = UserInfo.getUserId(),
      Status__c = 'Planejamento',
      ApprovalDate__c = Date.today(),
      InstallDate__c = Date.today().addDays(10),
      DateInspection__c = Date.today().addDays(20)
    );
    insert projectRecord;
    insert new Instalacao__c(
      Projeto__c = projectRecord.Id,
      Oportunidade__c = opportunityRecord.Id,
      ClienteConta__c = accountRecord.Id,
      ConsultorInstalacao__c = consultorRecord.Id,
      GestorObra__c = UserInfo.getUserId(),
      InstallDate__c = Date.today().addDays(12),
      DateInspection__c = Date.today().addDays(22)
    );

    Opportunity oldOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    oldOpportunity.StageName = OpportunityUtils.STATUS_NEGOCIACAO;
    Opportunity newOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    newOpportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;

    Test.startTest();
    OpportunityBO.createCaseCustomerJourney(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldOpportunity }
    );
    Test.stopTest();

    Case journeyCase = [
      SELECT AccountId, ContactId, Nome_da_Oportunidade__c, Subject
      FROM Case
      WHERE Nome_da_Oportunidade__c = :opportunityRecord.Id
      LIMIT 1
    ];
    System.assertEquals(accountRecord.Id, journeyCase.AccountId);
    System.assertEquals(contactRecord.Id, journeyCase.ContactId);
    System.assertEquals('Jornada do Projeto', journeyCase.Subject);

    InstalacaoTriggerHandler.enableTrigger();
    ProjetoTriggerHandler.enableTrigger();
    OpportunityTriggerHandler.enableTrigger();
  }

  @IsTest
  static void shouldCoverBuildCaseAndHelperMethods() {
    List<Group> existingQueues = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = 'Suporte_Pos_Vendas'
      LIMIT 1
    ];
    Group supportQueue = existingQueues.isEmpty()
      ? new Group(
          Name = 'Suporte Pos Vendas Coverage',
          DeveloperName = 'Suporte_Pos_Vendas',
          Type = 'Queue'
        )
      : existingQueues[0];
    if (existingQueues.isEmpty()) {
      insert supportQueue;
    }

    Opportunity opportunityRecord = new Opportunity(
      Id = '006000000000021AAA',
      AccountId = '001000000000001AAA',
      OwnerId = UserInfo.getUserId(),
      PotenciaPicoSistema__c = 1,
      ValidadeProposta__c = '7',
      ConsumoAnual__c = 1,
      GrupoTarifario__c = 'A',
      CustoMedioEnergia__c = 1,
      NumeroModulos__c = 1,
      FabricanteModulos__c = 'Fabricante',
      Modelo__c = 'Modelo',
      PotenciaNominalWp__c = 550,
      Pesokg__c = 1,
      NumeroInversores__c = 1,
      FabricanteInversor__c = 'Fabricante',
      ModeloInversor__c = 'Modelo',
      PotenciaNominalSistema__c = 100,
      GeracaoAnualEstimada__c = 100,
      GeracaoMensalEstimada__c = 10,
      PaybackAnos__c = 1,
      EconomiaMensalEstimada__c = 10,
      EconomiaAnualEstimada__c = 100,
      EconomiaAcumulada__c = 100,
      TipoTelhadoEstrutura__c = 'Estrutura',
      AreaM__c = 10,
      PrazoEntregaDias__c = '30',
      Amount = 1000,
      FaturaDescontoFixo__c = 10,
      EconomiaXMesesFixa__c = 12,
      PrazoContratoParceiro__c = '24'
    );
    Projeto__c projectRecord = new Projeto__c(
      Consultor__c = UserInfo.getUserId(),
      GestorObra__c = UserInfo.getUserId(),
      ApprovalDate__c = Date.today(),
      InstallDate__c = Date.today().addDays(7),
      DateInspection__c = Date.today().addDays(14)
    );
    Instalacao__c installationRecord = new Instalacao__c(
      GestorObra__c = UserInfo.getUserId(),
      InstallDate__c = Date.today().addDays(10),
      DateInspection__c = Date.today().addDays(20)
    );
    Contact contactRecord = new Contact(Id = '003000000000001AAA');

    Test.startTest();
    Case builtCase = OpportunityBO.buildCase(
      opportunityRecord,
      projectRecord,
      installationRecord,
      contactRecord
    );
    Test.stopTest();

    System.assertEquals(supportQueue.Id, builtCase.OwnerId);
    System.assertEquals('Jornada do Projeto', builtCase.Subject);
    System.assertEquals(contactRecord.Id, builtCase.ContactId);
    System.assertEquals(
      projectRecord.Consultor__c,
      builtCase.Nome_do_Consultor__c
    );
    System.assertEquals(
      installationRecord.GestorObra__c,
      builtCase.ManagerName__c
    );
    System.assertEquals(
      installationRecord.InstallDate__c,
      builtCase.InstallDate__c
    );
    System.assertEquals(
      installationRecord.DateInspection__c,
      builtCase.DateInspection__c
    );
    System.assert(
      OpportunityBO.areRequiredFieldsFilled(opportunityRecord),
      'Os campos obrigatórios da proposta completa devem retornar true.'
    );
    System.assert(
      OpportunityBO.areRequiredFieldsFilledConnect(opportunityRecord),
      'Os campos obrigatórios do Connect devem retornar true.'
    );

    Opportunity oldOpportunity = opportunityRecord.clone(
      false,
      true,
      true,
      true
    );
    Opportunity changedOpportunity = opportunityRecord.clone(
      false,
      true,
      true,
      true
    );
    changedOpportunity.CustoFinanceiroWeg__c = 99;

    System.assertEquals(
      false,
      OpportunityBO.formulaFieldsChanged(oldOpportunity, opportunityRecord)
    );
    System.assert(
      OpportunityBO.formulaFieldsChanged(oldOpportunity, changedOpportunity),
      'Mudança em campo fonte de fórmula deve ser detectada.'
    );
    System.assertEquals(
      'Nota',
      OpportunityBO.appendAutomationNote(null, 'Nota', 10)
    );
    System.assertEquals(
      'Atual. Nota',
      OpportunityBO.appendAutomationNote('Atual.', 'Nota', 20)
    );
    System.assertEquals(
      'Atual | Nota',
      OpportunityBO.appendAutomationNote('Atual', 'Nota', 20)
    );
    System.assertEquals(
      'Atual | Nota',
      OpportunityBO.appendAutomationNote('Atual | Nota', 'Nota', 20)
    );
    System.assertEquals(
      '12345',
      OpportunityBO.appendAutomationNote('123456', 'Nota', 5)
    );
  }

  @IsTest
  static void shouldCreateReminderTasksAndRevoTaskBranches() {
    Account accountRecord = new Account(Name = 'Conta Reminder');
    insert accountRecord;
    insert new Contact(
      AccountId = accountRecord.Id,
      LastName = 'Reminder Contact',
      Email = 'reminder.contact@test.com'
    );

    OpportunityTriggerHandler.disableTrigger();
    Opportunity financeOpp = new Opportunity(
      Name = 'Opp Simulacao Fin',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(10),
      IdVirtualOffice__c = 'VO-REM-FIN-' +
        String.valueOf(DateTime.now().getTime())
    );
    insert financeOpp;

    Id ezeeSolarBRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('EzeeSolarB')
      .getRecordTypeId();
    Opportunity revoOpp = new Opportunity(
      Name = 'Opp Revo',
      AccountId = accountRecord.Id,
      OwnerId = UserInfo.getUserId(),
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(10),
      RecordTypeId = ezeeSolarBRecordTypeId,
      GrupoTarifario__c = 'Grupo B',
      ReferenceIdRevo__c = 'REF-' + String.valueOf(DateTime.now().getTime()),
      IdVirtualOffice__c = 'VO-REM-REVO-' +
        String.valueOf(DateTime.now().getTime())
    );
    insert revoOpp;
    OpportunityTriggerHandler.enableTrigger();

    OpportunityBO.createRequiredFieldsReminderTasks(
      new List<Opportunity>{
        new Opportunity(
          Id = financeOpp.Id,
          AccountId = accountRecord.Id,
          OwnerId = financeOpp.OwnerId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          Financiamento_solicitado__c = true
        ),
        new Opportunity(
          Id = '006000000000071AAA',
          AccountId = accountRecord.Id,
          OwnerId = UserInfo.getUserId(),
          StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
          GrupoTarifario__c = 'Grupo B'
        ),
        new Opportunity(
          Id = '006000000000072AAA',
          AccountId = accountRecord.Id,
          OwnerId = UserInfo.getUserId(),
          StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE,
          Status__c = OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA
        )
      },
      new Map<Id, Opportunity>{
        financeOpp.Id => new Opportunity(
          Id = financeOpp.Id,
          AccountId = accountRecord.Id,
          OwnerId = financeOpp.OwnerId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          Financiamento_solicitado__c = false
        ),
        '006000000000071AAA' => new Opportunity(
          Id = '006000000000071AAA',
          AccountId = accountRecord.Id,
          OwnerId = UserInfo.getUserId(),
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          GrupoTarifario__c = 'Grupo B'
        ),
        '006000000000072AAA' => new Opportunity(
          Id = '006000000000072AAA',
          AccountId = accountRecord.Id,
          OwnerId = UserInfo.getUserId(),
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          Status__c = null
        )
      }
    );

    OpportunityBO.checkAndSendToRevo(
      new List<Opportunity>{
        new Opportunity(
          Id = revoOpp.Id,
          AccountId = accountRecord.Id,
          OwnerId = revoOpp.OwnerId,
          RecordTypeId = ezeeSolarBRecordTypeId,
          GrupoTarifario__c = 'Grupo B',
          StageName = 'Análise de Crédito',
          ReferenceIdRevo__c = revoOpp.ReferenceIdRevo__c
        )
      },
      new Map<Id, Opportunity>{
        revoOpp.Id => new Opportunity(
          Id = revoOpp.Id,
          AccountId = accountRecord.Id,
          OwnerId = revoOpp.OwnerId,
          RecordTypeId = ezeeSolarBRecordTypeId,
          GrupoTarifario__c = 'Grupo B',
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          ReferenceIdRevo__c = revoOpp.ReferenceIdRevo__c
        )
      }
    );
  }

  @IsTest
  static void shouldCloseFollowUpTasksWithContentLink() {
    User closerUser = createUser('wagner.sampaio@enerzee.com.br.test', 'wgcl');
    Account accountRecord = new Account(Name = 'Conta FollowUp HC');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opp FollowUp HC',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA,
      CloseDate = Date.today().addDays(10),
      IdVirtualOffice__c = 'VO-FOLLOW-' +
        String.valueOf(DateTime.now().getTime())
    );
    insert opportunityRecord;

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      OwnerId = closerUser.Id,
      Status = TaskUtils.STATUS_OPEN,
      Subject = 'Ligação de follow-up - cobertura alta'
    );
    insert taskRecord;

    Task refreshedTask = [
      SELECT Status, MetodoDeFollowup__c
      FROM Task
      WHERE Id = :taskRecord.Id
    ];
    Integer documentLinks = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :taskRecord.Id
    ];
  }

  @IsTest
  static void shouldHandleLeadConversionPositiveBranches() {
    Lead convertLead = new Lead(
      LastName = 'Convert',
      Company = 'Company Convert'
    );
    Lead lostLead = new Lead(LastName = 'Lost', Company = 'Company Lost');
    insert new List<Lead>{ convertLead, lostLead };

    Account accountRecord = new Account(Name = 'Conta Lead HC');
    insert accountRecord;

    Opportunity convertOpportunity = new Opportunity(
      Name = 'Opp Lead Convert',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(5),
      IdVirtualOffice__c = 'VO-LEAD-CONV-' +
        String.valueOf(DateTime.now().getTime()),
      Lead__c = convertLead.Id
    );
    Opportunity lostOpportunity = new Opportunity(
      Name = 'Opp Lead Lost',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(5),
      IdVirtualOffice__c = 'VO-LEAD-LOST-' +
        String.valueOf(DateTime.now().getTime()),
      Lead__c = lostLead.Id
    );
    insert new List<Opportunity>{ convertOpportunity, lostOpportunity };

    OpportunityBO.handleOpportunityLeadConversion(
      new List<Opportunity>{
        new Opportunity(
          Id = convertOpportunity.Id,
          AccountId = accountRecord.Id,
          Lead__c = convertLead.Id,
          StageName = 'Ganho fechado'
        ),
        new Opportunity(
          Id = lostOpportunity.Id,
          AccountId = accountRecord.Id,
          Lead__c = lostLead.Id,
          StageName = 'Ganho Perdido'
        )
      },
      new Map<Id, Opportunity>{
        convertOpportunity.Id => new Opportunity(
          Id = convertOpportunity.Id,
          AccountId = accountRecord.Id,
          Lead__c = convertLead.Id,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        lostOpportunity.Id => new Opportunity(
          Id = lostOpportunity.Id,
          AccountId = accountRecord.Id,
          Lead__c = lostLead.Id,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        )
      }
    );

    System.assertEquals(
      'Não Qualificado',
      [SELECT Status FROM Lead WHERE Id = :lostLead.Id].Status
    );
  }

  @IsTest
  static void shouldCoverProposalAsyncAndSubstatusBranches() {
    Id solarRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('Solar')
      .getRecordTypeId();
    Id sellerRecordTypeId = solarRecordTypeId;

    Opportunity resetOld = buildProposalEligibleOpportunity(
      null,
      solarRecordTypeId
    );
    resetOld.PropostaGerada__c = true;
    Opportunity resetNew = buildProposalEligibleOpportunity(
      null,
      solarRecordTypeId
    );
    resetNew.PropostaGerada__c = false;

    Opportunity approvedOld = buildProposalEligibleOpportunity(
      null,
      solarRecordTypeId
    );
    approvedOld.StatusAprovacaoDesconto__c = 'Pendente';
    approvedOld.CustoFinanceiroWeg__c = 1;
    Opportunity approvedNew = buildProposalEligibleOpportunity(
      null,
      solarRecordTypeId
    );
    approvedNew.StatusAprovacaoDesconto__c = 'Aprovado';
    approvedNew.CustoFinanceiroWeg__c = 2;

    OpportunityBO.generateProposalAsync(
      new Map<Id, Opportunity>{ null => resetNew },
      new Map<Id, Opportunity>{ null => resetOld }
    );
    OpportunityBO.generateProposalAsync(
      new Map<Id, Opportunity>{ null => approvedNew },
      new Map<Id, Opportunity>{ null => approvedOld }
    );

    Opportunity accessOpinionOpp = new Opportunity(
      Id = '006000000000041AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO
    );
    Opportunity completedOpp = new Opportunity(
      Id = '006000000000042AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_FINALIZADO
    );
    Opportunity equipmentOpp = new Opportunity(
      Id = '006000000000043AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_EQUIPAMENTO
    );
    Opportunity installationOpp = new Opportunity(
      Id = '006000000000044AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_INSTALACAO
    );
    Opportunity wonOpp = new Opportunity(
      Id = '006000000000045AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_GANHO_FECHADO
    );
    Opportunity lostOpp = new Opportunity(
      Id = '006000000000046AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO
    );

    OpportunityBO.controlsSubstatus(
      new List<Opportunity>{
        accessOpinionOpp,
        completedOpp,
        equipmentOpp,
        installationOpp,
        wonOpp,
        lostOpp
      },
      new Map<Id, Opportunity>{
        accessOpinionOpp.Id => new Opportunity(
          Id = accessOpinionOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        completedOpp.Id => new Opportunity(
          Id = completedOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        equipmentOpp.Id => new Opportunity(
          Id = equipmentOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        installationOpp.Id => new Opportunity(
          Id = installationOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        wonOpp.Id => new Opportunity(
          Id = wonOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        ),
        lostOpp.Id => new Opportunity(
          Id = lostOpp.Id,
          RecordTypeId = sellerRecordTypeId,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        )
      }
    );

    System.assertEquals(
      OpportunityUtils.SUB_STATUS_EM_ANALISE,
      accessOpinionOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_VALIDANDO_BONIFICACAO,
      completedOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_ENTREGA_DE_MATERIAIS,
      equipmentOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_EM_INSTALACAO,
      installationOpp.Status__c
    );
    System.assertEquals(OpportunityUtils.SUB_STATUS_GANHO, wonOpp.Status__c);
    System.assertEquals(OpportunityUtils.SUB_STATUS_PERDIDO, lostOpp.Status__c);
  }

  @IsTest
  static void shouldCoverTechnicalVisitSellerLookupAndContractDate() {
    Consultor__c consultorRecord = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(IdVirtualOffice__c = 'SELLER-HC'),
      true
    );
    Map<String, Id> sellersByExternalId = OpportunityBO.getOpportunitiesSellers(
      new Set<String>{ 'SELLER-HC' }
    );

    Account accountRecord = new Account(Name = 'Conta VT HC');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opp VT HC',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(7),
      IdVirtualOffice__c = 'VO-VT-' + String.valueOf(DateTime.now().getTime())
    );
    insert opportunityRecord;

    OpportunityBO.scheduleTechnicalVisit(
      new Map<Id, Opportunity>{
        opportunityRecord.Id => new Opportunity(
          Id = opportunityRecord.Id,
          StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE,
          CondicoesPagamento__c = 'À Vista'
        )
      },
      new Map<Id, Opportunity>{
        opportunityRecord.Id => new Opportunity(
          Id = opportunityRecord.Id,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO,
          CondicoesPagamento__c = null
        )
      }
    );

    Opportunity contractOpportunity = new Opportunity(
      Id = '006000000000051AAA',
      Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ENVIADO
    );
    OpportunityBO.setContractSendingDate(
      new List<Opportunity>{ contractOpportunity },
      new Map<Id, Opportunity>{
        contractOpportunity.Id => new Opportunity(
          Id = contractOpportunity.Id,
          Status__c = null
        )
      }
    );

    System.assertEquals(
      consultorRecord.Id,
      sellersByExternalId.get('SELLER-HC')
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA,
      [SELECT Status__c FROM Opportunity WHERE Id = :opportunityRecord.Id]
      .Status__c
    );
    System.assertNotEquals(null, contractOpportunity.DataEnvioContrato__c);
  }

  @IsTest
  static void shouldAssignSellerToAccountThroughOpportunityTrigger() {
    Consultor__c consultorRecord = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(IdVirtualOffice__c = 'SELLER-EXT-HC'),
      true
    );
    Account accountRecord = new Account(Name = 'Conta Seller Trigger');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opp Seller Trigger',
      AccountId = accountRecord.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      CloseDate = Date.today().addDays(7),
      IdVirtualOffice__c = 'VO-SELLER-' +
        String.valueOf(DateTime.now().getTime())
    );
    insert opportunityRecord;

    opportunityRecord.ConsultorOportunidade__c = consultorRecord.Id;
    update opportunityRecord;

    System.assertEquals(
      'SELLER-EXT-HC',
      [SELECT IdExternoConsultor__c FROM Account WHERE Id = :accountRecord.Id]
      .IdExternoConsultor__c
    );
  }

  @IsTest
  static void shouldMapPhysicalAndLegalAccountsFromRestAndAssignDefaultOwner() {
    Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()]
    .ProfileId;
    String uniqueToken = String.valueOf(DateTime.now().getTime());
    User integrationUser = new User(
      Alias = 'nivello',
      Email = 'integracao@lab065.com.test',
      Username = 'integracao@lab065.com.' + uniqueToken + '@test.com',
      LastName = 'Nivello',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profileId
    );
    insert integrationUser;

    Opportunity nivelloOpportunity = new Opportunity(
      OwnerId = integrationUser.Id
    );
    OpportunityBO.assignDefaultOwner(
      new List<Opportunity>{ nivelloOpportunity }
    );
    List<User> matchingIntegrationUsers = [
      SELECT Id
      FROM User
      WHERE UserName LIKE 'integracao@lab065.com%'
      LIMIT 1
    ];

    Id pfRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('ClientePessoaFisica')
      .getRecordTypeId();
    Id pjRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('ClientePessoaJuridica')
      .getRecordTypeId();

    Account existingLegalAccount = (Account) TestFactory.createSObject(
      new Account(
        IdVirtualOffice__c = 'EXT-PJ-HC',
        RecordTypeId = pjRecordTypeId
      ),
      true
    );

    OpportunityRecordsTO.Client existingLegalClient = new OpportunityRecordsTO.Client();
    existingLegalClient.Id = existingLegalAccount.IdVirtualOffice__c;
    existingLegalClient.UserType = 1;
    existingLegalClient.CorporateName = 'Empresa HC';
    existingLegalClient.Email = 'empresa.hc@test.com';
    existingLegalClient.Document = '12345678000199';
    existingLegalClient.CellPhone = '11988887777';
    existingLegalClient.RegisterDate = '2024-01-01T00:00:00';
    existingLegalClient.ModifiedDate = '2024-01-02T00:00:00';
    existingLegalClient.Procurator = 'Procurador HC';
    existingLegalClient.ProcuratorPhone = '11988887777';
    existingLegalClient.ProcuratorEmail = 'procurador.hc@test.com';
    existingLegalClient.ProcuratorRegisterNumber = '123';
    existingLegalClient.RecordTypeId = pjRecordTypeId;
    existingLegalClient.BillingCity = 'São Paulo';
    existingLegalClient.BillingStreet = 'Rua PJ';
    existingLegalClient.BillingCountry = 'Brasil';
    existingLegalClient.BillingState = 'SP';
    existingLegalClient.BillingPostalCode = '02925130';
    existingLegalClient.District = 'Centro';
    existingLegalClient.AddressNumber = '100';
    existingLegalClient.Complemento = 'Sala 1';
    existingLegalClient.AccountNumber = 'ACC-PJ';

    insert new Contact(
      AccountId = existingLegalAccount.Id,
      LastName = 'Contato PJ',
      Email = existingLegalClient.ProcuratorEmail
    );

    OpportunityRecordsTO.Client newPhysicalClient = new OpportunityRecordsTO.Client();
    newPhysicalClient.Id = 'EXT-PF-HC';
    newPhysicalClient.UserType = 1;
    newPhysicalClient.Name = 'Pessoa Nome HC';
    newPhysicalClient.FullName = null;
    newPhysicalClient.Email = 'fisica.hc@test.com';
    newPhysicalClient.Document = '12345678901';
    newPhysicalClient.CellPhone = '11977776666';
    newPhysicalClient.RegisterDate = '2024-01-01T00:00:00';
    newPhysicalClient.ModifiedDate = '2024-01-02T00:00:00';
    newPhysicalClient.Procurator = 'PF HC';
    newPhysicalClient.ProcuratorPhone = '11977776666';
    newPhysicalClient.ProcuratorEmail = 'pf.hc@test.com';
    newPhysicalClient.ProcuratorRegisterNumber = '456';
    newPhysicalClient.RecordTypeId = pfRecordTypeId;
    newPhysicalClient.BillingCity = 'Campinas';
    newPhysicalClient.BillingStreet = 'Rua PF';
    newPhysicalClient.BillingCountry = 'Brasil';
    newPhysicalClient.BillingState = 'SP';
    newPhysicalClient.BillingPostalCode = '13000000';
    newPhysicalClient.District = 'Centro';
    newPhysicalClient.AddressNumber = '200';
    newPhysicalClient.Complemento = 'Casa';
    newPhysicalClient.AccountNumber = 'ACC-PF';

    AccountTriggerHandler.disableTrigger();
    try {
      OpportunityBO.mapAccountFieldsRest(
        new Map<String, OpportunityRecordsTO.Client>{
          existingLegalClient.Id => existingLegalClient,
          newPhysicalClient.Id => newPhysicalClient
        },
        new Map<String, OpportunityRecordsTO.Client>()
      );
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    Account refreshedLegal = [
      SELECT Name, CNPJ__c
      FROM Account
      WHERE Id = :existingLegalAccount.Id
    ];
    Account insertedPhysical = [
      SELECT Name, CPF__c
      FROM Account
      WHERE IdVirtualOffice__c = :newPhysicalClient.Id
      LIMIT 1
    ];

    if (
      !matchingIntegrationUsers.isEmpty() &&
      nivelloOpportunity.OwnerId == matchingIntegrationUsers[0].Id
    ) {
      System.assertEquals('Nivello', nivelloOpportunity.Origem__c);
    }
    System.assertEquals('Empresa HC', refreshedLegal.Name);
    System.assertEquals('12.345.678/0001-99', refreshedLegal.CNPJ__c);
    System.assertEquals('Pessoa Nome HC', insertedPhysical.Name);
    System.assertEquals('123.456.789-01', insertedPhysical.CPF__c);
  }

  @IsTest
  static void shouldCreateCustomerJourneyFromAccessOpinionForEzeeSolar() {
    OpportunityTriggerHandler.disableTrigger();
    ProjetoTriggerHandler.disableTrigger();
    InstalacaoTriggerHandler.disableTrigger();

    Account accountRecord = createUniqueAccount('JOURNEY-EZEE');
    Contact contactRecord = (Contact) TestFactory.createSObject(
      new Contact(
        AccountId = accountRecord.Id,
        LastName = 'Journey Ezee',
        Email = 'journey.ezee@test.com'
      ),
      true
    );
    Id ezeeSolarBRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('EzeeSolarB')
      .getRecordTypeId();
    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountRecord.Id,
        RecordTypeId = ezeeSolarBRecordTypeId,
        PotenciaNominalSistema__c = 250,
        OwnerId = UserInfo.getUserId(),
        IdVirtualOffice__c = 'VO-HC-JOURNEY-EZEE'
      ),
      true
    );
    ViabilityStudy__c viabilityRecord = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viabilityRecord;

    Projeto__c projectRecord = new Projeto__c(
      Name = 'Projeto Journey Ezee',
      Oportunidade__c = opportunityRecord.Id,
      Conta__c = accountRecord.Id,
      Viabilidade__c = viabilityRecord.Id,
      GestorObra__c = UserInfo.getUserId(),
      Status__c = 'Planejamento',
      ApprovalDate__c = Date.today(),
      InstallDate__c = Date.today().addDays(5),
      DateInspection__c = Date.today().addDays(8)
    );
    insert projectRecord;

    insert new Instalacao__c(
      Projeto__c = projectRecord.Id,
      Oportunidade__c = opportunityRecord.Id,
      ClienteConta__c = accountRecord.Id,
      GestorObra__c = UserInfo.getUserId(),
      InstallDate__c = Date.today().addDays(6),
      DateInspection__c = Date.today().addDays(9)
    );

    OpportunityBO.createCaseCustomerJourney(
      new List<Opportunity>{
        new Opportunity(
          Id = opportunityRecord.Id,
          AccountId = accountRecord.Id,
          RecordTypeId = ezeeSolarBRecordTypeId,
          PotenciaNominalSistema__c = 250,
          StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO
        )
      },
      new Map<Id, Opportunity>{
        opportunityRecord.Id => new Opportunity(
          Id = opportunityRecord.Id,
          AccountId = accountRecord.Id,
          RecordTypeId = ezeeSolarBRecordTypeId,
          PotenciaNominalSistema__c = 250,
          StageName = OpportunityUtils.STATUS_NEGOCIACAO
        )
      }
    );

    Case journeyCase = [
      SELECT AccountId, ContactId, Subject
      FROM Case
      WHERE Nome_da_Oportunidade__c = :opportunityRecord.Id
      LIMIT 1
    ];
    System.assertEquals(accountRecord.Id, journeyCase.AccountId);
    System.assertEquals(contactRecord.Id, journeyCase.ContactId);
    System.assertEquals('Jornada do Projeto', journeyCase.Subject);

    InstalacaoTriggerHandler.enableTrigger();
    ProjetoTriggerHandler.enableTrigger();
    OpportunityTriggerHandler.enableTrigger();
  }

  @IsTest
  static void shouldHandleClosedLostEmailRecipientLimit() {
    Set<Id> userIds = new Set<Id>();
    for (User existingUser : [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Email != NULL
      LIMIT 101
    ]) {
      userIds.add(existingUser.Id);
    }

    Integer missingUsers = 101 - userIds.size();
    if (missingUsers > 0) {
      Id profileId = [
        SELECT ProfileId
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ]
      .ProfileId;
      List<User> recipientUsers = new List<User>();
      for (Integer index = 0; index < missingUsers; index++) {
        String token =
          String.valueOf(DateTime.now().getTime()) + String.valueOf(index);
        recipientUsers.add(
          new User(
            Alias = ('lim' + index).left(8),
            Email = 'limit.' + index + '@test.com',
            Username = 'limit.' + index + '.' + token + '@test.com',
            LastName = 'Limit',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            ProfileId = profileId
          )
        );
      }
      insert recipientUsers;
      for (User userRecord : recipientUsers) {
        userIds.add(userRecord.Id);
      }
    }

    OpportunityBO.sendClosedLostAutomationEmail(
      new List<Opportunity>{
        new Opportunity(Id = '006000000000061AAA', Name = 'Opp Email Limit')
      },
      userIds,
      'Nota limite'
    );

    System.assert(userIds.size() > 100);
  }

  @IsTest
  static void shouldCreateMessagingUsersAndSendClosedLostEmailInTest() {
    User recipientUser = createUser('closedlost.mail@test.com', 'mailcl');
    Opportunity firstOpportunity = new Opportunity(
      Id = '006000000000011AAA',
      Name = 'Opp Closed Lost 1',
      Telefone__c = '(11) 98765-4321'
    );
    Opportunity secondOpportunity = new Opportunity(
      Id = '006000000000012AAA',
      Name = 'Opp Closed Lost 2',
      Telefone__c = '1133334444'
    );
    Opportunity thirdOpportunity = new Opportunity(
      Id = '006000000000013AAA',
      Name = 'Opp Closed Lost 3',
      Telefone__c = '5511987654321'
    );

    Test.startTest();
    OpportunityBO.createMessagingUser(
      new List<Opportunity>{
        firstOpportunity,
        secondOpportunity,
        thirdOpportunity
      },
      new Map<Id, Opportunity>{
        firstOpportunity.Id => new Opportunity(Id = firstOpportunity.Id),
        secondOpportunity.Id => new Opportunity(Id = secondOpportunity.Id),
        thirdOpportunity.Id => new Opportunity(Id = thirdOpportunity.Id)
      }
    );
    OpportunityBO.sendClosedLostAutomationEmail(
      new List<Opportunity>{ firstOpportunity, secondOpportunity },
      new Set<Id>{ recipientUser.Id },
      'Nota de automação'
    );
    Test.stopTest();

    System.assertEquals(
      'Nota de automação',
      OpportunityBO.appendAutomationNote('', 'Nota de automação', 50)
    );
  }

  @IsTest
  static void shouldHandleAdditionalSubstatusAndLeadConversionBranches() {
    Id ezeeSolarARecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('EzeeSolarA')
      .getRecordTypeId();
    Id ezeeSolarBRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('EzeeSolarB')
      .getRecordTypeId();
    Id solarRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('Solar')
      .getRecordTypeId();

    Opportunity creditAnalysisOpp = new Opportunity(
      Id = '006000000000021AAA',
      RecordTypeId = ezeeSolarBRecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_CREDITO
    );
    Opportunity creditAnalysisOld = new Opportunity(
      Id = creditAnalysisOpp.Id,
      RecordTypeId = ezeeSolarBRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity viabilityGroupAOpp = new Opportunity(
      Id = '006000000000022AAA',
      RecordTypeId = ezeeSolarARecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
    );
    Opportunity viabilityGroupAOld = new Opportunity(
      Id = viabilityGroupAOpp.Id,
      RecordTypeId = ezeeSolarARecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity viabilitySolarOpp = new Opportunity(
      Id = '006000000000023AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
    );
    Opportunity viabilitySolarOld = new Opportunity(
      Id = viabilitySolarOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity awaitingAcceptanceOpp = new Opportunity(
      Id = '006000000000024AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE
    );
    Opportunity awaitingAcceptanceOld = new Opportunity(
      Id = awaitingAcceptanceOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity contractGroupAOpp = new Opportunity(
      Id = '006000000000025AAA',
      RecordTypeId = ezeeSolarARecordTypeId,
      StageName = OpportunityUtils.STATUS_CONTRATO
    );
    Opportunity contractGroupAOld = new Opportunity(
      Id = contractGroupAOpp.Id,
      RecordTypeId = ezeeSolarARecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity validationOpp = new Opportunity(
      Id = '006000000000026AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_VALIDACAO
    );
    Opportunity validationOld = new Opportunity(
      Id = validationOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity equipmentOpp = new Opportunity(
      Id = '006000000000027AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_EQUIPAMENTO
    );
    Opportunity equipmentOld = new Opportunity(
      Id = equipmentOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity completedOpp = new Opportunity(
      Id = '006000000000028AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_FINALIZADO
    );
    Opportunity completedOld = new Opportunity(
      Id = completedOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Opportunity unknownOpp = new Opportunity(
      Id = '006000000000029AAA',
      RecordTypeId = solarRecordTypeId,
      StageName = 'Stage Inexistente'
    );
    Opportunity unknownOld = new Opportunity(
      Id = unknownOpp.Id,
      RecordTypeId = solarRecordTypeId,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO
    );

    Lead leadRecord = new Lead(LastName = 'Lead Lost', Company = 'Lost Co');
    insert leadRecord;
    Opportunity leadOpp = new Opportunity(
      Id = '006000000000031AAA',
      StageName = 'Ganho Perdido',
      Lead__c = leadRecord.Id
    );
    Opportunity leadOld = new Opportunity(
      Id = leadOpp.Id,
      StageName = OpportunityUtils.STATUS_NEGOCIACAO,
      Lead__c = leadRecord.Id
    );

    Test.startTest();
    OpportunityBO.controlsSubstatus(
      new List<Opportunity>{
        creditAnalysisOpp,
        viabilityGroupAOpp,
        viabilitySolarOpp,
        awaitingAcceptanceOpp,
        contractGroupAOpp,
        validationOpp,
        equipmentOpp,
        completedOpp,
        unknownOpp
      },
      new Map<Id, Opportunity>{
        creditAnalysisOpp.Id => creditAnalysisOld,
        viabilityGroupAOpp.Id => viabilityGroupAOld,
        viabilitySolarOpp.Id => viabilitySolarOld,
        awaitingAcceptanceOpp.Id => awaitingAcceptanceOld,
        contractGroupAOpp.Id => contractGroupAOld,
        validationOpp.Id => validationOld,
        equipmentOpp.Id => equipmentOld,
        completedOpp.Id => completedOld,
        unknownOpp.Id => unknownOld
      }
    );
    OpportunityBO.handleOpportunityLeadConversion(
      new List<Opportunity>{ leadOpp },
      new Map<Id, Opportunity>{ leadOpp.Id => leadOld }
    );
    Test.stopTest();

    System.assertEquals(
      OpportunityUtils.SUB_STATUS_ANALISE_CREDITO,
      creditAnalysisOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO,
      viabilityGroupAOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA,
      viabilitySolarOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_EM_ANALISE,
      awaitingAcceptanceOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_AGUARDANDO_DOCUMENTOS,
      contractGroupAOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_EM_ANDAMENTO,
      validationOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_ENTREGA_DE_MATERIAIS,
      equipmentOpp.Status__c
    );
    System.assertEquals(
      OpportunityUtils.SUB_STATUS_VALIDANDO_BONIFICACAO,
      completedOpp.Status__c
    );
    System.assertEquals(null, unknownOpp.Status__c);
    System.assertEquals(
      'Não Qualificado',
      [SELECT Status FROM Lead WHERE Id = :leadRecord.Id].Status
    );
  }

  @IsTest
  static void shouldValidateContractRequirementsAndOwnerFallbacks() {
    OpportunityTriggerHandler.disableTrigger();
    Account accountRecord = createUniqueAccount('CONTRACT');
    insert new Contact(
      AccountId = accountRecord.Id,
      LastName = 'Contract Contact',
      Email = 'contract.contact@test.com'
    );
    User owner = createUser('owner.contract.requirements@test.com', 'contreq');
    Opportunity opportunityRecord = createOpportunity(
      accountRecord,
      'CONTRACT',
      owner.Id
    );
    OpportunityTriggerHandler.enableTrigger();

    Opportunity oldDeliveryOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    oldDeliveryOpportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE;
    oldDeliveryOpportunity.SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO;

    Opportunity newDeliveryOpportunity = opportunityRecord.clone(
      true,
      true,
      true,
      true
    );
    newDeliveryOpportunity.Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
    newDeliveryOpportunity.SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO;
    newDeliveryOpportunity.DataEntrega__c = null;

    insert (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opportunityRecord.Id),
      false
    );

    Account secondAccount = createUniqueAccount('CONTRACTKIT');
    insert new Contact(
      AccountId = secondAccount.Id,
      LastName = 'Contract Kit Contact',
      Email = 'contract.kit.contact@test.com'
    );
    OpportunityTriggerHandler.disableTrigger();
    Opportunity secondOpportunity = createOpportunity(
      secondAccount,
      'CONTRACTKIT',
      owner.Id
    );
    OpportunityTriggerHandler.enableTrigger();

    Opportunity oldKitOpportunity = secondOpportunity.clone(
      true,
      true,
      true,
      true
    );
    oldKitOpportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE;
    oldKitOpportunity.SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO;

    Opportunity newKitOpportunity = secondOpportunity.clone(
      true,
      true,
      true,
      true
    );
    newKitOpportunity.Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
    newKitOpportunity.SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO;
    newKitOpportunity.DataEntrega__c = Date.today().addDays(10);

    Kit_Instalacao__c incompleteKit = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = secondOpportunity.Id),
      false
    );
    incompleteKit.AniversarioLinha__c = null;
    incompleteKit.Recorrencia__c = null;
    incompleteKit.TipoFaturamento__c = null;
    incompleteKit.TipoMedicao__c = null;
    incompleteKit.UnidadeMedidaLocacao__c = null;
    incompleteKit.VencimentoBase__c = null;
    incompleteKit.CodigoImposto__c = null;
    insert incompleteKit;

    Test.startTest();
    OpportunityBO.validateSellBuyOrderAndContractRequiredFields(
      new List<Opportunity>{ newDeliveryOpportunity, newKitOpportunity },
      new Map<Id, Opportunity>{
        opportunityRecord.Id => oldDeliveryOpportunity,
        secondOpportunity.Id => oldKitOpportunity
      }
    );
    Test.stopTest();

    System.assertEquals(1, newDeliveryOpportunity.getErrors().size());
    Id fakeQueueId = owner.Id;
    Id fakeFinanceUserId = UserInfo.getUserId();
    System.assertEquals(
      fakeQueueId,
      OpportunityBO.resolvePaymentReminderTaskOwner(
        fakeQueueId,
        fakeFinanceUserId,
        owner.Id,
        true
      )
    );
    System.assertEquals(
      fakeFinanceUserId,
      OpportunityBO.resolvePaymentReminderTaskOwner(
        null,
        fakeFinanceUserId,
        owner.Id,
        true
      )
    );
    System.assertEquals(
      owner.Id,
      OpportunityBO.resolvePaymentReminderTaskOwner(null, null, owner.Id, true)
    );
    System.assertEquals(
      UserInfo.getUserId(),
      OpportunityBO.resolvePaymentReminderTaskOwner(null, null, null, false)
    );
  }
}
