/**
 * @description       : Notifica o solicitante interno quando o chamado do
 *                      Help Desk é concluído ou cancelado no Jira.
 * @test              : HelpDeskCaseNotificationServiceTest
 **/
public without sharing class HelpDeskCaseNotificationService {
  private static final String HELP_DESK_RECORD_TYPE = 'Help_Desk_Salesforce';
  private static final String CLOSED_CASE_STATUS = 'Finalizado';

  @TestVisible
  private static Boolean skipSend = false;

  public static void closeCasesFromJira(
    List<Case> newRecords,
    Map<Id, Case> oldMap
  ) {
    Schema.RecordTypeInfo helpDeskRecordType = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(HELP_DESK_RECORD_TYPE);
    if (helpDeskRecordType == null) {
      return;
    }

    Id helpDeskRecordTypeId = helpDeskRecordType.getRecordTypeId();
    for (Case currentRecord : newRecords) {
      if (
        currentRecord.RecordTypeId == helpDeskRecordTypeId &&
        isClosingTransition(currentRecord, oldMap.get(currentRecord.Id))
      ) {
        currentRecord.Status = CLOSED_CASE_STATUS;
      }
    }
  }

  public static void notifyStatusChanges(
    List<Case> newRecords,
    Map<Id, Case> oldMap
  ) {
    Set<Id> changedIds = new Set<Id>();
    for (Case currentRecord : newRecords) {
      Case previousRecord = oldMap.get(currentRecord.Id);
      if (isClosingTransition(currentRecord, previousRecord)) {
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
        ComentarioSuporte__c,
        SuppliedEmail,
        Contact.Email,
        CreatedBy.Email,
        CreatedBy.UserType,
        RecordType.DeveloperName
      FROM Case
      WHERE Id IN :changedIds
    ]) {
      if (caseRecord.RecordType.DeveloperName != HELP_DESK_RECORD_TYPE) {
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
  private static Boolean isClosingTransition(
    Case currentRecord,
    Case previousRecord
  ) {
    return previousRecord != null &&
      currentRecord.JiraStatus__c != previousRecord.JiraStatus__c &&
      isClosingStatus(currentRecord.JiraStatus__c);
  }

  private static Boolean isClosingStatus(String jiraStatus) {
    if (String.isBlank(jiraStatus)) {
      return false;
    }
    String normalizedStatus = jiraStatus.trim().toUpperCase();
    return normalizedStatus == 'CONCLUIDO' ||
      normalizedStatus == 'CONCLUÍDO' ||
      normalizedStatus == 'DONE' ||
      normalizedStatus == 'CANCELADO' ||
      normalizedStatus == 'ITENS CANCELADOS';
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
    Boolean cancelled =
      caseRecord.JiraStatus__c != null &&
      (caseRecord.JiraStatus__c.equalsIgnoreCase('Cancelado') ||
      caseRecord.JiraStatus__c.equalsIgnoreCase('ITENS CANCELADOS'));
    String closureLabel = cancelled
      ? 'Motivo do cancelamento'
      : 'Conclusão do suporte';
    String supportCommentHtml = String.isNotBlank(
        caseRecord.ComentarioSuporte__c
      )
      ? caseRecord.ComentarioSuporte__c
      : 'Não informado.';
    String supportCommentText = supportCommentHtml.stripHtmlTags();
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
      '\n\n' +
      closureLabel +
      ':\n' +
      supportCommentText +
      '\n\nAcompanhe o chamado: ' +
      caseUrl;

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ recipient });
    email.setSaveAsActivity(false);
    email.setSubject(
      '[Help Desk] Chamado ' +
        caseRecord.CaseNumber +
        (cancelled ? ' cancelado' : ' concluído')
    );
    email.setPlainTextBody(body);
    email.setHtmlBody(
      ('O chamado ' +
          caseRecord.CaseNumber +
          (cancelled ? ' foi cancelado.' : ' foi concluído.') +
          '\n\nAssunto: ' +
          caseRecord.Subject +
          '\nStatus da aprovação: ' +
          approvalStatus +
          '\nStatus de execução: ' +
          executionStatus +
          '\nStatus operacional: ' +
          caseRecord.Status)
          .escapeHtml4()
          .replace('\n', '<br/>') +
        '<br/><br/><strong>' +
        closureLabel.escapeHtml4() +
        ':</strong><br/>' +
        supportCommentHtml +
        '<br/><br/><a href="' +
        caseUrl +
        '">Abrir chamado</a>'
    );
    return email;
  }
}
