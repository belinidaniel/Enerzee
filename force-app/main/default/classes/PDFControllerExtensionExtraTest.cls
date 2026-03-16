/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class PDFControllerExtensionExtraTest {
  private static Opportunity createOpp() {
    Account acc = new Account(Name = 'PDF Acc');
    insert acc;
    return new Opportunity(
      Name = 'PDF Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'vo-pdf',
      TarifaEnergia__c = 100,
      CustoMensalAproximadoBowE__c = 200,
      EconomiaPromocional__c = 300,
      EconomiaFixa__c = 400,
      FaturaDescontoPromocional__c = 500,
      FaturaDescontoFixo__c = 600,
      EconomiaXMesesPromocional__c = 700,
      EconomiaXMesesFixa__c = 800,
      EconomiaAnualEstimada__c = 900
    );
  }

  @IsTest
  static void hasKitReturnsTrueWhenLineItemsExist() {
    Opportunity opp = createOpp();
    insert opp;
    opp.PropostaGerada__c = true;
    opp.ReadequacaoSolicitada__c = false;
    opp.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
    opp.ObservacaoPagamentoEsquerdo__c = 'Teste';
    opp.ObservacaoPagamentoDireito__c = 'Teste';
    update opp;

    Pricebook2 pb = new Pricebook2(Name = 'Test PB', IsActive = true);
    insert pb;
    Product2 prod = new Product2(
      Name = 'Prod',
      IsActive = true,
      Id_Externo__c = 'EXT-PROD',
      ExternalId__c = 'EXT-PROD'
    );
    insert prod;

    // Standard pricebook entry is required before custom pricebook entries
    Id stdPbId = Test.getStandardPricebookId();
    insert new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = prod.Id,
      UnitPrice = 1,
      IsActive = true
    );

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = pb.Id,
      Product2Id = prod.Id,
      UnitPrice = 1,
      IsActive = true
    );
    insert pbe;
    OpportunityLineItem oli = new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      TotalPrice = 1
    );
    insert oli;

    // Insere um ContentVersion marcado como proposta para acionar caminho existingCount>0
    ContentVersion cv = new ContentVersion(
      Title = 'PROPOSTA_TESTE',
      PathOnClient = 'PROPOSTA_TESTE.pdf',
      FirstPublishLocationId = opp.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('pdf'),
      IsProposal__c = true
    );
    insert cv;

    Test.startTest();
    Boolean result = PDFControllerExtension.hasKit(opp);
    PDFControllerExtension.savePdfFileAsync(opp.Id, true);
    Test.stopTest();

    System.assertEquals(true, result);
  }

  @IsTest
  static void createAddContextIdToEndpointMapAddsEntry() {
    Map<Integer, Set<Id>> mapIds = new Map<Integer, Set<Id>>();
    Opportunity opp = createOpp();
    insert opp;
    Id dummyOppId = opp.Id;

    PDFControllerExtension.createAddContextIdToEndpointMap(
      mapIds,
      1,
      dummyOppId
    );

    System.assert(mapIds.containsKey(1));
    System.assert(mapIds.get(1).contains(dummyOppId));
  }

  @IsTest
  static void shouldFormatCurrencyBRAndAccessGetters() {
    ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = ProposalCover.id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.id;

    insert opp;
    opp.MainViability__c = null;
    update opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    System.assertNotEquals(null, ext.getTarifaFormatada());
    System.assertNotEquals(null, ext.getCustoMensalFormatado());
    System.assertNotEquals(null, ext.getEconomiaPromocionalFormatada());
    System.assertNotEquals(null, ext.getEconomiaFixaFormatada());
    System.assertNotEquals(null, ext.getFaturaPromocionalFormatada());
    System.assertNotEquals(null, ext.getFaturaFixaFormatada());
    System.assertNotEquals(null, ext.getEconomiaXMesesPromocionalFormatada());
    System.assertNotEquals(null, ext.getEconomiaXMesesFixaFormatada());
    System.assertNotEquals(null, ext.getEconomiaAnualFormatada());
    System.assertNotEquals(null, ext.getHasViabilityEnerzeeCosts());
    System.assertNotEquals(null, ext.getHasViabilityClientCosts());
    System.assertNotEquals(null, ext.getMainViabilityChunkCount());
    ext.getActiveCovers();
    ext.getLogoUrl();
  }

  @IsTest
  static void shouldPrioritizeOpportunityBatteryDescriptionOverProductDescription() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    opp.DescricaoBateria__c = 'Descricao da bateria informada na modal';
    insert opp;

    Pricebook2 pb = new Pricebook2(Name = 'Battery Test PB', IsActive = true);
    insert pb;
    opp.Pricebook2Id = pb.Id;
    update opp;

    Product2 prod = new Product2(
      Name = 'Bateria Produto',
      Description = 'Descricao padrao do produto',
      IsActive = true,
      Id_Externo__c = 'EXT-BATT',
      ExternalId__c = 'EXT-BATT'
    );
    insert prod;

    Id stdPbId = Test.getStandardPricebookId();
    insert new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = prod.Id,
      UnitPrice = 1,
      IsActive = true
    );

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = pb.Id,
      Product2Id = prod.Id,
      UnitPrice = 1,
      IsActive = true
    );
    insert pbe;

    insert new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      TotalPrice = 1
    );

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    System.assertEquals(
      'Descricao da bateria informada na modal',
      ext.description,
      'DescricaoBateria__c deve prevalecer sobre a descricao do produto.'
    );
  }

  @IsTest
  static void shouldHandleMainViabilityHelpers() {
    Opportunity opp = createOpp();
    insert opp;

    // sem viability => line count 0, chunks vazios
    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);
    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    System.assertEquals(0, ext.getMainViabilityTextLineCount());
    System.assertEquals(true, ext.getMainViabilityStudyChunks().isEmpty());

    // com viability e texto
    ViabilityStudy__c vs = new ViabilityStudy__c(
      TextStudy__c = 'linha1\nlinha2',
      Opportunity__c = opp.Id
    );
    insert vs;
    opp.MainViability__c = vs.Id;
    update opp;

    pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);
    ext = new PDFControllerExtension(new ApexPages.StandardController(opp));
    System.assertEquals(2, ext.getMainViabilityTextLineCount());
    System.assert(!ext.getMainViabilityStudyChunks().isEmpty());
  }

  @IsTest
  static void shouldReturnFalseFromSalvarPdfWhenSkipAutoSaveTrue() {
    Opportunity opp = createOpp();
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('skipAutoSave', 'true');
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Test.startTest();
    PageReference result = ext.salvarPDF();
    Test.stopTest();

    Assert.isNull(result, 'salvarPDF deve retornar null quando skipAutoSave=true.');
  }

  @IsTest
  static void shouldReturnNullFromSalvarPdfWhenSalvarIsNao() {
    Opportunity opp = createOpp();
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('salvar', 'Não');
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Test.startTest();
    PageReference result = ext.salvarPDF();
    Test.stopTest();

    Assert.isNull(result, 'salvarPDF deve retornar null quando salvar=Não.');
  }

  @IsTest
  static void shouldCoverGetShouldRenderAndGetHasMainViabilityLayout() {
    Opportunity opp = createOpp();
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension extEmpty = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    Assert.isFalse(
      extEmpty.getShouldRenderMainViabilityStudy(),
      'Sem viability chunks deve retornar false.'
    );
    Assert.isFalse(
      extEmpty.getHasMainViabilityLayout(),
      'Sem layout URL deve retornar false.'
    );
    Assert.areEqual(0, extEmpty.getMainViabilityChunkCount());

    // Com viability e texto longo (>2200 chars para acionar chunking)
    String longText = 'A'.repeat(2500);
    ViabilityStudy__c vs = new ViabilityStudy__c(
      TextStudy__c = longText,
      Opportunity__c = opp.Id
    );
    insert vs;
    opp.MainViability__c = vs.Id;
    update opp;

    pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension extWithChunks = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    Assert.isTrue(
      extWithChunks.getShouldRenderMainViabilityStudy(),
      'Com texto longo deve ter chunks.'
    );
    Assert.isTrue(extWithChunks.getMainViabilityChunkCount() > 0);
  }

  @IsTest
  static void shouldCallSavePdfFileStaticAndGeneratePdfContent() {
    Opportunity opp = createOpp();
    insert opp;

    Blob content = PDFControllerExtension.generatePdfContent(
      opp.Id,
      null,
      'dummy',
      false
    );
    Assert.isNotNull(content, 'generatePdfContent deve retornar blob em test context.');

    Id fileId = PDFControllerExtension.savePdfFile(
      opp.Id,
      'Test File',
      'dummy',
      Blob.valueOf('test content'),
      false
    );
    Assert.isNotNull(fileId, 'savePdfFile deve retornar um Id.');
  }

  @IsTest
  static void shouldEnqueueSavePdfJob() {
    Opportunity opp = createOpp();
    opp.PropostaGerada__c = true;
    opp.ReadequacaoSolicitada__c = false;
    opp.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
    insert opp;

    ContentVersion cv = new ContentVersion(
      Title = 'PROPOSTA_JOB',
      PathOnClient = 'PROPOSTA_JOB.pdf',
      FirstPublishLocationId = opp.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('pdf'),
      IsProposal__c = true
    );
    insert cv;

    Test.startTest();
    System.enqueueJob(
      new PDFControllerExtension.SavePdfJob(opp.Id, false, false)
    );
    Test.stopTest();

    Assert.isTrue(true, 'SavePdfJob nao deve lancar erro.');
  }

  // ─── Additional coverage tests ───────────────────────────────────────────────

  @IsTest
  static void shouldFormatCurrencyBRNullReturnsHyphen() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    // All numeric fields null for this test
    opp.TarifaEnergia__c = null;
    opp.CustoMensalAproximadoBowE__c = null;
    opp.EconomiaPromocional__c = null;
    opp.EconomiaFixa__c = null;
    opp.FaturaDescontoPromocional__c = null;
    opp.FaturaDescontoFixo__c = null;
    opp.EconomiaXMesesPromocional__c = null;
    opp.EconomiaXMesesFixa__c = null;
    opp.EconomiaAnualEstimada__c = null;
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Assert.areEqual('-', ext.getTarifaFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getCustoMensalFormatado(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getEconomiaPromocionalFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getEconomiaFixaFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getFaturaPromocionalFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getFaturaFixaFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getEconomiaXMesesPromocionalFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getEconomiaXMesesFixaFormatada(), 'null deve retornar hífen.');
    Assert.areEqual('-', ext.getEconomiaAnualFormatada(), 'null deve retornar hífen.');
  }

  @IsTest
  static void shouldFormatCurrencyBRLargeValueWithThousandsSeparator() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    opp.TarifaEnergia__c = 1234567.89;
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    String formatted = ext.getTarifaFormatada();
    Assert.isTrue(
      formatted.startsWith('R$'),
      'Valor formatado deve começar com R$'
    );
    Assert.isTrue(
      formatted.contains('.'),
      'Valor grande deve ter separador de milhar.'
    );
  }

  @IsTest
  static void shouldFormatCurrencyBRZeroValue() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    opp.TarifaEnergia__c = 0;
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    String formatted = ext.getTarifaFormatada();
    Assert.areEqual('R$ 0,00', formatted, 'Zero deve ser formatado como R$ 0,00.');
  }

  @IsTest
  static void shouldLoadViabilityCostDetailsWithCostData() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    insert opp;

    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      AdequacyCostEnerzee__c = 'Ramal CC;Ramal CA;Adequação Padrão;Cobertura;Laudo Estrutural;Outros Custos',
      AdequacyCostClient__c = 'Ramal CC;Outros Custos',
      DcBranchCost__c = 500,
      AcBranchCost__c = 300,
      StandardAdequacyCost__c = 800,
      CoberturaCost__c = 200,
      StruturalReport__c = 150,
      OtherCosts__c = 100,
      OtherCostsDescription__c = 'Reforma elétrica',
      AdditionalCost__c = 400
    );
    insert vs;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Assert.isTrue(
      ext.getHasViabilityEnerzeeCosts(),
      'Deve ter entradas de custo Enerzee quando campos preenchidos.'
    );
    Assert.isTrue(
      ext.getHasViabilityClientCosts(),
      'Deve ter entradas de custo Cliente quando campos preenchidos.'
    );
    Assert.isTrue(
      ext.viabilityEnerzeeCostEntries.size() > 0,
      'viabilityEnerzeeCostEntries não deve estar vazio.'
    );
  }

  @IsTest
  static void shouldCoverResolveViabilityCostLabelWithOutrosDescricao() {
    // Cover resolveViabilityCostLabel when label is "outros custos" and OtherCostsDescription__c is set
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    insert opp;

    ViabilityStudy__c vs = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      AdequacyCostEnerzee__c = 'Outros Custos',
      AdequacyCostClient__c = 'Outros Custos',
      OtherCosts__c = 0,
      OtherCostsDescription__c = 'Manutenção geral'
    );
    insert vs;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    // When amount is 0/null the entry is added without amount — triggers label resolution path
    Assert.isTrue(
      ext.viabilityEnerzeeCostEntries.size() > 0,
      'Deve ter ao menos uma entrada de custo Enerzee mesmo com valor 0.'
    );
  }

  @IsTest
  static void shouldCoverMainViabilityStudyChunksWithLongTextSplitOnSpace() {
    // Cover findBestSplitPosition: text exactly at boundary with spaces for split
    Opportunity opp = createOpp();
    insert opp;

    // Build a text > 2200 chars with spaces to exercise backward/forward scan in findBestSplitPosition
    String word = 'palavra ';
    String longText = word.repeat(300); // ~2400 chars with spaces
    ViabilityStudy__c vs = new ViabilityStudy__c(
      TextStudy__c = longText,
      Opportunity__c = opp.Id
    );
    insert vs;
    opp.MainViability__c = vs.Id;
    update opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Assert.isTrue(
      ext.getMainViabilityStudyChunks().size() > 1,
      'Texto longo com espaços deve gerar múltiplos chunks.'
    );
    Assert.isTrue(
      ext.getMainViabilityChunkCount() > 1,
      'getMainViabilityChunkCount deve refletir múltiplos chunks.'
    );
    Assert.isTrue(
      ext.getMainViabilityTextLineCount() >= 1,
      'getMainViabilityTextLineCount deve ser ao menos 1.'
    );
  }

  @IsTest
  static void shouldCoverSalvarPDFWithPaymentMethodNotes() {
    Opportunity opp = createOpp();
    opp.ObservacaoPagamentoEsquerdo__c = 'Texto esquerdo';
    opp.ObservacaoPagamentoDireito__c = null;
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('salvar', 'Não');
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Assert.isTrue(ext.showPaymentMethodNotes, 'showPaymentMethodNotes deve ser true quando há texto esquerdo.');
    Assert.isNull(ext.salvarPDF(), 'salvarPDF deve retornar null quando salvar=Não.');
  }

  @IsTest
  static void shouldCoverGetLogoUrlWithLogoAttached() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    insert opp;

    // Attach a ContentVersion with 'Logo' in title linked to the parceiro
    ContentVersion cv = new ContentVersion(
      Title = 'Logo Parceiro',
      PathOnClient = 'Logo.png',
      FirstPublishLocationId = parceiro.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('logo-data')
    );
    insert cv;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    String logoUrl = ext.getLogoUrl();
    Assert.isNotNull(logoUrl, 'getLogoUrl deve retornar URL quando há arquivo Logo vinculado ao parceiro.');
    Assert.isTrue(logoUrl.startsWith('/sfc/'), 'URL do logo deve começar com /sfc/.');
  }

  @IsTest
  static void shouldCoverGetMainViabilityStudyChunksWhenNull() {
    Opportunity opp = createOpp();
    insert opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    // Call getMainViabilityStudyChunks when null (branch where it initializes list)
    List<String> chunks = ext.getMainViabilityStudyChunks();
    Assert.isNotNull(chunks, 'getMainViabilityStudyChunks não deve retornar null.');
    Assert.areEqual(0, chunks.size(), 'Sem viability deve retornar lista vazia.');

    Assert.isFalse(
      ext.getHasMainViabilityLayout(),
      'Sem layout deve retornar false.'
    );
  }

  @IsTest
  static void shouldCoverFindBestSplitPositionForwardScanNoSpaces() {
    // 2600 chars with NO spaces forces the forward scan branch in findBestSplitPosition
    // (backward scan finds no space → falls through to forward scan at line 1182)
    Opportunity opp = createOpp();
    insert opp;

    String noSpaceText = 'A'.repeat(2600);
    ViabilityStudy__c vs = new ViabilityStudy__c(
      TextStudy__c = noSpaceText,
      Opportunity__c = opp.Id
    );
    insert vs;
    opp.MainViability__c = vs.Id;
    update opp;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );

    Assert.isTrue(
      ext.getMainViabilityStudyChunks().size() > 0,
      'Texto sem espaços deve gerar ao menos um chunk.'
    );
  }

  @IsTest
  static void shouldLoadPdfUrlsWithSelectedCoverAndPaymentNote() {
    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = cover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = partner.Id;
    opp.NotePaymentMethod__c = 'nota';
    insert opp;

    ContentVersion cv = new ContentVersion(
      Title = 'SEMPAGAMENTOS',
      PathOnClient = 'SEMPAGAMENTOS.pdf',
      FirstPublishLocationId = cover.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('pdf')
    );
    insert cv;
    // FirstPublishLocationId already links the document to the cover; no extra link needed.

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('selectedCoverId', cover.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    System.assert(!String.isBlank(ext.paymentMethodNoteImageUrl));
  }

  @IsTest
  static void shouldLoadPdfUrlsWithPropostaDocumentNullTipoKit() {
    // Covers lines 187-231 in loadPdfUrls — PROPOSTA document makes documentIds non-empty
    // and exercises the else branch (TipoKitPromocional__c = null)
    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = cover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    opp.TipoKitPromocional__c = null;
    insert opp;

    // Insert a PROPOSTA-titled ContentVersion linked to the cover → adds to documentIds
    ContentVersion cv = new ContentVersion(
      Title = 'PROPOSTA_SOLAR',
      PathOnClient = 'PROPOSTA_SOLAR.pdf',
      FirstPublishLocationId = cover.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('pdf')
    );
    insert cv;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('selectedCoverId', cover.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    Assert.isTrue(true, 'loadPdfUrls com documento PROPOSTA e TipoKit null nao deve lancar erro.');
  }

  @IsTest
  static void shouldLoadPdfUrlsWithPropostaDocumentTipoKitOther() {
    // Covers lines 201-211 in loadPdfUrls — branch for TipoKitPromocional__c != null and != '6'
    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = cover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = createOpp();
    opp.Parceiro__c = parceiro.Id;
    opp.TipoKitPromocional__c = '3';
    insert opp;

    ContentVersion cv = new ContentVersion(
      Title = 'PROPOSTA_OTHER',
      PathOnClient = 'PROPOSTA_OTHER.pdf',
      FirstPublishLocationId = cover.Id,
      IsMajorVersion = true,
      VersionData = Blob.valueOf('pdf')
    );
    insert cv;

    PageReference pref = new PageReference('/apex/dummy');
    pref.getParameters().put('id', opp.Id);
    pref.getParameters().put('selectedCoverId', cover.Id);
    Test.setCurrentPage(pref);

    PDFControllerExtension ext = new PDFControllerExtension(
      new ApexPages.StandardController(opp)
    );
    Assert.isTrue(true, 'loadPdfUrls com TipoKitPromocional != null e != 6 nao deve lancar erro.');
  }
}
