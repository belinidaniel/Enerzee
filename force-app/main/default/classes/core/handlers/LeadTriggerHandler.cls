public class LeadTriggerHandler extends TriggerHandler {
    
    public LeadTriggerHandler(){
        super(
            Trigger.operationType,
            Trigger.new, 
            Trigger.old,
            Trigger.newMap, 
            Trigger.oldMap
        );
    }
    
    public static boolean enabled = true;
    public static boolean isTriggerEnabled(){
        return enabled;
    }
    
    public static void enableTrigger(){
        enabled = true;
    }

    public static void disableTrigger(){
        enabled = false;
    }
    
    public override void beforeInsert(){}

    public override void afterInsert(){
        LeadBO.createMessagingUser(newRecordList, new Map<Id, Lead>());
    }

    public override void beforeUpdate(){
        LeadBO.checkTasksConclusionBeforeStatusChange((List<Lead>) newRecordList, (Map<Id, Lead>) oldMap);
        LeadBO.LeadValidationHandler((List<Lead>) newRecordList);
        LeadBO.setRecordTypeAccount((List<Lead>) newRecordList);
        LeadBO.sendConsultorRecordToVirtualOffice((List<Lead>) newRecordList,(Map<Id, Lead>) oldMap);
    }

    public override void afterUpdate(){
        LeadBO.sendClientRecordToProposalGenerator((List<Lead>) newRecordList);
        LeadBO.createMessagingUser(newRecordList, (Map<Id, Lead>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}

}