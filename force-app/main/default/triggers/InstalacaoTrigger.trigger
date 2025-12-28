/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-16-2025
 * @last modified by  : Daniel Belini
**/
trigger InstalacaoTrigger on Instalacao__c (after insert, after update, before update) {
    
    if (InstalacaoTriggerHandler.isTriggerEnabled()){
        new InstalacaoTriggerHandler().execute();
    }
}