global without sharing class TaskDeadlineNotificationScheduler implements Schedulable {

    private static final String JOB_NAME = 'Task Deadline Notification';
    private static final String CRON_FORMAT = '{0} {1} {2} {3} {4} {5}';

    global void execute(SchedulableContext sc){ run(sc); }

    @TestVisible
    private void run(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
            Database.executeBatch(new TaskDeadlineNotificationBatch(), 200);
        }
        scheduleNextExecution();
        if (sc != null) {
            System.abortJob(sc.getTriggerId());
        }
    }

    private void scheduleNextExecution() {
        Integer intervalMinutes = 5;
        DateTime nextExecution = DateTime.now().addMinutes(intervalMinutes);
        List<String> args = new List<String>{
            '0',
            String.valueOf(nextExecution.minute()),
            String.valueOf(nextExecution.hour()),
            String.valueOf(nextExecution.day()),
            String.valueOf(nextExecution.month()),
            '?'
        };
        String jobName = JOB_NAME + ' - ' + nextExecution.format('yyyy-MM-dd HH:mm');
        String expression = String.format(CRON_FORMAT, args);

        if (!Test.isRunningTest()) {
            System.schedule(jobName, expression, this);
        }
    }

    public void scheduleNowExecution() {
        DateTime nextExecution = DateTime.now().addMinutes(1);
        List<String> args = new List<String>{
            '0',
            String.valueOf(nextExecution.minute()),
            String.valueOf(nextExecution.hour()),
            String.valueOf(nextExecution.day()),
            String.valueOf(nextExecution.month()),
            '?'
        };
        String jobName = JOB_NAME + ' - ' + nextExecution.format('yyyy-MM-dd HH:mm');
        String expression = String.format(CRON_FORMAT, args);

        if (!Test.isRunningTest()) {
            System.schedule(jobName, expression, this);
        }
    }
}