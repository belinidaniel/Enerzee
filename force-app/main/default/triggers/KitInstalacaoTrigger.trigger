trigger KitInstalacaoTrigger on Kit_Instalacao__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (KitInstalacaoTriggerHandler.isTriggerEnabled()){
        new KitInstalacaoTriggerHandler().execute();
    }
}