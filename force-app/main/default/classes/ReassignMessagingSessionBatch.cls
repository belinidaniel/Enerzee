global with sharing class ReassignMessagingSessionBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  global Database.QueryLocator start(Database.BatchableContext BC) {
    String status = 'Waiting';
    return Database.getQueryLocator(
      'SELECT Id, OwnerId FROM MessagingSession WHERE Status = :status'
    );
  }

  global void execute(SchedulableContext sc) {
    Database.executeBatch(new ReassignMessagingSessionBatch());
  }

  global void execute(
    Database.BatchableContext BC,
    List<MessagingSession> scope
  ) {
    for (MessagingSession session : scope) {
      Map<String, Object> flowParams = new Map<String, Object>();
      flowParams.put('recordId', session.Id);
      flowParams.put('ownerId', session.OwnerId);

      // Inicia o fluxo
      Flow.Interview.Reatribuir_Messaging_Session flow = new Flow.Interview.Reatribuir_Messaging_Session(
        flowParams
      );
      flow.start();
    }
  }

  global void finish(Database.BatchableContext BC) {
    // Reagenda o job
    System.debug('Reagendando o batch...');
    ReassignMessagingSessionBatch job = new ReassignMessagingSessionBatch();
    Datetime nextRun = Datetime.now().addMinutes(5);
    String cronExp = nextRun.format('s m H d M \'?\' yyyy');
    if (!Test.isRunningTest())
      System.schedule(
        'ReassignMessagingSessionBatch - ' + nextRun,
        cronExp,
        job
      );
  }
}
