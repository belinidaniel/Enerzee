global without sharing class TaskSlaDailySummaryScheduler implements Schedulable {

    private static final String JOB_NAME = 'Task SLA Daily Summary';

    global void execute(SchedulableContext sc) {
        TaskSlaDailySummaryService.runDaily();
    }

    public static void scheduleDaily(String cronExpression) {
        if (String.isBlank(cronExpression)) {
            return;
        }
        abortExistingJobs();
        System.schedule(JOB_NAME, cronExpression, new TaskSlaDailySummaryScheduler());
    }

    @TestVisible
    private static void abortExistingJobs() {
        List<CronTrigger> existingJobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
                AND State != 'DELETED'
        ];

        for (CronTrigger job : existingJobs) {
            if (job == null || job.Id == null) {
                continue;
            }
            try {
                System.abortJob(job.Id);
            } catch (Exception ex) {
                // Se nao for possivel abortar (estado nao abortavel), segue para tentativa de reagendamento.
            }
        }
    }
}
