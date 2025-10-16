trigger TaskTrigger on Task (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (TaskTriggerHandler.isTriggerEnabled()){
        new TaskTriggerHandler().execute();
    }
}