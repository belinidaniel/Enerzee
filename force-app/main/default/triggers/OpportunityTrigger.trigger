trigger OpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (OpportunityTriggerHandler.isTriggerEnabled()){
        new OpportunityTriggerHandler().execute();
    }
}