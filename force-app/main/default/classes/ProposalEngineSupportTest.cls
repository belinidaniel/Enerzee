/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class ProposalEngineSupportTest {
  private static final String COVER_KEY = 'API_ENGINE_SUPPORT';
  private static String apiMockMode = 'BASE64';

  @TestSetup
  static void setup() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaEngine')
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;

    ProposalCover__c apiCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaEngine'),
        GrupoTarifario__c = 'Grupo B',
        IntegrationKey__c = COVER_KEY,
        Template__c = 'ModeloPropostaA',
        TemplateUrl__c = 'https://api.example.com/template-engine'
      ),
      true
    );

    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = TestFactory.nextUniqueValue('ParceiroEngine'),
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = apiCover.Id
      ),
      true
    );

    insert new Opportunity(
      AccountId = account.Id,
      Name = TestFactory.nextUniqueValue('OpportunityEngine'),
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
      CloseDate = Date.today(),
      Parceiro__c = partner.Id,
      GrupoTarifario__c = 'Grupo B',
      Amount = 123.45,
      IdVirtualOffice__c = 'VO-ENGINE-001'
    );

    insert new ContentVersion(
      Title = 'Template Engine',
      PathOnClient = 'template-engine.pptx',
      VersionData = Blob.valueOf('pptx-engine'),
      FirstPublishLocationId = apiCover.Id,
      IsTemplate__c = true,
      ProposalTemplateRole__c = 'API_PPTX_TEMPLATE'
    );
  }

  @isTest
  static void configurationServiceReturnsExactAndFallbackRules() {
    ProposalConfigurationService.TagConfig genericTag = new ProposalConfigurationService.TagConfig();
    genericTag.coverKey = COVER_KEY;
    genericTag.tagKey = '{{AccountName}}';
    genericTag.sourcePath = 'Account.Name';
    genericTag.scenario = ProposalConfigurationService.SCENARIO_ALL;
    genericTag.sortOrder = 2;
    genericTag.active = true;

    ProposalConfigurationService.TagConfig paymentTag = new ProposalConfigurationService.TagConfig();
    paymentTag.coverKey = COVER_KEY;
    paymentTag.tagKey = '{{PaymentType}}';
    paymentTag.sourcePath = 'SelectedSimulation__r.PaymentType__c';
    paymentTag.scenario = ProposalConfigurationService.SCENARIO_PAYMENT_SELECTED;
    paymentTag.paymentType = 'FINANCING';
    paymentTag.sortOrder = 1;
    paymentTag.active = true;

    ProposalConfigurationService.setTestTagConfigs(
      new List<ProposalConfigurationService.TagConfig>{ genericTag, paymentTag }
    );
    ProposalConfigurationService.setTestSectionsByKey(
      new Map<String, List<String>>{
        ProposalConfigurationService.SCENARIO_INITIAL => new List<String>{
          'Proposta'
        },
        'Financing' => new List<String>{ 'Valor Financiamento' }
      }
    );

    try {
      List<ProposalConfigurationService.TagConfig> genericTags = ProposalConfigurationService.getTagConfigs(
        COVER_KEY,
        ProposalConfigurationService.SCENARIO_INITIAL,
        null
      );
      Assert.areEqual(
        1,
        genericTags.size(),
        'Deve retornar apenas a tag genérica.'
      );
      Assert.areEqual(
        '{{AccountName}}',
        genericTags[0].tagKey,
        'A tag genérica deve permanecer disponível no cenário inicial.'
      );

      List<String> paymentSections = ProposalConfigurationService.getSectionsToShow(
        COVER_KEY,
        ProposalConfigurationService.SCENARIO_PAYMENT_SELECTED,
        'Financing'
      );
      Assert.areEqual(
        1,
        paymentSections.size(),
        'O cenário com tipo de pagamento específico deve preferir a configuração exata.'
      );
      Assert.areEqual(
        'Valor Financiamento',
        paymentSections[0],
        'A section específica do financiamento deve ser selecionada.'
      );
    } finally {
      ProposalConfigurationService.setTestTagConfigs(null);
      ProposalConfigurationService.setTestSectionsByKey(null);
    }
  }

  @isTest
  static void determineIsPromotionalDependsOnTipoKitPromocional() {
    Assert.isFalse(
      ProposalContextResolver.determineIsPromotional(null),
      'O helper deve retornar falso quando a oportunidade não for informada.'
    );

    Opportunity opportunityRecord = new Opportunity(
      isPromotional__c = true,
      TipoKitPromocional__c = null
    );

    Assert.isFalse(
      ProposalContextResolver.determineIsPromotional(opportunityRecord),
      'Sem TipoKitPromocional preenchido, a oportunidade não deve ser tratada como promocional.'
    );

    opportunityRecord.TipoKitPromocional__c = '6';

    Assert.isTrue(
      ProposalContextResolver.determineIsPromotional(opportunityRecord),
      'Com TipoKitPromocional preenchido, a oportunidade deve ser tratada como promocional.'
    );

    Assert.isNull(
      ProposalCoverRoutingService.resolveCoverKey(
        new ProposalCover__c(
          Template__c = 'ModeloPropostaB',
          isPromotional__c = false
        )
      ),
      'Sem TemplateUrl__c a capa legada não possui chave de API.'
    );
    Assert.isFalse(
      ProposalCoverRoutingService.usesApiFlow(
        new ProposalCover__c(
          Template__c = 'ModeloPropostaB',
          isPromotional__c = false
        )
      ),
      'Sem TemplateUrl__c a capa legada não deve usar o fluxo de API.'
    );
    Assert.areEqual(
      'CHAVE_EXPLICITA',
      ProposalCoverRoutingService.resolveCoverKey(
        new ProposalCover__c(
          IntegrationKey__c = 'CHAVE_EXPLICITA',
          TemplateUrl__c = 'https://api.example.com/template'
        )
      ),
      'Quando existir IntegrationKey explícita e TemplateUrl ela deve ter prioridade.'
    );
  }

  @isTest
  static void contextResolverValidatesRequiredIdsAndInactiveCover() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    try {
      ProposalContextResolver.resolve(null, null);
      Assert.fail('Os identificadores obrigatórios deveriam ser validados.');
    } catch (Exception handledException) {
      Assert.isTrue(
        String.isNotBlank(handledException.getMessage()),
        'A validação precisa retornar uma mensagem de erro.'
      );
    }

    ProposalCover__c inactiveCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaInativa'),
        GrupoTarifario__c = 'Grupo B',
        IsActive__c = false,
        IntegrationKey__c = TestFactory.nextUniqueValue('COVER_INACTIVE')
      ),
      true
    );

    try {
      ProposalContextResolver.resolve(opportunityRecord.Id, inactiveCover.Id);
      Assert.fail('Capas inativas não podem ser resolvidas.');
    } catch (Exception handledException) {
      Assert.isTrue(
        String.isNotBlank(handledException.getMessage()),
        'A validação da capa inativa precisa retornar uma mensagem de erro.'
      );
    }
  }

  @isTest
  static void payloadBuilderFormatsValuesAndValidatesRequiredFields() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    ProposalConfigurationService.TagConfig accountTag = new ProposalConfigurationService.TagConfig();
    accountTag.tagKey = '{{AccountName}}';
    accountTag.sourcePath = 'Account.Name';
    accountTag.formatValue = 'UPPER';

    ProposalConfigurationService.TagConfig amountTag = new ProposalConfigurationService.TagConfig();
    amountTag.tagKey = '{{Amount}}';
    amountTag.sourcePath = 'Amount';
    amountTag.formatValue = 'CURRENCY_BR';

    ProposalConfigurationService.TagConfig dateTag = new ProposalConfigurationService.TagConfig();
    dateTag.tagKey = '{{CloseDate}}';
    dateTag.sourcePath = 'CloseDate';
    dateTag.formatValue = 'DATE_BR';

    List<ProposalConfigurationService.TagConfig> configs = new List<ProposalConfigurationService.TagConfig>{
      accountTag,
      amountTag,
      dateTag
    };

    Opportunity queriedOpportunity = ProposalPayloadBuilder.queryOpportunityForTags(
      opportunityRecord.Id,
      configs
    );
    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      queriedOpportunity,
      configs,
      new List<String>{ 'Proposta', 'Rodape' },
      '068000000000001AAA'
    );

    Assert.areEqual(
      'CONTAENGINE',
      payload.tags.get('{{AccountName}}').left(11),
      'O payload deve aplicar o formato UPPER.'
    );
    Assert.areEqual(
      '123,45',
      payload.tags.get('{{Amount}}'),
      'O payload deve aplicar formatação monetária pt-BR com prefixo e separador de milhar.'
    );
    Assert.isTrue(
      payload.tags.get('{{CloseDate}}').contains('/'),
      'A data deve ser formatada em dd/MM/yyyy.'
    );
    Assert.isTrue(
      String.isNotBlank(payload.payloadHash),
      'O hash do payload deve ser calculado.'
    );

    ProposalConfigurationService.TagConfig requiredTag = new ProposalConfigurationService.TagConfig();
    requiredTag.tagKey = '{{Missing}}';
    requiredTag.sourcePath = 'Description';
    requiredTag.required = true;

    try {
      ProposalPayloadBuilder.buildPayload(
        context,
        ProposalPayloadBuilder.queryOpportunityForTags(
          opportunityRecord.Id,
          new List<ProposalConfigurationService.TagConfig>{ requiredTag }
        ),
        new List<ProposalConfigurationService.TagConfig>{ requiredTag },
        new List<String>{ 'Proposta' },
        '068000000000001AAA'
      );
      Assert.fail('A tag obrigatória sem valor deveria lançar exceção.');
    } catch (Exception handledException) {
      Assert.isTrue(
        String.isNotBlank(handledException.getMessage()),
        'A exceção deve retornar uma mensagem de validação.'
      );
    }
  }

  @isTest
  static void fileServiceSavesAndFindsProposal() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    ProposalApiClient.ApiResponse response = new ProposalApiClient.ApiResponse();
    response.fileBlob = Blob.valueOf('pdf-engine');
    response.fileName = null;
    response.mimeType = 'application/pdf';

    Test.startTest();
    Id contentVersionId = ProposalFileService.saveGeneratedProposal(
      context,
      response,
      'HASH-001'
    );
    Test.stopTest();

    Assert.isNotNull(contentVersionId, 'O arquivo gerado deve ser salvo.');
    Assert.isNotNull(
      ProposalFileService.findExistingProposal(
        opportunityRecord.Id,
        'HASH-001'
      ),
      'O serviço deve localizar a proposta já existente pelo hash.'
    );
    Assert.isTrue(
      ProposalFileService.buildPreviewUrl(contentVersionId)
        .contains(String.valueOf(contentVersionId)),
      'A URL de preview deve usar o identificador da versão.'
    );
  }

  @isTest
  static void fileServiceHandlesLatestLookupAndCustomFileNames() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    ProposalApiClient.ApiResponse response = new ProposalApiClient.ApiResponse();
    response.fileBlob = Blob.valueOf('pdf-custom');
    response.fileName = 'arquivo-personalizado';
    response.mimeType = 'application/pdf';

    Id contentVersionId = ProposalFileService.saveGeneratedProposal(
      context,
      response,
      'HASH-LATEST-001'
    );

    ContentVersion latestProposal = ProposalFileService.findLatestProposal(
      opportunityRecord.Id
    );
    Assert.areEqual(
      contentVersionId,
      latestProposal.Id,
      'A busca da proposta mais recente deve retornar o último PDF salvo.'
    );
    Assert.areEqual(
      null,
      ProposalFileService.findLatestProposal(null),
      'Sem oportunidade informada, não deve existir proposta mais recente.'
    );
    Assert.areEqual(
      null,
      ProposalFileService.findExistingProposal(null, 'HASH'),
      'Sem oportunidade informada, a busca por hash deve retornar nulo.'
    );
    Assert.areEqual(
      null,
      ProposalFileService.findExistingProposal(opportunityRecord.Id, null),
      'Sem hash informado, a busca por hash deve retornar nulo.'
    );
    Assert.areEqual(
      null,
      ProposalFileService.buildPreviewUrl(null),
      'Sem versão informada, a URL de preview deve ser nula.'
    );

    ContentVersion savedVersion = [
      SELECT Title, PathOnClient, FirstPublishLocationId
      FROM ContentVersion
      WHERE Id = :contentVersionId
    ];
    Opportunity sourceOpportunity = [
      SELECT Id, Name, Numeroproposta__c, Account.Name
      FROM Opportunity
      WHERE Id = :savedVersion.FirstPublishLocationId
    ];
    Assert.areEqual(
      ProposalFileService.buildProposalFileName(sourceOpportunity),
      savedVersion.PathOnClient,
      'O PDF salvo deve seguir o padrao de nomenclatura da proposta.'
    );
    Assert.areEqual(
      ProposalFileService.buildProposalTitle(sourceOpportunity),
      savedVersion.Title,
      'O titulo salvo deve seguir o padrao de nomenclatura da proposta.'
    );
  }

  @isTest
  static void proposalNamingServiceUsesProposalNumberAndAccountName() {
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"attributes":{"type":"Opportunity"},"Name":"Nome XPTO","Numeroproposta__c":"P-ENGINE-001"}',
      Opportunity.class
    );

    Assert.areEqual(
      'P-ENGINE-001 Nome XPTO',
      ProposalFileService.buildProposalTitle(opportunityRecord),
      'O titulo deve seguir o padrao numero da proposta + nome principal.'
    );
    Assert.isTrue(
      ProposalFileService.buildProposalFileName(opportunityRecord)
        .endsWith('.pdf'),
      'O nome de arquivo precisa manter a extensao PDF.'
    );
    Assert.areEqual(
      'P-001 Cliente Teste',
      ProposalFileService.sanitizeFileName('P-001/Cliente:Teste'),
      'Caracteres invalidos de nome de arquivo devem ser higienizados.'
    );
  }

  @isTest
  static void templateResolverUsesSinglePptxAttachedToStandardCover() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaTemplateUnico') + ' Teste'
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;

    // Inserir contato antes da Opportunity para que o Flow "Opportunity - Insert
    // Opportunity Contact" siga o caminho "conta possui contato" (só cria
    // OpportunityContactRole), evitando a criação de Contact que aciona Flows
    // de mensagem e causa FIELD_CUSTOM_VALIDATION_EXCEPTION em teste.
    insert new Contact(LastName = 'Teste', AccountId = account.Id);

    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaTemplateUnico'),
        GrupoTarifario__c = 'Grupo B',
        Template__c = 'ModeloPropostaB',
        isPromotional__c = false
      ),
      true
    );

    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = TestFactory.nextUniqueValue('ParceiroTemplateUnico'),
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = cover.Id
      ),
      true
    );

    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = partner.Id,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = TestFactory.nextUniqueValue('VO-SINGLE-PPTX')
      )
    );
    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    insert new ContentVersion(
      Title = 'Template Unico',
      PathOnClient = 'template-unico.pptx',
      VersionData = Blob.valueOf('pptx-single-template'),
      FirstPublishLocationId = cover.Id,
      IsTemplate__c = true,
      TipoKitPromocional__c = '6'
    );

    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );
    ContentVersion resolvedTemplate = ProposalTemplateResolver.resolveTemplate(
      context
    );

    Assert.areEqual(
      'Template Unico',
      resolvedTemplate.Title,
      'Quando existir apenas um PPTX anexado, ele deve ser utilizado diretamente.'
    );
  }

  @isTest
  static void templateResolverValidatesContext() {
    try {
      ProposalTemplateResolver.resolveTemplate(null);
      Assert.fail('O resolver deveria validar o contexto obrigatório.');
    } catch (Exception handledException) {
      Assert.isTrue(
        String.isNotBlank(handledException.getMessage()),
        'A validação de contexto inválido deve retornar uma mensagem de erro.'
      );
    }
  }

  @isTest
  static void apiClientSupportsBase64UrlAndPdfResponses() {
    ContentVersion templateVersion = [
      SELECT Id, Title, PathOnClient, FileExtension, VersionData
      FROM ContentVersion
      WHERE ProposalTemplateRole__c = 'API_PPTX_TEMPLATE'
      LIMIT 1
    ];

    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());

    apiMockMode = 'BASE64';
    ProposalApiClient.ApiResponse base64Response;
    Test.startTest();
    base64Response = ProposalApiClient.convertProposal(
      templateVersion,
      '{"a":"b"}',
      '["Proposta"]'
    );
    Test.stopTest();
    Assert.areEqual(
      'base64.pdf',
      base64Response.fileName,
      'O cliente deve ler o arquivo retornado em base64.'
    );

    apiMockMode = 'URL';
    ProposalApiClient.ApiResponse urlResponse = ProposalApiClient.convertProposal(
      templateVersion,
      '{"a":"b"}',
      '["Proposta"]'
    );
    Assert.isTrue(
      urlResponse.fileBlob.size() > 0,
      'O cliente deve baixar o PDF quando a API retornar urlFile.'
    );

    apiMockMode = 'PDF';
    ProposalApiClient.ApiResponse pdfResponse = ProposalApiClient.convertProposal(
      templateVersion,
      '{"a":"b"}',
      '["Proposta"]'
    );
    Assert.areEqual(
      'Template Engine.pdf',
      pdfResponse.fileName,
      'Quando a API responder com PDF cru, o fallback deve usar o título do template.'
    );
  }

  @isTest
  static void payloadBuilderResolvesSimulationSummaryMappings() {
    Opportunity opportunityRecord = [
      SELECT Id, CustoMedioEnergia__c, EconomiaMensalEstimada__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    opportunityRecord.CustoMedioEnergia__c = 1511;
    opportunityRecord.EconomiaMensalEstimada__c = 380;
    update opportunityRecord;

    insert new List<PaymentSimulation__c>{
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 36,
        InstallmentAmount__c = 2208.67
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 48,
        InstallmentAmount__c = 2228.09
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 60,
        InstallmentAmount__c = 2488.41
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Rental',
        ProposalLabel__c = 'Solar Aluguel',
        InstallmentCount__c = 72,
        InstallmentAmount__c = 1540.55
      )
    };

    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    List<ProposalConfigurationService.TagConfig> configs = new List<ProposalConfigurationService.TagConfig>();

    ProposalConfigurationService.TagConfig aluguelValor = new ProposalConfigurationService.TagConfig();
    aluguelValor.tagKey = '{{AluguelValor__c}}';
    aluguelValor.sourcePath = 'SimulationSummary.Rental.InstallmentAmount1';
    aluguelValor.formatValue = 'CURRENCY_BR';
    configs.add(aluguelValor);

    ProposalConfigurationService.TagConfig aluguelPercentual = new ProposalConfigurationService.TagConfig();
    aluguelPercentual.tagKey = '{{AluguelPorcentagem__c}}';
    aluguelPercentual.sourcePath = 'Calculated.EconomiaPercentual';
    aluguelPercentual.formatValue = 'DECIMAL_BR';
    configs.add(aluguelPercentual);

    ProposalConfigurationService.TagConfig financiamento1 = new ProposalConfigurationService.TagConfig();
    financiamento1.tagKey = '{{Financiamento1__c}}';
    financiamento1.sourcePath = 'SimulationSummary.Financing.InstallmentAmount1';
    financiamento1.formatValue = 'CURRENCY_BR';
    configs.add(financiamento1);

    ProposalConfigurationService.TagConfig financiamento2 = new ProposalConfigurationService.TagConfig();
    financiamento2.tagKey = '{{Financiamento2__c}}';
    financiamento2.sourcePath = 'SimulationSummary.Financing.InstallmentAmount2';
    financiamento2.formatValue = 'CURRENCY_BR';
    configs.add(financiamento2);

    ProposalConfigurationService.TagConfig financiamento3 = new ProposalConfigurationService.TagConfig();
    financiamento3.tagKey = '{{Financiamento3__c}}';
    financiamento3.sourcePath = 'SimulationSummary.Financing.InstallmentAmount3';
    financiamento3.formatValue = 'CURRENCY_BR';
    configs.add(financiamento3);

    ProposalConfigurationService.TagConfig financiamentoMensal = new ProposalConfigurationService.TagConfig();
    financiamentoMensal.tagKey = '{{FinanciamentoMensal__c}}';
    financiamentoMensal.sourcePath = 'EconomiaMensalEstimada__c';
    financiamentoMensal.formatValue = 'CURRENCY_BR';
    configs.add(financiamentoMensal);

    Opportunity queriedOpportunity = ProposalPayloadBuilder.queryOpportunityForTags(
      opportunityRecord.Id,
      configs
    );
    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      queriedOpportunity,
      configs,
      new List<String>{ 'Proposta de valores' },
      '068000000000009AAA'
    );

    Assert.areEqual(
      '1.540,55',
      payload.tags.get('{{AluguelValor__c}}'),
      'O aluguel deve usar a simulacao relacionada de 72x com prefixo e separador de milhar.'
    );
    Assert.areEqual(
      '',
      payload.tags.get('{{AluguelPorcentagem__c}}'),
      'Quando a porcentagem de economia do aluguel e negativa, o campo deve ser zerado.'
    );
    Assert.areEqual(
      '2.208,67',
      payload.tags.get('{{Financiamento1__c}}'),
      'A primeira opcao de financiamento deve vir da simulacao relacionada com prefixo R$.'
    );
    Assert.areEqual(
      '2.228,09',
      payload.tags.get('{{Financiamento2__c}}'),
      'A segunda opcao de financiamento deve vir da simulacao relacionada com prefixo R$.'
    );
    Assert.areEqual(
      '2.488,41',
      payload.tags.get('{{Financiamento3__c}}'),
      'A terceira opcao de financiamento deve vir da simulacao relacionada com prefixo R$.'
    );
    Assert.areEqual(
      '380,00',
      payload.tags.get('{{FinanciamentoMensal__c}}'),
      'A economia mensal deve continuar vindo da oportunidade com prefixo R$.'
    );
  }

  @isTest
  static void payloadBuilderPopulatesOtherPaymentTagsForPixAndCard() {
    Opportunity opportunityRecord = [
      SELECT Id, ValorTotalProdutos__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    opportunityRecord.ValorTotalProdutos__c = 66144.88;
    update opportunityRecord;

    insert new PaymentSimulation__c(
      Opportunity__c = opportunityRecord.Id,
      PaymentType__c = 'Pix',
      ProposalLabel__c = 'PIX',
      InstallmentCount__c = 1,
      InstallmentAmount__c = 66144.88,
      Selected__c = true
    );

    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    List<ProposalConfigurationService.TagConfig> pixConfigs = new List<ProposalConfigurationService.TagConfig>();
    ProposalConfigurationService.TagConfig pixLabel = new ProposalConfigurationService.TagConfig();
    pixLabel.tagKey = '{{formaPagamentoOutroSelecionado}}';
    pixLabel.sourcePath = 'Calculated.formaPagamentoOutroSelecionado';
    pixLabel.formatValue = 'RAW';
    pixConfigs.add(pixLabel);

    ProposalConfigurationService.TagConfig pixValue = new ProposalConfigurationService.TagConfig();
    pixValue.tagKey = '{{ValorOutros}}';
    pixValue.sourcePath = 'Calculated.ValorOutros';
    pixValue.formatValue = 'CURRENCY_BR_PREFIX';
    pixConfigs.add(pixValue);

    ProposalConfigurationService.TagConfig pixText = new ProposalConfigurationService.TagConfig();
    pixText.tagKey = '{{textoOutrosPagamento}}';
    pixText.sourcePath = 'Calculated.textoOutrosPagamento';
    pixText.formatValue = 'RAW';
    pixConfigs.add(pixText);

    ProposalPayloadBuilder.Payload pixPayload = ProposalPayloadBuilder.buildPayload(
      context,
      ProposalPayloadBuilder.queryOpportunityForTags(
        opportunityRecord.Id,
        pixConfigs
      ),
      pixConfigs,
      new List<String>{ 'Outros' },
      '068000000000009AAA'
    );

    Assert.areEqual(
      'PIX VIA LINK',
      pixPayload.tags.get('{{formaPagamentoOutroSelecionado}}')
    );
    Assert.areEqual('R$ 66.144,88', pixPayload.tags.get('{{ValorOutros}}'));
    Assert.areEqual('', pixPayload.tags.get('{{textoOutrosPagamento}}'));

    delete [
      SELECT Id
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opportunityRecord.Id
    ];

    insert new PaymentSimulation__c(
      Opportunity__c = opportunityRecord.Id,
      PaymentType__c = 'Card',
      ProposalLabel__c = 'Taxa cartão de credito',
      InstallmentCount__c = 12,
      InstallmentAmount__c = 6000,
      Selected__c = true
    );

    ProposalPayloadBuilder.Payload cardPayload = ProposalPayloadBuilder.buildPayload(
      context,
      ProposalPayloadBuilder.queryOpportunityForTags(
        opportunityRecord.Id,
        pixConfigs
      ),
      pixConfigs,
      new List<String>{ 'Outros' },
      '068000000000009AAA'
    );

    Assert.areEqual(
      'CARTÃO DE CRÉDITO',
      cardPayload.tags.get('{{formaPagamentoOutroSelecionado}}')
    );
    Assert.areEqual(
      'até 12x R$ 6.000,00',
      cardPayload.tags.get('{{ValorOutros}}')
    );
    Assert.areEqual(
      '³ Juros aplicados no valor total da proposta.',
      cardPayload.tags.get('{{textoOutrosPagamento}}')
    );
  }

  @isTest
  static void payloadBuilderPopulatesEconomiaMensalLabels() {
    Opportunity opportunityRecord = [
      SELECT
        Id,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c,
        MainViability__c,
        CreatedDate
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    opportunityRecord.CustoMedioEnergia__c = 3000;
    opportunityRecord.EconomiaMensalEstimada__c = 2500;
    opportunityRecord.TarifaComTributosB__c = 0;

    insert new List<PaymentSimulation__c>{
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 36,
        InstallmentAmount__c = 1400
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 48,
        InstallmentAmount__c = 1200
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 60,
        InstallmentAmount__c = 1000
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Rental',
        ProposalLabel__c = 'Solar Aluguel',
        InstallmentCount__c = 72,
        InstallmentAmount__c = 500
      )
    };

    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    List<ProposalConfigurationService.TagConfig> configs = new List<ProposalConfigurationService.TagConfig>();

    ProposalConfigurationService.TagConfig economiaMensal = new ProposalConfigurationService.TagConfig();
    economiaMensal.tagKey = '{{EconomiaMensal__c}}';
    economiaMensal.sourcePath = 'Calculated.EconomiaMensal';
    configs.add(economiaMensal);

    ProposalConfigurationService.TagConfig economiaMensalTxt = new ProposalConfigurationService.TagConfig();
    economiaMensalTxt.tagKey = '{{EconomiaMensalTxt__c}}';
    economiaMensalTxt.sourcePath = 'Calculated.EconomiaMensalTxt';
    configs.add(economiaMensalTxt);

    ProposalConfigurationService.TagConfig economiaMensalFinalTxt = new ProposalConfigurationService.TagConfig();
    economiaMensalFinalTxt.tagKey = '{{EconomiaMensalFinalTxt__c}}';
    economiaMensalFinalTxt.sourcePath = 'Calculated.EconomiaMensalFinalTxt';
    configs.add(economiaMensalFinalTxt);

    ProposalConfigurationService.TagConfig financiamentoMensal = new ProposalConfigurationService.TagConfig();
    financiamentoMensal.tagKey = '{{FinanciamentoMensal__c}}';
    financiamentoMensal.sourcePath = 'Calculated.FinanciamentoMensal';
    financiamentoMensal.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(financiamentoMensal);

    ProposalConfigurationService.TagConfig aluguelEconomiaMensal = new ProposalConfigurationService.TagConfig();
    aluguelEconomiaMensal.tagKey = '{{AluguelEconomiaMensal__c}}';
    aluguelEconomiaMensal.sourcePath = 'Calculated.AluguelEconomiaMensal';
    aluguelEconomiaMensal.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(aluguelEconomiaMensal);

    ProposalConfigurationService.TagConfig diferencaMedioMensal = new ProposalConfigurationService.TagConfig();
    diferencaMedioMensal.tagKey = '{{DiferencaMedioMensal}}';
    diferencaMedioMensal.sourcePath = 'Calculated.DiferencaMedioMensal';
    diferencaMedioMensal.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(diferencaMedioMensal);

    ProposalConfigurationService.TagConfig diferencaMedioAnual = new ProposalConfigurationService.TagConfig();
    diferencaMedioAnual.tagKey = '{{DiferencaMedioAnual}}';
    diferencaMedioAnual.sourcePath = 'Calculated.DiferencaMedioAnual';
    diferencaMedioAnual.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(diferencaMedioAnual);

    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      opportunityRecord,
      configs,
      new List<String>{ 'Proposta de valores' },
      '068000000000009AAA'
    );

    Assert.areEqual(
      'Economia mensal',
      payload.tags.get('{{EconomiaMensal__c}}'),
      'O rótulo do aluguel deve ser preenchido quando a economia percentual for positiva.'
    );
    Assert.areEqual(
      'Economia mensal 60 x',
      payload.tags.get('{{EconomiaMensalTxt__c}}'),
      'O rótulo do financiamento deve incluir a quantidade de parcelas.'
    );
    Assert.areEqual(
      'Economia mensal 60 x',
      payload.tags.get('{{EconomiaMensalFinalTxt__c}}'),
      'A tag final do texto deve repetir o mesmo rótulo com a quantidade de parcelas.'
    );
    Assert.areEqual(
      'R$ 1.500,00',
      payload.tags.get('{{FinanciamentoMensal__c}}'),
      'O valor do financiamento deve ser a economia mensal estimada menos a parcela de 60x.'
    );
    Assert.areEqual(
      'R$ 2.000,00',
      payload.tags.get('{{AluguelEconomiaMensal__c}}'),
      'O valor do aluguel deve ser a economia mensal estimada menos a parcela de aluguel.'
    );
    Assert.areEqual(
      'R$ 500,00',
      payload.tags.get('{{DiferencaMedioMensal}}'),
      'A diferenca mensal deve ser o custo medio mensal menos a economia mensal estimada.'
    );
    Assert.areEqual(
      'R$ 6.000,00',
      payload.tags.get('{{DiferencaMedioAnual}}'),
      'A diferenca anual deve ser a diferenca mensal multiplicada por 12.'
    );
  }

  @isTest
  static void payloadBuilderClearsEconomiaMensalLabelsWhenPercentageIsNegative() {
    Opportunity opportunityRecord = [
      SELECT
        Id,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c,
        MainViability__c,
        CreatedDate
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    opportunityRecord.CustoMedioEnergia__c = 1000;
    opportunityRecord.EconomiaMensalEstimada__c = 500;
    opportunityRecord.TarifaComTributosB__c = 0;

    insert new List<PaymentSimulation__c>{
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 36,
        InstallmentAmount__c = 1300
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 48,
        InstallmentAmount__c = 1400
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Financing',
        ProposalLabel__c = 'Opção 1',
        InstallmentCount__c = 60,
        InstallmentAmount__c = 1500
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Rental',
        ProposalLabel__c = 'Solar Aluguel',
        InstallmentCount__c = 72,
        InstallmentAmount__c = 1200
      )
    };

    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];
    ProposalContextResolver.Context context = ProposalContextResolver.resolve(
      opportunityRecord.Id,
      cover.Id
    );

    List<ProposalConfigurationService.TagConfig> configs = new List<ProposalConfigurationService.TagConfig>();

    ProposalConfigurationService.TagConfig economiaMensal = new ProposalConfigurationService.TagConfig();
    economiaMensal.tagKey = '{{EconomiaMensal__c}}';
    economiaMensal.sourcePath = 'Calculated.EconomiaMensal';
    configs.add(economiaMensal);

    ProposalConfigurationService.TagConfig economiaMensalTxt = new ProposalConfigurationService.TagConfig();
    economiaMensalTxt.tagKey = '{{EconomiaMensalTxt__c}}';
    economiaMensalTxt.sourcePath = 'Calculated.EconomiaMensalTxt';
    configs.add(economiaMensalTxt);

    ProposalConfigurationService.TagConfig economiaMensalFinalTxt = new ProposalConfigurationService.TagConfig();
    economiaMensalFinalTxt.tagKey = '{{EconomiaMensalFinalTxt__c}}';
    economiaMensalFinalTxt.sourcePath = 'Calculated.EconomiaMensalFinalTxt';
    configs.add(economiaMensalFinalTxt);

    ProposalConfigurationService.TagConfig financiamentoMensal = new ProposalConfigurationService.TagConfig();
    financiamentoMensal.tagKey = '{{FinanciamentoMensal__c}}';
    financiamentoMensal.sourcePath = 'Calculated.FinanciamentoMensal';
    financiamentoMensal.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(financiamentoMensal);

    ProposalConfigurationService.TagConfig aluguelEconomiaMensal = new ProposalConfigurationService.TagConfig();
    aluguelEconomiaMensal.tagKey = '{{AluguelEconomiaMensal__c}}';
    aluguelEconomiaMensal.sourcePath = 'Calculated.AluguelEconomiaMensal';
    aluguelEconomiaMensal.formatValue = 'CURRENCY_BR_PREFIX';
    configs.add(aluguelEconomiaMensal);

    ProposalPayloadBuilder.Payload payload = ProposalPayloadBuilder.buildPayload(
      context,
      opportunityRecord,
      configs,
      new List<String>{ 'Proposta de valores' },
      '068000000000009AAA'
    );

    Assert.areEqual(
      '',
      payload.tags.get('{{EconomiaMensal__c}}'),
      'O rótulo do aluguel deve ser limpo quando a economia percentual for negativa.'
    );
    Assert.areEqual(
      '',
      payload.tags.get('{{EconomiaMensalTxt__c}}'),
      'O rótulo do financiamento deve ser limpo quando a economia percentual for negativa.'
    );
    Assert.areEqual(
      '',
      payload.tags.get('{{EconomiaMensalFinalTxt__c}}'),
      'A tag final do texto deve ser limpa quando a economia percentual for negativa.'
    );
    Assert.areEqual(
      '',
      payload.tags.get('{{FinanciamentoMensal__c}}'),
      'A economia mensal do financiamento deve ser zerada quando a porcentagem for negativa.'
    );
    Assert.areEqual(
      '',
      payload.tags.get('{{AluguelEconomiaMensal__c}}'),
      'A economia mensal do aluguel deve ser zerada quando a porcentagem for negativa.'
    );
  }

  @isTest
  static void integracaoNivelloHandlesEmptyAndExplicitProposal() {
    Opportunity opportunityRecord = [
      SELECT Id, SucessoIntegracaoNivello__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    IntegracaoNivelloProposta.ProposalIntegrationResult emptyResult = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opportunityRecord.Id,
      null
    );
    Assert.isTrue(
      emptyResult.success == false,
      'Sem arquivo de proposta o serviço deve indicar falha controlada.'
    );

    ContentVersion proposalVersion = new ContentVersion(
      Title = 'Proposta Engine',
      PathOnClient = 'proposta-engine.pdf',
      VersionData = Blob.valueOf('pdf'),
      FirstPublishLocationId = opportunityRecord.Id,
      IsProposal__c = true
    );
    insert proposalVersion;

    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'NIVELLO_ROOT';

    Test.startTest();
    IntegracaoNivelloProposta.ProposalIntegrationResult successResult = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opportunityRecord.Id,
      proposalVersion.Id
    );
    Test.stopTest();

    Assert.isTrue(
      successResult.success,
      'A integração deve aceitar o arquivo explícito.'
    );
    Opportunity updatedOpportunity = [
      SELECT SucessoIntegracaoNivello__c, StatusBodyIntegracaoNivello__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    Assert.isTrue(
      updatedOpportunity.SucessoIntegracaoNivello__c,
      'A oportunidade deve registrar sucesso na integração.'
    );
    Assert.isTrue(
      String.isNotBlank(updatedOpportunity.StatusBodyIntegracaoNivello__c),
      'O corpo da resposta precisa ser auditado na oportunidade.'
    );
  }

  @isTest
  static void integracaoNivelloPersistsFailureWhenCalloutThrows() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    ContentVersion proposalVersion = new ContentVersion(
      Title = 'Proposta Engine Falha',
      PathOnClient = 'proposta-engine-failure.pdf',
      VersionData = Blob.valueOf('pdf-failure'),
      FirstPublishLocationId = opportunityRecord.Id,
      IsProposal__c = true
    );
    insert proposalVersion;

    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'NIVELLO_THROW';

    Test.startTest();
    IntegracaoNivelloProposta.ProposalIntegrationResult failureResult = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opportunityRecord.Id,
      proposalVersion.Id
    );
    Test.stopTest();

    Assert.isFalse(
      failureResult.success,
      'Quando o callout falhar, a integração síncrona deve retornar erro controlado.'
    );
    Opportunity updatedOpportunity = [
      SELECT SucessoIntegracaoNivello__c, StatusBodyIntegracaoNivello__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    Assert.isFalse(
      updatedOpportunity.SucessoIntegracaoNivello__c,
      'A oportunidade deve registrar a falha da integração.'
    );
    Assert.isTrue(
      updatedOpportunity.StatusBodyIntegracaoNivello__c != null &&
      updatedOpportunity.StatusBodyIntegracaoNivello__c.contains(
        'Falha simulada'
      ),
      'A mensagem de erro precisa ficar auditada na oportunidade.'
    );
  }

  @isTest
  static void proposalAvailabilityRequiresStoredFileAndProposalLink() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    ProposalFileService.ProposalAvailability initialAvailability = ProposalFileService.getProposalAvailability(
        new Set<Id>{ opportunityRecord.Id }
      )
      .get(opportunityRecord.Id);
    Assert.isFalse(
      initialAvailability != null && initialAvailability.isReady(),
      'Sem artefatos, a oportunidade não deve ser considerada pronta.'
    );

    insert new ContentVersion(
      Title = 'Proposta Disponibilidade',
      PathOnClient = 'proposal-availability.pdf',
      VersionData = Blob.valueOf('pdf-availability'),
      FirstPublishLocationId = opportunityRecord.Id,
      IsProposal__c = true
    );

    insert new OpportunityAttachmentLink__c(
      Name = 'Link antigo',
      OpportunityId__c = opportunityRecord.Id,
      Type__c = 'Other',
      AttachmentURL__c = 'https://example.com/old-proposal.pdf'
    );

    ProposalFileService.ProposalAvailability incompleteAvailability = ProposalFileService.getProposalAvailability(
        new Set<Id>{ opportunityRecord.Id }
      )
      .get(opportunityRecord.Id);
    Assert.isTrue(
      incompleteAvailability != null &&
      incompleteAvailability.hasStoredProposal,
      'O arquivo salvo deve ser identificado.'
    );
    Assert.isFalse(
      incompleteAvailability != null && incompleteAvailability.hasProposalLink,
      'Um link classificado como Other não deve validar a proposta.'
    );
    Assert.isFalse(
      incompleteAvailability != null && incompleteAvailability.isReady(),
      'Sem link do tipo Proposal, a proposta ainda não está pronta.'
    );

    insert new OpportunityAttachmentLink__c(
      Name = 'Link proposta',
      OpportunityId__c = opportunityRecord.Id,
      Type__c = 'Proposal',
      AttachmentURL__c = 'https://example.com/proposal-ready.pdf'
    );

    ProposalFileService.ProposalAvailability readyAvailability = ProposalFileService.getProposalAvailability(
        new Set<Id>{ opportunityRecord.Id }
      )
      .get(opportunityRecord.Id);
    Assert.isTrue(
      readyAvailability != null && readyAvailability.isReady(),
      'Quando houver arquivo e link de proposta, a oportunidade deve ser tratada como pronta.'
    );
  }

  @isTest
  static void proposalApiGenerationJobIntegratesExplicitGeneratedVersion() {
    Opportunity opportunityRecord = [
      SELECT Id, SucessoIntegracaoNivello__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(opportunityRecord.Id, cover.Id, true)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT PropostaGerada__c, SucessoIntegracaoNivello__c
        FROM Opportunity
        WHERE Id = :opportunityRecord.Id
      ];
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'O job precisa marcar a oportunidade como proposta gerada.'
      );
      Assert.isTrue(
        updatedOpportunity.SucessoIntegracaoNivello__c,
        'O job deve integrar a proposta ao aplicativo.'
      );

      List<OpportunityAttachmentLink__c> attachmentLinks = [
        SELECT Type__c, AttachmentURL__c
        FROM OpportunityAttachmentLink__c
        WHERE OpportunityId__c = :opportunityRecord.Id AND Type__c = 'Proposal'
      ];
      Assert.areEqual(
        1,
        attachmentLinks.size(),
        'A integração assíncrona deve registrar a proposta na timeline da oportunidade.'
      );
      Assert.isTrue(
        String.isNotBlank(attachmentLinks[0].AttachmentURL__c),
        'O link salvo precisa conter a URL da proposta integrada.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalApiGenerationJobCanGenerateWithoutImmediateIntegration() {
    Opportunity opportunityRecord = [
      SELECT Id, PropostaGerada__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(opportunityRecord.Id, cover.Id, false)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT PropostaGerada__c
        FROM Opportunity
        WHERE Id = :opportunityRecord.Id
      ];
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'Mesmo sem integração imediata, o job deve salvar a proposta.'
      );

      Integer proposalLinkCount = [
        SELECT COUNT()
        FROM OpportunityAttachmentLink__c
        WHERE OpportunityId__c = :opportunityRecord.Id AND Type__c = 'Proposal'
      ];
      Assert.areEqual(
        0,
        proposalLinkCount,
        'Sem autoIntegrate, o job não deve criar link externo da proposta.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalApiGenerationJobMovesAwaitingAcceptanceToContract() {
    Opportunity opportunityRecord = [
      SELECT Id, StageName
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    update new Opportunity(
      Id = opportunityRecord.Id,
      StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE
    );

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(opportunityRecord.Id, cover.Id, false)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT StageName, PropostaGerada__c
        FROM Opportunity
        WHERE Id = :opportunityRecord.Id
      ];
      Assert.areEqual(
        OpportunityUtils.STATUS_CONTRATO,
        updatedOpportunity.StageName,
        'Quando a oportunidade estiver aguardando aceite, o job deve avançar para Contrato.'
      );
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'O avanço para contrato deve manter o flag de proposta gerada.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalApiGenerationJobHandlesGenerationFailureGracefully() {
    Opportunity opportunityRecord = [
      SELECT Id, PropostaGerada__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    Test.startTest();
    new ProposalApiGenerationJob(opportunityRecord.Id, cover.Id, true)
      .execute(null);
    Test.stopTest();

    Opportunity unchangedOpportunity = [
      SELECT PropostaGerada__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    Assert.isFalse(
      unchangedOpportunity.PropostaGerada__c,
      'Sem configuração mínima da API, o job deve falhar sem marcar proposta gerada.'
    );
  }

  @isTest
  static void proposalApiGenerationJobMovesEzeeConnectToProposalSent() {
    Opportunity baseOpportunity = [
      SELECT AccountId, Parceiro__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    Opportunity connectOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = baseOpportunity.AccountId,
        Parceiro__c = baseOpportunity.Parceiro__c,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('EzeeConnect')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = TestFactory.nextUniqueValue('VO-CONNECT-JOB')
      ),
      true
    );

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(connectOpportunity.Id, cover.Id, false)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT StageName, PropostaGerada__c
        FROM Opportunity
        WHERE Id = :connectOpportunity.Id
      ];
      Assert.areEqual(
        OpportunityUtils.STATUS_PROPOSTA_ENVIADA,
        updatedOpportunity.StageName,
        'Para EzeeConnect o job deve avançar para Proposta enviada.'
      );
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'O job deve marcar a proposta como gerada também para EzeeConnect.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalApiGenerationJobMovesSolarSimulationToProposalGenerated() {
    Opportunity baseOpportunity = [
      SELECT AccountId, Parceiro__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    Opportunity solarOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = baseOpportunity.AccountId,
        Parceiro__c = baseOpportunity.Parceiro__c,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_SIMULACAO_DE_PROPOSTA,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = TestFactory.nextUniqueValue('VO-SOLAR-JOB')
      ),
      true
    );

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(solarOpportunity.Id, cover.Id, false)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT StageName, PropostaGerada__c
        FROM Opportunity
        WHERE Id = :solarOpportunity.Id
      ];
      Assert.areEqual(
        OpportunityUtils.STATUS_PROPOSTA_GERADA,
        updatedOpportunity.StageName,
        'Para Solar em simulação o job deve avançar para Proposta Gerada.'
      );
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'O job deve marcar a proposta como gerada também no cenário Solar.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalApiGenerationJobMovesEzeeSolarBToCreditAnalysis() {
    Opportunity baseOpportunity = [
      SELECT AccountId, Parceiro__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    Opportunity ezeeSolarBOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = baseOpportunity.AccountId,
        Parceiro__c = baseOpportunity.Parceiro__c,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('EzeeSolarB')
          .getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = TestFactory.nextUniqueValue('VO-EZEESOLARB-JOB')
      ),
      true
    );

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'BASE64';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(ezeeSolarBOpportunity.Id, cover.Id, false)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT StageName, PropostaGerada__c
        FROM Opportunity
        WHERE Id = :ezeeSolarBOpportunity.Id
      ];
      Assert.areEqual(
        OpportunityUtils.STATUS_ANALISE_CREDITO,
        updatedOpportunity.StageName,
        'Para EzeeSolarB o job deve avançar para Análise de Crédito.'
      );
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'O job deve marcar a proposta como gerada também para EzeeSolarB.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalConsoleReturnsLegacyPreviewUrl() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    ProposalCover__c legacyCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaLegacy'),
        GrupoTarifario__c = 'Grupo B',
        Template__c = 'ModeloPropostaA'
      ),
      true
    );

    ProposalConsoleController.ProposalActionResult result = ProposalConsoleController.generatePreview(
      opportunityRecord.Id,
      legacyCover.Id
    );
    Assert.isTrue(
      result.success,
      'O preview legado deve continuar disponível.'
    );
    Assert.isTrue(
      result.previewUrl.contains('/apex/ModeloPropostaA'),
      'A URL do preview legado deve continuar apontando para a Visualforce.'
    );
  }

  private static void configureProposalMappingsForGeneration() {
    ProposalConfigurationService.TagConfig genericTag = new ProposalConfigurationService.TagConfig();
    genericTag.coverKey = COVER_KEY;
    genericTag.tagKey = '{{AccountName}}';
    genericTag.sourcePath = 'Account.Name';
    genericTag.scenario = ProposalConfigurationService.SCENARIO_ALL;
    genericTag.sortOrder = 1;
    genericTag.active = true;

    ProposalConfigurationService.setTestTagConfigs(
      new List<ProposalConfigurationService.TagConfig>{ genericTag }
    );
    ProposalConfigurationService.setTestSectionsByKey(
      new Map<String, List<String>>{
        ProposalConfigurationService.SCENARIO_INITIAL => new List<String>{
          'Proposta'
        }
      }
    );
    ProposalApiClient.testIntegrationUrl = 'https://api.example.com/convertProposal';
  }

  private static void clearProposalMappingsForGeneration() {
    ProposalConfigurationService.setTestTagConfigs(null);
    ProposalConfigurationService.setTestSectionsByKey(null);
    ProposalApiClient.testIntegrationUrl = null;
  }

  @isTest
  static void proposalApiGenerationJobHandlesApiFailureGracefully() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    configureProposalMappingsForGeneration();
    Test.setMock(HttpCalloutMock.class, new ProposalApiClientMock());
    apiMockMode = 'API_FAIL';

    try {
      Test.startTest();
      new ProposalApiGenerationJob(opportunityRecord.Id, cover.Id, true)
        .execute(null);
      Test.stopTest();

      Opportunity updatedOpportunity = [
        SELECT PropostaGerada__c
        FROM Opportunity
        WHERE Id = :opportunityRecord.Id
      ];
      Assert.isFalse(
        updatedOpportunity.PropostaGerada__c == true,
        'Quando a API falha o job nao deve marcar proposta como gerada.'
      );
    } finally {
      clearProposalMappingsForGeneration();
    }
  }

  @isTest
  static void proposalConfigurationServiceLoadsRealMetadataWithoutTestOverride() {
    // Remove overrides para forcar execucao dos caminhos reais
    ProposalConfigurationService.setTestTagConfigs(null);
    ProposalConfigurationService.setTestSectionsByKey(null);

    Test.startTest();
    List<ProposalConfigurationService.TagConfig> tags = ProposalConfigurationService.getTagConfigs(
      'GRUPO_B_PADRAO',
      ProposalConfigurationService.SCENARIO_INITIAL,
      null
    );
    List<String> sections = ProposalConfigurationService.getSectionsToShow(
      'GRUPO_B_PADRAO',
      ProposalConfigurationService.SCENARIO_INITIAL,
      'FINANCING'
    );
    List<String> sectionsDefault = ProposalConfigurationService.getSectionsToShow(
      'GRUPO_B_PADRAO',
      ProposalConfigurationService.SCENARIO_INITIAL,
      null
    );
    Test.stopTest();

    // Nao ha assertions sobre valores especificos — apenas garantindo cobertura dos caminhos reais
    Assert.isNotNull(tags, 'getTagConfigs nao deve retornar null.');
    Assert.isNotNull(sections, 'getSectionsToShow nao deve retornar null.');
    Assert.isNotNull(
      sectionsDefault,
      'getSectionsToShow sem paymentType nao deve retornar null.'
    );
  }

  @isTest
  static void computedValueServiceCoversViabilityCostPaths() {
    Opportunity opportunityRecord = [
      SELECT
        Id,
        MainViability__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    // Sem viabilidade — deve retornar vazio sem erro
    Map<String, Object> valuesNoViability = ProposalComputedValueService.build(
      opportunityRecord.Id,
      opportunityRecord
    );
    Assert.isNotNull(
      valuesNoViability,
      'build deve retornar mapa mesmo sem viabilidade.'
    );

    // Com viabilidade que tem todos os custos preenchidos
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      AdequacyCostEnerzee__c = 'Ramal CC;Ramal CA;Adequação Padrão;Cobertura;Laudo Estrutural;Outros Custos',
      AdequacyCostClient__c = 'Ramal CC',
      DcBranchCost__c = 100,
      AcBranchCost__c = 200,
      StandardAdequacyCost__c = 300,
      CoberturaCost__c = 400,
      StruturalReport__c = 500,
      OtherCosts__c = 600,
      OtherCostsDescription__c = 'Custo personalizado',
      AdditionalCost__c = 700
    );
    insert viability;

    update new Opportunity(
      Id = opportunityRecord.Id,
      MainViability__c = viability.Id
    );

    Opportunity oppWithViability = [
      SELECT
        Id,
        MainViability__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    oppWithViability.CustoMedioEnergia__c = 1000;
    oppWithViability.EconomiaMensalEstimada__c = 800;
    oppWithViability.GeracaoMensalEstimada__c = 500;
    oppWithViability.ConsumoInformadoB__c = 600;

    Map<String, Object> valuesWithViability = ProposalComputedValueService.build(
      oppWithViability.Id,
      oppWithViability
    );

    String custos = (String) valuesWithViability.get(
      'Calculated.CustosViabilidade'
    );
    Assert.isTrue(
      String.isNotBlank(custos),
      'CustosViabilidade deve ser preenchido quando há viabilidade com custos.'
    );
    Assert.isTrue(
      custos.contains('100'),
      'Ramal CC deve aparecer com valor formatado.'
    );
    Assert.isTrue(
      custos.contains('Custo personalizado'),
      'OtherCostsDescription deve substituir o label padrão.'
    );
  }

  @isTest
  static void computedValueServiceCoversViabilityCostWithoutMainViability() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunityRecord.Id,
      AdequacyCostEnerzee__c = 'Ramal CC',
      DcBranchCost__c = 150
    );
    insert viability;

    // Sem MainViability__c — cai no branch de busca por Opportunity__c
    Opportunity opp = [
      SELECT
        Id,
        MainViability__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Map<String, Object> values = ProposalComputedValueService.build(
      opp.Id,
      opp
    );
    String custos = (String) values.get('Calculated.CustosViabilidade');
    Assert.isTrue(
      String.isNotBlank(custos),
      'CustosViabilidade deve funcionar com fallback por Opportunity__c.'
    );
  }

  @isTest
  static void computedValueServiceCoversRental60xAndPixFallback() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];
    opportunityRecord.ValorTotalProdutos__c = 50000;
    update opportunityRecord;

    // Aluguel com exatamente 60 parcelas — deve ser selecionado diretamente
    insert new List<PaymentSimulation__c>{
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Rental',
        ProposalLabel__c = 'Aluguel',
        InstallmentCount__c = 48,
        InstallmentAmount__c = 800
      ),
      new PaymentSimulation__c(
        Opportunity__c = opportunityRecord.Id,
        PaymentType__c = 'Rental',
        ProposalLabel__c = 'Aluguel',
        InstallmentCount__c = 60,
        InstallmentAmount__c = 700
      )
    };

    Opportunity opp = [
      SELECT
        Id,
        MainViability__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    // Sem simulação selecionada (PIX) — fallback para ValorTotalProposta__c
    Map<String, Object> values = ProposalComputedValueService.build(
      opp.Id,
      opp
    );

    Assert.areEqual(
      'PIX VIA LINK',
      values.get('Calculated.formaPagamentoOutroSelecionado'),
      'Sem simulação selecionada, deve cair no caminho PIX.'
    );
    Assert.isTrue(
      String.valueOf(values.get('Calculated.ValorOutros')).contains('50.000'),
      'Sem simulação selecionada, PIX deve usar ValorTotalProposta__c como fallback.'
    );
    Assert.areEqual(
      700,
      ((Decimal) values.get('SimulationSummary.Rental.InstallmentAmount1'))
        .intValue(),
      'Deve selecionar o aluguel de 60 parcelas exatas.'
    );
  }

  @isTest
  static void computedValueServiceCoversBateriaValues() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    // Bateria via DescricaoBateria__c
    opportunityRecord.DescricaoBateria__c = '- Bateria 10,5 kWh\n- Inclui instalação\n- Garantia 10 anos';
    update opportunityRecord;

    Opportunity opp = [
      SELECT
        Id,
        MainViability__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Map<String, Object> values = ProposalComputedValueService.build(
      opp.Id,
      opp
    );

    Assert.areEqual(
      'Bateria 10,5 kWh',
      values.get('Calculated.BateriaDescricao'),
      'Deve remover o prefixo "- " e retornar a primeira linha.'
    );
    Assert.areEqual(
      '10,5',
      values.get('Calculated.bateriaKwh'),
      'Deve extrair o valor de kWh da descrição.'
    );
    Assert.isTrue(
      String.valueOf(values.get('Calculated.BateriaIncluso'))
        .contains('Inclui instalação'),
      'Deve capturar as linhas de inclusões.'
    );
  }

  @isTest
  static void computedValueServiceCoversBateriaFallbackToLineItem() {
    Opportunity opportunityRecord = [
      SELECT Id, AccountId
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    // Sem DescricaoBateria__c — fallback para Product2.Description
    String productCode = TestFactory.nextUniqueValue('BAT');
    Product2 product = new Product2(
      Name = 'Kit Bateria',
      Description = '- Bateria 7,5 kWh\n- Inclui suporte',
      IsActive = true,
      ProductCode = productCode,
      Id_Externo__c = productCode
    );
    insert product;

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product.Id,
      UnitPrice = 10000,
      IsActive = true
    );
    insert pbe;

    insert new OpportunityLineItem(
      OpportunityId = opportunityRecord.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 10000
    );

    Opportunity opp = [
      SELECT
        Id,
        MainViability__c,
        CreatedDate,
        ValorTotalProposta__c,
        DescricaoBateria__c,
        CustoMedioEnergia__c,
        EconomiaMensalEstimada__c,
        TarifaComTributosB__c,
        GeracaoMensalEstimada__c,
        ConsumoInformadoB__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Map<String, Object> values = ProposalComputedValueService.build(
      opp.Id,
      opp
    );

    Assert.areEqual(
      'Bateria 7,5 kWh',
      values.get('Calculated.BateriaDescricao'),
      'Deve usar Product2.Description como fallback quando DescricaoBateria__c estiver vazio.'
    );
    Assert.areEqual(
      '7,5',
      values.get('Calculated.bateriaKwh'),
      'Deve extrair kWh do fallback de Product2.'
    );
  }

  private class ProposalApiClientMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      String endpoint = request.getEndpoint();
      String contentType = request.getHeader('Content-Type');

      if (endpoint != null && endpoint.contains('/download/url-file.pdf')) {
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'application/pdf');
        response.setBodyAsBlob(Blob.valueOf('downloaded-pdf'));
        return response;
      }

      if (apiMockMode == 'API_FAIL') {
        response.setStatusCode(500);
        response.setHeader('Content-Type', 'application/json');
        response.setBody('{"success":false,"error":"Internal Server Error"}');
        return response;
      }

      if (
        String.isNotBlank(contentType) &&
        contentType.toLowerCase().contains('multipart/form-data')
      ) {
        if (apiMockMode == 'BASE64') {
          response.setStatusCode(200);
          response.setHeader('Content-Type', 'application/json');
          response.setBody(
            '{"fileBase64":"' +
              EncodingUtil.base64Encode(Blob.valueOf('pdf-base64')) +
              '","fileName":"base64.pdf","mimeType":"application/pdf"}'
          );
          return response;
        }

        if (apiMockMode == 'URL') {
          response.setStatusCode(200);
          response.setHeader('Content-Type', 'application/json');
          response.setBody(
            '{"data":{"urlFile":"https://example.com/download/url-file.pdf","fileName":"url-file.pdf"}}'
          );
          return response;
        }

        if (apiMockMode == 'PDF') {
          response.setStatusCode(200);
          response.setHeader('Content-Type', 'application/pdf');
          response.setBodyAsBlob(Blob.valueOf('raw-pdf'));
          return response;
        }
      }

      if (apiMockMode == 'NIVELLO_THROW') {
        throw new CalloutException('Falha simulada integracao');
      }

      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"success":true,"id":"ROOT-1","urlFile":"https://example.com/proposta-root.pdf"}'
      );
      return response;
    }
  }

  @isTest
  static void deleteStoredProposalsSkipsClicksignFiles() {
    Opportunity opportunityRecord = [
      SELECT Id, Numeroproposta__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-ENGINE-001'
      LIMIT 1
    ];

    String proposalNumber = opportunityRecord.Numeroproposta__c;

    // Arquivo de proposta normal — deve ser deletado
    ContentVersion normalVersion = new ContentVersion(
      Title = proposalNumber + ' Cliente Teste 2026-04-27',
      PathOnClient = proposalNumber + '-proposta.pdf',
      VersionData = Blob.valueOf('pdf-normal'),
      FirstPublishLocationId = opportunityRecord.Id,
      IsProposal__c = true
    );
    insert normalVersion;
    Id normalDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :normalVersion.Id
    ]
    .ContentDocumentId;

    // Arquivo ClickSign — NÃO deve ser deletado
    ContentVersion clicksignVersion = new ContentVersion(
      Title = proposalNumber + ' Cliente Teste 2026-03-27 01-10-19 - Clicksign',
      PathOnClient = proposalNumber + '-clicksign.pdf',
      VersionData = Blob.valueOf('pdf-clicksign'),
      FirstPublishLocationId = opportunityRecord.Id
    );
    insert clicksignVersion;
    Id clicksignDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :clicksignVersion.Id
    ]
    .ContentDocumentId;

    Test.startTest();
    ProposalFileService.deleteStoredProposals(
      new Set<Id>{ opportunityRecord.Id }
    );
    Test.stopTest();

    List<ContentDocument> remainingNormal = [
      SELECT Id
      FROM ContentDocument
      WHERE Id = :normalDocId
    ];
    List<ContentDocument> remainingClicksign = [
      SELECT Id
      FROM ContentDocument
      WHERE Id = :clicksignDocId
    ];

    Assert.areEqual(
      0,
      remainingNormal.size(),
      'O arquivo de proposta normal deve ser deletado no close.'
    );
    Assert.areEqual(
      1,
      remainingClicksign.size(),
      'O arquivo com Clicksign no título não deve ser deletado.'
    );
  }
}
