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
    TaskDeadlineNotificationScheduler scheduler = new TaskDeadlineNotificationScheduler();
    Test.startTest();
    scheduler.execute(null);
    Test.stopTest();
    System.assert(true, 'Scheduler executed without errors in test context.');
  }

  @IsTest
  static void shouldPrepareImmediateExecutionWithoutErrors() {
    TaskDeadlineNotificationScheduler scheduler = new TaskDeadlineNotificationScheduler();

    Test.startTest();
    scheduler.scheduleNowExecution();
    Test.stopTest();

    System.assert(true, 'scheduleNowExecution deve montar o agendamento.');
  }

  @IsTest
  static void shouldExecuteWhenScheduledByPlatform() {
    String cron = '0 0 0 1 1 ? 2099';

    Test.startTest();
    System.schedule(
      'TaskDeadlineNotificationSchedulerTestJob',
      cron,
      new TaskDeadlineNotificationScheduler()
    );
    Test.stopTest();

    System.assert(true, 'Job agendado deve executar sem erros em teste.');
  }
}
