public class OpportunityLineItemTriggerHandler extends TriggerHandler {
    
    public OpportunityLineItemTriggerHandler(){
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
        OpportunityLineItemBO.GenerateOppLineItemKit((List<OpportunityLineItem>) newRecordList);
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>();

        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) newRecordList) {
            opportunityIds.add(opportunityLineItem.OpportunityId);
        }

        if (!opportunityIds.isEmpty()) {
            opportunityMap = new Map<Id, Opportunity>([SELECT Id, StageName, RecordType.Name FROM Opportunity WHERE Id IN :opportunityIds]);
        }
        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) newRecordList) {
            Opportunity opp = opportunityMap.get(opportunityLineItem.OpportunityId);
            if (!OpportunityLineItemBO.shouldAllowOperation(opportunityLineItem,opp)) {
                opportunityLineItem.addError('Não é permitido incluir produtos nessa fase.');
            }
        }
    }
		
    public override void afterInsert(){
        OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate((List<OpportunityLineItem>) newRecordList);
        //OpportunityLineItemBO.GenerateOppLineItemKit((List<OpportunityLineItem>) newRecordList);
    }
    
    public override void beforeUpdate(){
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>();

        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) newRecordList) {
            opportunityIds.add(opportunityLineItem.OpportunityId);
        }

        if (!opportunityIds.isEmpty()) {
            opportunityMap = new Map<Id, Opportunity>([SELECT Id, StageName, RecordType.Name FROM Opportunity WHERE Id IN :opportunityIds]);
        }

        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) newRecordList) {
            Opportunity opp = opportunityMap.get(opportunityLineItem.OpportunityId);
            if (!OpportunityLineItemBO.shouldAllowOperation(opportunityLineItem,opp)) {
                opportunityLineItem.addError('Não é permitido alterar produtos nessa fase.');
            }
        }
    }
    
    public override void afterUpdate(){
        OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate((List<OpportunityLineItem>) newRecordList);
        //OpportunityLineItemBO.GenerateOppLineItemKit((List<OpportunityLineItem>) newRecordList);
    }

    public override void beforeDelete(){
        //OpportunityLineItemBO.shouldAllowOperation((List<OpportunityLineItem>) newRecordList);
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>();

        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) oldRecordList) {
            opportunityIds.add(opportunityLineItem.OpportunityId);
        }

        if (!opportunityIds.isEmpty()) {
            opportunityMap = new Map<Id, Opportunity>([SELECT Id, StageName, RecordType.Name FROM Opportunity WHERE Id IN :opportunityIds]);
        }

        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>) oldRecordList) {
            Opportunity opp = opportunityMap.get(opportunityLineItem.OpportunityId);
            if (!OpportunityLineItemBO.shouldAllowOperation(opportunityLineItem,opp)) {
                opportunityLineItem.addError('Não é permitido excluir produtos nessa fase.');
            }
        }
    }
    public override void afterDelete(){
        OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate((List<OpportunityLineItem>) oldRecordList);
    }
}