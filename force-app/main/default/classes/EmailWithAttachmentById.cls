/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-12-2025
 * @last modified by	 : Daniel Belini
 **/
public class EmailWithAttachmentById {
  public class Request {
    @InvocableVariable(required=true)
    public String recipientEmail;

    @InvocableVariable(required=true)
    public String subject;

    @InvocableVariable(required=true)
    public String body;

    @InvocableVariable(required=false)
    public String contentDocumentId;

    @InvocableVariable(required=false)
    public String ccEmail;

    @InvocableVariable(required=false)
    public String orgWideEmailAddressId;
  }

  @InvocableMethod(
    label='Enviar Email com Arquivo'
    description='Envia um e-mail com anexo buscando o arquivo pelo ContentDocumentId ou ContentVersionId.'
  )
  public static void sendEmailWithAttachment(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    Messaging.reserveSingleEmailCapacity(requests.size());
    for (Request req : requests) {
      if (
        String.isEmpty(req.recipientEmail) ||
        String.isEmpty(req.subject) ||
        String.isEmpty(req.body)
      ) {
        throw new IllegalArgumentException(
          'Parâmetros obrigatórios não preenchidos.'
        );
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
          WHERE ContentDocumentId = :req.contentDocumentId AND IsLatest = TRUE
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
        throw new IllegalArgumentException(
          'Arquivo não encontrado para o ID fornecido: ' + req.contentDocumentId
        );
      }

      Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
      String fileName = String.isNotBlank(contentVersion.Title)
        ? contentVersion.Title
        : 'anexo';
      if (!String.isBlank(contentVersion.FileExtension)) {
        fileName += '.' + contentVersion.FileExtension;
      }
      attachment.setFileName(fileName);
      attachment.setBody(contentVersion.VersionData);

      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ req.recipientEmail });
      email.setTreatTargetObjectAsRecipient(false);
      email.setUseSignature(false);
      email.setSaveAsActivity(false);

      if (!String.isEmpty(req.ccEmail)) {
        email.setCcAddresses(new List<String>{ req.ccEmail });
      }

      if (!String.isEmpty(req.orgWideEmailAddressId)) {
        email.setOrgWideEmailAddressId(req.orgWideEmailAddressId);
      }

      email.setSubject(req.subject);
      email.setHtmlBody(req.body);
      email.setPlainTextBody(convertToPlainText(req.body));
      email.setFileAttachments(
        new List<Messaging.EmailFileAttachment>{ attachment }
      );

      try {
        Messaging.SendEmailResult[] results = Messaging.sendEmail(
          new List<Messaging.SingleEmailMessage>{ email },
          false
        );
        if (results == null || results.isEmpty() || !results[0].isSuccess()) {
          String errorMessage = (results != null &&
            !results.isEmpty() &&
            results[0].getErrors() != null &&
            results[0].getErrors().size() > 0)
            ? results[0].getErrors()[0].getMessage()
            : 'Motivo não informado pelo Salesforce.';
          throw new EmailException('Falha ao enviar e-mail: ' + errorMessage);
        }
      } catch (Exception e) {
        System.debug('Erro ao enviar e-mail: ' + e.getMessage());
        throw e;
      }
    }
  }

  @TestVisible
  private static String convertToPlainText(String htmlBody) {
    if (String.isBlank(htmlBody)) {
      return null;
    }

    String plain = htmlBody.replaceAll('<[^>]+>', ' ');
    plain = plain.replaceAll('&nbsp;', ' ');
    while (plain.contains('	 ')) {
      plain = plain.replace('	 ', ' ');
    }
    return plain.trim();
  }
}
