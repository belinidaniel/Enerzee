public class IntegradorTriggerHandler extends TriggerHandler {
  public IntegradorTriggerHandler() {
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
  }

  public override void afterInsert() {
    IntegradorBO.sendIntegradorToSAP((List<Integradores__c>) newRecordList);
    IntegradorBO.createMessagingUser(
      (List<Integradores__c>) newRecordList,
      new Map<Id, Integradores__c>()
    );
  }

  public override void beforeUpdate() {
  }

  public override void afterUpdate() {
    IntegradorBO.sendIntegradorToSAP((List<Integradores__c>) newRecordList);
    IntegradorBO.createMessagingUser(
      (List<Integradores__c>) newRecordList,
      (Map<Id, Integradores__c>) oldMap
    );
  }

  public override void beforeDelete() {
  }

  public override void afterDelete() {
  }
}
