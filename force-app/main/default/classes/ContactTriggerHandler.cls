public class ContactTriggerHandler extends TriggerHandler {
    
    public ContactTriggerHandler(){
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
        ContactBO.createMessagingUser(newRecordList, new Map<Id, Contact>());
    }

    public override void beforeUpdate(){}

    public override void afterUpdate(){
        ContactBO.createMessagingUser(newRecordList, (Map<Id, Contact>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}

}