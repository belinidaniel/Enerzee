/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class TaskTriggerTest{

    @TestSetup
    static void makeData(){
        TaskTriggerHandler.disableTrigger();

        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);

        Account account = (Account) TestFactory.createSObject(new Account(), true);

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId                = account.id,
            ConsultorOportunidade__c = consultor.Id,
            MunicipioInstalacao__c   = 'São Paulo',
            IdVirtualOffice__c       = '00000000-0000-0000-0000-000000000001'
        ), true);

        Instalacao__c instalation = (Instalacao__c) TestFactory.createSObject(new Instalacao__c(
            ClienteConta__c          = account.Id,
            ConsultorInstalacao__c   = consultor.Id,
            OportunidadeConcluida__c = opportunity.Id
        ), true);

        opportunity.Instalacao__c = instalation.Id;
        update opportunity;

        Projeto__c project = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Oportunidade__c = opportunity.Id,
            Conta__c        = account.Id,
            Consultor__c    = consultor.Id,
            Instalacao__c   = instalation.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByName().get('UFV Mini até 300').getRecordTypeId()
        ), true);

        Task task = (Task) TestFactory.createSObject(new Task(
            WhatId = project.Id
        ), true);

        WorkType workType = (WorkType) TestFactory.createSObject(new WorkType(
            Name = 'Instalação UFV Mini até 300'
        ), true);

        OperatingHours operatingHours = (OperatingHours) TestFactory.createSObject(new OperatingHours(), true);

        ServiceTerritory serviceTerritory = (ServiceTerritory) TestFactory.createSObject(new ServiceTerritory(
            OperatingHoursId = operatingHours.Id,
            Name             = 'São Paulo'
        ), true);
    }

    @isTest
    static void createTaskTest(){
        System.assert(
            TaskBO.createTask(
                [SELECT Id FROM Opportunity LIMIT 1].Id,
                'Subject Teste',
                'Description Teste',
                UserInfo.getUserId(),
                System.today(),
                '10'
            ) != null
        );
    }

    @isTest
    static void createWorkOrderTest(){
        System.assert(
            TaskBO.createWorkOrder(
                [SELECT Id, AccountId, ConsultorOportunidade__c,cep__c,Logradouro__c,MunicipioInstalacao__c,EstadoInstalacao__c, Instalacao__c FROM Opportunity LIMIT 1],
                Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Instalacao').getRecordTypeId(),
                [SELECT Id FROM WorkType LIMIT 1].Id,
                [SELECT Id FROM ServiceTerritory LIMIT 1].Id
            ) != null
        );
    }

    @isTest
    static void createWorkOrderContractingIntegratorTest(){
        Task task = [
            SELECT  ID, Subject
            FROM    Task
            LIMIT   1
        ];
        task.Subject = 'CONTRATAR INTEGRADOR';
        update task;

        task.Status = TaskUtils.STATUS_CONCLUIDO;
        update task;

        /*WorkOrder workOrder = [
            SELECT  Id, AccountId, Consultor__c, InstalacaoAssociada__c, Projeto__c,
                    Status, Priority, RecordTypeId, WorkTypeId, ServiceTerritoryId
            FROM    WorkOrder
        ];*/
    }

    @isTest
    static void createWorkOrderRequestMaterialBuyTest(){
        WorkType workType = [
            SELECT  Id
            FROM    WorkType
            LIMIT   1
        ];
        workType.Name = 'Recebimento de Material';
        update workType;

        Task task = [
            SELECT  ID, Subject
            FROM    Task
            LIMIT   1
        ];
        task.Subject = 'SOLICITAR COMPRA DE MATERIAIS';
        update task;

        task.Status = TaskUtils.STATUS_CONCLUIDO;
        update task;

        /*WorkOrder workOrder = [
            SELECT  Id, AccountId, Consultor__c, InstalacaoAssociada__c, Projeto__c,
                    Status, Priority, RecordTypeId, WorkTypeId, ServiceTerritoryId
            FROM  */
    }

    @isTest
    static void notifyAfterTaskConclusionTest(){
        Task task = [
            SELECT  ID, Subject
            FROM    Task
            LIMIT   1
        ];
        task.Subject = 'Defina quem executará a visita técnica do negócio';
        update task;

        task.Status = TaskUtils.STATUS_CONCLUIDO;
        update task;
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Task task = [
            SELECT  ID, Subject
            FROM    Task
            LIMIT   1
        ];
        
        update task;

        delete task;

        TaskTriggerHandler.disableTrigger();
        System.assert(!TaskTriggerHandler.isTriggerEnabled());
        
        TaskTriggerHandler.enableTrigger();
        System.assert(TaskTriggerHandler.isTriggerEnabled());
    }
}
