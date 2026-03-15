/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MessagingSessionSLABatchTest {
  private static final Id TEST_CONVERSATION_ID = '0dwU50000034lLBIAY';

  @IsTest
  static void shouldNotifyQueueDefinedInQueueN1Field() {
    if (!hasMessagingSessionField('QueueN1__c')) {
      return;
    }

    Id channelId = resolveMessagingChannelId();
    MessagingEndUser endUser = createEndUser(channelId);
    Group queue = createQueueWithMember(UserInfo.getUserId());

    MessagingSession insertedSession = createSession(
      channelId,
      endUser.Id,
      queue.Id,
      resolveQueueN1PicklistValue()
    );
    if (insertedSession == null) {
      return;
    }

    MessagingSession scopeRecord = loadSessionForBatch(insertedSession.Id);

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(null, new List<MessagingSession>{ scopeRecord });
    Test.stopTest();

    MessagingSession updatedSession = [
      SELECT NotifyN1__c
      FROM MessagingSession
      WHERE Id = :insertedSession.Id
    ];
    System.assertEquals(
      shouldMarkStage1AsNotified(),
      updatedSession.NotifyN1__c,
      'Queue-owner notification depends on business hours and CustomNotificationType "Padrao".'
    );
  }

  @IsTest
  static void shouldFallbackToOwnerWhenQueueFieldIsBlank() {
    Id channelId = resolveMessagingChannelId();
    MessagingEndUser endUser = createEndUser(channelId);

    MessagingSession insertedSession = createSession(
      channelId,
      endUser.Id,
      UserInfo.getUserId(),
      null
    );
    if (insertedSession == null) {
      return;
    }

    MessagingSession scopeRecord = loadSessionForBatch(insertedSession.Id);

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(null, new List<MessagingSession>{ scopeRecord });
    Test.stopTest();

    MessagingSession updatedSession = [
      SELECT NotifyN1__c
      FROM MessagingSession
      WHERE Id = :insertedSession.Id
    ];
    System.assertEquals(
      shouldMarkStage1AsNotified(),
      updatedSession.NotifyN1__c,
      'Direct owner notification depends on business hours and CustomNotificationType "Padrao".'
    );
  }

  @IsTest
  static void shouldCoverNoOpBranchesAndSchedulerHelpers() {
    MessagingSessionSLABatch batchInstance = new MessagingSessionSLABatch();

    Test.startTest();
    Database.QueryLocator locator = batchInstance.start(null);
    batchInstance.execute(null, new List<MessagingSession>());
    batchInstance.finish(null);
    new MessagingSessionSLAScheduler().scheduleNowExecution();
    new MessagingSessionSLAScheduler().execute(null);
    Test.stopTest();

    System.assertNotEquals(
      null,
      locator,
      'O batch deve sempre retornar um query locator.'
    );

    MessagingSessionSLABatch.setBusinessHoursId(null);
    System.assertEquals(
      false,
      MessagingSessionSLABatch.isWithinBusinessHours(null),
      'Momento nulo deve retornar false.'
    );
  }

  private static Id resolveMessagingChannelId() {
    List<MessagingChannel> channels = [SELECT Id FROM MessagingChannel LIMIT 1];
    System.assert(
      !channels.isEmpty(),
      'A MessagingChannel record is required for the batch tests.'
    );
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
    String queueN1Value
  ) {
    MessagingSession session = new MessagingSession(
      MessagingChannelId = channelId,
      Status = 'Waiting',
      MessagingEndUserId = endUserId,
      ConversationId = TEST_CONVERSATION_ID,
      OwnerId = ownerId,
      OwnerAssignmentDate__c = System.now().addMinutes(-120),
      MinuteSLAN1__c = 1,
      NotifyN1__c = false
    );

    if (String.isNotBlank(queueN1Value)) {
      session.put('QueueN1__c', queueN1Value);
    }

    try {
      insert session;
      return session;
    } catch (DmlException ex) {
      if (
        ex.getMessage() != null && ex.getMessage().contains('MessagingDisabled')
      ) {
        return null;
      }
      throw ex;
    }
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

    insert new GroupMember(GroupId = queue.Id, UserOrGroupId = userId);

    return queue;
  }

  private static MessagingSession loadSessionForBatch(Id sessionId) {
    String soql =
      'SELECT Id, Name, OwnerId, OwnerAssignmentDate__c, MinuteSLAN1__c, ' +
      'MinuteSLAN2__c, MinuteSLAN3__c, NotifyN1__c, NotifyN2__c, NotifyN3__c, ' +
      'QueueSupervisorRole__c, QueueCoordinatorRole__c';
    if (hasMessagingSessionField('QueueN1__c')) {
      soql += ', QueueN1__c';
    }
    soql += ' FROM MessagingSession WHERE Id = :sessionId';
    return Database.query(soql);
  }

  private static Boolean hasMessagingSessionField(String fieldApiName) {
    return Schema.SObjectType.MessagingSession.fields.getMap()
      .containsKey(fieldApiName);
  }

  private static String resolveQueueN1PicklistValue() {
    if (!hasMessagingSessionField('QueueN1__c')) {
      return null;
    }
    List<Schema.PicklistEntry> values = Schema.SObjectType.MessagingSession.fields
      .getMap()
      .get('QueueN1__c')
      .getDescribe()
      .getPicklistValues();
    return values.isEmpty() ? null : values[0].getValue();
  }

  private static Boolean hasConfiguredNotificationType() {
    return [
        SELECT COUNT()
        FROM CustomNotificationType
        WHERE
          DeveloperName = :MessagingSessionSLABatch.NOTIFICATION_TYPE_DEVELOPER_NAME
      ] > 0;
  }

  private static Boolean shouldMarkStage1AsNotified() {
    return hasConfiguredNotificationType() &&
      MessagingSessionSLABatch.isWithinBusinessHours(System.now());
  }
}
