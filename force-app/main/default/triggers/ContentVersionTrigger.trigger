trigger ContentVersionTrigger on ContentVersion (before insert) {

    if (ContentVersionTriggerHandler.isTriggerEnabled()){
        new ContentVersionTriggerHandler().execute();
    }

}