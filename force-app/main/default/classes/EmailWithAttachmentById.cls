/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : EmailWithAttachmentByIdTest
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

      ContentVersion contentVersion = resolveContentVersion(
        req.contentDocumentId
      );

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

      if (contentVersion != null) {
        email.setFileAttachments(
          new List<Messaging.EmailFileAttachment>{
            buildAttachment(contentVersion)
          }
        );
      } else if (String.isNotBlank(req.contentDocumentId)) {
        System.debug(
          'EmailWithAttachmentById: arquivo não encontrado para o ID informado. E-mail será enviado sem anexo. ID=' +
          req.contentDocumentId
        );
      } else {
        System.debug(
          'EmailWithAttachmentById: contentDocumentId não informado. E-mail será enviado sem anexo.'
        );
      }

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
  private static ContentVersion resolveContentVersion(String fileId) {
    if (String.isBlank(fileId)) {
      return null;
    }

    if (fileId.startsWith('069')) {
      List<ContentVersion> versions = [
        SELECT Id, Title, VersionData, FileExtension
        FROM ContentVersion
        WHERE ContentDocumentId = :fileId AND IsLatest = TRUE
        LIMIT 1
      ];
      return versions.isEmpty() ? null : versions[0];
    }

    if (fileId.startsWith('068')) {
      List<ContentVersion> versions = [
        SELECT Id, Title, VersionData, FileExtension
        FROM ContentVersion
        WHERE Id = :fileId
        LIMIT 1
      ];
      return versions.isEmpty() ? null : versions[0];
    }

    return null;
  }

  private static Messaging.EmailFileAttachment buildAttachment(
    ContentVersion contentVersion
  ) {
    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    String fileName = String.isNotBlank(contentVersion.Title)
      ? contentVersion.Title
      : 'anexo';
    if (!String.isBlank(contentVersion.FileExtension)) {
      fileName += '.' + contentVersion.FileExtension;
    }
    attachment.setFileName(fileName);
    attachment.setBody(contentVersion.VersionData);
    return attachment;
  }

  @TestVisible
  private static String convertToPlainText(String htmlBody) {
    if (String.isBlank(htmlBody)) {
      return null;
    }

    String plain = htmlBody.replaceAll('<[^>]+>', ' ');
    plain = plain.replaceAll('&nbsp;', ' ');
    plain = plain.replaceAll('\\s+', ' ');
    return plain.trim();
  }
}
