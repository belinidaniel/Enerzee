/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class ProjetoTriggerTest {
    
    @TestSetup
    static void makeData(){
        TaskTriggerHandler.disableTrigger();

        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);

        Account account = (Account) TestFactory.createSObject(new Account(), true);

        Contact contact = (Contact) TestFactory.createSObject(new Contact(AccountId = account.Id, LastName = 'New Contact', Email = 'test.data@enrz.com'), true);

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId                = account.id,
            ConsultorOportunidade__c = consultor.Id,
            MunicipioInstalacao__c   = 'São Paulo',
            IdVirtualOffice__c       = '00000000-0000-0000-0000-000000000010'
        ), true);

        Instalacao__c instalation = (Instalacao__c) TestFactory.createSObject(new Instalacao__c(
            ClienteConta__c          = account.Id,
            ConsultorInstalacao__c   = consultor.Id,
            OportunidadeConcluida__c = opportunity.Id,
            GestorObra__c            = UserInfo.getUserId()
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
    static void createTasksTest(){
        Opportunity opportunity = [
            SELECT  StageName, TipoObraProjeto__c
            FROM    Opportunity
            LIMIT   1
        ];

        Test.startTest();

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        insert viability;

        update opportunity;

        Projeto__c projeto = [
            SELECT  Status__c, Projetista__c, GestorObra__c
            FROM    Projeto__c
            LIMIT   1
        ];

        // Preencher responsáveis antes de concluir tarefas de delegação
        projeto.Projetista__c = UserInfo.getUserId();
        projeto.GestorObra__c = UserInfo.getUserId();
        update projeto;

        List<Task> tasks = [
            SELECT  Id, Subject 
            FROM    Task
        ];

        Integer taskListSize = tasks.size();
        for(Task task : tasks){
            task.Status = TaskUtils.STATUS_CONCLUIDO;
        }
        update tasks;

        projeto.Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO;
        
        update projeto;

        Test.stopTest();
    }

    @isTest
    static void createTasksJourneyTest(){
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opportunity = [
            SELECT  StageName, TipoObraProjeto__c
            FROM    Opportunity
            LIMIT   1
        ];

        Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId();

        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Case c = new Case(Status='Novo', Origin='Web To Case Integrador', NomeIntegradorWeb__c='Data Test', RecordTypeId = caseRecordTypeId, Nome_da_Oportunidade__c = opportunity.Id, ContactId = contact.Id);
        insert c;

        opportunity.StageName = 'Closed Won';
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;

        Projeto__c projeto = [
            SELECT  Status__c, Projetista__c, GestorObra__c
            FROM    Projeto__c
            LIMIT   1
        ];

        Test.startTest();

        // Preencher responsáveis antes de concluir tarefas de delegação
        projeto.Projetista__c = UserInfo.getUserId();
        projeto.GestorObra__c = UserInfo.getUserId();
        update projeto;

        List<Task> projectTasks = [
            SELECT Id, Status
            FROM   Task
            WHERE  WhatId = :projeto.Id
        ];
        for (Task t : projectTasks) {
            t.Status = TaskUtils.STATUS_CONCLUIDO;
        }
        if (!projectTasks.isEmpty()) {
            update projectTasks;
        }

        projeto.Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO;
        projeto.ApprovalDate__c = System.today();
        projeto.FinishProjectDate__c = System.today();
        
        update projeto;

        Test.stopTest();
    }

    // @isTest
    // static void checkTasksConclusionBeforeStatusChangeTest(){
    //     Opportunity opportunity = [
    //         SELECT  StageName, TipoObraProjeto__c
    //         FROM    Opportunity
    //         LIMIT   1
    //     ];

    //     ViabilityStudy__c viability = new ViabilityStudy__c();
    //     viability.Opportunity__c = opportunity.Id;
    //     viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
    //     insert viability;
        

    //     Test.startTest();

    //     opportunity.ViabilityStudyFinished__c = true;
    //     opportunity.StageName = OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO;
    //     update opportunity;

    //     Projeto__c projeto = [
    //         SELECT  Status__c, Projetista__c, GestorObra__c
    //         FROM    Projeto__c
    //         WHERE   Oportunidade__c = :opportunity.Id
    //         LIMIT   1
    //     ];

    //     try {
    //         projeto.Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO;
    //         update projeto;
    //     } catch(Exception e){
    //     }
    // }

    // @isTest
    // static void coverageOtherTriggerMethods(){
    //     Account account = [
    //         SELECT  Id
    //         FROM    Account
    //         LIMIT   1
    //     ];
    //     Opportunity opportunity = [
    //         SELECT  Id
    //         FROM    Opportunity
    //         LIMIT   1
    //     ];

        
    //     ViabilityStudy__c viability = new ViabilityStudy__c();
    //     viability.Opportunity__c = opportunity.Id;
    //     viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
    //     insert viability;
        
    //     opportunity.ViabilityStudyFinished__c = true;
    //     update opportunity;

    //     Projeto__c projeto = (Projeto__c) TestFactory.createSObject(new Projeto__c(
    //         Conta__c        = account.id,
    //         Oportunidade__c = opportunity.Id
    //     ), true);
        
    //     update projeto;
    //     delete projeto;

    //     ProjetoTriggerHandler.disableTrigger();
    //     System.assert(!ProjetoTriggerHandler.isTriggerEnabled());
        
    //     ProjetoTriggerHandler.enableTrigger();
    //     System.assert(ProjetoTriggerHandler.isTriggerEnabled());
    // }
}
