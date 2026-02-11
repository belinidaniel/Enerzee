public with sharing class TaskSlaNotificationService {
    private static Map<String, Id> notificationTypeCache = new Map<String, Id>();

    public static void processDeadlineNotifications(List<Task> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Integer total = scope.size();
        Integer skippedClosed = 0;
        Integer skippedNoDue = 0;
        Integer skippedWindow = 0;
        Integer skippedConfig = 0;
        Integer skippedRecipients = 0;
        Integer skippedChannel = 0;
        Integer notifyBeforeCount = 0;
        Integer notifyAfterCount = 0;

        String emailOverride = TaskSlaConfig.getSandboxEmailOverride();

        TaskSlaConfig.NotificationConfig beforeConfig = TaskSlaConfig.getNotificationConfig(
            TaskSlaConfig.TYPE_BEFORE_DUE
        );
        TaskSlaConfig.NotificationConfig afterConfig = TaskSlaConfig.getNotificationConfig(
            TaskSlaConfig.TYPE_AFTER_DUE
        );

        Boolean beforeEnabled = beforeConfig != null && beforeConfig.enabled;
        Boolean afterEnabled = afterConfig != null && afterConfig.enabled;
        if (!beforeEnabled && !afterEnabled) {
            TaskSlaUtils.debug('DeadlineNotifications', 'disabled. total=' + total);
            return;
        }
        TaskSlaUtils.debug(
            'DeadlineNotifications',
            'start total=' + total
            + ' beforeEnabled=' + beforeEnabled
            + ' afterEnabled=' + afterEnabled
            + ' beforeMin=' + (beforeConfig != null ? String.valueOf(beforeConfig.minutesBeforeDue) : 'null')
            + ' afterMin=' + (afterConfig != null ? String.valueOf(afterConfig.minutesAfterDue) : 'null')
            + ' override=' + (String.isBlank(emailOverride) ? 'none' : emailOverride)
        );

        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();
        Boolean hasBeforeField = fields.containsKey('NotificadoAntesVencer__c');
        Boolean hasAfterField = fields.containsKey('NotificadoAposVencer__c');
        Boolean hasHoraField = fields.containsKey('HoraVencimento__c');

        DateTime nowDt = System.now();
        List<Task> updates = new List<Task>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Log__c> logs = new List<Log__c>();

        Set<Id> ownerIds = new Set<Id>();
        for (Task taskRecord : scope) {
            ownerIds.add(taskRecord.OwnerId);
        }

        Boolean needsQueueMembers = needsQueueMembers(beforeConfig) || needsQueueMembers(afterConfig);
        TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(ownerIds, needsQueueMembers);
        Map<Id, String> queueDevNames = context.queueDeveloperNameById;

        for (Task taskRecord : scope) {
            if (TaskSlaUtils.isClosedOrCanceled(taskRecord.Status)) {
                skippedClosed++;
                continue;
            }

            Object horaValue = hasHoraField ? taskRecord.get('HoraVencimento__c') : null;
            DateTime dueDateTime = TaskTemplateUtils.combineDateAndTime(taskRecord.ActivityDate, horaValue);
            if (dueDateTime == null) {
                skippedNoDue++;
                continue;
            }

            Boolean notifiedBefore = hasBeforeField ? (Boolean) taskRecord.get('NotificadoAntesVencer__c') : null;
            Boolean notifiedAfter = hasAfterField ? (Boolean) taskRecord.get('NotificadoAposVencer__c') : null;

            Boolean notifyBefore = false;
            Boolean notifyAfter = false;

            if (beforeEnabled && (notifiedBefore == null || !notifiedBefore)) {
                Integer minutesBefore = beforeConfig.minutesBeforeDue != null ? beforeConfig.minutesBeforeDue : 30;
                notifyBefore = nowDt >= dueDateTime.addMinutes(-minutesBefore);
            }
            if (afterEnabled && (notifiedAfter == null || !notifiedAfter)) {
                Integer minutesAfter = afterConfig.minutesAfterDue != null ? afterConfig.minutesAfterDue : 0;
                notifyAfter = nowDt >= dueDateTime.addMinutes(minutesAfter);
            }
            if (notifyBefore) {
                notifyBeforeCount++;
            }
            if (notifyAfter) {
                notifyAfterCount++;
            }

            if (!notifyBefore && !notifyAfter) {
                skippedWindow++;
                continue;
            }

            TaskSlaConfig.NotificationConfig configToUse = notifyAfter ? afterConfig : beforeConfig;
            if (!TaskSlaUtils.matchesConfig(taskRecord, configToUse, queueDevNames)) {
                skippedConfig++;
                continue;
            }

            TaskSlaRecipientResolver.RecipientResult recipients = TaskSlaRecipientResolver.resolveRecipients(
                taskRecord,
                configToUse,
                context
            );

            if (recipients.userIds.isEmpty() && recipients.emailAddresses.isEmpty()) {
                skippedRecipients++;
                continue;
            }
            if ((configToUse.sendEmail == null || !configToUse.sendEmail)
                && (configToUse.sendBell == null || !configToUse.sendBell)) {
                skippedChannel++;
                continue;
            }

            Task updateTask = new Task(Id = taskRecord.Id);
            if (notifyBefore && hasBeforeField) {
                updateTask.put('NotificadoAntesVencer__c', true);
            }
            if (notifyAfter && hasAfterField) {
                updateTask.put('NotificadoAposVencer__c', true);
            }
            updates.add(updateTask);

            String notificationType = notifyAfter ? TaskSlaConfig.TYPE_AFTER_DUE : TaskSlaConfig.TYPE_BEFORE_DUE;
            addLogs(logs, taskRecord.Id, notificationType, recipients);

            if (configToUse.sendEmail) {
                addEmailMessages(emails, taskRecord, dueDateTime, notifyAfter, recipients, emailOverride);
            }

            if (String.isBlank(emailOverride)
                && configToUse.sendBell
                && !recipients.userIds.isEmpty()
                && !Test.isRunningTest()) {
                sendBellNotification(taskRecord, notifyAfter, recipients.userIds, configToUse);
            }
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            sendEmailsInChunks(emails);
        }

        if (!logs.isEmpty()) {
            Database.insert(logs, false);
        }

        TaskSlaUtils.debug(
            'DeadlineNotifications',
            'done total=' + total
            + ' before=' + notifyBeforeCount
            + ' after=' + notifyAfterCount
            + ' updates=' + updates.size()
            + ' emails=' + emails.size()
            + ' logs=' + logs.size()
            + ' skippedClosed=' + skippedClosed
            + ' skippedNoDue=' + skippedNoDue
            + ' skippedWindow=' + skippedWindow
            + ' skippedConfig=' + skippedConfig
            + ' skippedRecipients=' + skippedRecipients
            + ' skippedChannel=' + skippedChannel
        );
    }

    private static Boolean needsQueueMembers(TaskSlaConfig.NotificationConfig config) {
        if (config == null || !config.notifyQueue) {
            return false;
        }
        return true;
    }

    private static void addEmailMessages(
        List<Messaging.SingleEmailMessage> emails,
        Task taskRecord,
        DateTime dueDateTime,
        Boolean isAfter,
        TaskSlaRecipientResolver.RecipientResult recipients,
        String emailOverride
    ) {
        if (emails == null || taskRecord == null || recipients == null) {
            return;
        }

        if (!String.isBlank(emailOverride)) {
            Messaging.SingleEmailMessage email = buildDeadlineEmail(taskRecord, dueDateTime, isAfter);
            email.setToAddresses(new String[]{ emailOverride });
            email.setSaveAsActivity(false);
            emails.add(email);
            return;
        }

        for (Id userId : recipients.userIds) {
            Messaging.SingleEmailMessage email = buildDeadlineEmail(taskRecord, dueDateTime, isAfter);
            email.setTargetObjectId(userId);
            email.setTreatTargetObjectAsRecipient(true);
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        for (String emailAddress : recipients.emailAddresses) {
            if (String.isBlank(emailAddress)) {
                continue;
            }
            Messaging.SingleEmailMessage email = buildDeadlineEmail(taskRecord, dueDateTime, isAfter);
            email.setToAddresses(new String[]{ emailAddress });
            email.setSaveAsActivity(false);
            emails.add(email);
        }
    }

    private static Messaging.SingleEmailMessage buildDeadlineEmail(
        Task taskRecord,
        DateTime dueDateTime,
        Boolean isAfter
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String statusMsg = isAfter ? 'ja venceu' : 'vai vencer em breve';
        String dueText = dueDateTime != null ? dueDateTime.format('dd/MM/yyyy HH:mm') : '';
        String taskLink = buildTaskLink(taskRecord);
        String body = 'A tarefa "' + taskRecord.Subject + '" ' + statusMsg + '.'
            + (!String.isBlank(dueText) ? ' Vencimento: ' + dueText : '')
            + (!String.isBlank(taskLink) ? ' Link: ' + taskLink : '');
        String html = buildDeadlineHtml(taskRecord, statusMsg, dueText, taskLink);
        email.setSubject('[Tarefas] ' + (isAfter ? 'Tarefa vencida' : 'Tarefa proxima do vencimento'));
        email.setPlainTextBody(body);
        email.setHtmlBody(html);
        return email;
    }

    private static String buildDeadlineHtml(
        Task taskRecord,
        String statusMsg,
        String dueText,
        String taskLink
    ) {
        String subject = taskRecord != null ? taskRecord.Subject : '';
        String safeSubject = TaskSlaUtils.escapeHtml(subject);
        String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
        body += '<tr><td align="center">';
        body += '<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
        body += '<tr><td style="padding:18px 22px;background:linear-gradient(135deg,#0f172a,#1e293b);color:#ffffff;">';
        body += '<div style="font-size:16px;font-weight:600;">Alerta de tarefa</div>';
        body += '</td></tr>';
        body += '<tr><td style="padding:20px 22px;">';
        body += '<div style="font-size:14px;color:#0f172a;margin-bottom:8px;">A tarefa abaixo ' + TaskSlaUtils.escapeHtml(statusMsg) + '.</div>';
        body += '<div style="font-size:15px;font-weight:600;color:#111827;margin:6px 0;">';
        if (!String.isBlank(taskLink)) {
            body += '<a href="' + taskLink + '" style="color:#2563eb;text-decoration:none;">' + safeSubject + '</a>';
        } else {
            body += safeSubject;
        }
        body += '</div>';
        if (!String.isBlank(dueText)) {
            body += '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' + TaskSlaUtils.escapeHtml(dueText) + '</div>';
        }
        if (!String.isBlank(taskLink)) {
            body += '<div style="margin-top:14px;">';
            body += '<a href="' + taskLink + '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:9px 14px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Abrir tarefa</a>';
            body += '</div>';
        }
        body += '</td></tr>';
        body += '<tr><td style="padding:14px 22px;background:#f8fafc;color:#94a3b8;font-size:11px;text-align:center;">';
        body += 'Email automatico - SLA de Tarefas';
        body += '</td></tr>';
        body += '</table>';
        body += '</td></tr></table>';
        body += '</body></html>';
        return body;
    }

    private static String buildTaskLink(Task taskRecord) {
        if (taskRecord == null || taskRecord.Id == null) {
            return '';
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        return baseUrl + '/lightning/r/Task/' + String.valueOf(taskRecord.Id) + '/view';
    }

    private static void sendBellNotification(
        Task taskRecord,
        Boolean isAfter,
        Set<Id> recipientIds,
        TaskSlaConfig.NotificationConfig config
    ) {
        if (taskRecord == null || recipientIds == null || recipientIds.isEmpty()) {
            return;
        }
        Id typeId = getCustomNotificationTypeId(config != null ? config.customNotificationTypeDevName : null);
        if (typeId == null) {
            return;
        }
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(isAfter ? 'Tarefa vencida' : 'Tarefa prestes a vencer');
            notification.setBody(taskRecord.Subject != null ? taskRecord.Subject : 'Tarefa');
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(taskRecord.Id);
            Set<String> recipientStrings = new Set<String>();
            for (Id recipientId : recipientIds) {
                recipientStrings.add(String.valueOf(recipientId));
            }
            notification.send(recipientStrings);
        } catch (Exception e) {
            // Nao interrompe o batch
        }
    }

    private static Id getCustomNotificationTypeId(String developerName) {
        String key = String.isBlank(developerName) ? 'DEFAULT' : developerName.trim().toUpperCase();
        if (notificationTypeCache.containsKey(key)) {
            return notificationTypeCache.get(key);
        }

        Id typeId;
        if (!String.isBlank(developerName)) {
            List<CustomNotificationType> types = [
                SELECT Id, DeveloperName, CustomNotifTypeName
                FROM CustomNotificationType
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            if (!types.isEmpty()) {
                typeId = types[0].Id;
            }
        }

        if (typeId == null) {
            List<CustomNotificationType> types = [
                SELECT Id, DeveloperName, CustomNotifTypeName
                FROM CustomNotificationType
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            typeId = types.isEmpty() ? null : types[0].Id;
        }

        notificationTypeCache.put(key, typeId);
        return typeId;
    }

    private static void addLogs(
        List<Log__c> logs,
        Id taskId,
        String notificationType,
        TaskSlaRecipientResolver.RecipientResult recipients
    ) {
        if (logs == null || recipients == null) {
            return;
        }
        String baseName = 'TaskSLA ' + (notificationType != null ? notificationType : 'NOTIF');

        for (Id userId : recipients.userIds) {
            Log__c log = new Log__c();
            log.Name = baseName;
            log.Type__c = notificationType;
            log.RelatedId__c = taskId != null ? String.valueOf(taskId) : null;
            log.Message__c = 'RecipientUserId=' + String.valueOf(userId);
            logs.add(log);
        }
        for (String email : recipients.emailAddresses) {
            if (String.isBlank(email)) {
                continue;
            }
            Log__c log = new Log__c();
            log.Name = baseName;
            log.Type__c = notificationType;
            log.RelatedId__c = taskId != null ? String.valueOf(taskId) : null;
            log.Message__c = 'RecipientEmail=' + email;
            logs.add(log);
        }
    }

    public static void sendEmailsInChunks(List<Messaging.SingleEmailMessage> emails) {
        Integer chunkSize = 10;
        List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
        for (Messaging.SingleEmailMessage email : emails) {
            chunk.add(email);
            if (chunk.size() == chunkSize) {
                Messaging.sendEmail(chunk, false);
                chunk.clear();
            }
        }
        if (!chunk.isEmpty()) {
            Messaging.sendEmail(chunk, false);
        }
    }
}
