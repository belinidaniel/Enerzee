trigger ViabilityStudyTrigger on ViabilityStudy__c (before insert, after insert, before update, after update, before delete, after delete) {
    if(ViabilityStudyTriggerHandler.isTriggerEnabled()){
        new ViabilityStudyTriggerHandler().execute();
    }
}