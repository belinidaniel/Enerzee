public class ServiceAppointmentTriggerHandler extends TriggerHandler{
    public ServiceAppointmentTriggerHandler(){
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
        ServiceAppointmentBO.assignScheduledStartAndEndTime((List<ServiceAppointment>) newRecordList);
        ServiceAppointmentBO.assignOpportunityToAppointment((List<ServiceAppointment>) newRecordList);
    }

    public override void afterInsert(){
        ServiceAppointmentBO.updateRespectiveOpportunityFields((List<ServiceAppointment>) newRecordList, new Map<Id, ServiceAppointment>());
        ServiceAppointmentBO.assignVisitDateTimeOnOpportunity((List<ServiceAppointment>) newRecordList, new Map<Id, ServiceAppointment>());
        ServiceAppointmentBO.sendTechnicalVisitDate((Map<Id, ServiceAppointment>) newMap);
    }

    public override void beforeUpdate(){}
    public override void afterUpdate(){
        ServiceAppointmentBO.updateRespectiveOpportunityFields((List<ServiceAppointment>) newRecordList, (Map<Id, ServiceAppointment>) oldMap);
        ServiceAppointmentBO.assignVisitDateTimeOnOpportunity((List<ServiceAppointment>) newRecordList, (Map<Id, ServiceAppointment>) oldMap);
    }

    public override void beforeDelete(){}
    public override void afterDelete(){}
}