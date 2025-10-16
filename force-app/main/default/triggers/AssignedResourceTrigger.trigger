trigger AssignedResourceTrigger on AssignedResource (before insert, after insert, before update, after update, before delete, after delete) {
    if (AssignedResourceTriggerHandler.isTriggerEnabled()){
        new AssignedResourceTriggerHandler().execute();
    }
}