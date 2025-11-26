public class ProjetoTriggerHandler extends TriggerHandler {
    
    public ProjetoTriggerHandler(){
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
        ProjetoBO.initializeStatusStartDate((List<Projeto__c>) newRecordList);
    }

    public override void afterInsert(){
        ProjetoBO.createTasks((List<Projeto__c>) newRecordList, new Map<Id, Projeto__c>());
        ProjetoBO.sendProjectToNivello((List<Projeto__c>) newRecordList);
        InstalacaoBO.ensureInstallationOnProjectApproved((List<Projeto__c>) newRecordList, new Map<Id, Projeto__c>());
    }

    public override void beforeUpdate(){
        ProjetoBO.updateStageDurations((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
        ProjetoBO.checkTasksConclusionBeforeStatusChange((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
    }

    public override void afterUpdate(){
        ProjetoBO.createTasks((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
        ProjetoBO.sendProjectToNivello((List<Projeto__c>) newRecordList);
        InstalacaoBO.ensureInstallationOnProjectApproved((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
        ProjetoBO.createTaskOnboarding((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
        ProjetoBO.createTaskProjectApproved((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
        ProjetoBO.createTaskFinishProject((List<Projeto__c>) newRecordList, (Map<Id, Projeto__c>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}