@IsTest
private class HelpDeskCaseNotificationServiceTest {
  @IsTest
  static void shouldBuildStatusNotificationForRequester() {
    Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Help_Desk_Salesforce')
      .getRecordTypeId();
    Case caseRecord = new Case(
      Subject = 'Falha no acesso',
      Status = 'New',
      Origin = 'Help Desk Salesforce',
      RecordTypeId = recordTypeId,
      StatusAprovacao__c = 'Em Aprovação'
    );
    insert caseRecord;

    Case previousRecord = caseRecord.clone(true, true, false, false);
    previousRecord.StatusAprovacao__c = 'Pendente';
    caseRecord.StatusAprovacao__c = 'Em Aprovação';

    HelpDeskCaseNotificationService.skipSend = true;
    Test.startTest();
    HelpDeskCaseNotificationService.notifyStatusChanges(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => previousRecord }
    );
    Test.stopTest();

    Case storedCase = [
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
      WHERE Id = :caseRecord.Id
    ];
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
  }
}