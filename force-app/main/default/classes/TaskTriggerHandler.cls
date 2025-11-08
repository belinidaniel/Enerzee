public class TaskTriggerHandler extends TriggerHandler {
    
    public TaskTriggerHandler(){
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

    public override void afterInsert(){}

    public override void beforeUpdate(){
        //TaskBO.reassignTaskOwner((List<Task>) Trigger.new);
    }

    public override void afterUpdate(){
        TaskBO.createWorkOrderContractingIntegrator((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
        TaskBO.createWorkOrderRequestMaterialBuy((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
        TaskBO.notifyAfterTaskConclusion((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
        TaskBO.updateProjectPhase((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
        TaskBO.checkTaskCloser((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
        TaskBO.updateViabilityStatusOnTaskCompletion((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}
