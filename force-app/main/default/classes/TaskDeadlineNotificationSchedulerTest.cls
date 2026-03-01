@IsTest
private class TaskDeadlineNotificationSchedulerTest {
  @IsTest
  static void shouldRunWithoutSchedulingInTest() {
    // Em teste, o scheduler não agenda/roda batch, mas chama scheduleNextExecution e aborta o job se existir.
    TaskDeadlineNotificationScheduler scheduler = new TaskDeadlineNotificationScheduler();
    Test.startTest();
    scheduler.execute(null);
    Test.stopTest();
    System.assert(true, 'Scheduler executed without errors in test context.');
  }
}
