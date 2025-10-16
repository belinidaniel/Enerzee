trigger FaturamentoTrigger on Faturamento__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (FaturamentoTriggerHandler.isTriggerEnabled()){
        new FaturamentoTriggerHandler().execute();
    }
}