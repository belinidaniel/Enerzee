global with sharing class MessagingSessionSLAScheduler implements Schedulable {
  private static final String JOB_NAME = 'Messaging Session SLA Job';
  private static final String CRON_FORMAT = '{0} {1} {2} {3} {4} {5}';
  private static final Integer INTERVAL_MINUTES = 5;

  global void execute(SchedulableContext sc) {
    run(sc);
  }

  @TestVisible
  private void run(SchedulableContext sc) {
    if (MessagingSessionSLABatch.isWithinBusinessHours(System.now())) {
      Database.executeBatch(new MessagingSessionSLABatch(), 50);
    }

    scheduleNextExecution();

    if (sc != null) {
      System.abortJob(sc.getTriggerId());
    }
  }

  private void scheduleNextExecution() {
    DateTime nextExecution = DateTime.now().addMinutes(INTERVAL_MINUTES);
    scheduleAt(nextExecution);
  }

  public void scheduleNowExecution() {
    DateTime nextExecution = DateTime.now().addMinutes(1);
    scheduleAt(nextExecution);
  }

  private void scheduleAt(DateTime nextExecution) {
    List<String> args = new List<String>{
      '0',
      String.valueOf(nextExecution.minute()),
      String.valueOf(nextExecution.hour()),
      String.valueOf(nextExecution.day()),
      String.valueOf(nextExecution.month()),
      '?'
    };

    String jobName =
      JOB_NAME +
      ' - ' +
      nextExecution.format('yyyy-MM-dd HH:mm');
    String expression = String.format(CRON_FORMAT, args);

    if (!Test.isRunningTest()) {
      System.schedule(jobName, expression, this);
    }
  }
}
