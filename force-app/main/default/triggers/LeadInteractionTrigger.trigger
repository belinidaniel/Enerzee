trigger LeadInteractionTrigger on LeadInteraction__c(
  before insert,
  after insert,
  before update,
  after update,
  before delete,
  after delete
) {
  if (LeadInteractionTriggerHandler.isTriggerEnabled()) {
    new LeadInteractionTriggerHandler().execute();
  }
}
