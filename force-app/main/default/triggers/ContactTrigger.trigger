trigger ContactTrigger on Contact (before insert, after insert, before update, after update, before delete, after delete) {
    if (ContactTriggerHandler.isTriggerEnabled()){
        new ContactTriggerHandler().execute();
    }
}