/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : TaskSlaCoreTest
 **/
global without sharing class TaskSlaDailySummaryScheduler implements Schedulable {
  private static final String JOB_NAME = 'Task SLA Daily Summary';

  global void execute(SchedulableContext sc) {
    TaskSlaDailySummaryService.runDaily();
  }

  public static void scheduleDaily(String cronExpression) {
    if (String.isBlank(cronExpression)) {
      return;
    }
    for (CronTrigger existing : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name = :JOB_NAME AND State != 'DELETED'
    ]) {
      try {
        System.abortJob(existing.Id);
      } catch (Exception e) {
        // Ignore jobs that cannot be aborted and continue scheduling.
      }
    }
    System.schedule(
      JOB_NAME,
      cronExpression,
      new TaskSlaDailySummaryScheduler()
    );
  }
}
