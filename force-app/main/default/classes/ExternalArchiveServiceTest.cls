/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ExternalArchiveServiceTest {
  private class ExternalArchiveMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    ExternalArchiveMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setStatus(statusCode >= 200 && statusCode < 300 ? 'OK' : 'ERROR');
      res.setHeader('Content-Type', 'application/json');
      res.setBody(body);
      return res;
    }
  }

  private static Opportunity createOpportunity(
    String name,
    String virtualOfficeId
  ) {
    Account acc = new Account(Name = 'Conta ' + name);
    insert acc;

    Opportunity opp = new Opportunity(
      Name = 'Opp ' + name,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      AccountId = acc.Id,
      IdVirtualOffice__c = virtualOfficeId
    );
    insert opp;
    return opp;
  }

  @IsTest
  static void shouldUploadArchive() {
    Opportunity opp = createOpportunity('Arquivo', 'VO-ARQ');
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalArchiveMock(
        200,
        '{"data":"https://files.example.com/doc.pdf"}'
      )
    );

    Test.startTest();
    ExternalArchiveService.UploadResult result = ExternalArchiveService.uploadExternalArchive(
      opp.Id,
      'arquivo',
      EncodingUtil.base64Encode(Blob.valueOf('conteudo')),
      opp.AccountId,
      'Outra atividade',
      'Documento'
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    OpportunityAttachmentLink__c link = [
      SELECT AttachmentDescription__c, AttachmentURL__c, SObjectId__c
      FROM OpportunityAttachmentLink__c
      WHERE Id = :result.attachmentId
    ];
    System.assertEquals('arquivo.pdf', link.AttachmentDescription__c);
    System.assertEquals(
      'https://files.example.com/doc.pdf',
      link.AttachmentURL__c
    );
    System.assertEquals(String.valueOf(opp.AccountId), link.SObjectId__c);
  }

  @IsTest
  static void shouldUploadRelatorioAndPersistFileReferences() {
    Opportunity opp = createOpportunity('Relatorio', 'VO-REL');
    String base64File =
      'data:application/pdf;base64,' +
      EncodingUtil.base64Encode(Blob.valueOf('relatorio-final'));

    Test.setMock(
      HttpCalloutMock.class,
      new ExternalArchiveMock(
        200,
        '{"data":"https://files.example.com/relatorio"}'
      )
    );

    Test.startTest();
    ExternalArchiveService.UploadResult result = ExternalArchiveService.uploadExternalArchive(
      opp.Id,
      'Relatorio Final',
      base64File,
      opp.AccountId,
      TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
      'Relatorio'
    );
    Test.stopTest();

    OpportunityAttachmentLink__c link = [
      SELECT
        AttachmentDescription__c,
        AttachmentURL__c,
        InternalAttachmentURL__c,
        ContentDocumentId__c
      FROM OpportunityAttachmentLink__c
      WHERE Id = :result.attachmentId
    ];
    System.assertEquals(true, result.success);
    System.assertEquals('Relatorio Final', link.AttachmentDescription__c);
    System.assertNotEquals(null, link.ContentDocumentId__c);
    System.assert(
      link.InternalAttachmentURL__c.contains(
        '/sfc/servlet.shepherd/document/download/'
      )
    );
  }

  @IsTest
  static void shouldReturnErrorResultWhenArchiveCallFails() {
    Opportunity opp = createOpportunity('Erro', 'VO-ERR');
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalArchiveMock(500, '{"error":"failure"}')
    );

    Test.startTest();
    ExternalArchiveService.UploadResult result = ExternalArchiveService.uploadExternalArchive(
      opp.Id,
      'erro.pdf',
      EncodingUtil.base64Encode(Blob.valueOf('erro')),
      opp.AccountId,
      'Outra atividade',
      'Documento'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(result.message.contains('500'));
  }

  @IsTest
  static void shouldValidateGuardClauses() {
    Opportunity opp = createOpportunity('Guard', 'VO-GUARD');

    Boolean blankFile = false;
    Boolean blankRelatedRecord = false;
    Boolean blankOpportunity = false;

    try {
      ExternalArchiveService.uploadExternalArchive(
        opp.Id,
        'arquivo.pdf',
        '',
        opp.AccountId,
        'Outra atividade',
        'Documento'
      );
    } catch (AuraHandledException ex) {
      blankFile = true;
    }

    try {
      ExternalArchiveService.uploadExternalArchive(
        opp.Id,
        'arquivo.pdf',
        EncodingUtil.base64Encode(Blob.valueOf('conteudo')),
        null,
        'Outra atividade',
        'Documento'
      );
    } catch (AuraHandledException ex) {
      blankRelatedRecord = true;
    }

    try {
      ExternalArchiveService.uploadExternalArchive(
        null,
        'arquivo.pdf',
        EncodingUtil.base64Encode(Blob.valueOf('conteudo')),
        opp.AccountId,
        'Outra atividade',
        'Documento'
      );
    } catch (AuraHandledException ex) {
      blankOpportunity = true;
    }

    System.assertEquals(true, blankFile);
    System.assertEquals(true, blankRelatedRecord);
    System.assertEquals(true, blankOpportunity);
  }
}
