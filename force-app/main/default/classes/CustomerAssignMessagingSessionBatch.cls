global with sharing class CustomerAssignMessagingSessionBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  global Database.QueryLocator start(Database.BatchableContext BC) {
    return Database.getQueryLocator(
      'SELECT Id, MessagingEndUserId, MessagingEndUser.Telefone_Formatado__c, MessagingEndUser.ContactId, CaseId FROM MessagingSession WHERE CaseId = null'
    );
  }

  global void execute(SchedulableContext sc) {
    Database.executeBatch(new CustomerAssignMessagingSessionBatch());
  }

  global void execute(
    Database.BatchableContext BC,
    List<MessagingSession> scope
  ) {
    Set<Id> contactIds = new Set<Id>();
    Set<String> phones = new Set<String>();
    Map<Id, Case> caseByContactId = new Map<Id, Case>();
    List<MessagingSession> sessionsToUpdate = new List<MessagingSession>();

    if (scope?.isEmpty())
      return;

    for (MessagingSession session : scope) {
      phones.add(session.MessagingEndUser.Telefone_Formatado__c);

      if (session.MessagingEndUser?.ContactId != null) {
        contactIds.add(session.MessagingEndUser.ContactId);
      }
    }

    Map<Id, MessagingEndUser> endUsers = new Map<Id, MessagingEndUser>(
      [
        SELECT Id, ContactId, Telefone_Formatado__c
        FROM MessagingEndUser
        WHERE Telefone_Formatado__c IN :phones OR ContactId IN :contactIds
      ]
    );

    for (MessagingEndUser endUser : endUsers.values()) {
      if (endUser.ContactId != null) {
        contactIds.add(endUser.ContactId);
      }
    }

    List<Case> cases = [
      SELECT Id, ContactId
      FROM Case
      WHERE
        ContactId IN :contactIds
        AND RecordType.DeveloperName = 'Jornada_do_Cliente'
    ];

    for (Case c : cases) {
      caseByContactId.put(c.ContactId, c);
    }

    for (MessagingSession session : scope) {
      MessagingEndUser endUser = endUsers.get(session.MessagingEndUserId);

      if (endUser == null) {
        continue;
      }

      Case c = caseByContactId.get(endUser.ContactId);

      if (c != null) {
        session.CaseId = c.Id;
        sessionsToUpdate.add(session);
      }
    }

    update sessionsToUpdate;
  }

  global void finish(Database.BatchableContext BC) {
    // Reagenda o job
    System.debug('Reagendando o batch...');
    CustomerAssignMessagingSessionBatch job = new CustomerAssignMessagingSessionBatch();
    Datetime nextRun = Datetime.now().addMinutes(5);
    String cronExp = nextRun.format('s m H d M \'?\' yyyy');
    if (!Test.isRunningTest())
      System.schedule(
        'CustomerAssignMessagingSessionBatch - ' + nextRun,
        cronExp,
        job
      );
  }
}
