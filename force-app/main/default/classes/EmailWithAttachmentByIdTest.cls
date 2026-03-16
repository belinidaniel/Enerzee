/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class EmailWithAttachmentByIdTest {
  @isTest
  static void sendEmailWithValidParameters() {
    ContentVersion cv = new ContentVersion(
      Title = 'Manual Teste',
      PathOnClient = 'manual.pdf',
      VersionData = Blob.valueOf('PDF DATA')
    );
    insert cv;

    Id contentDocumentId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    EmailWithAttachmentById.Request req = new EmailWithAttachmentById.Request();
    req.recipientEmail = 'destinatario@teste.com';
    req.ccEmail = 'cc@teste.com';
    req.subject = 'Assunto Teste';
    req.body = '<p>Corpo <strong>HTML</strong></p>';
    req.contentDocumentId = contentDocumentId;

    Test.startTest();
    EmailWithAttachmentById.sendEmailWithAttachment(
      new List<EmailWithAttachmentById.Request>{ req }
    );
    Test.stopTest();
  }

  @isTest
  static void convertHtmlToPlainText() {
    String plain = EmailWithAttachmentById.convertToPlainText(
      '<p>Olá&nbsp;<strong>Mundo</strong></p>'
    );

    Assert.areEqual('Olá Mundo', plain);
  }

  @isTest
  static void shouldHandleVersionIdAndValidationErrors() {
    ContentVersion cv = new ContentVersion(
      Title = 'Arquivo Direto',
      PathOnClient = 'arquivo.txt',
      VersionData = Blob.valueOf('conteudo')
    );
    insert cv;

    EmailWithAttachmentById.Request versionRequest = new EmailWithAttachmentById.Request();
    versionRequest.recipientEmail = 'destinatario2@teste.com';
    versionRequest.subject = 'Assunto Version';
    versionRequest.body = '<div>Teste</div>';
    versionRequest.contentDocumentId = cv.Id;

    Test.startTest();
    EmailWithAttachmentById.sendEmailWithAttachment(
      new List<EmailWithAttachmentById.Request>{ versionRequest }
    );
    EmailWithAttachmentById.sendEmailWithAttachment(
      new List<EmailWithAttachmentById.Request>()
    );
    Test.stopTest();

    Boolean hasValidationError = false;
    try {
      EmailWithAttachmentById.Request invalidRequest = new EmailWithAttachmentById.Request();
      invalidRequest.recipientEmail = 'destinatario3@teste.com';
      invalidRequest.body = '<p>Sem assunto</p>';
      invalidRequest.contentDocumentId = cv.Id;
      EmailWithAttachmentById.sendEmailWithAttachment(
        new List<EmailWithAttachmentById.Request>{ invalidRequest }
      );
    } catch (IllegalArgumentException ex) {
      hasValidationError = ex.getMessage()
        .contains('Parâmetros obrigatórios não preenchidos');
    }

    Assert.areEqual(true, hasValidationError);
    Assert.areEqual(null, EmailWithAttachmentById.convertToPlainText(null));
  }
}
