@IsTest
public with sharing class MessagingTriggerTest {
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
  private static void shouldTestUpdate() {
    List<MessagingSession> sessions = [
      SELECT Id, OwnerId
      FROM MessagingSession
      LIMIT 1
    ];
    if (sessions.isEmpty()) {
      System.assert(
        true,
        'No messaging session available in this org/test context.'
      );
      return;
    }
    MessagingSession ms = sessions[0];
    ms.OwnerId = [SELECT Id FROM User WHERE Profile.Name LIKE '%Admin%' LIMIT 1]
    .Id;

    Test.startTest();

    try {
      update ms;
    } catch (Exception ex) {
      if (
        ex.getMessage() == null ||
        !ex.getMessage().contains('MessagingDisabled')
      ) {
        throw ex;
      }
    }

    test.stopTest();
  }
}
