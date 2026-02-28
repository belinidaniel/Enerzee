@IsTest
public with sharing class ReassignMessagingSessionBatchTest {
  @TestSetup
  private static void testSetup() {
    try {
      List<MessagingChannel> channels = [
        SELECT Id
        FROM MessagingChannel
        LIMIT 1
      ];
      if (channels.isEmpty()) {
        return;
      }
      Id mChannelId = channels[0].Id;

      MessagingEndUser mUser = new MessagingEndUser();
      mUser.Name = 'Guest';
      mUser.MessagingPlatformKey = 'v2/iamessage/AUTH/Test User Verification/uid:test13245serg2g1234';
      mUser.MessagingChannelId = mChannelId;
      mUser.MessageType = 'EmbeddedMessaging';

      insert mUser;

      Test.startTest();

      MessagingSession ms = new MessagingSession(
        MessagingChannelId = mChannelId,
        Status = 'Waiting',
        MessagingEndUserId = mUser.Id,
        ConversationId = '0dwU50000034lLBIAY'
      );

      insert ms;

      test.stopTest();
    } catch (Exception ex) {
      if (
        ex.getMessage() == null ||
        !ex.getMessage().contains('MessagingDisabled')
      ) {
        throw ex;
      }
    }
  }

  @IsTest
  private static void shouldTestBatch() {
    Test.startTest();

    try {
      Database.executeBatch(new ReassignMessagingSessionBatch());
    } catch (Exception ex) {
    }

    Test.stopTest();
  }
}
