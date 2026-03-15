/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class CustomerAssignMessagingSessionBatchTest {
  private static final String SESSION_PREFIX = MessagingSession.SObjectType.getDescribe()
    .getKeyPrefix();
  private static final String END_USER_PREFIX = MessagingEndUser.SObjectType.getDescribe()
    .getKeyPrefix();
  private static final String CASE_PREFIX = Case.SObjectType.getDescribe()
    .getKeyPrefix();
  private static final String CONTACT_PREFIX = Contact.SObjectType.getDescribe()
    .getKeyPrefix();

  @TestSetup
  static void setupTestData() {
    try {
      List<MessagingChannel> channels = [
        SELECT Id
        FROM MessagingChannel
        WHERE MasterLabel LIKE '%+55 11 4003-8852%'
        LIMIT 1
      ];
      if (channels.isEmpty()) {
        return;
      }
      MessagingChannel channel = channels[0];

      List<MessagingEndUser> endUsers = new List<MessagingEndUser>{
        new MessagingEndUser(
          ContactId = null,
          MessagingPlatformKey = '1234567890',
          Name = 'Test User 1',
          MessageType = 'WhatsApp',
          MessagingChannelId = channel.Id
        ),
        new MessagingEndUser(
          ContactId = null,
          MessagingPlatformKey = '0987654321',
          Name = 'Test User 2',
          MessageType = 'WhatsApp',
          MessagingChannelId = channel.Id
        )
      };
      insert endUsers;

      List<MessagingSession> sessions = new List<MessagingSession>{
        new MessagingSession(
          MessagingEndUserId = endUsers[0].Id,
          MessagingChannelId = channel.Id,
          Status = 'New',
          ConversationId = '0dwU50000034lLBIAY'
        ),
        new MessagingSession(
          MessagingEndUserId = endUsers[1].Id,
          MessagingChannelId = channel.Id,
          Status = 'New',
          ConversationId = '0dwU50000034lLBIAY'
        )
      };
      insert sessions;

      Contact contact = new Contact(LastName = 'Test Contact');
      insert contact;

      if (
        Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
          .containsKey('Jornada_do_Cliente')
      ) {
        Case caseRecord = new Case(
          ContactId = contact.Id,
          RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('Jornada_do_Cliente')
            .getRecordTypeId()
        );
        insert caseRecord;
      }

      endUsers[0].ContactId = contact.Id;
      update endUsers;
    } catch (Exception ex) {
      if (
        ex.getMessage() == null ||
        !ex.getMessage().contains('MessagingDisabled')
      ) {
        throw ex;
      }
    }
  }

  @isTest
  static void testExecuteMethod() {
    Test.startTest();
    try {
      CustomerAssignMessagingSessionBatch batch = new CustomerAssignMessagingSessionBatch();
      Database.executeBatch(batch, 2);
    } catch (Exception ex) {
      System.debug('Exception: ' + ex.getMessage());
    }

    Test.stopTest();
  }

  @IsTest
  static void shouldAssignCaseWhenContactMatchesOverrideData() {
    Id contactId = buildId(CONTACT_PREFIX, 1);
    Id caseId = buildId(CASE_PREFIX, 1);
    Id endUserWithCaseId = buildId(END_USER_PREFIX, 1);
    Id endUserWithoutCaseId = buildId(END_USER_PREFIX, 2);

    CustomerAssignMessagingSessionBatch.endUsersOverride = new Map<Id, MessagingEndUser>{
      endUserWithCaseId => new MessagingEndUser(
        Id = endUserWithCaseId,
        ContactId = contactId
      ),
      endUserWithoutCaseId => new MessagingEndUser(Id = endUserWithoutCaseId)
    };
    CustomerAssignMessagingSessionBatch.casesOverride = new List<Case>{
      new Case(Id = caseId, ContactId = contactId)
    };
    CustomerAssignMessagingSessionBatch.skipUpdateForTest = true;
    CustomerAssignMessagingSessionBatch.phoneByEndUserIdOverride = new Map<Id, String>{
      endUserWithCaseId => '5511999991111',
      endUserWithoutCaseId => '5511999992222',
      buildId(END_USER_PREFIX, 3) => '5511999993333'
    };

    List<MessagingSession> scope = new List<MessagingSession>{
      new MessagingSession(
        Id = buildId(SESSION_PREFIX, 1),
        MessagingEndUserId = endUserWithCaseId,
        MessagingEndUser = new MessagingEndUser(
          Id = endUserWithCaseId,
          ContactId = contactId
        )
      ),
      new MessagingSession(
        Id = buildId(SESSION_PREFIX, 2),
        MessagingEndUserId = endUserWithoutCaseId,
        MessagingEndUser = new MessagingEndUser(Id = endUserWithoutCaseId)
      ),
      new MessagingSession(
        Id = buildId(SESSION_PREFIX, 3),
        MessagingEndUserId = buildId(END_USER_PREFIX, 3),
        MessagingEndUser = new MessagingEndUser(
          Id = buildId(END_USER_PREFIX, 3)
        )
      )
    };

    try {
      new CustomerAssignMessagingSessionBatch().execute(null, scope);
    } finally {
      CustomerAssignMessagingSessionBatch.endUsersOverride = null;
      CustomerAssignMessagingSessionBatch.casesOverride = null;
      CustomerAssignMessagingSessionBatch.skipUpdateForTest = false;
      CustomerAssignMessagingSessionBatch.phoneByEndUserIdOverride = null;
    }

    System.assertEquals(caseId, scope[0].CaseId);
    System.assertEquals(null, scope[1].CaseId);
    System.assertEquals(null, scope[2].CaseId);
  }

  @IsTest
  static void shouldHandleStartFinishAndSchedulableExecution() {
    CustomerAssignMessagingSessionBatch batch = new CustomerAssignMessagingSessionBatch();

    Test.startTest();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(
      (Database.BatchableContext) null,
      new List<MessagingSession>()
    );
    batch.finish(null);
    batch.execute((SchedulableContext) null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  private static Id buildId(String prefix, Integer sequence) {
    return (Id) (prefix + String.valueOf(sequence).leftPad(15, '0'));
  }
}
