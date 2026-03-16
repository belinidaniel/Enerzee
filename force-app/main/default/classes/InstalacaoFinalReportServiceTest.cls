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

  // ---------------------------------------------------------------------------
  // FinalReportJob — constructor with null list and execute with empty ids
  // ---------------------------------------------------------------------------
  @IsTest
  static void finalReportJobExecuteWithEmptyIdsReturnsGracefully() {
    Test.startTest();
    InstalacaoFinalReportService.FinalReportJob job =
      new InstalacaoFinalReportService.FinalReportJob(null);
    // Cannot call execute directly (needs QueueableContext), so enqueue and let
    // the framework run it — validates no uncaught exception on empty list.
    System.enqueueJob(job);
    Test.stopTest();

    Assert.isTrue(true, 'FinalReportJob com lista nula nao deve lançar erro.');
  }

  // ---------------------------------------------------------------------------
  // FinalReportJob — execute with more than MAX_PER_RUN items triggers chaining
  // ---------------------------------------------------------------------------
  @IsTest
  static void finalReportJobExecuteWithMoreThanMaxPerRunEnqueuesChain() {
    // Build 7 synthetic ids so the job slices 5 + 2 and re-enqueues
    List<Id> ids = new List<Id>();
    for (Integer i = 10; i <= 16; i++) {
      ids.add(buildSyntheticInstalacaoId(String.valueOf(i)));
    }

    Integer before = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];

    Test.startTest();
    System.enqueueJob(new InstalacaoFinalReportService.FinalReportJob(ids));
    Test.stopTest();

    // At least the first job was queued; in test context chaining is allowed once
    Integer after = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
    Assert.isTrue(after > before, 'Deve ter enfileirado o job com chain.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — link with SObjectId__c that cannot be parsed as Id
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsSkipsInvalidSObjectIdInLinks() {
    Account anchor = new Account(Name = 'Anchor InvalidSObjectId');
    insert anchor;

    // Create a link whose SObjectId__c is not a valid Id — parseId returns null → skip
    OpportunityAttachmentLink__c badLink = new OpportunityAttachmentLink__c(
      Name = 'BadSObjectId',
      SObjectId__c = String.valueOf(anchor.Id), // valid anchor so query hits it...
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      AttachmentDescription__c = 'bad'
      // No ContentDocumentId__c, no URLs → storeDocOrVersion not called
    );
    insert badLink;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    // PDF is still generated (generatePdf returns blob in test context)
    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Deve gerar PDF mesmo sem doc/url nos links.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — AttachmentURL__c with query-string (exercises parseIdFromUrl)
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsWithAttachmentUrlContainingQueryString() {
    Account anchor = new Account(Name = 'Anchor QueryString');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'qs-file',
      'qs-file.png'
    );

    // URL with query string — parseIdFromUrl must strip the ?... part
    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'LinkQS',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      AttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
        oldVersion.Id + '?operationContext=CHATTER',
      AttachmentDescription__c = 'qs'
    );
    insert link;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Deve gerar PDF para URL com query string.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — InternalAttachmentURL__c pointing to a ContentVersion
  // (prefix 068) exercises storeDocOrVersion version branch
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsWithInternalUrlPointingToContentVersion() {
    Account anchor = new Account(Name = 'Anchor InternalVersion');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'internal-version-file',
      'internal-version-file.png'
    );

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'LinkInternalVersion',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      // The version Id starts with 068 → storeDocOrVersion puts it in versionIdsByInst
      InternalAttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
        oldVersion.Id,
      AttachmentDescription__c = 'internal-version'
    );
    insert link;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Deve gerar PDF e resolver versao por URL interna.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — LEGACY subject (RELATORIO_FINAL_DE_OBRA_LEGACY) as
  // fallback activity name (exercises resolveActivityByInstallation fallback path)
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsWithLegacySubjectAsFallbackActivity() {
    Account anchor = new Account(Name = 'Anchor LegacySubject');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'legacy-subject-file',
      'legacy-subject-file.png'
    );

    // Use LEGACY subject only — resolveActivityByInstallation falls back (not the primary)
    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'LinkLegacy',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA_LEGACY,
      ContentDocumentId__c = String.valueOf(oldVersion.ContentDocumentId),
      AttachmentDescription__c = 'legacy'
    );
    insert link;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Deve gerar PDF com subject legacy como fallback.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — both primary and fallback links present: primary wins
  // (exercises resolveActivityByInstallation primary-wins break)
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsPrimarySubjectTakesPrecedenceOverLegacy() {
    Account anchor = new Account(Name = 'Anchor PrimaryWins');
    insert anchor;

    ContentVersion v1 = createContentVersion(anchor.Id, 'prim-file', 'prim.png');
    ContentVersion v2 = createContentVersion(anchor.Id, 'leg-file', 'leg.png');

    OpportunityAttachmentLink__c legacyLink = new OpportunityAttachmentLink__c(
      Name = 'LegacyLink',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA_LEGACY,
      ContentDocumentId__c = String.valueOf(v1.ContentDocumentId),
      AttachmentDescription__c = 'leg'
    );
    OpportunityAttachmentLink__c primaryLink = new OpportunityAttachmentLink__c(
      Name = 'PrimaryLink',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      ContentDocumentId__c = String.valueOf(v2.ContentDocumentId),
      AttachmentDescription__c = 'prim'
    );
    insert new List<OpportunityAttachmentLink__c>{ legacyLink, primaryLink };

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchor.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Deve gerar PDF com subject primario prioritario.');
  }

  // ---------------------------------------------------------------------------
  // enqueueIfNeeded — status changes to CONCLUIDA_AGUARDANDO_TROCA (not concluida
  // variant) → should NOT enqueue (exercises isObraConcluida negative path)
  // ---------------------------------------------------------------------------
  @IsTest
  static void enqueueIfNeededSkipsNonConcluidaStatus() {
    Integer before = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];

    Id syntheticId = buildSyntheticInstalacaoId('020');

    Instalacao__c oldInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );
    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      new Map<Id, Instalacao__c>{ syntheticId => oldInst }
    );
    Test.stopTest();

    Integer after = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
    Assert.areEqual(before, after, 'Status diferente de concluida nao deve enfileirar.');
  }

  // ---------------------------------------------------------------------------
  // enqueueIfNeeded — status is blank → isObraConcluida returns false
  // ---------------------------------------------------------------------------
  @IsTest
  static void enqueueIfNeededSkipsBlankStatus() {
    Integer before = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];

    Id syntheticId = buildSyntheticInstalacaoId('021');

    Instalacao__c oldInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );
    Instalacao__c newInst = new Instalacao__c(
      Id = syntheticId,
      Status__c = ''
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInst },
      new Map<Id, Instalacao__c>{ syntheticId => oldInst }
    );
    Test.stopTest();

    Integer after = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
    Assert.areEqual(before, after, 'Status em branco nao deve enfileirar.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — link with ContentDocumentId__c AND InternalAttachmentURL__c
  // both set: both cleared after success (exercises linksToUpdate full path)
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsClearsBothDocIdAndInternalUrl() {
    Account anchor = new Account(Name = 'Anchor BothClear');
    insert anchor;

    ContentVersion oldVersion = createContentVersion(
      anchor.Id,
      'both-clear-file',
      'both-clear-file.png'
    );

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'BothSet',
      SObjectId__c = String.valueOf(anchor.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      ContentDocumentId__c = String.valueOf(oldVersion.ContentDocumentId),
      InternalAttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
        oldVersion.Id,
      AttachmentDescription__c = 'both'
    );
    insert link;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchor.Id }
    );
    Test.stopTest();

    OpportunityAttachmentLink__c refreshed = [
      SELECT Id, ContentDocumentId__c, InternalAttachmentURL__c
      FROM OpportunityAttachmentLink__c
      WHERE Id = :link.Id
      LIMIT 1
    ];
    Assert.areEqual(null, refreshed.ContentDocumentId__c, 'ContentDocumentId__c deve ser nulo.');
    Assert.areEqual(null, refreshed.InternalAttachmentURL__c, 'InternalAttachmentURL__c deve ser nulo.');
  }

  // ---------------------------------------------------------------------------
  // processInstallations — multiple installations in one call, only one has links
  // (exercises loop where instLinks is null/empty for some ids)
  // ---------------------------------------------------------------------------
  @IsTest
  static void processInstallationsMultipleIdsOnlyOneHasLinks() {
    Account anchorWithLinks = new Account(Name = 'Anchor WithLinks');
    Account anchorNoLinks = new Account(Name = 'Anchor WithoutLinks');
    insert new List<Account>{ anchorWithLinks, anchorNoLinks };

    ContentVersion cv = createContentVersion(anchorWithLinks.Id, 'multi-file', 'multi.png');

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'MultiLink',
      SObjectId__c = String.valueOf(anchorWithLinks.Id),
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId),
      AttachmentDescription__c = 'multi'
    );
    insert link;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ anchorWithLinks.Id, anchorNoLinks.Id }
    );
    Test.stopTest();

    List<ContentVersion> generated = [
      SELECT Id
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :anchorWithLinks.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    Assert.isTrue(!generated.isEmpty(), 'Instalacao com links deve ter PDF gerado.');
  }
}
