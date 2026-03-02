/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 12-03-2025
 * @last modified by	 : Daniel Belini
 **/
global without sharing class TaskDeadlineNotificationBatch implements Database.Batchable<SObject> {
  global Database.QueryLocator start(Database.BatchableContext bc) {
    Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();

    String query = 'SELECT Id, Status, ActivityDate, OwnerId, Subject, Priority, TaskSubtype, Type';
    if (fields.containsKey('HoraVencimento__c')) {
      query += ', HoraVencimento__c';
    }
    if (fields.containsKey('NotificadoAntesVencer__c')) {
      query += ', NotificadoAntesVencer__c';
    }
    if (fields.containsKey('NotificadoAposVencer__c')) {
      query += ', NotificadoAposVencer__c';
    }
    query += ' FROM Task WHERE ActivityDate != null';

    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext bc, List<Task> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    TaskSlaNotificationService.processDeadlineNotifications(scope);
  }

  global void finish(Database.BatchableContext bc) {
  }

  // lógica movida para TaskSlaNotificationService
}
