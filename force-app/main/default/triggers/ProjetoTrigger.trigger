trigger ProjetoTrigger on Projeto__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (ProjetoTriggerHandler.isTriggerEnabled()){
        new ProjetoTriggerHandler().execute();
    }
}