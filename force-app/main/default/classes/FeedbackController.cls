public without sharing class FeedbackController {
    public FeedbackController() {

    }

    @AuraEnabled(cacheable=true)
    public static List<Task> getEventsBySubject(String recordId) {
            return [SELECT Id, RecordTypeId, WhoId, WhatId, WhoCount, WhatCount, Subject, ActivityDate, Status, Priority, IsHighPriority, OwnerId, Description, Type, IsDeleted, AccountId, IsClosed, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, IsArchived, IsVisibleInSelfService, CallDurationInSeconds, CallType, CallDisposition, CallObject, ReminderDateTime, IsReminderSet, RecurrenceActivityId, IsRecurrence, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval, RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, TaskSubtype, CompletedDateTime, Descricao__c, Observacoes__c, PrazoDiasUteis__c, ResponsavelAcompanhar__c, ResponsavelReceber__c, StatusProjeto__c, TipoObraProjeto__c, FSL__Count_of_Events__c, FSL__Count_of_Tasks__c, FSL__Event_Type__c, DateInspectionRequest__c, EstimatedDateKitWeb__c, InspectionDays__c, InstallationPlanned__c, Login__c, MonitoringApplication__c, NextNotification__c, Password__c, Manager__c, NomeDoProprietario__c, Feedback__c  FROM Task WHERE  Feedback__c = :recordId];
    }

    @AuraEnabled
    public static String saveFeedback(String recordId, String score, String notes) {
            Feedback__c feedback = new Feedback__c();
            feedback.Score__c = score;
            feedback.Notes__c = notes;
            feedback.Id = recordId;
            update feedback;

            return 'Success';
    }
}