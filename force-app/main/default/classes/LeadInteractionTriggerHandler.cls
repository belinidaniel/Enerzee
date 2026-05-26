/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-25-2026
 * @last modified by  : Daniel Belini
 * @test              : LeadInteractionLeadSyncServiceTest
 **/
/**
 * @description Trigger handler for LeadInteraction__c synchronization.
 * @test LeadInteractionLeadSyncServiceTest
 */
public class LeadInteractionTriggerHandler extends TriggerHandler {
  public LeadInteractionTriggerHandler() {
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

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
  }

  public override void afterInsert() {
    LeadInteractionLeadSyncService.syncToLeads(
      (List<LeadInteraction__c>) newRecordList,
      null
    );
  }

  public override void beforeUpdate() {
  }

  public override void afterUpdate() {
    LeadInteractionLeadSyncService.syncToLeads(
      (List<LeadInteraction__c>) newRecordList,
      (Map<Id, LeadInteraction__c>) oldMap
    );
  }

  public override void beforeDelete() {
  }

  public override void afterDelete() {
  }
}
