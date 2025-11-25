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
        // ServiceAppointment app = [
        //     SELECT  Id, EarliestStartTime, DueDate, SchedStartTime, SchedEndTime
        //     FROM    ServiceAppointment
        //     LIMIT   1
        // ];
        // Test.startTest();
        // System.assertEquals(app.SchedStartTime, app.EarliestStartTime);
        // System.assertEquals(app.SchedEndTime, app.DueDate);
        // Test.stopTest();
    }
    @isTest
    static void updateRespectiveOpportunityFieldsTest(){
        // ServiceAppointment app = [
        //     SELECT  Id, Equipe_Propria_ou_Terceira__c, DurationInMinutes
        //     FROM    ServiceAppointment
        //     LIMIT   1
        // ];
        // Opportunity opp = [
        //     SELECT  Id, Equipe_Propria_ou_Terceira__c, Duracao_estimada_da_visita_em_minutos__c
        //     FROM    Opportunity
        //     LIMIT   1
        // ];

        // Test.startTest();
        // System.assertEquals(app.Equipe_Propria_ou_Terceira__c, opp.Equipe_Propria_ou_Terceira__c);
        // System.assertEquals(app.DurationInMinutes, opp.Duracao_estimada_da_visita_em_minutos__c);

        // app.Equipe_Propria_ou_Terceira__c = 'Enerzee';
        // app.Duration                      = 5;
        // update app;
        // Test.stopTest();

        // opp = [
        //     SELECT  Id, Equipe_Propria_ou_Terceira__c, Duracao_estimada_da_visita_em_minutos__c
        //     FROM    Opportunity
        //     LIMIT   1
        // ];
        // System.assertEquals('Enerzee', opp.Equipe_Propria_ou_Terceira__c);
        // System.assertEquals(300, opp.Duracao_estimada_da_visita_em_minutos__c);
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        // ServiceAppointment app = [
        //     SELECT  ID
        //     FROM    ServiceAppointment
        //     LIMIT   1
        // ];

        // Test.startTest();
        // update app;
        
        // delete app;

        // ServiceAppointmentTriggerHandler.disableTrigger();
        // System.assert(!ServiceAppointmentTriggerHandler.isTriggerEnabled());

        // ServiceAppointmentTriggerHandler.enableTrigger();
        // System.assert(ServiceAppointmentTriggerHandler.isTriggerEnabled());
        // Test.stopTest();
    }
}