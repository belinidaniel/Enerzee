public with sharing class TaskStateService {
  public class TaskState {
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Boolean isClosed;
  }

  @AuraEnabled(cacheable=true)
  public static TaskState getState(Id taskId) {
    if (taskId == null) {
      throw new AuraHandledException('Task Id is required.');
    }

    Task t = [
      SELECT Status, IsClosed
      FROM Task
      WHERE Id = :taskId
      LIMIT 1
    ];

    TaskState state = new TaskState();
    state.status = t.Status;
    state.isClosed = t.IsClosed;
    return state;
  }
}
