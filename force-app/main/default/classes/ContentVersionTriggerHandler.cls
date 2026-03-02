public class ContentVersionTriggerHandler extends TriggerHandler {
  public ContentVersionTriggerHandler() {
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
    ContentVersionBO.fillIsProposal((List<ContentVersion>) newRecordList);
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
