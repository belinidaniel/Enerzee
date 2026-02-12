global without sharing class TaskSlaDailySummaryScheduler implements Schedulable {

    private static final String JOB_NAME = 'Task SLA Daily Summary';

    global void execute(SchedulableContext sc) {
        TaskSlaDailySummaryService.runDaily();
    }

    public static void scheduleDaily(String cronExpression) {
        if (String.isBlank(cronExpression)) {
            return;
        }
        System.schedule(JOB_NAME, cronExpression, new TaskSlaDailySummaryScheduler());
    }
}