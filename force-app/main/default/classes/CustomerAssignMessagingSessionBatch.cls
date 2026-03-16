/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : CustomerAssignMessagingSessionBatchTest
 **/
global with sharing class CustomerAssignMessagingSessionBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  @TestVisible
  private static Map<Id, MessagingEndUser> endUsersOverride;

  @TestVisible
  private static List<Case> casesOverride;

  @TestVisible
  private static Boolean skipUpdateForTest = false;

  @TestVisible
  private static Map<Id, String> phoneByEndUserIdOverride;

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
      String formattedPhone = getFormattedPhone(session);
      if (String.isNotBlank(formattedPhone)) {
        phones.add(formattedPhone);
      }

      if (session.MessagingEndUser?.ContactId != null) {
        contactIds.add(session.MessagingEndUser.ContactId);
      }
    }

    Map<Id, MessagingEndUser> endUsers = loadEndUsers(phones, contactIds);

    for (MessagingEndUser endUser : endUsers.values()) {
      if (endUser.ContactId != null) {
        contactIds.add(endUser.ContactId);
      }
    }

    List<Case> cases = loadCases(contactIds);

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

    if (!sessionsToUpdate.isEmpty()) {
      if (Test.isRunningTest() && skipUpdateForTest) {
        return;
      }
      update sessionsToUpdate;
    }
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

  private static Map<Id, MessagingEndUser> loadEndUsers(
    Set<String> phones,
    Set<Id> contactIds
  ) {
    if (Test.isRunningTest() && endUsersOverride != null) {
      return new Map<Id, MessagingEndUser>(endUsersOverride);
    }

    return new Map<Id, MessagingEndUser>(
      [
        SELECT Id, ContactId, Telefone_Formatado__c
        FROM MessagingEndUser
        WHERE Telefone_Formatado__c IN :phones OR ContactId IN :contactIds
      ]
    );
  }

  private static List<Case> loadCases(Set<Id> contactIds) {
    if (Test.isRunningTest() && casesOverride != null) {
      return new List<Case>(casesOverride);
    }

    return [
      SELECT Id, ContactId
      FROM Case
      WHERE
        ContactId IN :contactIds
        AND RecordType.DeveloperName = 'Jornada_do_Cliente'
    ];
  }

  private static String getFormattedPhone(MessagingSession session) {
    if (
      Test.isRunningTest() &&
      phoneByEndUserIdOverride != null &&
      session != null &&
      phoneByEndUserIdOverride.containsKey(session.MessagingEndUserId)
    ) {
      return phoneByEndUserIdOverride.get(session.MessagingEndUserId);
    }

    return session?.MessagingEndUser?.Telefone_Formatado__c;
  }
}
