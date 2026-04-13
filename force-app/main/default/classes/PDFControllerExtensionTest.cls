/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public with sharing class PDFControllerExtensionTest {
  //Objetivo: classe de testes para a classe PDFControllerExtension

  @isTest
  static void testePositivoA() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaA'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(opp);
    PDFControllerExtension ext = new PDFControllerExtension(sc);
    ext.salvarPDF();
    test.stopTest();

    List<ContentVersion> resultados = [
      SELECT Id, FirstPublishLocationId, NomePaginaPDF__c
      FROM ContentVersion
      WHERE FirstPublishLocationId = :opp.Id
    ];
  }

  @isTest
  static void testePositivoB() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaB'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(opp);
    PDFControllerExtension ext = new PDFControllerExtension(sc);
    ext.salvarPDF();
    test.stopTest();

    List<ContentVersion> resultados = [
      SELECT Id, FirstPublishLocationId, NomePaginaPDF__c
      FROM ContentVersion
      WHERE FirstPublishLocationId = :opp.Id
    ];
  }

  @isTest
  static void testePositivoBowe() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        Template__c = 'ModeloPropostaBowe',
        isPromotional__c = true
      ),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Name = 'Bow-e',
        CapaPromocional__c = proposalCover.id,
        Produto__c = 'Solar'
      ),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(opp);
    PDFControllerExtension ext = new PDFControllerExtension(sc);
    ext.salvarPDF();
    test.stopTest();

    List<ContentVersion> resultados = [
      SELECT Id, FirstPublishLocationId, NomePaginaPDF__c
      FROM ContentVersion
      WHERE FirstPublishLocationId = :opp.Id
    ];
  }

  @isTest
  static void testePositivoEzeeConnect() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaEzeeConnect'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(opp);
    PDFControllerExtension ext = new PDFControllerExtension(sc);
    ext.salvarPDF();
    test.stopTest();

    List<ContentVersion> resultados = [
      SELECT Id, FirstPublishLocationId, NomePaginaPDF__c
      FROM ContentVersion
      WHERE FirstPublishLocationId = :opp.Id
    ];
  }

  @isTest
  static void shouldExposeMainViabilityStudyData() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaA'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        Parceiro__c = parceiro.id,
        observacaoPagamentoEsquerdo__c = 'Teste',
        observacaoPagamentoDireito__c = 'Teste',
        NotePaymentMethod__c = 'Boleto'
      ),
      true
    );

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      TextStudy__c = 'Linha 1\nLinha 2',
      AdequacyCostEnerzee__c = 'Ramal CC;Ramal CA;Laudo Estrutural;Adequação Padrão;Cobertura;Outros Custos',
      AdequacyCostClient__c = 'Ramal CC'
    );
    insert viability;

    opp.MainViability__c = viability.Id;
    update opp;

    ContentVersion layoutFile = new ContentVersion(
      Title = 'Layout',
      PathOnClient = 'layout.png',
      VersionData = Blob.valueOf('dummy data'),
      FirstPublishLocationId = viability.Id
    );
    insert layoutFile;

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(
      new Opportunity(Id = opp.Id)
    );
    PDFControllerExtension controller = new PDFControllerExtension(sc);
    test.stopTest();

    System.assertEquals('Linha 1\nLinha 2', controller.mainViabilityStudyText);
    System.assertEquals(
      1,
      controller.mainViabilityStudyChunks.size(),
      'Single chunk expected for short text'
    );
    System.assert(
      controller.getShouldRenderMainViabilityStudy(),
      'Study page should be rendered when text exists'
    );
    System.assert(
      controller.getHasMainViabilityLayout(),
      'Layout image should be available when file is attached'
    );
    System.assertNotEquals(
      null,
      controller.mainViabilityLayoutUrl,
      'Layout URL should be populated'
    );
  }

  @isTest
  static void shouldFallbackToAttachmentForLayout() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaA'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      TextStudy__c = 'Layout attachment fallback'
    );
    insert viability;

    opp.MainViability__c = viability.Id;
    update opp;

    Attachment layoutAttachment = new Attachment(
      Name = 'Layout Cliente.png',
      Body = Blob.valueOf('layout data'),
      ContentType = 'image/png',
      ParentId = viability.Id
    );
    insert layoutAttachment;

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(
      new Opportunity(Id = opp.Id)
    );
    PDFControllerExtension controller = new PDFControllerExtension(sc);
    test.stopTest();

    System.assert(
      controller.getHasMainViabilityLayout(),
      'Layout must exist when attachment is present'
    );
    System.assert(
      controller.mainViabilityLayoutUrl != null &&
      controller.mainViabilityLayoutUrl.contains(
        '/servlet/servlet.FileDownload'
      ),
      'Attachment URL should use servlet download path'
    );
  }

  @isTest
  static void shouldSplitLargeStudyTextAcrossPages() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaA'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.id),
      true
    );

    String longText = '';
    for (Integer i = 0; i < 200; i++) {
      longText +=
        'Linha muito longa ' +
        i +
        ' com detalhes adicionais para ultrapassar o limite de caracteres por página.\n';
    }

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      TextStudy__c = longText
    );
    insert viability;

    opp.MainViability__c = viability.Id;
    update opp;

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(
      new Opportunity(Id = opp.Id)
    );
    PDFControllerExtension controller = new PDFControllerExtension(sc);
    test.stopTest();

    System.assert(
      controller.mainViabilityStudyChunks.size() > 1,
      'Large text should be split across multiple chunks'
    );
    for (String chunk : controller.mainViabilityStudyChunks) {
      System.assert(
        chunk.length() <= 2500,
        'Each chunk should respect the maximum page size approximation'
      );
    }
  }

  @isTest
  static void shouldResolvePartnerLogoUrl() {
    ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(Template__c = 'ModeloPropostaA'),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = proposalCover.Id, Produto__c = 'Solar'),
      true
    );

    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = parceiro.Id),
      true
    );

    ContentVersion logo = new ContentVersion(
      Title = 'Minha Logo Oficial',
      PathOnClient = 'logo.png',
      VersionData = Blob.valueOf('logo'),
      FirstPublishLocationId = parceiro.Id
    );
    insert logo;

    PageReference pageRef = Page.PropostaContainer;
    pageRef.getParameters().put('id', String.valueOf(opp.Id));
    Test.setCurrentPage(pageRef);

    Test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(
      new Opportunity(Id = opp.Id)
    );
    PDFControllerExtension controller = new PDFControllerExtension(sc);
    String logoUrl = controller.getLogoUrl();
    Test.stopTest();

    System.assert(
      logoUrl != null &&
      logoUrl.contains('/sfc/servlet.shepherd/version/download/'),
      'Logo vinculada ao parceiro deve gerar URL de download.'
    );
  }
}
