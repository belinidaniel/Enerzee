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

    MessagingSessionSLABatch.businessHoursOverride = true;
    MessagingSessionSLABatch.notificationTypeIdOverride = UserInfo.getUserId();
    MessagingSessionSLABatch.skipUpdateForTest = true;
    Group queue = createQueueWithMember(UserInfo.getUserId());

    MessagingSession scopeRecord = buildSessionStub(
      queue.Id,
      System.now().addMinutes(-120),
      1,
      null,
      null
    );
    String queueN1Value = resolveQueueN1PicklistValue();
    if (String.isNotBlank(queueN1Value)) {
      scopeRecord.put('QueueN1__c', queueN1Value);
    }

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(null, new List<MessagingSession>{ scopeRecord });
    Test.stopTest();

    System.assertEquals(
      true,
      scopeRecord.NotifyN1__c,
      'Queue-owner notification depends on business hours and CustomNotificationType "Padrao".'
    );
  }

  @IsTest
  static void shouldFallbackToOwnerWhenQueueFieldIsBlank() {
    MessagingSessionSLABatch.businessHoursOverride = true;
    MessagingSessionSLABatch.notificationTypeIdOverride = UserInfo.getUserId();
    MessagingSessionSLABatch.skipUpdateForTest = true;

    MessagingSession scopeRecord = buildSessionStub(
      UserInfo.getUserId(),
      System.now().addMinutes(-120),
      1,
      null,
      null
    );

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(null, new List<MessagingSession>{ scopeRecord });
    Test.stopTest();

    System.assertEquals(
      true,
      scopeRecord.NotifyN1__c,
      'Direct owner notification depends on business hours and CustomNotificationType "Padrao".'
    );
  }

  @IsTest
  static void shouldCoverNoOpBranchesAndSchedulerHelpers() {
    MessagingSessionSLABatch.businessHoursOverride = false;
    MessagingSessionSLABatch.notificationTypeIdOverride = null;
    MessagingSessionSLABatch.skipUpdateForTest = true;
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

  @IsTest
  static void shouldCoverRoleBasedAndFutureSessionBranches() {
    MessagingSessionSLABatch.businessHoursOverride = true;
    MessagingSessionSLABatch.notificationTypeIdOverride = UserInfo.getUserId();
    MessagingSessionSLABatch.skipUpdateForTest = true;

    MessagingSession stage2Session = buildSessionStub(
      UserInfo.getUserId(),
      System.now().addMinutes(-120),
      null,
      1,
      null
    );
    stage2Session.QueueSupervisorRole__c = 'Papel Inexistente';

    MessagingSession futureSession = buildSessionStub(
      UserInfo.getUserId(),
      System.now().addMinutes(30),
      1,
      null,
      null
    );

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(
        null,
        new List<MessagingSession>{ stage2Session, futureSession }
      );
    Test.stopTest();

    System.assertEquals(
      false,
      stage2Session.NotifyN2__c,
      'Sem destinatarios para o papel, o N2 nao deve ser marcado.'
    );
    System.assertEquals(
      false,
      futureSession.NotifyN1__c,
      'Sessao no futuro deve ser ignorada.'
    );
  }

  @IsTest
  static void shouldNotifyRoleBasedStagesWhenMatchingUsersExist() {
    MessagingSessionSLABatch.businessHoursOverride = true;
    MessagingSessionSLABatch.notificationTypeIdOverride = UserInfo.getUserId();
    MessagingSessionSLABatch.skipUpdateForTest = true;

    List<User> usersWithRole = [
      SELECT Id, UserRole.Name
      FROM User
      WHERE IsActive = TRUE AND UserRole.Name != NULL
      LIMIT 1
    ];
    if (usersWithRole.isEmpty()) {
      return;
    }

    MessagingSession stage2Session = buildSessionStub(
      UserInfo.getUserId(),
      System.now().addMinutes(-120),
      null,
      1,
      null
    );
    stage2Session.QueueSupervisorRole__c = usersWithRole[0].UserRole.Name;

    MessagingSession stage3Session = buildSessionStub(
      UserInfo.getUserId(),
      System.now().addMinutes(-120),
      null,
      null,
      1
    );
    stage3Session.QueueCoordinatorRole__c = usersWithRole[0].UserRole.Name;

    Test.startTest();
    new MessagingSessionSLABatch()
      .execute(
        null,
        new List<MessagingSession>{ stage2Session, stage3Session }
      );
    Test.stopTest();

    System.assertEquals(
      true,
      stage2Session.NotifyN2__c,
      'Quando existir usuario ativo para o papel, o N2 deve ser marcado.'
    );
    System.assertEquals(
      true,
      stage3Session.NotifyN3__c,
      'Quando existir usuario ativo para o papel, o N3 deve ser marcado.'
    );
  }

  private static MessagingSession buildSessionStub(
    Id ownerId,
    Datetime ownerAssignmentDate,
    Decimal minuteSlaN1,
    Decimal minuteSlaN2,
    Decimal minuteSlaN3
  ) {
    String keyPrefix = MessagingSession.SObjectType.getDescribe()
      .getKeyPrefix();
    String uniqueChunk = String.valueOf(Math.abs(Crypto.getRandomInteger()))
      .leftPad(15, '0')
      .substring(0, 15);
    String fakeId = keyPrefix + uniqueChunk;
    return new MessagingSession(
      Id = fakeId,
      OwnerId = ownerId,
      OwnerAssignmentDate__c = ownerAssignmentDate,
      MinuteSLAN1__c = minuteSlaN1,
      MinuteSLAN2__c = minuteSlaN2,
      MinuteSLAN3__c = minuteSlaN3,
      NotifyN1__c = false,
      NotifyN2__c = false,
      NotifyN3__c = false
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
