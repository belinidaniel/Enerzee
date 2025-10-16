@isTest
public class AssignedResourceTriggerTest {
    @TestSetup
    static void makeData(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId                = account.id,
            MunicipioInstalacao__c   = 'São Paulo',
            Parceiro__c = parceiro.id
        ), true);

        OperatingHours operatingHours = (OperatingHours) TestFactory.createSObject(new OperatingHours(), true);
        
        SchedulingConstraint constraint = (SchedulingConstraint) TestFactory.createSObject(new SchedulingConstraint(), true);

        ServiceTerritory serviceTerritory = (ServiceTerritory) TestFactory.createSObject(new ServiceTerritory(
            OperatingHoursId       = operatingHours.Id,
            Name                   = 'São Paulo',
            SchedulingConstraintId = constraint.Id
        ), true);

        ServiceAppointment serviceAppointment = (ServiceAppointment) TestFactory.createSObject(new ServiceAppointment(
            ParentRecordId     = opportunity.Id,
            Oportunidade__c    = opportunity.Id,
            ServiceTerritoryId = serviceTerritory.Id
        ), true);
        

        ServiceResource serviceRes = (ServiceResource) TestFactory.createSObject(new ServiceResource(
            SchedulingConstraintId = constraint.Id
        ), true);

        ServiceTerritoryMember member = (ServiceTerritoryMember) TestFactory.createSOBject(new ServiceTerritoryMember(
            ServiceResourceId  = serviceRes.Id,
            ServiceTerritoryId = serviceTerritory.Id
        ), true);
    }
    
    @isTest
    static void assignServiceResourceToAppointmentVisitAssigneeTest(){
        ServiceAppointment serviceAppointment = [
            SELECT  Id
            FROM    ServiceAppointment
            LIMIT   1
        ];

        ServiceResource serviceRes = [
            SELECT  Id
            FROM    ServiceResource
            LIMIT   1
        ];
        
        Test.startTest();
        AssignedResource assignedRes = (AssignedResource) TestFactory.createSObject(new AssignedResource(
            ServiceResourceId    = serviceRes.Id,
            ServiceAppointmentId = serviceAppointment.Id
        ), true);
        Test.stopTest();

        serviceAppointment = [
            SELECT  Id, ResponsavelVisita__c
            FROM    ServiceAppointment
            LIMIT   1
        ];
        System.assertEquals(serviceRes.Id, serviceAppointment.ResponsavelVisita__c);
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        /*ServiceAppointment serviceAppointment = [
            SELECT  Id
            FROM    ServiceAppointment
            LIMIT   1
        ];

        ServiceResource serviceRes = [
            SELECT  Id
            FROM    ServiceResource
            LIMIT   1
        ];
        
        AssignedResource assignedRes = (AssignedResource) TestFactory.createSObject(new AssignedResource(
            ServiceResourceId    = serviceRes.Id,
            ServiceAppointmentId = serviceAppointment.Id
        ), true);
        delete assignedRes;*/

        AssignedResourceTriggerHandler.disableTrigger();

        System.assert(!AssignedResourceTriggerHandler.isTriggerEnabled());
        
        AssignedResourceTriggerHandler.enableTrigger();
        System.assert(AssignedResourceTriggerHandler.isTriggerEnabled());
    }
}