/**
 * Provides metadata-driven field set sections for Lightning components.
 */
public with sharing class FieldSetConfigurationService {

    @TestVisible
    private static List<FieldSetMapping__mdt> testFieldSetMappings;

    @TestVisible
    private static RecordContext testRecordContextOverride;

    @TestVisible
    private static void setTestFieldSetMappings(List<FieldSetMapping__mdt> mappings) {
        testFieldSetMappings = mappings;
    }

    @TestVisible
    private static void setTestRecordContext(String recordTypeDeveloperName, String subject) {
        if (String.isBlank(recordTypeDeveloperName) && String.isBlank(subject)) {
            testRecordContextOverride = null;
            return;
        }

        RecordContext context = new RecordContext();
        context.recordTypeDeveloperName = normalize(recordTypeDeveloperName);
        context.subject = normalize(subject);
        testRecordContextOverride = context;
    }

    @AuraEnabled(cacheable=true)
    public static List<SectionConfiguration> getConfiguration(String objectApiName, Id recordId) {
        return getConfigurationInternal(objectApiName, recordId, null);
    }

    @AuraEnabled(cacheable=true)
    public static RelatedConfiguration getConfigurationForTask(Id taskId) {
        if (taskId == null) {
            throw new AuraHandledException('Task Id is required.');
        }

        Task taskRecord = [
            SELECT Id, Subject, WhatId, IsClosed
            FROM Task
            WHERE Id = :taskId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (taskRecord.WhatId == null) {
            return new RelatedConfiguration();
        }

        Id relatedRecordId = taskRecord.WhatId;
        Schema.SObjectType relatedSObjectType = relatedRecordId.getSObjectType();
        Schema.DescribeSObjectResult relatedDescribe = relatedSObjectType.getDescribe();
        if (!relatedDescribe.isAccessible()) {
            throw new AuraHandledException('You do not have access to view ' + relatedDescribe.getLabel() + ' records.');
        }

        String relatedObjectApiName = relatedDescribe.getName();

        RelatedConfiguration response = new RelatedConfiguration();
        response.targetRecordId = relatedRecordId;
        response.targetObjectApiName = relatedObjectApiName;
        response.sections = getConfigurationInternal(relatedObjectApiName, relatedRecordId, taskRecord.Subject);
        response.readOnly = taskRecord.IsClosed;

        return response;
    }

    // Exposed for server-side validations (e.g., before closing tasks).
    @TestVisible
    public static List<SectionConfiguration> getConfigurationForValidation(String objectApiName, Id recordId, String subject) {
        return getConfigurationInternal(objectApiName, recordId, subject);
    }

    private static List<SectionConfiguration> getConfigurationInternal(String objectApiName, Id recordId, String overrideSubject) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API name is required.');
        }

        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjectType == null) {
            throw new AuraHandledException('Object not found: ' + objectApiName);
        }

        Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
        if (!describeResult.isAccessible()) {
            throw new AuraHandledException('You do not have access to view ' + describeResult.getLabel() + ' records.');
        }

        RecordContext recordContext = resolveRecordContext(describeResult, recordId);
        if (overrideSubject != null) {
            recordContext.subject = normalize(overrideSubject);
        }

        List<FieldSetMapping__mdt> mappings = fetchFieldSetMappings(objectApiName, recordContext);

        if (mappings.isEmpty()) {
            return new List<SectionConfiguration>();
        }

        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        Map<String, Schema.FieldSet> fieldSetMap = describeResult.fieldSets.getMap();

        List<SectionConfiguration> sections = new List<SectionConfiguration>();
        for (FieldSetMapping__mdt mapping : mappings) {
            Schema.FieldSet fieldSet = fieldSetMap.get(mapping.FieldSetName__c);
            if (fieldSet == null) {
                continue;
            }

            SectionConfiguration section = new SectionConfiguration();
            section.fieldSetName = fieldSet.getName();
            section.label = String.isNotBlank(mapping.SectionLabel__c) ? mapping.SectionLabel__c : fieldSet.getLabel();
            section.required = mapping.IsSectionRequired__c == true;
            section.sortOrder = mapping.SortOrder__c == null ? 0 : mapping.SortOrder__c.intValue();
            section.fields = buildFieldConfigurations(fieldSet, fieldMap, section.required);
            section.requiresAttachment = mapping.RequiresAttachment__c == true;
            section.requiresComment = mapping.RequiresComment__c == true;

            if (!section.fields.isEmpty() || section.requiresAttachment || section.requiresComment) {
                sections.add(section);
            }
        }

        return sections;
    }

    private static List<FieldConfiguration> buildFieldConfigurations(
        Schema.FieldSet fieldSet,
        Map<String, Schema.SObjectField> fieldMap,
        Boolean sectionRequired
    ) {
        List<FieldConfiguration> fieldConfigurations = new List<FieldConfiguration>();

        for (Schema.FieldSetMember fieldSetMember : fieldSet.getFields()) {
            String fieldPath = fieldSetMember.getFieldPath();
            Schema.SObjectField fieldToken = fieldMap.get(fieldPath);

            if (fieldToken == null) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (!fieldDescribe.isAccessible()) {
                continue;
            }

            FieldConfiguration fieldConfiguration = new FieldConfiguration();
            fieldConfiguration.apiName = fieldPath;
            fieldConfiguration.label = fieldSetMember.getLabel();
            fieldConfiguration.type = String.valueOf(fieldDescribe.getType());
            fieldConfiguration.required = fieldSetMember.getRequired() || sectionRequired;
            fieldConfiguration.updateable = fieldDescribe.isUpdateable();

            fieldConfigurations.add(fieldConfiguration);
        }

        return fieldConfigurations;
    }

    private static List<FieldSetMapping__mdt> fetchFieldSetMappings(String objectApiName, RecordContext recordContext) {
        List<FieldSetMapping__mdt> mappings;
        if (Test.isRunningTest() && testFieldSetMappings != null) {
            mappings = testFieldSetMappings;
        } else {
            mappings = [
                SELECT DeveloperName, FieldSetName__c, SectionLabel__c, IsSectionRequired__c, SortOrder__c,
                    RecordTypeDeveloperName__c, Subject__c, RequiresAttachment__c, RequiresComment__c
                FROM FieldSetMapping__mdt
                WHERE ObjectApiName__c = :objectApiName
                ORDER BY SortOrder__c, DeveloperName
            ];
        }

        List<FieldSetMapping__mdt> filtered = new List<FieldSetMapping__mdt>();
        for (FieldSetMapping__mdt mapping : mappings) {
            if (matchesCriterion(recordContext.recordTypeDeveloperName, mapping.RecordTypeDeveloperName__c)
                && matchesCriterion(recordContext.subject, mapping.Subject__c)) {
                filtered.add(mapping);
            }
        }

        return filtered;
    }

    private static RecordContext resolveRecordContext(Schema.DescribeSObjectResult describeResult, Id recordId) {
        if (Test.isRunningTest() && testRecordContextOverride != null) {
            return testRecordContextOverride;
        }

        RecordContext recordContext = new RecordContext();

        if (recordId == null) {
            return recordContext;
        }

        List<String> fieldsToQuery = new List<String>{'Id'};
        Boolean hasRecordType = !describeResult.getRecordTypeInfos().isEmpty()
            && describeResult.fields.getMap().containsKey('RecordTypeId');
        Boolean hasSubjectField = describeResult.fields.getMap().containsKey('Subject');


        if (hasSubjectField) {
            fieldsToQuery.add('Subject');
        }

        if (hasRecordType) {
            fieldsToQuery.add('RecordTypeId');
        }

        String queryString = 'SELECT ' + String.join(fieldsToQuery, ', ')
            + ' FROM ' + describeResult.getName()
            + ' WHERE Id = :recordId'
            + ' WITH SECURITY_ENFORCED';

        SObject record = Database.query(queryString);


        if (hasSubjectField) {
            recordContext.subject = normalize((String)record.get('Subject'));
        }

        if (hasRecordType) {
            Id recordTypeId = (Id)record.get('RecordTypeId');
            String developerName = resolveRecordTypeDeveloperName(describeResult, recordTypeId);
            recordContext.recordTypeDeveloperName = normalize(developerName);
        }

        return recordContext;
    }

    public class SectionConfiguration {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public String fieldSetName;
        @AuraEnabled public List<FieldConfiguration> fields;
        @AuraEnabled public Boolean requiresAttachment;
        @AuraEnabled public Boolean requiresComment;
    }

    public class FieldConfiguration {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean updateable;
    }

    public class RelatedConfiguration {
        @AuraEnabled public List<SectionConfiguration> sections;
        @AuraEnabled public Id targetRecordId;
        @AuraEnabled public String targetObjectApiName;
        @AuraEnabled public Boolean readOnly;
    }

    private class RecordContext {
        String recordTypeDeveloperName;
        String subject;
    }

    private static String normalize(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String resolveRecordTypeDeveloperName(Schema.DescribeSObjectResult describeResult, Id recordTypeId) {
        if (recordTypeId == null) {
            return null;
        }

        Map<Id, Schema.RecordTypeInfo> infosById = describeResult.getRecordTypeInfosById();
        if (infosById == null || !infosById.containsKey(recordTypeId)) {
            return null;
        }

        Schema.RecordTypeInfo info = infosById.get(recordTypeId);
        return info == null ? null : info.getDeveloperName();
    }

    private static Boolean matchesCriterion(String contextValue, String criterionValue) {
        if (String.isBlank(criterionValue)) {
            return true;
        }
        if (contextValue == null) {
            return false;
        }
        return criterionValue.trim().equalsIgnoreCase(contextValue);
    }
}
