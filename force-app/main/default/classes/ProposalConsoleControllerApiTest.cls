/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class ProposalConsoleControllerApiTest {
  private static final String COVER_KEY = 'API_GROUP_B_TEST';
  private static Integer proposalCallCount = 0;
  private static Integer nivelloCallCount = 0;

  @TestSetup
  static void setup() {
    Account account = (Account) TestFactory.createSObject(
      new Account(Name = 'Conta API Teste'),
      true
    );

    ProposalCover__c apiCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = 'Capa API Teste',
        GrupoTarifario__c = 'Grupo B',
        IntegrationKey__c = COVER_KEY,
        Template__c = 'ModeloPropostaA'
      ),
      true
    );

    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = 'Parceiro API Teste',
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = apiCover.Id
      ),
      true
    );

    TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = partner.Id,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = 'VO-API-001'
      ),
      true
    );

    insert new ContentVersion(
      Title = 'Template API Teste',
      PathOnClient = 'template-api-teste.pptx',
      VersionData = Blob.valueOf('pptx-template'),
      FirstPublishLocationId = apiCover.Id,
      IsTemplate__c = true,
      ProposalTemplateRole__c = 'API_PPTX_TEMPLATE'
    );
  }

  @isTest
  static void generatePreviewAndSendProposalReuseGeneratedFile() {
    Opportunity opportunityRecord = [
      SELECT Id, StageName, PropostaGerada__c
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-API-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    configureApiMappings(COVER_KEY);
    resetCalloutCounters();
    Test.setMock(HttpCalloutMock.class, new ProposalApiAndNivelloMock());

    try {
      ProposalConsoleController.ProposalActionResult previewResult;
      ProposalConsoleController.ProposalActionResult sendResult;

      Test.startTest();
      previewResult = ProposalConsoleController.generatePreview(
        opportunityRecord.Id,
        cover.Id
      );
      sendResult = ProposalConsoleController.sendProposal(
        opportunityRecord.Id,
        cover.Id
      );
      Test.stopTest();

      Assert.isTrue(
        previewResult.success,
        'O preview deve ser gerado com sucesso.'
      );
      Assert.isNotNull(
        previewResult.contentVersionId,
        'O preview deve persistir um ContentVersion reutilizavel.'
      );
      Assert.isTrue(
        String.isNotBlank(previewResult.previewUrl),
        'O preview deve expor uma URL para o iframe.'
      );

      Assert.isTrue(
        sendResult.success,
        'O envio da proposta deve retornar sucesso.'
      );
      Assert.isTrue(
        sendResult.message != null &&
        sendResult.message.contains('envio para o aplicativo iniciado'),
        'O retorno do envio deve explicar que a integração roda em segundo plano.'
      );
      Assert.areEqual(
        previewResult.contentVersionId,
        sendResult.contentVersionId,
        'O envio deve reutilizar o mesmo arquivo gerado no preview.'
      );
      Assert.isTrue(
        sendResult.reusedExistingFile,
        'O fluxo de envio deve indicar que reutilizou o PDF existente.'
      );
      Assert.areEqual(
        1,
        proposalCallCount,
        'A API de conversao deve ser chamada apenas uma vez.'
      );
      Assert.areEqual(
        1,
        nivelloCallCount,
        'O envio ao aplicativo deve ocorrer uma vez.'
      );

      ContentVersion generatedVersion = [
        SELECT
          Id,
          FirstPublishLocationId,
          IsProposal__c,
          ProposalCoverKey__c,
          ProposalScenario__c
        FROM ContentVersion
        WHERE Id = :sendResult.contentVersionId
      ];
      Assert.areEqual(
        opportunityRecord.Id,
        generatedVersion.FirstPublishLocationId,
        'O PDF final precisa estar vinculado a oportunidade.'
      );
      Assert.isTrue(
        generatedVersion.IsProposal__c,
        'O arquivo gerado precisa ser marcado como proposta.'
      );
      Assert.areEqual(
        COVER_KEY,
        generatedVersion.ProposalCoverKey__c,
        'A auditoria do arquivo precisa guardar a chave da capa.'
      );
      Assert.areEqual(
        ProposalConfigurationService.SCENARIO_INITIAL,
        generatedVersion.ProposalScenario__c,
        'O preview inicial deve registrar o cenário correto.'
      );

      Opportunity updatedOpportunity = [
        SELECT PropostaGerada__c, StageName, SucessoIntegracaoNivello__c
        FROM Opportunity
        WHERE Id = :opportunityRecord.Id
      ];
      Assert.isTrue(
        updatedOpportunity.PropostaGerada__c,
        'A oportunidade deve ser marcada como proposta gerada.'
      );
      Assert.areEqual(
        OpportunityUtils.STATUS_PROPOSTA_GERADA,
        updatedOpportunity.StageName,
        'A oportunidade deve avançar para a fase esperada.'
      );
      Assert.isTrue(
        updatedOpportunity.SucessoIntegracaoNivello__c,
        'O envio ao app deve marcar sucesso na oportunidade.'
      );

      List<OpportunityAttachmentLink__c> attachmentLinks = [
        SELECT AttachmentURL__c, ExternalId__c, OpportunityId__c, Type__c
        FROM OpportunityAttachmentLink__c
        WHERE OpportunityId__c = :opportunityRecord.Id
        LIMIT 1
      ];
      if (!attachmentLinks.isEmpty()) {
        OpportunityAttachmentLink__c attachmentLink = attachmentLinks[0];
        Assert.areEqual(
          'https://example.com/proposta-api.pdf',
          attachmentLink.AttachmentURL__c,
          'A URL retornada pelo aplicativo deve ser persistida.'
        );
        Assert.areEqual(
          'ATT-001',
          attachmentLink.ExternalId__c,
          'O identificador externo deve ser guardado no link da proposta.'
        );
        Assert.areEqual(
          'Proposal',
          attachmentLink.Type__c,
          'O anexo externo deve ser classificado como proposta.'
        );
      }
    } finally {
      clearApiMappings();
    }
  }

  @isTest
  static void loadProposalDataUsesPromotionalCoverAsDefault() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaPromocional')
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;
    ProposalCover__c standardCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaPadrao'),
        GrupoTarifario__c = 'Grupo B',
        isPromotional__c = false
      ),
      true
    );
    ProposalCover__c promotionalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaPromocional'),
        GrupoTarifario__c = 'Grupo B',
        isPromotional__c = true
      ),
      true
    );
    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = TestFactory.nextUniqueValue('ParceiroPromocional'),
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = standardCover.Id,
        CapaPromocional__c = promotionalCover.Id
      ),
      true
    );
    Opportunity promotionalOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = partner.Id,
        GrupoTarifario__c = 'Grupo B',
        isPromotional__c = true,
        TipoKitPromocional__c = '6'
      ),
      true
    );

    Test.startTest();
    ProposalConsoleController.ProposalDataDTO result = ProposalConsoleController.loadProposalData(
      promotionalOpportunity.Id
    );
    Test.stopTest();

    Assert.areEqual(
      promotionalCover.Id,
      result.defaultTemplateId,
      'O cover promocional deve ser o default quando a oportunidade for promocional.'
    );
    Assert.areEqual(
      2,
      result.templates.size(),
      'As duas capas ativas do parceiro devem ser exibidas.'
    );
  }

  @isTest
  static void loadProposalDataIgnoresPromotionalCoverWhenKitIsBlank() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaSemKit')
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;

    ProposalCover__c standardCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaPadraoSemKit'),
        GrupoTarifario__c = 'Grupo B',
        isPromotional__c = false
      ),
      true
    );
    ProposalCover__c promotionalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaPromoSemKit'),
        GrupoTarifario__c = 'Grupo B',
        isPromotional__c = true
      ),
      true
    );
    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = TestFactory.nextUniqueValue('ParceiroSemKit'),
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = standardCover.Id,
        CapaPromocional__c = promotionalCover.Id
      ),
      true
    );
    Opportunity opportunityWithoutKit = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = partner.Id,
        GrupoTarifario__c = 'Grupo B'
      ),
      true
    );

    update new Opportunity(
      Id = opportunityWithoutKit.Id,
      TipoKitPromocional__c = null,
      isPromotional__c = false
    );

    Test.startTest();
    ProposalConsoleController.ProposalDataDTO result = ProposalConsoleController.loadProposalData(
      opportunityWithoutKit.Id
    );
    Test.stopTest();

    Assert.areEqual(
      standardCover.Id,
      result.defaultTemplateId,
      'Sem kit promocional preenchido, a capa padrão deve continuar como default.'
    );
    Assert.areEqual(
      1,
      result.templates.size(),
      'Sem kit promocional preenchido, a capa promocional não deve ser exibida.'
    );
    Assert.areEqual(
      standardCover.Id,
      result.templates[0].id,
      'A única opção disponível deve ser a capa padrão.'
    );
  }

  @isTest
  static void generatePreviewFailsWhenApiTemplateConfigurationIsAmbiguous() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE IdVirtualOffice__c = 'VO-API-001'
      LIMIT 1
    ];
    ProposalCover__c cover = [
      SELECT Id
      FROM ProposalCover__c
      WHERE IntegrationKey__c = :COVER_KEY
      LIMIT 1
    ];

    insert new ContentVersion(
      Title = 'Template API Duplicado',
      PathOnClient = 'template-api-duplicado.pptx',
      VersionData = Blob.valueOf('pptx-template-2'),
      FirstPublishLocationId = cover.Id,
      IsTemplate__c = true,
      ProposalTemplateRole__c = 'API_PPTX_TEMPLATE'
    );

    configureApiMappings(COVER_KEY);
    Test.setMock(HttpCalloutMock.class, new ProposalApiAndNivelloMock());

    try {
      Test.startTest();
      try {
        ProposalConsoleController.generatePreview(
          opportunityRecord.Id,
          cover.Id
        );
        Assert.fail(
          'A geração deveria falhar quando existir mais de um template válido.'
        );
      } catch (AuraHandledException handledException) {
        Assert.isTrue(
          String.isNotBlank(handledException.getMessage()),
          'O fluxo deve lançar uma exceção quando houver mais de um template válido.'
        );
      }
      Test.stopTest();
    } finally {
      clearApiMappings();
    }
  }

  @isTest
  static void generatePreviewUsesApiFallbackWhenLegacyTemplateIsMapped() {
    Account account = new Account(
      Name = TestFactory.nextUniqueValue('ContaFallbackApi')
    );
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    account.setOptions(accountOptions);
    insert account;

    ProposalCover__c mappedCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Name = TestFactory.nextUniqueValue('CapaFallbackApi'),
        GrupoTarifario__c = 'Grupo B',
        Template__c = 'ModeloPropostaB'
      ),
      true
    );

    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = TestFactory.nextUniqueValue('ParceiroFallbackApi'),
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = mappedCover.Id
      ),
      true
    );

    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
        Parceiro__c = partner.Id,
        GrupoTarifario__c = 'Grupo B',
        IdVirtualOffice__c = TestFactory.nextUniqueValue('VO-FALLBACK')
      ),
      true
    );

    insert new ContentVersion(
      Title = 'Template Fallback API',
      PathOnClient = 'template-fallback-api.pptx',
      VersionData = Blob.valueOf('pptx-template-fallback'),
      FirstPublishLocationId = mappedCover.Id,
      IsTemplate__c = true,
      ProposalTemplateRole__c = 'API_PPTX_TEMPLATE'
    );

    configureApiMappings('GRUPO_B_PADRAO');
    resetCalloutCounters();
    Test.setMock(HttpCalloutMock.class, new ProposalApiAndNivelloMock());

    try {
      Test.startTest();
      ProposalConsoleController.ProposalActionResult result = ProposalConsoleController.generatePreview(
        opportunityRecord.Id,
        mappedCover.Id
      );
      Test.stopTest();

      Assert.isTrue(
        result.success,
        'A capa legada mapeada deve gerar preview usando a API.'
      );
      Assert.isTrue(
        String.isNotBlank(result.previewUrl),
        'O preview precisa retornar a URL do PDF gerado.'
      );
      Assert.areEqual(
        1,
        proposalCallCount,
        'A geração deve passar pela API quando o template legado estiver mapeado.'
      );
    } finally {
      clearApiMappings();
    }
  }

  private static void configureApiMappings(String coverKey) {
    ProposalConfigurationService.TagConfig tagConfig = new ProposalConfigurationService.TagConfig();
    tagConfig.coverKey = coverKey;
    tagConfig.tagKey = '{{NomeDaConta__c}}';
    tagConfig.sourcePath = 'Account.Name';
    tagConfig.scenario = ProposalConfigurationService.SCENARIO_INITIAL;
    tagConfig.required = true;
    tagConfig.sortOrder = 1;
    tagConfig.active = true;

    ProposalConfigurationService.setTestTagConfigs(
      new List<ProposalConfigurationService.TagConfig>{ tagConfig }
    );
    ProposalConfigurationService.setTestSectionsByKey(
      new Map<String, List<String>>{
        ProposalConfigurationService.SCENARIO_INITIAL => new List<String>{
          'Proposta'
        }
      }
    );
  }

  private static void clearApiMappings() {
    ProposalConfigurationService.setTestTagConfigs(null);
    ProposalConfigurationService.setTestSectionsByKey(null);
  }

  private static void resetCalloutCounters() {
    proposalCallCount = 0;
    nivelloCallCount = 0;
  }

  private class ProposalApiAndNivelloMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      String endpoint = request.getEndpoint();
      String requestBody = request.getBody();

      if (endpoint != null && endpoint.contains('/convertProposal')) {
        ProposalConsoleControllerApiTest.proposalCallCount++;
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(
          '{"fileBase64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('pdf-api-content')) +
            '","fileName":"proposta-api.pdf","mimeType":"application/pdf"}'
        );
        return response;
      }

      if (requestBody != null && requestBody.contains('"contract"')) {
        ProposalConsoleControllerApiTest.nivelloCallCount++;
      }
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"success":true,"data":{"id":"ATT-001","urlFile":"https://example.com/proposta-api.pdf"}}'
      );
      return response;
    }
  }
}
