@IsTest
private class MessagingSessionSLABatchTest {

    @IsTest
    static void shouldNotifyQueueDefinedInQueueN1Field() {
        Id channelId = resolveMessagingChannelId();
        MessagingEndUser endUser = createEndUser(channelId);
        Group queue = createQueueWithMember(UserInfo.getUserId());

        MessagingSession insertedSession = createSession(channelId, endUser.Id, UserInfo.getUserId(), queue.Id);

        MessagingSession scopeRecord = [
            SELECT  Id, Name, OwnerId, QueueN1__c, OwnerAssignmentDate__c,
                    MinuteSLAN1__c, MinuteSLAN2__c, MinuteSLAN3__c,
                    NotifyN1__c, NotifyN2__c, NotifyN3__c,
                    QueueSupervisorRole__c, QueueCoordinatorRole__c
            FROM    MessagingSession
            WHERE   Id = :insertedSession.Id
        ];

        Test.startTest();
        new MessagingSessionSLABatch().execute(null, new List<MessagingSession>{ scopeRecord });
        Test.stopTest();

        MessagingSession updatedSession = [SELECT NotifyN1__c FROM MessagingSession WHERE Id = :insertedSession.Id];
        System.assertEquals(true, updatedSession.NotifyN1__c, 'Queue N1 field should drive SLA notifications.');
    }

    @IsTest
    static void shouldFallbackToOwnerWhenQueueFieldIsBlank() {
        Id channelId = resolveMessagingChannelId();
        MessagingEndUser endUser = createEndUser(channelId);

        MessagingSession insertedSession = createSession(channelId, endUser.Id, UserInfo.getUserId(), null);

        MessagingSession scopeRecord = [
            SELECT  Id, Name, OwnerId, QueueN1__c, OwnerAssignmentDate__c,
                    MinuteSLAN1__c, MinuteSLAN2__c, MinuteSLAN3__c,
                    NotifyN1__c, NotifyN2__c, NotifyN3__c,
                    QueueSupervisorRole__c, QueueCoordinatorRole__c
            FROM    MessagingSession
            WHERE   Id = :insertedSession.Id
        ];

        Test.startTest();
        new MessagingSessionSLABatch().execute(null, new List<MessagingSession>{ scopeRecord });
        Test.stopTest();

        MessagingSession updatedSession = [SELECT NotifyN1__c FROM MessagingSession WHERE Id = :insertedSession.Id];
        System.assertEquals(true, updatedSession.NotifyN1__c, 'Direct owner notification should be preserved.');
    }

    private static Id resolveMessagingChannelId() {
        List<MessagingChannel> channels = [SELECT Id FROM MessagingChannel LIMIT 1];
        System.assert(!channels.isEmpty(), 'A MessagingChannel record is required for the batch tests.');
        return channels[0].Id;
    }

    private static MessagingEndUser createEndUser(Id messagingChannelId) {
        MessagingEndUser endUser = new MessagingEndUser(
            Name = 'Test End User',
            MessagingPlatformKey = 'test-' + String.valueOf(DateTime.now().getTime()),
            MessagingChannelId = messagingChannelId,
            MessageType = 'EmbeddedMessaging'
        );
        insert endUser;
        return endUser;
    }

    private static MessagingSession createSession(
        Id channelId,
        Id endUserId,
        Id ownerId,
        Id queueId
    ) {
        MessagingSession session = new MessagingSession(
            MessagingChannelId = channelId,
            Status = 'Waiting',
            MessagingEndUserId = endUserId,
            ConversationId = 'TEST-CONV-' + String.valueOf(DateTime.now().getTime()),
            OwnerId = ownerId,
            OwnerAssignmentDate__c = System.now().addMinutes(-120),
            MinuteSLAN1__c = 1,
            NotifyN1__c = false
        );

        if (queueId != null) {
            session.QueueN1__c = queueId;
        }

        insert session;
        return session;
    }

    private static Group createQueueWithMember(Id userId) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        Group queue = new Group(
            Name = 'Fila SLA N1 ' + uniqueSuffix,
            DeveloperName = 'Fila_SLA_N1_' + uniqueSuffix,
            Type = 'Queue'
        );
        insert queue;

        insert new QueueSobject(
            QueueId = queue.Id,
            SobjectType = 'MessagingSession'
        );

        insert new GroupMember(
            GroupId = queue.Id,
            UserOrGroupId = userId
        );

        return queue;
    }
}
