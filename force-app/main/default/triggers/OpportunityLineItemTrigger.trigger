trigger OpportunityLineItemTrigger on OpportunityLineItem (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (OpportunityLineItemTriggerHandler.isTriggerEnabled()){
        new OpportunityLineItemTriggerHandler().execute();
    }
}