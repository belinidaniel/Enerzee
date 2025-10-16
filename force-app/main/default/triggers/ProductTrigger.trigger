trigger ProductTrigger on Product2 (before insert, after insert, before update, after update, before delete, after delete) {
    if (ProductTriggerHandler.isTriggerEnabled()){
        new ProductTriggerHandler().execute();
    }
}