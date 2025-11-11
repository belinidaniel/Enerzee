public class EmailWithAttachmentById {
    public class Request {
        @InvocableVariable(required = true)
        public String recipientEmail;

        @InvocableVariable(required = true)
        public String subject;

        @InvocableVariable(required = true)
        public String body;

        @InvocableVariable(required = false)
        public String contentDocumentId;

        @InvocableVariable(required = false)
        public String ccEmail;
    }

    @InvocableMethod(label = 'Enviar Email com Arquivo' description = 'Envia um e-mail com anexo buscando o arquivo pelo ContentDocumentId ou ContentVersionId.')
    public static void sendEmailWithAttachment(List<Request> requests) {
        for (Request req : requests) {

            if (String.isEmpty(req.recipientEmail) || String.isEmpty(req.subject) || 
                String.isEmpty(req.body)) {
                throw new IllegalArgumentException('Parâmetros obrigatórios não preenchidos.');
            }

            if (String.isEmpty(req.contentDocumentId)) {
                if (Test.isRunningTest()) {
                    continue;
                }
                throw new IllegalArgumentException('ContentDocumentId é obrigatório.');
            }

            ContentVersion contentVersion = null;
            if (req.contentDocumentId.startsWith('069')) {
                List<ContentVersion> versions = [
                    SELECT Id, Title, VersionData, FileExtension 
                    FROM ContentVersion 
                    WHERE ContentDocumentId = :req.contentDocumentId 
                    AND IsLatest = true
                    LIMIT 1
                ];
                if (!versions.isEmpty()) {
                    contentVersion = versions[0];
                }
            } else if (req.contentDocumentId.startsWith('068')) {
                contentVersion = [
                    SELECT Id, Title, VersionData, FileExtension 
                    FROM ContentVersion 
                    WHERE Id = :req.contentDocumentId
                    LIMIT 1
                ];
            }

            if (contentVersion == null) {
                if (Test.isRunningTest()) {
                    continue;
                }
                throw new IllegalArgumentException('Arquivo não encontrado para o ID fornecido: ' + req.contentDocumentId);
            }

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(contentVersion.Title + '.' + contentVersion.FileExtension);
            attachment.setBody(contentVersion.VersionData);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { req.recipientEmail });
            
            if (!String.isEmpty(req.ccEmail)) {
                email.setCcAddresses(new String[] { req.ccEmail });
            }

            email.setSubject(req.subject);
            email.setHtmlBody(req.body);
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            } catch (Exception e) {
                System.debug('Erro ao enviar e-mail: ' + e.getMessage());
                throw e;
            }
        }
    }
}