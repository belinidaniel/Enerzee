/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-03-2025
 * @last modified by  : Daniel Belini
**/
global without sharing class TaskDeadlineNotificationBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc){
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();

        String query = 'SELECT Id, Status, ActivityDate, OwnerId, Subject';
        if(fields.containsKey('HoraVencimento__c')){
            query += ', HoraVencimento__c';
        }
        if(fields.containsKey('NotificadoAntesVencer__c')){
            query += ', NotificadoAntesVencer__c';
        }
        if(fields.containsKey('NotificadoAposVencer__c')){
            query += ', NotificadoAposVencer__c';
        }
        query += ' FROM Task WHERE ActivityDate != null';

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<Task> scope){
        if(scope == null || scope.isEmpty()){
            return;
        }

        DateTime nowDt = System.now();
        List<Task> updates = new List<Task>();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();
        Boolean hasBefore = fields.containsKey('NotificadoAntesVencer__c');
        Boolean hasAfter = fields.containsKey('NotificadoAposVencer__c');
        Boolean hasHora = fields.containsKey('HoraVencimento__c');
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for(Task taskRecord : scope){
            if(taskRecord.Status != null && taskRecord.Status.equalsIgnoreCase(TaskUtils.STATUS_CONCLUIDO)){
                continue;
            }

            Object horaValue = hasHora ? taskRecord.get('HoraVencimento__c') : null;
            DateTime dueDateTime = TaskTemplateUtils.combineDateAndTime(taskRecord.ActivityDate, horaValue);
            if(dueDateTime == null){
                continue;
            }

            Boolean notifiedBefore = hasBefore ? (Boolean) taskRecord.get('NotificadoAntesVencer__c') : null;
            Boolean notifiedAfter = hasAfter ? (Boolean) taskRecord.get('NotificadoAposVencer__c') : null;

            Boolean notifyBefore = (notifiedBefore == null || !notifiedBefore) && nowDt >= dueDateTime.addMinutes(-30);
            Boolean notifyAfter = (notifiedAfter == null || !notifiedAfter) && nowDt >= dueDateTime;

            if(notifyBefore || notifyAfter){
                Task updateTask = new Task(Id = taskRecord.Id);
                if(notifyBefore && hasBefore){
                    updateTask.put('NotificadoAntesVencer__c', true);
                }
                if(notifyAfter && hasAfter){
                    updateTask.put('NotificadoAposVencer__c', true);
                }
                updates.add(updateTask);

                if(!Test.isRunningTest() && isUserOwner(taskRecord.OwnerId)){
                    sendBellNotification(taskRecord, notifyAfter);
                    emails.add(buildEmail(taskRecord, dueDateTime, notifyAfter));
                }
            }
        }

        if(!updates.isEmpty()){
            Database.SaveResult[] results = Database.update(updates, false);
            // opcionalmente poderíamos logar falhas, mas não interrompemos o batch
            for(Database.SaveResult sr : results){
                if(!sr.isSuccess()){
                    continue;
                }
            }
        }

        if(!Test.isRunningTest()){
            if(!emails.isEmpty()){
                Messaging.sendEmail(emails, false);
            }
        }
    }

    global void finish(Database.BatchableContext bc){}

    private static Boolean isUserOwner(Id ownerId){
        return ownerId != null && String.valueOf(ownerId).startsWith('005');
    }

    private static Messaging.SingleEmailMessage buildEmail(Task taskRecord, DateTime dueDateTime, Boolean isAfter){
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(taskRecord.OwnerId);
        email.setTreatTargetObjectAsRecipient(true);
        email.setSaveAsActivity(false);
        String statusMsg = isAfter ? 'já venceu' : 'vai vencer em breve';
        String body = 'A tarefa "' + taskRecord.Subject + '" ' + statusMsg + '.'
            + (dueDateTime != null ? ' Vencimento: ' + dueDateTime.format('dd/MM/yyyy HH:mm') : '');
        email.setSubject('[Tarefas] ' + (isAfter ? 'Tarefa vencida' : 'Tarefa próxima do vencimento'));
        email.setPlainTextBody(body);
        return email;
    }

    // Envia notificação no sino via Custom Notification (usa tipo existente na org)
    private static Id customNotificationTypeId;
    @TestVisible private static void sendBellNotification(Task taskRecord, Boolean isAfter){
        if(taskRecord == null || taskRecord.OwnerId == null){
            return;
        }
        Id typeId = getCustomNotificationTypeId();
        if(typeId == null){
            return; // tipo não configurado na org
        }
        try{
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(isAfter ? 'Tarefa vencida' : 'Tarefa prestes a vencer');
            notification.setBody(taskRecord.Subject != null ? taskRecord.Subject : 'Tarefa');
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(taskRecord.Id);
            notification.send(new Set<String>{ taskRecord.OwnerId });
        } catch (Exception e){
            // não interrompe o batch se a notificação falhar
        }
    }

    private static Id getCustomNotificationTypeId(){
        if(customNotificationTypeId != null){
            return customNotificationTypeId;
        }
        // Busca qualquer tipo disponível; se quiser algo específico, ajuste o filtro.
        List<CustomNotificationType> types = [
            SELECT Id, customNotifTypeName
            FROM CustomNotificationType
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        customNotificationTypeId = types.isEmpty() ? null : types[0].Id;
        return customNotificationTypeId;
    }
}
