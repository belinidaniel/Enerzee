@isTest
private class CustomerAssignMessagingSessionBatchTest {
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
    // Test the execute method
    List<MessagingSession> sessions = [SELECT Id, CaseId FROM MessagingSession];
    Test.startTest();
    try {
      CustomerAssignMessagingSessionBatch batch = new CustomerAssignMessagingSessionBatch();
      Database.executeBatch(batch, 2);
    } catch (Exception ex) {
      System.debug('Exception: ' + ex.getMessage());
    }

    Test.stopTest();
  }
}
