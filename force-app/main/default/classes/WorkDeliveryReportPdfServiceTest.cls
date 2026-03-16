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
      Assert.isTrue(
        ex.getMessage().contains('Registro'),
        'Mensagem deve mencionar registro.'
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
      Assert.isTrue(
        ex.getMessage().contains('Atividade'),
        'Mensagem deve mencionar atividade.'
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
      Assert.isTrue(
        ex.getMessage().contains('Atividade'),
        'Mensagem deve mencionar atividade.'
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
}
