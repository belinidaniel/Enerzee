@IsTest
private class FieldSetConfigurationServiceTest {

    @TestSetup
    static void setupMetadata() {
        FieldSetMapping__mdt accountMapping = new FieldSetMapping__mdt(
            DeveloperName = 'Account_Default_Test',
            MasterLabel = 'Account Default Test',
            ObjectApiName__c = 'Account',
            FieldSetName__c = 'DynamicAccountGeneral',
            SectionLabel__c = 'Informações da Conta',
            SortOrder__c = 1,
            IsSectionRequired__c = true
        );
        insert accountMapping;

        FieldSetMapping__mdt accountSubjectMapping = new FieldSetMapping__mdt(
            DeveloperName = 'Account_Subject_Dynamic_Test',
            MasterLabel = 'Account Subject Dynamic Test',
            ObjectApiName__c = 'Account',
            FieldSetName__c = 'DynamicAccountGeneral',
            SectionLabel__c = 'Account Subject Section',
            SortOrder__c = 2,
            Subject__c = 'Dynamic Account General'
        );
        insert accountSubjectMapping;

        FieldSetMapping__mdt taskMapping = new FieldSetMapping__mdt(
            DeveloperName = 'Task_FollowUp_Test',
            MasterLabel = 'Task Follow Up Test',
            ObjectApiName__c = 'Task',
            FieldSetName__c = 'DynamicTaskFollowUp',
            SectionLabel__c = 'Follow Up',
            SortOrder__c = 1,
            IsSectionRequired__c = false,
            Subject__c = 'Follow Up'
        );
        insert taskMapping;
    }

    @IsTest
    static void getConfigurationWithoutRecordType() {
        Account accountRecord = new Account(Name = 'Dynamic Account');
        insert accountRecord;

        Test.startTest();
        List<FieldSetConfigurationService.SectionConfiguration> sections =
            FieldSetConfigurationService.getConfiguration('Account', accountRecord.Id);
        Test.stopTest();

        System.assertEquals(1, sections.size(), 'Expected single default section for Account');

        FieldSetConfigurationService.SectionConfiguration section = sections[0];
        System.assertEquals('Informações da Conta', section.label);
        System.assertTrue(section.required);
        System.assertEquals(2, section.fields.size(), 'Field set should expose two fields');

        FieldSetConfigurationService.FieldConfiguration firstField = section.fields[0];
        System.assertEquals('Name', firstField.apiName);
        System.assertTrue(firstField.required, 'Section required flag should enforce field requirement');
    }

    @IsTest
    static void getConfigurationWithRecordTypeSpecificSection() {
        RecordType accountRecordType = new RecordType(
            SObjectType = 'Account',
            DeveloperName = 'DynamicRT',
            Name = 'Dynamic RT',
            IsActive = true
        );
        insert accountRecordType;

        FieldSetMapping__mdt recordTypeMapping = new FieldSetMapping__mdt(
            DeveloperName = 'Account_RT_Dynamic',
            MasterLabel = 'Account Dynamic RT',
            ObjectApiName__c = 'Account',
            FieldSetName__c = 'DynamicAccountGeneral',
            SectionLabel__c = 'RT Specific',
            SortOrder__c = 2,
            RecordTypeDeveloperName__c = 'DynamicRT'
        );
        insert recordTypeMapping;

        Account accountRecord = new Account(
            Name = 'RecordType Account',
            RecordTypeId = accountRecordType.Id
        );
        insert accountRecord;

        Test.startTest();
        List<FieldSetConfigurationService.SectionConfiguration> sections =
            FieldSetConfigurationService.getConfiguration('Account', accountRecord.Id);
        Test.stopTest();

        System.assertEquals(2, sections.size(), 'Expected default and record type specific sections');
        System.assertEquals('Informações da Conta', sections[0].label);
        System.assertEquals('RT Specific', sections[1].label);
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

        System.assertEquals(1, sectionsForFollowUp.size(), 'Subject-matching task should return configuration');
        System.assertEquals('Follow Up', sectionsForFollowUp[0].label);
        System.assertEquals(0, sectionsForOther.size(), 'Non-matching subject should return no configuration');
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

        System.assertEquals(accountRecord.Id, configuration.targetRecordId, 'Related record id should match account');
        System.assertEquals('Account', configuration.targetObjectApiName);
        System.assertEquals(2, configuration.sections.size(), 'Expected default and subject specific sections');
        System.assertFalse(configuration.readOnly, 'Task not completed should allow editing');
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

        System.assertTrue(configuration.readOnly, 'Completed task should be flagged as read only');
    }
}
