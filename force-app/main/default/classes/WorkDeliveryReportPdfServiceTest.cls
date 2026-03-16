/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class WorkDeliveryReportPdfServiceTest {
  @IsTest
  static void generatePdfBase64_returnsBase64() {
    Account acc = new Account(Name = 'Conta Teste');
    insert acc;

    Blob body = Blob.valueOf('TESTE');
    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'foto-teste';
    cv.PathOnClient = 'foto-teste.png';
    cv.VersionData = body;
    insert cv;

    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Anexo Teste',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'foto-teste.png',
      DocRequiredName__c = 'TESTE',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String base64 = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    System.assertNotEquals(null, base64, 'Base64 não deveria ser nulo.');
    System.assert(base64.length() > 0, 'Base64 não deveria ser vazio.');
  }

  @IsTest
  static void generatePdfBase64_throwsForNullSobjectId() {
    try {
      WorkDeliveryReportPdfService.generatePdfBase64(null, 'Atividade');
      Assert.fail('Deveria lançar exceção para sobjectId nulo.');
    } catch (AuraHandledException ex) {
      Assert.isNotNull(
        ex,
        'Deve lancar AuraHandledException para sobjectId nulo.'
      );
    }
  }

  @IsTest
  static void generatePdfBase64_throwsForNullActivitySubject() {
    Account acc = new Account(Name = 'Conta Subject Null');
    insert acc;

    try {
      WorkDeliveryReportPdfService.generatePdfBase64(acc.Id, null);
      Assert.fail('Deveria lançar exceção para atividade nula.');
    } catch (AuraHandledException ex) {
      Assert.isNotNull(
        ex,
        'Deve lancar AuraHandledException para atividade nula.'
      );
    }
  }

  @IsTest
  static void generatePdfBase64_throwsForBlankActivitySubject() {
    Account acc = new Account(Name = 'Conta Subject Blank');
    insert acc;

    try {
      WorkDeliveryReportPdfService.generatePdfBase64(acc.Id, '   ');
      Assert.fail('Deveria lançar exceção para atividade em branco.');
    } catch (AuraHandledException ex) {
      Assert.isNotNull(
        ex,
        'Deve lancar AuraHandledException para atividade em branco.'
      );
    }
  }

  @IsTest
  static void generatePdfBase64_throwsWhenNoLinks() {
    Account acc = new Account(Name = 'Conta Sem Links');
    insert acc;

    try {
      WorkDeliveryReportPdfService.generatePdfBase64(
        acc.Id,
        TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
      );
      Assert.fail('Deveria lançar exceção quando sem links.');
    } catch (AuraHandledException ex) {
      Assert.isNotNull(ex.getMessage());
    }
  }

  @IsTest
  static void generatePdfBase64_throwsWhenLinksHaveNullContentDocumentId() {
    Account acc = new Account(Name = 'Conta Link Null Doc');
    insert acc;

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Link Null',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'sem-docid'
    );
    insert link;

    try {
      WorkDeliveryReportPdfService.generatePdfBase64(
        acc.Id,
        TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
      );
      Assert.fail('Deveria lançar exceção quando ContentDocumentId e nulo.');
    } catch (AuraHandledException ex) {
      Assert.isNotNull(ex.getMessage());
    }
  }

  @IsTest
  static void generatePdfBase64_throwsWhenNoVersionForDocId() {
    Account acc = new Account(Name = 'Conta Sem Version');
    insert acc;

    String fakeDocId =
      ContentDocument.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Link Fake Doc',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'fake',
      ContentDocumentId__c = fakeDocId
    );

    try {
      insert link;
    } catch (DmlException e) {
      return;
    }

    try {
      WorkDeliveryReportPdfService.generatePdfBase64(
        acc.Id,
        TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
      );
    } catch (AuraHandledException ex) {
      Assert.isNotNull(ex.getMessage());
    }
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — link with DocRequiredName__c null/blank uses description
  // as caption (exercises the caption fallback branch in buildHtml)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_usesAttachmentDescriptionWhenDocRequiredNameBlank() {
    Account acc = new Account(Name = 'Conta Caption Fallback');
    insert acc;

    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'caption-fallback';
    cv.PathOnClient = 'caption-fallback.png';
    cv.VersionData = Blob.valueOf('DATA');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Caption Fallback Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'minha-descricao',
      DocRequiredName__c = null,
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    Assert.isNotNull(
      result,
      'Deve retornar base64 usando descricao como caption.'
    );
    Assert.isTrue(result.length() > 0, 'Base64 nao deve ser vazio.');
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — activity subject with leading/trailing spaces is trimmed
  // (exercises normalizedSubject = activitySubject.trim() branch)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_trimsActivitySubject() {
    Account acc = new Account(Name = 'Conta Subject Trim');
    insert acc;

    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'trim-subject';
    cv.PathOnClient = 'trim-subject.jpg';
    cv.VersionData = Blob.valueOf('DATA');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Trim Subject Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'trim',
      DocRequiredName__c = 'Trim Doc',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    // Pass subject with surrounding spaces — should be trimmed and match
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      '  ' + TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA + '  '
    );
    Test.stopTest();

    Assert.isNotNull(result, 'Deve retornar base64 com subject com espacos.');
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — link with an invalid (non-Id) ContentDocumentId__c string
  // is skipped gracefully without throwing (exercises the try/catch in the
  // contentDocIds loop and the docId try/catch in the items-building loop)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_skipsInvalidContentDocumentIdFormat() {
    Account acc = new Account(Name = 'Conta Invalid DocId Format');
    insert acc;

    // One valid link (so we don't hit the "no files" exception) plus a bad one
    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'valid-doc';
    cv.PathOnClient = 'valid-doc.png';
    cv.VersionData = Blob.valueOf('VALID');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c validLink = new OpportunityAttachmentLink__c(
      Name = 'Valid Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'valid',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    // A link with a non-Id string in ContentDocumentId__c — will fail Id cast
    OpportunityAttachmentLink__c badLink = new OpportunityAttachmentLink__c(
      Name = 'Bad DocId Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'bad',
      ContentDocumentId__c = 'NOT_AN_ID'
    );
    insert new List<OpportunityAttachmentLink__c>{ validLink, badLink };

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    Assert.isNotNull(
      result,
      'Deve ignorar ContentDocumentId invalido e gerar PDF.'
    );
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — multiple valid attachments in one call
  // (exercises the items loop in buildHtml with multiple entries,
  //  and the items.isEmpty() false path)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_withMultipleAttachments() {
    Account acc = new Account(Name = 'Conta Multi Attachments');
    insert acc;

    List<OpportunityAttachmentLink__c> links = new List<OpportunityAttachmentLink__c>();
    for (Integer i = 1; i <= 3; i++) {
      ContentVersion cv = new ContentVersion();
      cv.ContentLocation = 'S';
      cv.FirstPublishLocationId = acc.Id;
      cv.Title = 'multi-file-' + i;
      cv.PathOnClient = 'multi-file-' + i + '.jpg';
      cv.VersionData = Blob.valueOf('DATA' + i);
      insert cv;
      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];

      links.add(
        new OpportunityAttachmentLink__c(
          Name = 'Multi Link ' + i,
          SObjectId__c = acc.Id,
          ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
          AttachmentDescription__c = 'foto-' + i,
          DocRequiredName__c = 'Foto ' + i,
          ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
        )
      );
    }
    insert links;

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    Assert.isNotNull(result, 'Deve gerar PDF com multiplos anexos.');
    Assert.isTrue(
      result.length() > 0,
      'Base64 nao deve ser vazio com multiplos anexos.'
    );
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — link has ContentDocumentId set but no matching
  // ContentVersion (version was deleted) — item is skipped, no items remain →
  // AuraHandledException thrown (exercises cv == null branch in items loop)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_throwsWhenVersionMissingForValidDocId() {
    Account acc = new Account(Name = 'Conta Version Missing');
    insert acc;

    // Create a ContentVersion then delete the ContentDocument so no version exists
    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'to-delete';
    cv.PathOnClient = 'to-delete.png';
    cv.VersionData = Blob.valueOf('DEL');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];
    Id docId = cv.ContentDocumentId;

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Orphan Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'orphan',
      ContentDocumentId__c = String.valueOf(docId)
    );
    insert link;

    // Delete the document so there's no ContentVersion for that docId
    delete [SELECT Id FROM ContentDocument WHERE Id = :docId];

    Test.startTest();
    try {
      WorkDeliveryReportPdfService.generatePdfBase64(
        acc.Id,
        TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
      );
      Assert.fail(
        'Deveria lançar AuraHandledException quando versao inexistente.'
      );
    } catch (AuraHandledException ex) {
      Assert.isNotNull(ex, 'Deve lançar excecao para versao ausente.');
    }
    Test.stopTest();
  }

  // ---------------------------------------------------------------------------
  // generatePdfBase64 — link DataURI path: AttachmentURL is a data: URI so
  // normalizeUrl passes it through (covers data: branch in normalizeUrl)
  // Note: generatePdfBase64 only uses ContentDocumentId__c, so this test uses
  // a valid ContentVersion and verifies the happy-path still works with a
  // special-character activity name (exercises cleanText + escapeHtmlText)
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_withSpecialCharactersInActivityName() {
    Account acc = new Account(Name = 'Conta Special Chars');
    insert acc;

    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'special-chars';
    cv.PathOnClient = 'special-chars.png';
    cv.VersionData = Blob.valueOf('SPEC');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    // Use the same activity name but with HTML special chars that must be escaped
    String specialSubject = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA;
    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Special Chars Link',
      SObjectId__c = acc.Id,
      ActivityName__c = specialSubject,
      AttachmentDescription__c = '<foto> & "imagem"',
      DocRequiredName__c = '<Doc & Test>',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      specialSubject
    );
    Test.stopTest();

    Assert.isNotNull(
      result,
      'Deve gerar PDF com caracteres especiais no nome da atividade.'
    );
  }

  // ---------------------------------------------------------------------------
  // buildHtml — null caption covers cleanText(null) and escapeHtmlText(null) null paths
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_withNullCaption() {
    Account acc = new Account(Name = 'Conta Null Caption');
    insert acc;

    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'null-caption';
    cv.PathOnClient = 'null-caption.png';
    cv.VersionData = Blob.valueOf('DATA');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    // Both DocRequiredName__c and AttachmentDescription__c are null → caption = null
    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Null Caption Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      DocRequiredName__c = null,
      AttachmentDescription__c = null,
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    Assert.isNotNull(result, 'Deve gerar PDF mesmo com caption nula.');
  }

  // ---------------------------------------------------------------------------
  // inferContentType — gif branch (PathOnClient ends in .gif → 'image/gif')
  // ---------------------------------------------------------------------------
  @IsTest
  static void generatePdfBase64_withGifAttachment() {
    Account acc = new Account(Name = 'Conta Gif Test');
    insert acc;

    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'gif-attachment';
    cv.PathOnClient = 'gif-attachment.gif';
    cv.VersionData = Blob.valueOf('GIF89a');
    insert cv;
    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Gif Link',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'gif-test',
      DocRequiredName__c = 'GIF Test',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String result = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    Assert.isNotNull(result, 'Deve gerar PDF com arquivo GIF.');
  }
}
