public with sharing class AssignedResourceBO {
    public static void assignServiceResourceToAppointmentVisitAssignee(List<AssignedResource> newRecords){
        Map<Id, ServiceAppointment> contextAppointmentsMap = new Map<Id, ServiceAppointment>([
            SELECT  Id, ResponsavelVisita__c
            FROM    ServiceAppointment
            WHERE   Id IN :Collection.of(newRecords).pluckNotNullStrings(AssignedResource.ServiceAppointmentId)
        ]);

        List<ServiceAppointment> appointmentsToUpdate = new List<ServiceAppointment>();
        for(AssignedResource assignedResource : newRecords){
            ServiceAppointment app = contextAppointmentsMap.get(assignedResource.ServiceAppointmentId);
			app.ResponsavelVisita__c = assignedResource.ServiceResourceId;

            appointmentsToUpdate.add(app);
        }
        
        update appointmentsToUpdate;
    }
}