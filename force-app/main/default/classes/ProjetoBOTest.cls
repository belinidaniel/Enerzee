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

        Id projetoRtId = getAvailableProjetoRecordTypeId();

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id
        );
        if (projetoRtId != null) {
            testProject.RecordTypeId = projetoRtId;
        }
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

        Id projetoRtId = getAvailableProjetoRecordTypeId();

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id
        );
        if (projetoRtId != null) {
            testProject.RecordTypeId = projetoRtId;
        }
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
        Id projetoRtId = getAvailableProjetoRecordTypeId();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        if (projetoRtId != null) {
            testProject.RecordTypeId = projetoRtId;
        }
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
        Id projetoRtId = getAvailableProjetoRecordTypeId();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        if (projetoRtId != null) {
            testProject.RecordTypeId = projetoRtId;
        }
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

        Id projetoRtId = getAvailableProjetoRecordTypeId();

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = testAccount.id
        ), true);

        Projeto__c testProject = new Projeto__c(
            Name = 'Test Project',
            Status__c = 'Planejamento',
            Conta__c = testAccount.Id,
            Oportunidade__c = opportunity.Id // Ensure this field is populated
        );
        if (projetoRtId != null) {
            testProject.RecordTypeId = projetoRtId;
        }
        insert testProject;

        Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>();

        Test.startTest();
        ProjetoBO.createTaskProjectApproved(new List<Projeto__c>{testProject}, oldMap);
        Test.stopTest();
    }

    private static Id getAvailableProjetoRecordTypeId() {
        for (Schema.RecordTypeInfo rti : Projeto__c.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable() && !rti.isMaster()) {
                return rti.getRecordTypeId();
            }
        }
        return null;
    }
}
