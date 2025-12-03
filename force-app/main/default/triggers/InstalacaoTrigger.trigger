trigger InstalacaoTrigger on Instalacao__c (after insert, after update) {
    
    if (InstalacaoTriggerHandler.isTriggerEnabled()){
        new InstalacaoTriggerHandler().execute();
    }
}
