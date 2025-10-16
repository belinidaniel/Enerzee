@IsTest
public with sharing class ReassignMessagingSessionBatchTest {

    @TestSetup
    private static void testSetup(){

        Id mChannelId = [SELECT Id FROM MessagingChannel LIMIT 1].Id;

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
    }

    @IsTest
    private static void shouldTestBatch(){

        Test.startTest();

        try{
            Database.executeBatch(new ReassignMessagingSessionBatch());
        }catch(Exception ex){

        }

        Test.stopTest();
    }
}