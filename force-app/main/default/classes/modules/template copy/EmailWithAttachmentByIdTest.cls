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

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        EmailWithAttachmentById.Request req = new EmailWithAttachmentById.Request();
        req.recipientEmail = 'destinatario@teste.com';
        req.ccEmail = 'cc@teste.com';
        req.subject = 'Assunto Teste';
        req.body = '<p>Corpo <strong>HTML</strong></p>';
        req.contentDocumentId = contentDocumentId;

        Test.startTest();
        EmailWithAttachmentById.sendEmailWithAttachment(new List<EmailWithAttachmentById.Request>{req});
        Test.stopTest();
    }

    @isTest
    static void convertHtmlToPlainText() {
        String plain = EmailWithAttachmentById.convertToPlainText('<p>Olá&nbsp;<strong>Mundo</strong></p>');
        System.assertEquals('Olá Mundo', plain);
    }
}
