/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
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
        Template__c = 'ModeloPropostaA'
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

    Assert.areEqual(
      'GRUPO_B_PADRAO',
      ProposalCoverRoutingService.resolveCoverKey(
        new ProposalCover__c(
          Template__c = 'ModeloPropostaB',
          isPromotional__c = false
        )
      ),
      'A capa padrão ModeloPropostaB não promocional deve ser redirecionada para a chave da API.'
    );
    Assert.isTrue(
      ProposalCoverRoutingService.usesApiFlow(
        new ProposalCover__c(
          Template__c = 'ModeloPropostaB',
          isPromotional__c = false
        )
      ),
      'O fluxo deve reconhecer a capa padrão ModeloPropostaB como elegível para a API.'
    );
    Assert.areEqual(
      'CHAVE_EXPLICITA',
      ProposalCoverRoutingService.resolveCoverKey(
        new ProposalCover__c(IntegrationKey__c = 'CHAVE_EXPLICITA')
      ),
      'Quando existir IntegrationKey explícita ela deve ter prioridade.'
    );
    Assert.areEqual(
      null,
      ProposalCoverRoutingService.resolveCoverKey(
        new ProposalCover__c(
          Template__c = 'ModeloPropostaB',
          isPromotional__c = true
        )
      ),
      'A capa promocional não deve usar o fallback da capa padrão.'
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
    } catch (AuraHandledException handledException) {
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
    } catch (AuraHandledException handledException) {
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
      'O payload deve aplicar formatação monetária pt-BR.'
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
    } catch (AuraHandledException handledException) {
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
      SELECT Title, PathOnClient
      FROM ContentVersion
      WHERE Id = :contentVersionId
    ];
    Assert.areEqual(
      'arquivo-personalizado.pdf',
      savedVersion.PathOnClient,
      'O nome do arquivo sugerido pela API deve ser normalizado para PDF.'
    );
    Assert.areEqual(
      'arquivo-personalizado',
      savedVersion.Title,
      'O título salvo não deve repetir a extensão do PDF.'
    );
  }

  @isTest
  static void templateResolverUsesSinglePptxAttachedToStandardCover() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaTemplateUnico')
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;

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
      ),
      true
    );

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
    } catch (AuraHandledException handledException) {
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

  private class ProposalApiClientMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      String endpoint = request.getEndpoint();

      if (endpoint != null && endpoint.contains('/download/url-file.pdf')) {
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'application/pdf');
        response.setBodyAsBlob(Blob.valueOf('downloaded-pdf'));
        return response;
      }

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

      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"success":true,"id":"ROOT-1","urlFile":"https://example.com/proposta-root.pdf"}'
      );
      return response;
    }
  }
}
