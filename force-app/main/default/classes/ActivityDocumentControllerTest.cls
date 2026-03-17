/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ActivityDocumentControllerTest {
  private static Opportunity createOpportunity(Account acc, String name) {
    Opportunity opp = new Opportunity(
      Name = name,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(15),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'vo-' + name
    );
    insert opp;
    return opp;
  }

  private static Projeto__c createProject(
    Account acc,
    Opportunity opp,
    String name
  ) {
    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opp.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viability;

    Projeto__c project = new Projeto__c(
      Name = name,
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO,
      Oportunidade__c = opp.Id,
      Viabilidade__c = viability.Id,
      Conta__c = acc.Id,
      TipoObra__c = 'UFVMicro',
      RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
        .get('UFVMicro')
        .getRecordTypeId()
    );
    insert project;
    return project;
  }

  private static Instalacao__c createInstallation(
    Account acc,
    Opportunity opp,
    Projeto__c project,
    String name
  ) {
    InstalacaoTriggerHandler.disableTrigger();
    Instalacao__c installation = new Instalacao__c(
      Name = name,
      Status__c = 'Planejamento',
      Projeto__c = project.Id,
      Oportunidade__c = opp.Id,
      ClienteConta__c = acc.Id
    );
    insert installation;
    InstalacaoTriggerHandler.enableTrigger();
    return installation;
  }

  @IsTest
  static void shouldReturnEmptyWhenNoSubjectOrId() {
    System.assertEquals(
      0,
      ActivityDocumentController.getRequiredDocuments(null).size()
    );
    System.assertEquals(
      0,
      ActivityDocumentController.getAttachments(null, null).size()
    );
    System.assertEquals(
      0,
      ActivityDocumentController.getDocumentCompletionStates(null, null).size()
    );
  }

  @IsTest
  static void shouldReturnTaskContextForOpportunity() {
    Account acc = new Account(Name = 'ACC');
    insert acc;

    Opportunity opp = new Opportunity(
      Name = 'Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'test-vo'
    );
    insert opp;

    Task t = new Task(
      Subject = 'Teste',
      WhatId = opp.Id,
      Status = 'Not Started'
    );
    insert t;

    Test.startTest();
    ActivityDocumentController.TaskContext ctx = ActivityDocumentController.getTaskContext(
      t.Id
    );
    Test.stopTest();

    System.assertEquals('Teste', ctx.subject);
    System.assertEquals(opp.Id, ctx.whatId);
    System.assertEquals(opp.Id, ctx.opportunityId);
    System.assertEquals('test-vo', ctx.idVirtualOffice);
  }

  @IsTest
  static void shouldFallbackRequiredDocumentsForLegacySubject() {
    Test.startTest();
    List<ActivityDocumentController.RequiredDoc> docs = ActivityDocumentController.getRequiredDocuments(
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA_LEGACY
    );
    Test.stopTest();

    System.assert(
      !docs.isEmpty(),
      'Deve retornar documentos também para o assunto legado.'
    );
  }

  @IsTest
  static void shouldSetAndUnsetCompletionState() {
    Account acc = new Account(Name = 'Conta Docs');
    insert acc;

    String subject = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA;
    String docName = 'MOBILIZAÇÃO/CONFERÊNCIA DE MATERIAIS';

    insert new OpportunityAttachmentLink__c(
      Name = 'Evidencia 1',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      AttachmentDescription__c = 'foto_1.jpg',
      DocRequiredName__c = docName,
      AttachmentURL__c = 'https://example.com/foto_1.jpg'
    );

    Test.startTest();
    ActivityDocumentController.CompletionStateItem completed = ActivityDocumentController.setDocumentCompleted(
      acc.Id,
      subject,
      docName,
      true
    );
    ActivityDocumentController.CompletionStateItem uncompleted = ActivityDocumentController.setDocumentCompleted(
      acc.Id,
      subject,
      docName,
      false
    );
    Test.stopTest();

    System.assertEquals(
      true,
      completed.completed,
      'O item deve estar concluído após marcar.'
    );
    System.assertNotEquals(
      null,
      completed.completedById,
      'Usuário de conclusão deve ser preenchido.'
    );
    System.assertEquals(
      false,
      uncompleted.completed,
      'O item deve voltar a não concluído.'
    );
    System.assertEquals(
      null,
      uncompleted.completedById,
      'Usuário deve ser limpo ao desmarcar.'
    );
  }

  @IsTest
  static void shouldBlockCompletionWhenEvidenceIsMissing() {
    Account acc = new Account(Name = 'Conta Sem Evidencia');
    insert acc;

    Boolean hasException = false;
    try {
      ActivityDocumentController.setDocumentCompleted(
        acc.Id,
        TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
        'DOC SEM EVIDENCIA',
        true
      );
    } catch (AuraHandledException ex) {
      hasException = true;
    }
    System.assertEquals(
      true,
      hasException,
      'Conclusão sem evidência deve ser bloqueada.'
    );
  }

  @IsTest
  static void shouldDeleteAttachmentAndResetCompletion() {
    Account acc = new Account(Name = 'Conta Remove');
    insert acc;

    String subject = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA;
    String docName = 'COMISSIONAMENTO';

    OpportunityAttachmentLink__c evidence = new OpportunityAttachmentLink__c(
      Name = 'Evidencia para remover',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      AttachmentDescription__c = 'foto_remove.jpg',
      DocRequiredName__c = docName,
      AttachmentURL__c = 'https://example.com/foto_remove.jpg'
    );
    insert evidence;

    ActivityDocumentController.setDocumentCompleted(
      acc.Id,
      subject,
      docName,
      true
    );

    Test.startTest();
    Boolean removed = ActivityDocumentController.deleteAttachment(evidence.Id);
    Test.stopTest();

    System.assertEquals(
      true,
      removed,
      'A remoção do anexo deve retornar true.'
    );
    Integer evidenceCount = [
      SELECT COUNT()
      FROM OpportunityAttachmentLink__c
      WHERE Id = :evidence.Id
    ];
    System.assertEquals(
      0,
      evidenceCount,
      'O anexo removido não deve mais existir.'
    );

    OpportunityAttachmentLink__c state = [
      SELECT Completed__c, CompletedDate__c, CompletedBy__c
      FROM OpportunityAttachmentLink__c
      WHERE
        SObjectId__c = :String.valueOf(acc.Id)
        AND ActivityName__c = :subject
        AND DocRequiredName__c = :docName
        AND IsChecklistState__c = TRUE
      LIMIT 1
    ];
    System.assertEquals(
      false,
      state.Completed__c,
      'Ao remover a última evidência, a conclusão deve ser limpa.'
    );
    System.assertEquals(
      null,
      state.CompletedDate__c,
      'Data de conclusão deve ser limpa.'
    );
    System.assertEquals(
      null,
      state.CompletedBy__c,
      'Usuário de conclusão deve ser limpo.'
    );
  }

  @IsTest
  static void shouldReturnAttachmentsCompletionStatesAndDeleteStoredAssets() {
    Account acc = new Account(Name = 'Conta Arquivos');
    insert acc;

    String subject = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA;

    ContentVersion version = new ContentVersion(
      Title = 'evidencia-arquivo',
      PathOnClient = '/evidencia-arquivo.pdf',
      VersionData = Blob.valueOf('arquivo')
    );
    insert version;
    version = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :version.Id
    ];
    insert new ContentDocumentLink(
      ContentDocumentId = version.ContentDocumentId,
      LinkedEntityId = acc.Id,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );

    Attachment legacy = new Attachment(
      ParentId = acc.Id,
      Name = 'legacy.txt',
      Body = Blob.valueOf('legacy')
    );
    insert legacy;

    OpportunityAttachmentLink__c contentLink = new OpportunityAttachmentLink__c(
      Name = 'Arquivo Content',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      AttachmentDescription__c = 'Doc interno',
      DocRequiredName__c = 'MÓDULO',
      InternalAttachmentURL__c = '/sfc/servlet.shepherd/version/download/' +
        version.Id
    );
    OpportunityAttachmentLink__c publicLink = new OpportunityAttachmentLink__c(
      Name = 'Arquivo URL',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      AttachmentDescription__c = 'Doc externo',
      DocRequiredName__c = 'MÓDULO',
      AttachmentURL__c = 'https://example.com/documento.pdf'
    );
    OpportunityAttachmentLink__c blankState = new OpportunityAttachmentLink__c(
      Name = 'Checklist sem nome',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      IsChecklistState__c = true
    );
    OpportunityAttachmentLink__c duplicateState = new OpportunityAttachmentLink__c(
      Name = 'Checklist modulo',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      DocRequiredName__c = 'MODULO',
      Completed__c = true,
      CompletedDate__c = System.now(),
      CompletedBy__c = UserInfo.getUserId(),
      IsChecklistState__c = true
    );
    insert new List<OpportunityAttachmentLink__c>{
      contentLink,
      publicLink,
      blankState,
      duplicateState
    };

    List<ActivityDocumentController.AttachmentItem> allAttachments = ActivityDocumentController.getAttachments(
      acc.Id,
      null
    );
    List<ActivityDocumentController.AttachmentItem> filteredAttachments = ActivityDocumentController.getAttachments(
      acc.Id,
      subject
    );
    List<ActivityDocumentController.CompletionStateItem> states = ActivityDocumentController.getDocumentCompletionStates(
      acc.Id,
      subject
    );

    System.assertEquals(2, allAttachments.size());
    System.assertEquals(2, filteredAttachments.size());
    System.assertEquals(
      '/sfc/servlet.shepherd/version/download/' + version.Id,
      filteredAttachments[0].url
    );
    System.assertEquals(
      'https://example.com/documento.pdf',
      filteredAttachments[1].downloadUrl
    );
    System.assertEquals(1, states.size());
    System.assertEquals('MODULO', states[0].docRequiredName);
    System.assertEquals(UserInfo.getUserId(), states[0].completedById);

    OpportunityAttachmentLink__c legacyEvidence = new OpportunityAttachmentLink__c(
      Name = 'Arquivo legado',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      AttachmentDescription__c = 'Doc legado',
      DocRequiredName__c = 'LEGADO',
      AttachmentURL__c = '/servlet/servlet.FileDownload?file=' + legacy.Id
    );
    OpportunityAttachmentLink__c legacyState = new OpportunityAttachmentLink__c(
      Name = 'Checklist legado',
      SObjectId__c = String.valueOf(acc.Id),
      ActivityName__c = subject,
      DocRequiredName__c = 'LEGADO',
      Completed__c = true,
      CompletedDate__c = System.now(),
      CompletedBy__c = UserInfo.getUserId(),
      IsChecklistState__c = true
    );
    insert new List<OpportunityAttachmentLink__c>{
      legacyEvidence,
      legacyState
    };

    Test.startTest();
    Boolean contentRemoved = ActivityDocumentController.deleteAttachment(
      contentLink.Id
    );
    Boolean legacyRemoved = ActivityDocumentController.deleteAttachment(
      legacyEvidence.Id
    );
    Boolean missingRemoved = ActivityDocumentController.deleteAttachment(
      legacyEvidence.Id
    );
    Boolean nullRemoved = ActivityDocumentController.deleteAttachment(null);
    Test.stopTest();

    System.assertEquals(true, contentRemoved);
    System.assertEquals(true, legacyRemoved);
    System.assertEquals(false, missingRemoved);
    System.assertEquals(false, nullRemoved);
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE
          ContentDocumentId = :version.ContentDocumentId
          AND LinkedEntityId = :acc.Id
      ]
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Attachment WHERE Id = :legacy.Id]
    );

    OpportunityAttachmentLink__c resetState = [
      SELECT Completed__c, CompletedDate__c, CompletedBy__c
      FROM OpportunityAttachmentLink__c
      WHERE Id = :legacyState.Id
    ];
    System.assertEquals(false, resetState.Completed__c);
    System.assertEquals(null, resetState.CompletedDate__c);
    System.assertEquals(null, resetState.CompletedBy__c);
  }

  @IsTest
  static void shouldValidateCompletionInputsAndResolveProjectInstallationContext() {
    Boolean missingRecord = false;
    Boolean missingSubject = false;
    Boolean missingDoc = false;

    try {
      ActivityDocumentController.setDocumentCompleted(
        null,
        'Atividade',
        'Documento',
        true
      );
    } catch (AuraHandledException ex) {
      missingRecord = true;
    }

    try {
      ActivityDocumentController.setDocumentCompleted(
        UserInfo.getUserId(),
        null,
        'Documento',
        true
      );
    } catch (AuraHandledException ex) {
      missingSubject = true;
    }

    try {
      ActivityDocumentController.setDocumentCompleted(
        UserInfo.getUserId(),
        'Atividade',
        null,
        true
      );
    } catch (AuraHandledException ex) {
      missingDoc = true;
    }

    System.assertEquals(true, missingRecord);
    System.assertEquals(true, missingSubject);
    System.assertEquals(true, missingDoc);

    ActivityDocumentController.TaskContext emptyContext = ActivityDocumentController.getTaskContext(
      null
    );
    System.assertEquals(null, emptyContext.subject);

    Account acc = new Account(Name = 'Conta Contexto');
    insert acc;

    Opportunity opp = createOpportunity(acc, 'Opp Contexto');
    Projeto__c project = createProject(acc, opp, 'Projeto Contexto');
    Instalacao__c installation = createInstallation(
      acc,
      opp,
      project,
      'Instalacao Contexto'
    );

    Task projectTask = new Task(
      Subject = 'Projeto',
      WhatId = project.Id,
      Status = 'Not Started'
    );
    Task installationTask = new Task(
      Subject = 'Instalacao',
      WhatId = installation.Id,
      Status = 'Not Started'
    );
    insert new List<Task>{ projectTask, installationTask };

    ActivityDocumentController.TaskContext projectContext = ActivityDocumentController.getTaskContext(
      projectTask.Id
    );
    ActivityDocumentController.TaskContext installationContext = ActivityDocumentController.getTaskContext(
      installationTask.Id
    );

    System.assertEquals(project.Id, projectContext.whatId);
    System.assertEquals(opp.Id, projectContext.opportunityId);
    System.assertEquals(opp.IdVirtualOffice__c, projectContext.idVirtualOffice);
    System.assertEquals(installation.Id, installationContext.whatId);
    System.assertEquals(
      opp.Id,
      installationContext.opportunityId,
      'Instalação deve resolver a oportunidade pelo campo direto.'
    );
    System.assertEquals(
      opp.IdVirtualOffice__c,
      installationContext.idVirtualOffice
    );
  }
}
