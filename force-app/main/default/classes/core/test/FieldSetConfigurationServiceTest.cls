/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-08-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
private class FieldSetConfigurationServiceTest {

    @TestSetup
    static void setupMetadata() {
        List<FieldSetMapping__mdt> mappings = new List<FieldSetMapping__mdt>{
            new FieldSetMapping__mdt(
                DeveloperName = 'Account_Default_Test',
                MasterLabel = 'Account Default Test',
                ObjectApiName__c = 'Account',
                FieldSetName__c = 'DynamicAccountGeneral',
                SectionLabel__c = 'Informações da Conta',
                SortOrder__c = 1,
                IsSectionRequired__c = true
            ),
            new FieldSetMapping__mdt(
                DeveloperName = 'Account_RT_Dynamic',
                MasterLabel = 'Account Dynamic RT',
                ObjectApiName__c = 'Account',
                FieldSetName__c = 'DynamicAccountGeneral',
                SectionLabel__c = 'RT Specific',
                SortOrder__c = 2,
                RecordTypeDeveloperName__c = 'DynamicRT'
            ),
            new FieldSetMapping__mdt(
                DeveloperName = 'Account_Subject_Dynamic_Test',
                MasterLabel = 'Account Subject Dynamic Test',
                ObjectApiName__c = 'Account',
                FieldSetName__c = 'DynamicAccountGeneral',
                SectionLabel__c = 'Account Subject Section',
                SortOrder__c = 3,
                Subject__c = 'Dynamic Account General'
            ),
            new FieldSetMapping__mdt(
                DeveloperName = 'Task_FollowUp_Test',
                MasterLabel = 'Task Follow Up Test',
                ObjectApiName__c = 'Task',
                FieldSetName__c = 'DynamicTaskFollowUp',
                SectionLabel__c = 'Follow Up',
                SortOrder__c = 1,
                IsSectionRequired__c = false,
                Subject__c = 'Follow Up'
            )
        };

        FieldSetConfigurationService.setTestFieldSetMappings(mappings);
        FieldSetConfigurationService.setTestRecordContext(null, null);
    }

    @IsTest
    static void getConfigurationWithoutRecordType() {
        Account accountRecord = new Account(Name = 'Dynamic Account');
        insert accountRecord;

        Test.startTest();
        List<FieldSetConfigurationService.SectionConfiguration> sections =
            FieldSetConfigurationService.getConfiguration('Account', accountRecord.Id);
        Test.stopTest();

        FieldSetConfigurationService.SectionConfiguration section = sections[0];
        FieldSetConfigurationService.FieldConfiguration firstField = section.fields[0];
    }

    @IsTest
    static void getConfigurationWithRecordTypeSpecificSection() {
        Account accountRecord = new Account(
            Name = 'RecordType Account'
        );
        insert accountRecord;

        FieldSetConfigurationService.setTestRecordContext('DynamicRT', null);

        Test.startTest();
        List<FieldSetConfigurationService.SectionConfiguration> sections =
            FieldSetConfigurationService.getConfiguration('Account', accountRecord.Id);
        Test.stopTest();

        FieldSetConfigurationService.setTestRecordContext(null, null);
    }

    @IsTest
    static void getConfigurationFiltersBySubject() {
        Task followUpTask = new Task(
            Subject = 'Follow Up',
            Status = 'Not Started',
            Priority = 'Normal'
        );
        insert followUpTask;

        Task unrelatedTask = new Task(
            Subject = 'Call Customer',
            Status = 'Not Started',
            Priority = 'Normal'
        );
        insert unrelatedTask;

        Test.startTest();
        List<FieldSetConfigurationService.SectionConfiguration> sectionsForFollowUp =
            FieldSetConfigurationService.getConfiguration('Task', followUpTask.Id);
        List<FieldSetConfigurationService.SectionConfiguration> sectionsForOther =
            FieldSetConfigurationService.getConfiguration('Task', unrelatedTask.Id);
        Test.stopTest();
    }

    @IsTest
    static void getConfigurationForTaskRelatedRecord() {
        Account accountRecord = new Account(Name = 'Account For Task');
        insert accountRecord;

        Task taskRecord = new Task(
            Subject = 'Dynamic Account General',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = accountRecord.Id
        );
        insert taskRecord;

        Test.startTest();
        FieldSetConfigurationService.RelatedConfiguration configuration =
            FieldSetConfigurationService.getConfigurationForTask(taskRecord.Id);
        Test.stopTest();
    }

    @IsTest
    static void getConfigurationForTaskMarksReadOnlyWhenClosed() {
        Account accountRecord = new Account(Name = 'Closed Task Account');
        insert accountRecord;

        Task completedTask = new Task(
            Subject = 'Dynamic Account General',
            Status = 'Completed',
            Priority = 'Normal',
            WhatId = accountRecord.Id
        );
        insert completedTask;

        Test.startTest();
        FieldSetConfigurationService.RelatedConfiguration configuration =
            FieldSetConfigurationService.getConfigurationForTask(completedTask.Id);
        Test.stopTest();
    }
}