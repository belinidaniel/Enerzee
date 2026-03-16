/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalCoverTriggerHandlerTest, ProposalCoverTriggerTest
 **/
public class ProposalCoverTriggerHandler extends TriggerHandler {
  public ProposalCoverTriggerHandler() {
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
    //ProposalCoverBO.updateDefaultStatus((List<ProposalCover__c>) newRecordList);
  }

  public override void afterInsert() {
  }

  public override void beforeUpdate() {
    //ProposalCoverBO.updateDefaultStatus((List<ProposalCover__c>) newRecordList);
  }

  public override void afterUpdate() {
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
