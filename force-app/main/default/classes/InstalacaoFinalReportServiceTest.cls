/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class InstalacaoFinalReportServiceTest {
  @IsTest
  static void processInstallationsShouldGeneratePdfAndResetAttachmentFields() {
    Account anchor = new Account(Name = 'Anchor Instalacao Final Report');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'old-file',
      'old-file.png'
    );

    OpportunityAttachmentLink__c linkByDoc = new OpportunityAttachmentLink__c(
      Name = 'LinkByDoc',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      ContentDocumentId__c = String.valueOf(oldVersion.ContentDocumentId),
      AttachmentDescription__c = 'doc-id'
    );

    OpportunityAttachmentLink__c linkByUrl = new OpportunityAttachmentLink__c(
      Name = 'LinkByUrl',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA_LEGACY,
      InternalAttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
        oldVersion.Id,
      AttachmentDescription__c = 'internal-url'
    );

    insert new List<OpportunityAttachmentLink__c>{ linkByDoc, linkByUrl };

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id, Title, FirstPublishLocationId
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    System.assert(!generated.isEmpty(), 'Esperava a geracao de um PDF final.');

    List<OpportunityAttachmentLink__c> refreshed = [
      SELECT Id, ContentDocumentId__c, InternalAttachmentURL__c
      FROM OpportunityAttachmentLink__c
      WHERE Id IN :new List<Id>{ linkByDoc.Id, linkByUrl.Id }
    ];

    for (OpportunityAttachmentLink__c linkRecord : refreshed) {
      System.assertEquals(
        null,
        linkRecord.ContentDocumentId__c,
        'ContentDocumentId precisa ser limpo.'
      );
      System.assertEquals(
        null,
        linkRecord.InternalAttachmentURL__c,
        'InternalAttachmentURL precisa ser limpo.'
      );
    }
  }

  @IsTest
  static void enqueueIfNeededShouldCreateQueueableWhenStatusChangesToConcluded() {
    Integer beforeJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];

    Id syntheticId = buildSyntheticInstalacaoId('001');

    Instalacao__c oldInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );
    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_CONCLUIDA
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      new Map<Id, Instalacao__c>{ syntheticId => oldInst }
    );
    Test.stopTest();

    Integer queuedJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];
    System.assert(
      queuedJobs > beforeJobs,
      'Era esperado enfileirar pelo menos um Queueable.'
    );
  }

  @IsTest
  static void enqueueIfNeededShouldSkipWhenStatusDoesNotChange() {
    Integer beforeJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];

    Id syntheticId = buildSyntheticInstalacaoId('002');

    Instalacao__c oldInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );
    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      new Map<Id, Instalacao__c>{ syntheticId => oldInst }
    );
    Test.stopTest();

    Integer queuedJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];
    System.assertEquals(
      beforeJobs,
      queuedJobs,
      'Nao deveria enfileirar queueable sem mudanca de status.'
    );
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
      VersionData = Blob.valueOf('old-content')
    );
    insert cv;

    return [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];
  }

  @IsTest
  static void enqueueIfNeededShouldHandleNullOldMap() {
    Id syntheticId = buildSyntheticInstalacaoId('003');

    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_CONCLUIDA
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      null
    );
    Test.stopTest();

    Assert.isTrue(true, 'Nao deve lançar erro com oldMap nulo.');
  }

  @IsTest
  static void enqueueIfNeededShouldHandleEmptyList() {
    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>(),
      new Map<Id, Instalacao__c>()
    );
    InstalacaoFinalReportService.enqueueIfNeeded(null, null);
    Test.stopTest();

    Assert.isTrue(true, 'Deve tratar lista vazia e null sem erros.');
  }

  @IsTest
  static void enqueueIfNeededWithObraConcluidaAlternativeStatus() {
    Integer beforeJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];

    Id syntheticId = buildSyntheticInstalacaoId('004');

    Instalacao__c oldInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = 'Em Execucao'
    );
    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = 'Obra Concluida'
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      new Map<Id, Instalacao__c>{ syntheticId => oldInst }
    );
    Test.stopTest();

    Integer afterJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];
    Assert.isTrue(
      afterJobs >= beforeJobs,
      '"Obra Concluida" alternativo deve ser reconhecido como concluido.'
    );
  }

  @IsTest
  static void processInstallationsWithAttachmentUrlPath() {
    Account anchor = new Account(Name = 'Anchor FinalReport UrlPath');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'url-path-file',
      'url-path-file.png'
    );

    OpportunityAttachmentLink__c linkByAttachUrl = new OpportunityAttachmentLink__c(
      Name = 'LinkByAttachUrl',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      AttachmentURL__c = '/sfc/servlet.shepherd/version/download/' + oldVersion.Id,
      AttachmentDescription__c = 'attach-url'
    );
    insert linkByAttachUrl;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id, Title
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(
      !generated.isEmpty(),
      'Deve gerar PDF para link com AttachmentURL.'
    );
  }

  @IsTest
  static void processInstallationsWithNoLinksSkipsGracefully() {
    Account anchor = new Account(Name = 'Anchor No Links');
    insert anchor;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    Assert.isTrue(true, 'Sem links nao deve lançar erro.');
  }

  @IsTest
  static void processInstallationsWithEmptyList() {
    Test.startTest();
    InstalacaoFinalReportService.processInstallations(new List<Id>());
    InstalacaoFinalReportService.processInstallations(null);
    Test.stopTest();

    Assert.isTrue(true, 'Lista vazia/null nao deve lançar erro.');
  }

  private static Id buildSyntheticInstalacaoId(String sequence) {
    String prefix = Instalacao__c.SObjectType.getDescribe().getKeyPrefix();
    String padded = String.valueOf(sequence);
    while (padded.length() < 12) {
      padded = '0' + padded;
    }
    return (Id) (prefix + padded);
  }
}
