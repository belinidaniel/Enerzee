global with sharing class MessagingSessionSLAScheduler implements Schedulable {

    @TestVisible
    public static final String CRON_EVERY_FIVE_MINUTES = '0 0/5 * * * ?';

    @TestVisible
    public static final String JOB_NAME = 'Messaging Session SLA Batch';

    global void execute(SchedulableContext context) {
        Database.executeBatch(new MessagingSessionSLABatch(), 200);
    }

    @TestVisible
    public static String scheduleJob() {
        String cronExpression = CRON_EVERY_FIVE_MINUTES;
        if (Test.isRunningTest()) {
            cronExpression = '0 0 * * * ?';
        }
        return System.schedule(JOB_NAME, cronExpression, new MessagingSessionSLAScheduler());
    }
}
