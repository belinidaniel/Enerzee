trigger ServiceAppointmentTrigger on ServiceAppointment (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (ServiceAppointmentTriggerHandler.isTriggerEnabled()){
        new ServiceAppointmentTriggerHandler().execute();
    }
}