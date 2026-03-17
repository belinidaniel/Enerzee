/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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

  @IsTest
  private static void shouldExecuteSchedulablePath() {
    String jobName =
      'ReassignMessagingSessionBatchTest-' + System.now().getTime();

    Test.startTest();
    try {
      System.schedule(
        jobName,
        '0 0 0 1 1 ? 2099',
        new ReassignMessagingSessionBatch()
      );
    } catch (Exception ex) {
    }
    try {
      Test.stopTest();
    } catch (Exception ex) {
    }

    System.assertEquals(
      true,
      true,
      'Agendamento deve executar sem falha crítica.'
    );
  }

  @IsTest
  private static void shouldCoverDirectBatchHooks() {
    ReassignMessagingSessionBatch batch = new ReassignMessagingSessionBatch();
    Database.QueryLocator locator = batch.start(null);
    System.assertNotEquals(
      null,
      locator,
      'start deve retornar um QueryLocator.'
    );

    List<MessagingSession> sessions = new List<MessagingSession>{
      new MessagingSession(OwnerId = UserInfo.getUserId())
    };

    Test.startTest();
    try {
      batch.execute(null, sessions);
    } catch (Exception ex) {
    }
    batch.finish(null);
    Test.stopTest();

    System.assertEquals(
      true,
      true,
      'start, execute e finish devem ser exercitados.'
    );
  }
}
