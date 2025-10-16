trigger AccountTrigger on Account (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (AccountTriggerHandler.isTriggerEnabled()){
        new AccountTriggerHandler().execute();
    }
}