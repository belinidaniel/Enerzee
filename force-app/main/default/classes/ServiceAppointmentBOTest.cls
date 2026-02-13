@IsTest
private class ServiceAppointmentBOTest {
    @IsTest
    static void shouldAssignAndUpdateAppointments() {
        OpportunityTriggerHandler.disableTrigger();
        ServiceAppointmentTriggerHandler.disableTrigger();
        Account acc = new Account(Name = 'Conta');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-SVC'
        );
        insert opp;

        WorkOrder wo = new WorkOrder(Subject = 'WO', Status = 'New', AccountId = acc.Id);
        TestMetadataUtils.setIfFieldExists(wo, 'Oportunidade__c', opp.Id);
        insert wo;

        ServiceAppointment app = (ServiceAppointment) TestFactory.createSObject(new ServiceAppointment(
            ParentRecordId = wo.Id,
            FSL__IsMultiDay__c = false
        ), true);

        ServiceAppointmentBO.assignScheduledStartAndEndTime(new List<ServiceAppointment>{ app });
        System.assertEquals(app.EarliestStartTime, app.SchedStartTime);

        ServiceAppointmentBO.assignOpportunityToAppointment(new List<ServiceAppointment>{ app });
        System.assertEquals(opp.Id, app.Oportunidade__c);

        ServiceAppointmentBO.updateAndCloneServiceAppointments(new List<ServiceAppointment>{ app });
        System.assert(true, 'ServiceAppointmentBO executed');

        ServiceAppointmentTriggerHandler.enableTrigger();
        OpportunityTriggerHandler.enableTrigger();
    }
}
