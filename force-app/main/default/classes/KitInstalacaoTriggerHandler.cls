public class KitInstalacaoTriggerHandler extends TriggerHandler {
    public KitInstalacaoTriggerHandler(){
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
    

    public override void beforeInsert(){ 
        KitInstalacaoBO.populateKitFields((List<Kit_Instalacao__c>) newRecordList);
    }

    public override void afterInsert(){
        KitInstalacaoBO.sendKitRecordsToSAP((List<Kit_Instalacao__c>) newRecordList);
    }

    public override void beforeUpdate(){}

    public override void afterUpdate(){
        KitInstalacaoBO.sendKitRecordsToSAP((List<Kit_Instalacao__c>) newRecordList);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}