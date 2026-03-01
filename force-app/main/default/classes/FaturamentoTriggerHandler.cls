public class FaturamentoTriggerHandler extends TriggerHandler {
  public FaturamentoTriggerHandler() {
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

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
    FaturamentoBO.assignClientToIntegratedBilling(
      (List<Faturamento__c>) newRecordList
    );
    FaturamentoBO.assignOpportunityToIntegratedBilling(
      (List<Faturamento__c>) newRecordList
    );
  }

  public override void afterInsert() {
  }
  public override void beforeUpdate() {
  }
  public override void afterUpdate() {
  }
  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
