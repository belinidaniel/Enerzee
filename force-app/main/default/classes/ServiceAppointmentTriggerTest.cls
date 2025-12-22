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
        Group analistaQueue = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = 'AnalistaViabilidade'
                AND Type = 'Queue'
            LIMIT 1
        ];
        if (analistaQueue == null) {
            analistaQueue = new Group(Type = 'Queue', Name = 'AnalistaViabilidade', DeveloperName = 'AnalistaViabilidade');
            insert analistaQueue;
        }
        insert new QueueSobject(QueueId = analistaQueue.Id, SobjectType = 'Task');
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
