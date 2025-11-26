@isTest
public with sharing class ProjetoBOTest {

    @isTest
    static void testPopulateUserEmailMap() {

        // Setup test data
        User testUser = new User(
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Email = 'testuser@example.com',
            Alias = 'tuser',
            LastName = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Call the method
        ProjetoBO.populateUserEmailMap();

    }

    @isTest
    static void testCreateTasks() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;


        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id
        );
        insert testProject;

        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        // Call the method
        ProjetoBO.createTasks(new List<Projeto__c>{testProject}, oldMap);
        testProject.Status__c = 'Projeto aprovado';
        oldMap.put(testProject.Id, testProject);
        ProjetoBO.createTasks(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();

        // Verify the results
        // Add assertions to verify the expected behavior
    }

    @isTest
    static void testCreateTasks2() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;


        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id
        );
        insert testProject;
        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        // Call the method
        testProject.Status__c = 'Projeto aprovado';
        oldMap.put(testProject.Id, testProject);
        ProjetoBO.createTasks(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();

        // Verify the results
        // Add assertions to verify the expected behavior
    }


    @isTest
    static void testCreateTaskOnboarding() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        insert testProject;

        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        // Call the method
        ProjetoBO.createTaskOnboarding(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();

        // Verify the results
        // Add assertions to verify the expected behavior
    }

    @isTest
    static void testCreateTaskOnboarding2() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        insert testProject;

        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        // Call the method
        oldMap.put(testProject.Id, testProject);
        ProjetoBO.createTaskOnboarding(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();

        // Verify the results
        // Add assertions to verify the expected behavior
    }

    @isTest
    static void testCreateTaskProjectApproved() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        insert testProject;

        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        ProjetoBO.createTaskProjectApproved(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();
    }

    @isTest
    static void testStageDurationAccumulation() {
        Account testAccount = new Account(Name = 'Duration Account');
        insert testAccount;

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c project = new Projeto__c(
            Name = 'Duration Project',
            Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType='Projeto__c' LIMIT 1].Id,
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id
        );
        insert project;

        // Simula 5 dias no planejamento
        project.StatusAtualDesde__c = Date.today().addDays(-5);
        update project;

        // Muda para elaboração e valida contagem
        project = [SELECT Id, Status__c, StatusAtualDesde__c, ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c, RecordTypeId
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        project.Status__c = ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO;
        update project;

        project = [SELECT Id, Status__c, StatusAtualDesde__c, ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        System.assertEquals(5, project.ContagemPrazoPlanejamento__c, 'Planejamento deve acumular 5 dias');

        // Simula 3 dias na elaboração
        project.StatusAtualDesde__c = Date.today().addDays(-3);
        update project;
        project = [SELECT Id, Status__c, StatusAtualDesde__c, ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        project.Status__c = ProjetoUtils.STATUS_PROJETO_EM_ANALISE;
        update project;

        project = [SELECT Id, Status__c, StatusAtualDesde__c, ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        System.assertEquals(5, project.ContagemPrazoPlanejamento__c, 'Planejamento deve manter 5 dias');
        System.assertEquals(3, project.ContagemPrazoProjetoElaboracao__c, 'Elaboração deve acumular 3 dias');

        // Simula 2 dias na análise e encerra
        project.StatusAtualDesde__c = Date.today().addDays(-2);
        update project;
        project = [SELECT Id, Status__c, StatusAtualDesde__c, ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        project.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;
        update project;

        project = [SELECT ContagemPrazoPlanejamento__c, ContagemPrazoProjetoElaboracao__c, ContagemPrazoProjetoAnalise__c
                   FROM Projeto__c
                   WHERE Id = :project.Id];
        System.assertEquals(5, project.ContagemPrazoPlanejamento__c, 'Planejamento deve manter 5 dias');
        System.assertEquals(3, project.ContagemPrazoProjetoElaboracao__c, 'Elaboração deve manter 3 dias');
        System.assertEquals(2, project.ContagemPrazoProjetoAnalise__c, 'Análise deve acumular 2 dias');
    }
}