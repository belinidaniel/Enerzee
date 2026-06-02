/**
 * @description       : Handler do HelpDeskMessageTrigger. Aciona a ponte HelpDeskMessage__c -> CaseComment.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : HelpDeskMessageBOTest
 **/
public class HelpDeskMessageTriggerHandler extends TriggerHandler {
  public HelpDeskMessageTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static Boolean enabled = true;
  public static Boolean isTriggerEnabled() {
    return enabled;
  }
  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
  }
  public override void afterInsert() {
    HelpDeskMessageBO.mirrorToCaseComments(
      (List<HelpDeskMessage__c>) newRecordList
    );
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
