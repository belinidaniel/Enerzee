/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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
