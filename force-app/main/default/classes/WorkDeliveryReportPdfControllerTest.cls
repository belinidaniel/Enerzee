@IsTest
private class WorkDeliveryReportPdfControllerTest {
  @IsTest
  static void constructorWithoutParamsShouldKeepDefaults() {
    Test.setCurrentPage(Page.WorkDeliveryReportPdf);

    WorkDeliveryReportPdfController controller = new WorkDeliveryReportPdfController();

    System.assertEquals(
      'Relatorio de Execucao de Obra',
      controller.documentTitle
    );
    System.assertEquals(false, controller.getHasSections());
    System.assertEquals(false, controller.getHasCover());
    System.assertEquals(false, controller.getHasContraCover());
  }

  @IsTest
  static void constructorWithInstallationAndAttachmentsShouldLoadContent() {
    OpportunityTriggerHandler.disableTrigger();
    ProjetoTriggerHandler.disableTrigger();
    InstalacaoTriggerHandler.disableTrigger();
    TaskTriggerHandler.disableTrigger();

    try {
      Account accountRecord = new Account(
        Name = 'Conta PDF',
        Logradouro__c = 'Rua Um',
        NumeroRua__c = '100',
        MunicipioInstalacao__c = 'Sao Paulo',
        ShippingStreet = 'Rua Shipping',
        ShippingCity = 'Campinas'
      );
      insert accountRecord;

      Opportunity opp = (Opportunity) TestFactory.createSObject(
        new Opportunity(AccountId = accountRecord.Id),
        true
      );

      ViabilityStudy__c viability = new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      );
      insert viability;

      Projeto__c project = new Projeto__c(
        Name = 'Projeto PDF',
        Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO,
        RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
        Conta__c = accountRecord.Id,
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        GestorObra__c = UserInfo.getUserId()
      );
      insert project;

      Instalacao__c inst = new Instalacao__c(
        Name = 'Instalacao PDF',
        Projeto__c = project.Id,
        ClienteConta__c = accountRecord.Id,
        Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO,
        GestorObra__c = UserInfo.getUserId()
      );
      insert inst;

      ProposalCover__c coverRecord = new ProposalCover__c(
        Name = 'Relatorio de entrega de obra',
        Template__c = 'ModeloPropostaA'
      );
      insert coverRecord;

      ContentVersion coverVersion = createContentVersion(
        coverRecord.Id,
        'capa-principal',
        'cover-a.png'
      );
      ContentVersion contraVersion = createContentVersion(
        coverRecord.Id,
        'contra-capa',
        'cover-b.png'
      );
      ContentVersion extraVersion = createContentVersion(
        coverRecord.Id,
        'extra',
        'cover-c.png'
      );

      ContentVersion sectionDoc = createContentVersion(
        inst.Id,
        'secao-doc',
        'secao-1.png'
      );
      ContentVersion sectionDocTwo = createContentVersion(
        inst.Id,
        'secao-doc-two',
        'secao-2.png'
      );

      insert new List<OpportunityAttachmentLink__c>{
        new OpportunityAttachmentLink__c(
          Name = 'L1',
          SObjectId__c = String.valueOf(inst.Id),
          ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
          DocRequiredName__c = 'Fotos da Obra',
          AttachmentDescription__c = 'Imagem por ContentDocumentId',
          ContentDocumentId__c = String.valueOf(sectionDoc.ContentDocumentId)
        ),
        new OpportunityAttachmentLink__c(
          Name = 'L2',
          SObjectId__c = String.valueOf(inst.Id),
          ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
          DocRequiredName__c = 'Fotos da Obra',
          AttachmentDescription__c = 'Imagem por InternalAttachmentURL',
          InternalAttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
            sectionDocTwo.Id
        ),
        new OpportunityAttachmentLink__c(
          Name = 'L3',
          SObjectId__c = String.valueOf(inst.Id),
          ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
          DocRequiredName__c = 'Fotos da Obra',
          AttachmentDescription__c = 'Imagem por AttachmentURL',
          AttachmentURL__c = 'files/pasta/imagem-03.png'
        ),
        new OpportunityAttachmentLink__c(
          Name = 'L4',
          SObjectId__c = String.valueOf(inst.Id),
          ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
          DocRequiredName__c = 'Ignorar vazia'
        )
      };

      Test.setCurrentPage(Page.WorkDeliveryReportPdf);
      ApexPages.currentPage()
        .getParameters()
        .put('sobjectId', String.valueOf(inst.Id));
      ApexPages.currentPage()
        .getParameters()
        .put('activityName', TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA);

      WorkDeliveryReportPdfController controller = new WorkDeliveryReportPdfController();

      System.assertEquals(
        'Relatorio - ' + TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
        controller.documentTitle
      );
      System.assertEquals(true, controller.getHasSections());
      System.assert(
        controller.pages.size() >= 2,
        'Esperava ao menos duas paginas de secao.'
      );
      System.assertNotEquals(null, controller.introSubtitle);
      System.assertEquals(true, controller.getHasCover());
      System.assertEquals(true, controller.getHasContraCover());
      System.assertEquals(accountRecord.Name, controller.clientName);
      System.assertNotEquals('-', controller.endereco);
      System.assertNotEquals(null, controller.sections[0].title);
    } finally {
      TaskTriggerHandler.enableTrigger();
      InstalacaoTriggerHandler.enableTrigger();
      ProjetoTriggerHandler.enableTrigger();
      OpportunityTriggerHandler.enableTrigger();
    }
  }

  private static ContentVersion createContentVersion(
    Id firstPublishLocationId,
    String title,
    String path
  ) {
    ContentVersion cv = new ContentVersion(
      ContentLocation = 'S',
      FirstPublishLocationId = firstPublishLocationId,
      Title = title,
      PathOnClient = path,
      VersionData = Blob.valueOf('img')
    );
    insert cv;

    return [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];
  }
}
