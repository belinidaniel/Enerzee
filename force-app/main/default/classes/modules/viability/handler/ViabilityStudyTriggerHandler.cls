/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-23-2025
 * @last modified by  : Daniel Belini
**/
public class ViabilityStudyTriggerHandler extends TriggerHandler {

    private static Boolean enabled = true;

    public ViabilityStudyTriggerHandler(){
        super(
            Trigger.operationType,
            Trigger.new,
            Trigger.old,
            Trigger.newMap,
            Trigger.oldMap
        );
    }

    public static Boolean isTriggerEnabled(){
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
        ViabilityStudyBO.createTasks(
            (List<ViabilityStudy__c>) newRecordList,
            new Map<Id, ViabilityStudy__c>()
        );
        ViabilityStudyBO.syncOpportunityInstalledPower(
            (List<ViabilityStudy__c>) newRecordList,
            new Map<Id, ViabilityStudy__c>()
        );
    }

    public override void beforeUpdate(){
        ViabilityStudyBO.checkTasksConclusionBeforeStatusChange(
            (List<ViabilityStudy__c>) newRecordList,
            (Map<Id, ViabilityStudy__c>) oldMap
        );
    }

    public override void afterUpdate(){
        ViabilityStudyBO.createTasks(
            (List<ViabilityStudy__c>) newRecordList,
            (Map<Id, ViabilityStudy__c>) oldMap
        );
        ViabilityStudyBO.syncOpportunityInstalledPower(
            (List<ViabilityStudy__c>) newRecordList,
            (Map<Id, ViabilityStudy__c>) oldMap
        );
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}