trigger ProposalCoverTrigger on ProposalCover__c (before insert, before update) { 
    
    if (ProposalCoverTriggerHandler.isTriggerEnabled()){
        new ProposalCoverTriggerHandler().execute();
    }
}