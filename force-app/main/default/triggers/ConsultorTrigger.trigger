trigger ConsultorTrigger on Consultor__c (before insert, before update, after insert, after update, before delete, after delete) {
    if (ConsultorTriggerHandler.isTriggerEnabled()){
        new ConsultorTriggerHandler().execute();
    }
}