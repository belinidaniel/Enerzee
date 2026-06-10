trigger HelpDeskMessageTrigger on HelpDeskMessage__c(after insert) {
  if (HelpDeskMessageTriggerHandler.isTriggerEnabled()) {
    new HelpDeskMessageTriggerHandler().execute();
  }
}
