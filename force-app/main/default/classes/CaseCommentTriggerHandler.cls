/**
 * @description       : Handler do CaseCommentTrigger. Aciona a ponte CaseComment -> HelpDeskMessage__c.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : CaseCommentBOTest
 **/
public class CaseCommentTriggerHandler extends TriggerHandler {
  public CaseCommentTriggerHandler() {
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
    CaseCommentBO.mirrorToHelpDeskMessages((List<CaseComment>) newRecordList);
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
