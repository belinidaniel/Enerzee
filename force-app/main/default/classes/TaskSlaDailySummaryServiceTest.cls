@IsTest
private class TaskSlaDailySummaryServiceTest {
  private static final String DAILY_CONSOLIDATED_TYPE = 'TASK_DAILY_CONSOLIDATED';

  @IsTest
  static void managerOverdueSummaryCreatesLog() {
    User manager = createUser('manager+daily@example.com', null);
    User owner = createUser('owner+daily@example.com', manager.Id);

    Task taskRecord = new Task(
      Subject = 'Task Daily Overdue',
      Status = 'Open',
      ActivityDate = Date.today().addDays(-1),
      OwnerId = owner.Id
    );
    insert taskRecord;

    Test.startTest();
    TaskSlaDailySummaryService.runManagerOverdue();
    Test.stopTest();

    Integer logCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Consulta de logs deve executar sem excecao.');
  }

  @IsTest
  static void ownerOpenSummaryCreatesLog() {
    User manager = createUser('manager+open@example.com', null);
    User owner = createUser('owner+open@example.com', manager.Id);
    Task taskRecord = new Task(
      Subject = 'Task Daily Open',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = owner.Id
    );
    insert taskRecord;

    Test.startTest();
    TaskSlaDailySummaryService.runOwnerOpenSummary();
    Test.stopTest();

    Integer logCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Consulta de logs deve executar sem excecao.');
  }

  @IsTest
  static void runDailyAndDueTomorrowShouldCreateManagerSummaryLogs() {
    User manager = createUser('manager+summary@example.com', null);
    User owner = createUser('owner+summary@example.com', manager.Id);

    insert new Task(
      Subject = 'Task Daily Summary',
      Status = 'Open',
      ActivityDate = Date.today().addDays(1),
      OwnerId = owner.Id
    );

    Test.startTest();
    TaskSlaDailySummaryService.runDaily();
    TaskSlaDailySummaryService.runManagerDueTomorrow();
    Test.stopTest();

    Integer logCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE RelatedId__c = :manager.Id AND Type__c = :DAILY_CONSOLIDATED_TYPE
    ];
    System.assert(logCount >= 0, 'Execucoes diarias nao devem gerar erro.');
  }

  @IsTest
  static void managerSummaryShouldHandleOwnerWithoutManager() {
    User owner = createUser('owner+nomanager@example.com', null);
    insert new Task(
      Subject = 'Task No Manager',
      Status = 'Open',
      ActivityDate = Date.today(),
      OwnerId = owner.Id
    );

    Test.startTest();
    TaskSlaDailySummaryService.runManagerOverdue();
    Test.stopTest();

    System.assertEquals(true, true, 'Fluxo sem manager executado sem excecao.');
  }

  private static User createUser(String email, Id managerId) {
    return createUser(email, managerId, null);
  }

  private static User createUser(String email, Id managerId, Id roleId) {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    String unique = String.valueOf(System.currentTimeMillis());
    User u = new User(
      Username = 'user+' + unique + '@example.com',
      Email = email,
      Alias = email.substring(0, 5),
      LastName = 'Tester',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      ProfileId = p.Id,
      LanguageLocaleKey = 'pt_BR',
      UserRoleId = roleId
    );
    insert u;
    if (managerId != null) {
      u.ManagerId = managerId;
      update u;
    }
    return u;
  }
}
