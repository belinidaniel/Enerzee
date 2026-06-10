/**
 * @description       : Notifica o solicitante interno quando um status do caso
 *                      Help Desk é alterado.
 * @test              : HelpDeskCaseNotificationServiceTest
 **/
public without sharing class HelpDeskCaseNotificationService {
  @TestVisible
  private static Boolean skipSend = false;

  public static void notifyStatusChanges(
    List<Case> newRecords,
    Map<Id, Case> oldMap
  ) {
    Set<Id> changedIds = new Set<Id>();
    for (Case currentRecord : newRecords) {
      Case previousRecord = oldMap.get(currentRecord.Id);
      if (
        previousRecord != null &&
        (currentRecord.Status != previousRecord.Status ||
        currentRecord.StatusAprovacao__c != previousRecord.StatusAprovacao__c ||
        currentRecord.JiraStatus__c != previousRecord.JiraStatus__c)
      ) {
        changedIds.add(currentRecord.Id);
      }
    }
    if (changedIds.isEmpty()) {
      return;
    }

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    for (Case caseRecord : [
      SELECT
        Id,
        CaseNumber,
        Subject,
        Status,
        StatusAprovacao__c,
        JiraStatus__c,
        SuppliedEmail,
        Contact.Email,
        CreatedBy.Email,
        CreatedBy.UserType,
        RecordType.DeveloperName
      FROM Case
      WHERE Id IN :changedIds
    ]) {
      if (caseRecord.RecordType.DeveloperName != 'Help_Desk_Salesforce') {
        continue;
      }
      String recipient = resolveRecipient(caseRecord);
      if (String.isBlank(recipient)) {
        continue;
      }
      emails.add(buildEmail(caseRecord, recipient));
    }

    if (skipSend || emails.isEmpty()) {
      return;
    }
    try {
      Messaging.sendEmail(emails, false);
    } catch (Exception error) {
      System.debug(
        LoggingLevel.ERROR,
        'Falha ao notificar status do Help Desk: ' + error.getMessage()
      );
    }
  }

  @TestVisible
  private static String resolveRecipient(Case caseRecord) {
    if (
      caseRecord.CreatedBy != null &&
      caseRecord.CreatedBy.UserType != 'Guest' &&
      String.isNotBlank(caseRecord.CreatedBy.Email)
    ) {
      return caseRecord.CreatedBy.Email;
    }
    if (String.isNotBlank(caseRecord.SuppliedEmail)) {
      return caseRecord.SuppliedEmail;
    }
    return caseRecord.Contact != null ? caseRecord.Contact.Email : null;
  }

  @TestVisible
  private static Messaging.SingleEmailMessage buildEmail(
    Case caseRecord,
    String recipient
  ) {
    String approvalStatus = String.isNotBlank(caseRecord.StatusAprovacao__c)
      ? caseRecord.StatusAprovacao__c
      : 'Não iniciado';
    String executionStatus = String.isNotBlank(caseRecord.JiraStatus__c)
      ? caseRecord.JiraStatus__c
      : 'Aguardando aprovação';
    String caseUrl =
      URL.getOrgDomainUrl().toExternalForm() +
      '/lightning/r/Case/' +
      caseRecord.Id +
      '/view';
    String body =
      'O chamado ' +
      caseRecord.CaseNumber +
      ' foi atualizado.\n\n' +
      'Assunto: ' +
      caseRecord.Subject +
      '\nStatus da aprovação: ' +
      approvalStatus +
      '\nStatus de execução: ' +
      executionStatus +
      '\nStatus operacional: ' +
      caseRecord.Status +
      '\n\nAcompanhe o chamado: ' +
      caseUrl;

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ recipient });
    email.setSaveAsActivity(false);
    email.setSubject(
      '[Help Desk] Atualização do chamado ' + caseRecord.CaseNumber
    );
    email.setPlainTextBody(body);
    email.setHtmlBody(
      body.escapeHtml4().replace('\n', '<br/>') +
        '<br/><br/><a href="' +
        caseUrl +
        '">Abrir chamado</a>'
    );
    return email;
  }
}