trigger LeadTrigger on Lead (before insert, after insert, before update, after update, before delete, after delete) {

    	if (LeadTriggerHandler.isTriggerEnabled()){
            new LeadTriggerHandler().execute();
        }
}