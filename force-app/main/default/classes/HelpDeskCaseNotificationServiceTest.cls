@IsTest
private class HelpDeskCaseNotificationServiceTest {
  @IsTest
  static void shouldNotifyOnlyWhenJiraStatusClosesTheCase() {
    Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Help_Desk_Salesforce')
      .getRecordTypeId();
    Case caseRecord = new Case(
      Subject = 'Falha no acesso',
      Status = 'Novo',
      Origin = 'Help Desk Salesforce',
      RecordTypeId = recordTypeId,
      StatusAprovacao__c = 'Aprovado'
    );
    insert caseRecord;

    Case previousRecord = caseRecord.clone(true, true, false, false);
    previousRecord.JiraStatus__c = 'Trabalhando';
    caseRecord.JiraStatus__c = 'Concluido';
    caseRecord.ComentarioSuporte__c = '<p>Acesso restabelecido e validado com o solicitante.</p>';

    System.assertEquals(
      true,
      HelpDeskCaseNotificationService.isClosingTransition(
        caseRecord,
        previousRecord
      ),
      'A transição para concluído deve gerar o e-mail de encerramento.'
    );
    Case intermediateRecord = caseRecord.clone(true, true, false, false);
    intermediateRecord.JiraStatus__c = 'Trabalhando';
    System.assertEquals(
      false,
      HelpDeskCaseNotificationService.isClosingTransition(
        intermediateRecord,
        previousRecord
      ),
      'Status intermediário não deve gerar e-mail.'
    );

    HelpDeskCaseNotificationService.skipSend = true;
    update caseRecord;

    Case storedCase = [
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
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(
      'Finalizado',
      storedCase.Status,
      'O trigger deve fechar o Case quando o Jira for concluído.'
    );
    String recipient = HelpDeskCaseNotificationService.resolveRecipient(
      storedCase
    );
    System.assertEquals(UserInfo.getUserEmail(), recipient);

    Messaging.SingleEmailMessage email = HelpDeskCaseNotificationService.buildEmail(
      storedCase,
      recipient
    );
    System.assert(
      email.getSubject().contains(storedCase.CaseNumber),
      'O assunto deve identificar o chamado.'
    );
    System.assert(
      email.getPlainTextBody().contains('Status da aprovação'),
      'O e-mail deve informar o status da aprovação.'
    );
    System.assert(
      email
        .getPlainTextBody()
        .contains('Acesso restabelecido e validado com o solicitante.'),
      'O e-mail deve incluir o comentário de suporte.'
    );
    System.assert(
      email.getPlainTextBody().contains('Conclusão do suporte:') &&
      email
        .getHtmlBody()
        .contains('Acesso restabelecido e validado com o solicitante.'),
      'O e-mail de conclusão deve destacar o comentário do suporte.'
    );
  }

  @IsTest
  static void shouldLabelCancelledClosure() {
    Case cancelledRecord = new Case(
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Help_Desk_Salesforce')
        .getRecordTypeId(),
      Subject = 'Cancelamento solicitado',
      Status = 'Novo',
      Origin = 'Help Desk Salesforce',
      StatusAprovacao__c = 'Aprovado'
    );
    insert cancelledRecord;

    Case previousRecord = cancelledRecord.clone(true, true, false, false);
    previousRecord.JiraStatus__c = 'Trabalhando';
    cancelledRecord.JiraStatus__c = 'Cancelado';
    cancelledRecord.ComentarioSuporte__c = '<p>Solicitação cancelada pelo solicitante.</p>';

    HelpDeskCaseNotificationService.closeCasesFromJira(
      new List<Case>{ cancelledRecord },
      new Map<Id, Case>{ cancelledRecord.Id => previousRecord }
    );
    System.assertEquals(
      'Finalizado',
      cancelledRecord.Status,
      'O Case deve ser fechado quando o Jira for cancelado.'
    );

    System.assertEquals(
      true,
      HelpDeskCaseNotificationService.isClosingTransition(
        cancelledRecord,
        previousRecord
      )
    );

    Messaging.SingleEmailMessage email = HelpDeskCaseNotificationService.buildEmail(
      cancelledRecord,
      'solicitante@enerzee.com.br'
    );
    System.assert(email.getSubject().contains('cancelado'));
    System.assert(
      email.getHtmlBody().contains('<strong>Motivo do cancelamento:</strong>')
    );
  }
}
