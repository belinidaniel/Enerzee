public class ConsultorTriggerHandler extends TriggerHandler {
    
    public ConsultorTriggerHandler(){
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
        ConsultorBO.assignCPFCNPJToIdentificationNumber((List<Consultor__c>) newRecordList);
    }

    public override void afterInsert(){
        ConsultorBO.sendFornecedorRepresentanteRecordToSAP((List<Consultor__c>) newRecordList);
        ConsultorBO.createMessagingUser((List<Consultor__c>) newRecordList, new Map<Id, Consultor__c>());
    }

    public override void beforeUpdate(){}

    public override void afterUpdate(){
        ConsultorBO.sendFornecedorRepresentanteRecordToSAP((List<Consultor__c>) newRecordList);
        ConsultorBO.createMessagingUser((List<Consultor__c>) newRecordList, (Map<Id, Consultor__c>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}