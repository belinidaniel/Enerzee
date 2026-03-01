public class CaseTriggerHandler extends TriggerHandler {
  public CaseTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static boolean enabled = true;
  public static boolean isTriggerEnabled() {
    return enabled;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
    CaseBO.AssignContactForCase((List<Case>) newRecordList);
  }

  public override void afterInsert() {
    CaseBO.CreateAttachments((List<Case>) newRecordList);
    CaseBO.assignCaseToMessagingSessions((List<Case>) newRecordList);
  }

  public override void beforeUpdate() {
    CaseBO.checkTasksConclusionBeforeStatusChange(
      (List<Case>) newRecordList,
      (Map<Id, Case>) oldMap
    );
    CaseBO.updateStatusWhenOwnerChange(
      (List<Case>) newRecordList,
      (Map<Id, Case>) oldMap
    );
  }

  public override void afterUpdate() {
    //CaseBO.CreateServiceResource((Map<Id,Case>)newMap,(Map<Id,Case>)oldMap);
    CaseBO.CreateConsultor((Map<Id, Case>) newMap, (Map<Id, Case>) oldMap);
    CaseBO.createTaskWhenOwnerChange(
      (List<Case>) newRecordList,
      (Map<Id, Case>) oldMap
    );
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
