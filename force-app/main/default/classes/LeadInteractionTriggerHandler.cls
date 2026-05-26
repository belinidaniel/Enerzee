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
    normalizeFullNames((List<LeadInteraction__c>) newRecordList);
  }

  public override void afterInsert() {
    LeadInteractionLeadSyncService.syncToLeads(
      (List<LeadInteraction__c>) newRecordList,
      null
    );
  }

  public override void beforeUpdate() {
    normalizeFullNames((List<LeadInteraction__c>) newRecordList);
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

  private static void normalizeFullNames(
    List<LeadInteraction__c> interactions
  ) {
    if (interactions == null || interactions.isEmpty()) {
      return;
    }

    for (LeadInteraction__c interaction : interactions) {
      if (
        interaction == null ||
        !String.isBlank(interaction.Nome__c) ||
        String.isBlank(interaction.Sobrenome__c)
      ) {
        continue;
      }

      String fullName = interaction.Sobrenome__c.trim().replaceAll('\\s+', ' ');
      Integer firstSeparatorIndex = fullName.indexOf(' ');
      if (firstSeparatorIndex <= 0) {
        interaction.Sobrenome__c = fullName;
        continue;
      }

      interaction.Nome__c = fullName.substring(0, firstSeparatorIndex);
      interaction.Sobrenome__c = fullName.substring(firstSeparatorIndex + 1);
    }
  }
}
