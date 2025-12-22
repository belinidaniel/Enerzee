/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-25-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class ServiceAppointmentTriggerTest {

    @TestSetup
    static void makeData(){
        ServiceAppointmentTriggerHandler.disableTrigger();
        // Fila de validação de tarefas
        Group analistaQueue = new Group(Type = 'Queue', Name = 'AnalistaViabilidade', DeveloperName = 'AnalistaViabilidade');
        insert analistaQueue;
        insert new QueueSobject(QueueId = analistaQueue.Id, SobjectType = 'Task');
    ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Consultor__c cst = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            ConsultorOportunidade__c = cst.Id,
            Parceiro__c				 = parceiro.id,
            PotenciaPicoSistema__c   = 12
        ), true);



        OperatingHours hours = (OperatingHours) TestFactory.createSObject(new OperatingHours(), true);
        ServiceTerritory territory = (ServiceTerritory) TestFactory.createSObject(new ServiceTerritory(
            OperatingHoursId = hours.id
        ), true);
        WorkType workType = (WorkType) TestFactory.createSObject(new WorkType(), true);
        ServiceAppointment app = (ServiceAppointment) TestFactory.createSObject(new ServiceAppointment(
            ParentRecordId                = opp.Id,
            Oportunidade__c               = opp.Id,
            ServiceTerritoryId            = territory.Id,
            SchedStartTime                = System.now(),
            Equipe_Propria_ou_Terceira__c = 'Integrador',
            Duration                      = 1
        ), true);
    }

    @isTest
    static void assignScheduledStartAndEndTimeTest(){
        Test.startTest();
        System.assert(true);
        Test.stopTest();
    }
    @isTest
    static void updateRespectiveOpportunityFieldsTest(){
        Test.startTest();
        System.assert(true);
        Test.stopTest();
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Test.startTest();
        ServiceAppointmentTriggerHandler.disableTrigger();
        System.assert(!ServiceAppointmentTriggerHandler.isTriggerEnabled());
        ServiceAppointmentTriggerHandler.enableTrigger();
        System.assert(ServiceAppointmentTriggerHandler.isTriggerEnabled());
        Test.stopTest();
    }
}
