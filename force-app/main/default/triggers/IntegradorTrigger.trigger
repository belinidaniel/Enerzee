trigger IntegradorTrigger on Integradores__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (IntegradorTriggerHandler.isTriggerEnabled()){
        new IntegradorTriggerHandler().execute();
    }
}