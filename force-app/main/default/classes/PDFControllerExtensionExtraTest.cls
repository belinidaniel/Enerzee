/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 12-23-2025
 * @last modified by	 : Daniel Belini
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
}
