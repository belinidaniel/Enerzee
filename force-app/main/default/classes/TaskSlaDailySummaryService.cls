/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-11-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class TaskSlaDailySummaryService {

    public static void runDaily() {
        Date today = Date.today();
        Date tomorrow = today.addDays(1);

        sendManagerSummary(today, tomorrow, true);
        sendManagerSummary(today, tomorrow, false);
        sendOwnerOpenSummary(today, tomorrow);
    }

    public static void runManagerOverdue() {
        Date today = Date.today();
        Date tomorrow = today.addDays(1);
        sendManagerSummary(today, tomorrow, true);
    }

    public static void runManagerDueTomorrow() {
        Date today = Date.today();
        Date tomorrow = today.addDays(1);
        sendManagerSummary(today, tomorrow, false);
    }

    public static void runOwnerOpenSummary() {
        Date today = Date.today();
        Date tomorrow = today.addDays(1);
        sendOwnerOpenSummary(today, tomorrow);
    }

    private static void sendManagerSummary(Date today, Date tomorrow, Boolean overdue) {
        String configKey = overdue ? TaskSlaConfig.TYPE_MANAGER_OVERDUE : TaskSlaConfig.TYPE_MANAGER_DUE_TOMORROW;
        TaskSlaConfig.NotificationConfig config = TaskSlaConfig.getNotificationConfig(configKey);
        if (config == null || !config.enabled) {
            TaskSlaUtils.debug('DailySummary', 'manager summary disabled. key=' + configKey);
            return;
        }
        if ((config.notifyManager == null || !config.notifyManager) && (config.notifyQueue == null || !config.notifyQueue)) {
            TaskSlaUtils.debug('DailySummary', 'manager summary recipients disabled. key=' + configKey);
            return;
        }
        String emailOverride = TaskSlaConfig.getSandboxEmailOverride();

        Set<String> closedStatuses = TaskSlaConfig.getClosedStatusValues();
        Set<String> canceledStatuses = TaskSlaConfig.getCanceledStatusValues();

        List<Task> tasks = queryManagerTasks(today, tomorrow, overdue, closedStatuses, canceledStatuses);
        if (tasks.isEmpty()) {
            TaskSlaUtils.debug('DailySummary', 'manager summary empty. key=' + configKey);
            return;
        }

        Set<Id> ownerIds = new Set<Id>();
        for (Task taskRecord : tasks) {
            ownerIds.add(taskRecord.OwnerId);
        }

        TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(ownerIds, true);
        Map<Id, String> queueDevNames = context.queueDeveloperNameById;

        List<Task> filteredTasks = applyConfigFilter(tasks, config, queueDevNames);
        if (filteredTasks.isEmpty()) {
            TaskSlaUtils.debug('DailySummary', 'manager summary filtered empty. key=' + configKey);
            return;
        }

        Map<Id, List<Task>> ownerToTasks = new Map<Id, List<Task>>();
        for (Task taskRecord : filteredTasks) {
            if (!ownerToTasks.containsKey(taskRecord.OwnerId)) {
                ownerToTasks.put(taskRecord.OwnerId, new List<Task>());
            }
            ownerToTasks.get(taskRecord.OwnerId).add(taskRecord);
        }

        Map<Id, String> relatedNames = fetchRelatedNames(filteredTasks);
        Map<Id, List<Task>> managerToTasks = new Map<Id, List<Task>>();
        Map<Id, List<Task>> queueToTasks = new Map<Id, List<Task>>();

        for (Id ownerId : ownerToTasks.keySet()) {
            if (TaskSlaUtils.isUserOwner(ownerId)) {
                if (config.notifyManager == null || !config.notifyManager) {
                    continue;
                }
                User owner = context.ownersById.get(ownerId);
                if (owner == null || owner.ManagerId == null) {
                    continue;
                }
                if (!context.managersById.containsKey(owner.ManagerId)) {
                    continue;
                }
                if (!managerToTasks.containsKey(owner.ManagerId)) {
                    managerToTasks.put(owner.ManagerId, new List<Task>());
                }
                managerToTasks.get(owner.ManagerId).addAll(ownerToTasks.get(ownerId));
            } else if (TaskSlaUtils.isQueueOwner(ownerId)) {
                if (config.notifyQueue == null || !config.notifyQueue) {
                    continue;
                }
                if (!queueToTasks.containsKey(ownerId)) {
                    queueToTasks.put(ownerId, new List<Task>());
                }
                queueToTasks.get(ownerId).addAll(ownerToTasks.get(ownerId));
            }
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Log__c> logs = new List<Log__c>();
        String subjectPrefix = overdue ? 'SLA - Atrasadas ate ontem' : 'SLA - Vencem amanha';

        for (Id managerId : managerToTasks.keySet()) {
            User manager = context.managersById.get(managerId);
            if (manager == null || !manager.IsActive || String.isBlank(manager.Email)) {
                continue;
            }
            List<Task> managerTasks = managerToTasks.get(managerId);
            Messaging.SingleEmailMessage email = buildManagerSummaryEmail(
                manager,
                managerTasks,
                subjectPrefix,
                config,
                emailOverride,
                relatedNames
            );
            emails.add(email);
            addSummaryLogs(logs, managerId, configKey, managerTasks.size());
        }

        for (Id queueId : queueToTasks.keySet()) {
            List<Task> queueTasks = queueToTasks.get(queueId);
            TaskSlaRecipientResolver.RecipientResult recipients = TaskSlaRecipientResolver.resolveRecipients(
                new Task(OwnerId = queueId),
                config,
                context
            );
            if (recipients.userIds.isEmpty() && recipients.emailAddresses.isEmpty()) {
                continue;
            }
            String queueName = context.queuesById.containsKey(queueId) ? context.queuesById.get(queueId).Name : 'Fila';
            Messaging.SingleEmailMessage email = buildQueueManagerSummaryEmail(
                queueName,
                queueTasks,
                subjectPrefix,
                config,
                emailOverride,
                relatedNames
            );
            if (!String.isBlank(emailOverride)) {
                emails.add(email);
            } else {
                if (!recipients.userIds.isEmpty()) {
                    for (Id userId : recipients.userIds) {
                        Messaging.SingleEmailMessage cloneEmail = cloneEmailForUser(email, userId);
                        emails.add(cloneEmail);
                    }
                }
                if (!recipients.emailAddresses.isEmpty()) {
                    for (String address : recipients.emailAddresses) {
                        Messaging.SingleEmailMessage cloneEmail = cloneEmailForAddress(email, address);
                        emails.add(cloneEmail);
                    }
                }
            }
            addSummaryLogs(logs, queueId, configKey, queueTasks.size());
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            TaskSlaNotificationService.sendEmailsInChunks(emails);
        }

        if (!logs.isEmpty()) {
            Database.insert(logs, false);
        }

        TaskSlaUtils.debug(
            'DailySummary',
            'manager summary done. key=' + configKey
            + ' tasks=' + tasks.size()
            + ' filtered=' + filteredTasks.size()
            + ' managers=' + managerToTasks.size()
            + ' queues=' + queueToTasks.size()
            + ' emails=' + emails.size()
            + ' logs=' + logs.size()
            + ' override=' + (String.isBlank(emailOverride) ? 'none' : emailOverride)
        );
    }

    private static void sendOwnerOpenSummary(Date today, Date tomorrow) {
        TaskSlaConfig.NotificationConfig config = TaskSlaConfig.getNotificationConfig(
            TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
        );
        if (config == null || !config.enabled) {
            TaskSlaUtils.debug('DailySummary', 'owner summary disabled. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY);
            return;
        }
        if ((config.notifyOwner == null || !config.notifyOwner) && (config.notifyQueue == null || !config.notifyQueue)) {
            TaskSlaUtils.debug('DailySummary', 'owner summary recipients disabled. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY);
            return;
        }
        String emailOverride = TaskSlaConfig.getSandboxEmailOverride();

        Set<String> closedStatuses = TaskSlaConfig.getClosedStatusValues();
        Set<String> canceledStatuses = TaskSlaConfig.getCanceledStatusValues();

        List<Task> tasks = queryOpenTasks(closedStatuses, canceledStatuses);
        if (tasks.isEmpty()) {
            TaskSlaUtils.debug('DailySummary', 'owner summary empty. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY);
            return;
        }

        Set<Id> ownerIds = new Set<Id>();
        for (Task taskRecord : tasks) {
            ownerIds.add(taskRecord.OwnerId);
        }

        TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(ownerIds, true);
        Map<Id, String> queueDevNames = context.queueDeveloperNameById;

        List<Task> filteredTasks = applyConfigFilter(tasks, config, queueDevNames);
        if (filteredTasks.isEmpty()) {
            TaskSlaUtils.debug('DailySummary', 'owner summary filtered empty. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY);
            return;
        }

        Map<Id, List<Task>> ownerToTasks = new Map<Id, List<Task>>();
        for (Task taskRecord : filteredTasks) {
            if (!ownerToTasks.containsKey(taskRecord.OwnerId)) {
                ownerToTasks.put(taskRecord.OwnerId, new List<Task>());
            }
            ownerToTasks.get(taskRecord.OwnerId).add(taskRecord);
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Log__c> logs = new List<Log__c>();

        for (Id ownerId : ownerToTasks.keySet()) {
            List<Task> ownerTasks = ownerToTasks.get(ownerId);
            if (TaskSlaUtils.isUserOwner(ownerId)) {
                if (config.notifyOwner == null || !config.notifyOwner) {
                    continue;
                }
                User owner = context.ownersById.get(ownerId);
                if (owner == null || !owner.IsActive || String.isBlank(owner.Email)) {
                    continue;
                }
                Messaging.SingleEmailMessage email = buildOwnerSummaryEmail(
                    owner,
                    ownerTasks,
                    config,
                    today,
                    tomorrow,
                    emailOverride
                );
                emails.add(email);
                addSummaryLogs(logs, ownerId, TaskSlaConfig.TYPE_OWNER_OPEN_DAILY, ownerTasks.size());
            } else if (TaskSlaUtils.isQueueOwner(ownerId)) {
                if (config.notifyQueue == null || !config.notifyQueue) {
                    continue;
                }
                TaskSlaRecipientResolver.RecipientResult recipients = TaskSlaRecipientResolver.resolveRecipients(
                    new Task(OwnerId = ownerId),
                    config,
                    context
                );
                if (recipients.userIds.isEmpty() && recipients.emailAddresses.isEmpty()) {
                    continue;
                }
                String queueName = context.queuesById.containsKey(ownerId) ? context.queuesById.get(ownerId).Name : 'Fila';
                Messaging.SingleEmailMessage baseEmail = buildQueueSummaryEmail(
                    queueName,
                    ownerTasks,
                    'Resumo Diario - Tarefas em Aberto',
                    config,
                    emailOverride
                );
                if (!String.isBlank(emailOverride)) {
                    emails.add(baseEmail);
                } else {
                    for (Id userId : recipients.userIds) {
                        emails.add(cloneEmailForUser(baseEmail, userId));
                    }
                    for (String address : recipients.emailAddresses) {
                        emails.add(cloneEmailForAddress(baseEmail, address));
                    }
                }
                addSummaryLogs(logs, ownerId, TaskSlaConfig.TYPE_OWNER_OPEN_DAILY, ownerTasks.size());
            }
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            TaskSlaNotificationService.sendEmailsInChunks(emails);
        }

        if (!logs.isEmpty()) {
            Database.insert(logs, false);
        }

        TaskSlaUtils.debug(
            'DailySummary',
            'owner summary done. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
            + ' tasks=' + tasks.size()
            + ' filtered=' + filteredTasks.size()
            + ' owners=' + ownerToTasks.size()
            + ' emails=' + emails.size()
            + ' logs=' + logs.size()
            + ' override=' + (String.isBlank(emailOverride) ? 'none' : emailOverride)
        );
    }

    private static List<Task> queryManagerTasks(
        Date today,
        Date tomorrow,
        Boolean overdue,
        Set<String> closedStatuses,
        Set<String> canceledStatuses
    ) {
        String dateFilter = overdue ? 'ActivityDate < :today' : 'ActivityDate = :tomorrow';
        String baseQuery = 'SELECT Id, Subject, Description, ActivityDate, OwnerId, Owner.Name, '
            + 'WhatId, WhoId, Priority, TaskSubtype, Type, Status '
            + 'FROM Task WHERE ActivityDate != null AND ' + dateFilter;

        if (!closedStatuses.isEmpty()) {
            baseQuery += ' AND Status NOT IN :closedStatuses';
        }
        if (!canceledStatuses.isEmpty()) {
            baseQuery += ' AND Status NOT IN :canceledStatuses';
        }

        return Database.query(baseQuery);
    }

    private static List<Task> queryOpenTasks(
        Set<String> closedStatuses,
        Set<String> canceledStatuses
    ) {
        String baseQuery = 'SELECT Id, Subject, Description, ActivityDate, OwnerId, Owner.Name, '
            + 'WhatId, WhoId, Priority, TaskSubtype, Type, Status '
            + 'FROM Task WHERE Id != null';

        if (!closedStatuses.isEmpty()) {
            baseQuery += ' AND Status NOT IN :closedStatuses';
        }
        if (!canceledStatuses.isEmpty()) {
            baseQuery += ' AND Status NOT IN :canceledStatuses';
        }

        return Database.query(baseQuery);
    }

    private static List<Task> applyConfigFilter(
        List<Task> tasks,
        TaskSlaConfig.NotificationConfig config,
        Map<Id, String> queueDevNames
    ) {
        if (tasks == null || tasks.isEmpty()) {
            return new List<Task>();
        }
        if (config == null) {
            return tasks;
        }
        List<Task> filtered = new List<Task>();
        for (Task taskRecord : tasks) {
            if (TaskSlaUtils.matchesConfig(taskRecord, config, queueDevNames)) {
                filtered.add(taskRecord);
            }
        }
        return filtered;
    }

    private static Messaging.SingleEmailMessage buildManagerSummaryEmail(
        User manager,
        List<Task> tasks,
        String subjectPrefix,
        TaskSlaConfig.NotificationConfig config,
        String emailOverride,
        Map<Id, String> relatedNames
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        if (!String.isBlank(emailOverride)) {
            email.setToAddresses(new String[]{ emailOverride });
        } else {
            email.setTargetObjectId(manager.Id);
            email.setTreatTargetObjectAsRecipient(true);
        }
        email.setSaveAsActivity(false);
        email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
        email.setHtmlBody(buildManagerSummaryBody(manager.Name, tasks, config, relatedNames));
        return email;
    }

    private static Messaging.SingleEmailMessage buildQueueManagerSummaryEmail(
        String queueName,
        List<Task> tasks,
        String subjectPrefix,
        TaskSlaConfig.NotificationConfig config,
        String emailOverride,
        Map<Id, String> relatedNames
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        if (!String.isBlank(emailOverride)) {
            email.setToAddresses(new String[]{ emailOverride });
        }
        email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
        email.setHtmlBody(buildManagerSummaryBody(queueName, tasks, config, relatedNames));
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildQueueSummaryEmail(
        String queueName,
        List<Task> tasks,
        String subjectPrefix,
        TaskSlaConfig.NotificationConfig config,
        String emailOverride
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        if (!String.isBlank(emailOverride)) {
            email.setToAddresses(new String[]{ emailOverride });
        }
        email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
        email.setHtmlBody(buildSummaryBody(queueName, tasks, config));
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildOwnerSummaryEmail(
        User owner,
        List<Task> tasks,
        TaskSlaConfig.NotificationConfig config,
        Date today,
        Date tomorrow,
        String emailOverride
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        if (!String.isBlank(emailOverride)) {
            email.setToAddresses(new String[]{ emailOverride });
        } else {
            email.setTargetObjectId(owner.Id);
            email.setTreatTargetObjectAsRecipient(true);
        }
        email.setSaveAsActivity(false);
        email.setSubject('Resumo Diario - ' + formatDate(today));
        email.setHtmlBody(buildOwnerSummaryBody(owner.Name, tasks, config, today, tomorrow));
        return email;
    }

    private static Messaging.SingleEmailMessage cloneEmailForUser(Messaging.SingleEmailMessage baseEmail, Id userId) {
        Messaging.SingleEmailMessage cloneEmail = new Messaging.SingleEmailMessage();
        cloneEmail.setSubject(baseEmail.getSubject());
        cloneEmail.setHtmlBody(baseEmail.getHtmlBody());
        cloneEmail.setTargetObjectId(userId);
        cloneEmail.setTreatTargetObjectAsRecipient(true);
        cloneEmail.setSaveAsActivity(false);
        return cloneEmail;
    }

    private static Messaging.SingleEmailMessage cloneEmailForAddress(
        Messaging.SingleEmailMessage baseEmail,
        String address
    ) {
        Messaging.SingleEmailMessage cloneEmail = new Messaging.SingleEmailMessage();
        cloneEmail.setSubject(baseEmail.getSubject());
        cloneEmail.setHtmlBody(baseEmail.getHtmlBody());
        cloneEmail.setToAddresses(new String[]{ address });
        cloneEmail.setSaveAsActivity(false);
        return cloneEmail;
    }

    private static String buildManagerSummaryBody(
        String recipientName,
        List<Task> tasks,
        TaskSlaConfig.NotificationConfig config,
        Map<Id, String> relatedNames
    ) {
        Integer topN = resolveTopN(config, 30, 30);
        List<Task> limited = limitTasks(tasks, topN);
        String link = config != null ? config.reportLink : null;

        String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
        body += '<tr><td align="center">';
        body += '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
        body += '<tr><td style="padding:20px 24px;background:linear-gradient(135deg,#0f172a,#1e293b);color:#ffffff;">';
        body += '<div style="font-size:18px;font-weight:600;">Resumo de tarefas</div>';
        body += '<div style="font-size:13px;opacity:.85;margin-top:6px;">Ola, ' + TaskSlaUtils.escapeHtml(recipientName) + '</div>';
        body += '</td></tr>';
        body += '<tr><td style="padding:20px 24px;">';
        body += '<div style="font-size:14px;color:#0f172a;margin-bottom:12px;">Total de tarefas: ';
        body += '<span style="display:inline-block;background:#e2e8f0;color:#0f172a;padding:2px 10px;border-radius:999px;font-weight:600;">';
        body += String.valueOf(tasks.size()) + '</span></div>';

        for (Task t : limited) {
            String taskLink = buildTaskLink(t);
            String subject = TaskSlaUtils.escapeHtml(t.Subject);
            String dueDate = formatDateOrPlaceholder(t.ActivityDate);
            String ownerName = t.Owner != null ? TaskSlaUtils.escapeHtml(t.Owner.Name) : '';
            String relatedHtml = buildRelatedHtml(t, relatedNames);
            String descriptionHtml = formatDescription(t.Description);

            body += '<div style="padding:12px 0;border-bottom:1px solid #e5e7eb;">';
            body += '<div style="font-size:14px;color:#111827;font-weight:600;">';
            if (!String.isBlank(taskLink)) {
                body += '<a href="' + taskLink + '" style="color:#2563eb;text-decoration:none;">' + subject + '</a>';
            } else {
                body += subject;
            }
            body += '</div>';
            body += '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' + TaskSlaUtils.escapeHtml(dueDate);
            if (!String.isBlank(ownerName)) {
                body += ' | Owner: ' + ownerName;
            }
            body += '</div>';
            if (!String.isBlank(relatedHtml)) {
                body += '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Relacionado: ' + relatedHtml + '</div>';
            }
            if (!String.isBlank(descriptionHtml)) {
                body += '<div style="font-size:12px;color:#334155;margin-top:6px;line-height:1.4;">' + descriptionHtml + '</div>';
            }
            body += '</div>';
        }

        if (!String.isBlank(link)) {
            body += '<div style="margin-top:16px;">';
            body += '<a href="' + link + '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Ver lista completa</a>';
            body += '</div>';
        }
        body += '</td></tr>';
        body += '<tr><td style="padding:16px 24px;background:#f8fafc;color:#94a3b8;font-size:11px;text-align:center;">';
        body += 'Email automatico - SLA de Tarefas';
        body += '</td></tr>';
        body += '</table>';
        body += '</td></tr></table>';
        body += '</body></html>';
        return body;
    }

    private static String buildSummaryBody(String recipientName, List<Task> tasks, TaskSlaConfig.NotificationConfig config) {
        Integer topN = config != null && config.topN != null ? config.topN : 10;
        List<Task> limited = limitTasks(tasks, topN);
        String link = config != null ? config.reportLink : null;
        String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
        body += '<tr><td align="center">';
        body += '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
        body += '<tr><td style="padding:20px 24px;background:linear-gradient(135deg,#0f172a,#1e293b);color:#ffffff;">';
        body += '<div style="font-size:18px;font-weight:600;">Resumo de tarefas</div>';
        body += '<div style="font-size:13px;opacity:.85;margin-top:6px;">Ola, ' + TaskSlaUtils.escapeHtml(recipientName) + '</div>';
        body += '</td></tr>';
        body += '<tr><td style="padding:20px 24px;">';
        body += '<div style="font-size:14px;color:#0f172a;margin-bottom:12px;">Total de tarefas: ';
        body += '<span style="display:inline-block;background:#e2e8f0;color:#0f172a;padding:2px 10px;border-radius:999px;font-weight:600;">';
        body += String.valueOf(tasks.size()) + '</span></div>';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">';
        for (Task t : limited) {
            String taskLink = buildTaskLink(t);
            String subject = TaskSlaUtils.escapeHtml(t.Subject);
            String dueDate = formatDateOrPlaceholder(t.ActivityDate);
            body += '<tr>';
            body += '<td style="padding:10px 0;border-bottom:1px solid #e5e7eb;">';
            body += '<div style="font-size:14px;color:#111827;font-weight:600;">';
            if (!String.isBlank(taskLink)) {
                body += '<a href="' + taskLink + '" style="color:#2563eb;text-decoration:none;">' + subject + '</a>';
            } else {
                body += subject;
            }
            body += '</div>';
            body += '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' + TaskSlaUtils.escapeHtml(dueDate) + '</div>';
            body += '</td>';
            body += '</tr>';
        }
        body += '</table>';
        if (!String.isBlank(link)) {
            body += '<div style="margin-top:16px;">';
            body += '<a href="' + link + '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Ver lista completa</a>';
            body += '</div>';
        }
        body += '</td></tr>';
        body += '<tr><td style="padding:16px 24px;background:#f8fafc;color:#94a3b8;font-size:11px;text-align:center;">';
        body += 'Email automatico - SLA de Tarefas';
        body += '</td></tr>';
        body += '</table>';
        body += '</td></tr></table>';
        body += '</body></html>';
        return body;
    }

    private static String buildOwnerSummaryBody(
        String recipientName,
        List<Task> tasks,
        TaskSlaConfig.NotificationConfig config,
        Date today,
        Date tomorrow
    ) {
        Integer topN = config != null && config.topN != null ? config.topN : 10;
        Map<String, List<Task>> buckets = new Map<String, List<Task>>();
        buckets.put('Vencidas', new List<Task>());
        buckets.put('Hoje', new List<Task>());
        buckets.put('Amanha', new List<Task>());
        buckets.put('Futuras', new List<Task>());
        buckets.put('Sem data', new List<Task>());

        for (Task t : tasks) {
            if (t.ActivityDate == null) {
                buckets.get('Sem data').add(t);
                continue;
            }
            if (t.ActivityDate < today) {
                buckets.get('Vencidas').add(t);
            } else if (t.ActivityDate == today) {
                buckets.get('Hoje').add(t);
            } else if (t.ActivityDate == tomorrow) {
                buckets.get('Amanha').add(t);
            } else {
                buckets.get('Futuras').add(t);
            }
        }

        String link = config != null ? config.reportLink : null;
        String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
        body += '<tr><td align="center">';
        body += '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
        body += '<tr><td style="padding:20px 24px;background:linear-gradient(135deg,#0f172a,#1e293b);color:#ffffff;">';
        body += '<div style="font-size:18px;font-weight:600;">Resumo diario - tarefas em aberto</div>';
        body += '<div style="font-size:13px;opacity:.85;margin-top:6px;">Ola, ' + TaskSlaUtils.escapeHtml(recipientName) + '</div>';
        body += '</td></tr>';
        body += '<tr><td style="padding:20px 24px;">';
        body += '<div style="font-size:14px;color:#0f172a;margin-bottom:12px;">Total em aberto: ';
        body += '<span style="display:inline-block;background:#e2e8f0;color:#0f172a;padding:2px 10px;border-radius:999px;font-weight:600;">';
        body += String.valueOf(tasks.size()) + '</span></div>';
        body += buildBucketSection('Vencidas', buckets.get('Vencidas'), topN);
        body += buildBucketSection('Hoje', buckets.get('Hoje'), topN);
        body += buildBucketSection('Amanha', buckets.get('Amanha'), topN);
        body += buildBucketSection('Futuras', buckets.get('Futuras'), topN);
        body += buildBucketSection('Sem data', buckets.get('Sem data'), topN);
        if (!String.isBlank(link)) {
            body += '<div style="margin-top:16px;">';
            body += '<a href="' + link + '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Ver lista completa</a>';
            body += '</div>';
        }
        body += '</td></tr>';
        body += '<tr><td style="padding:16px 24px;background:#f8fafc;color:#94a3b8;font-size:11px;text-align:center;">';
        body += 'Email automatico - SLA de Tarefas';
        body += '</td></tr>';
        body += '</table>';
        body += '</td></tr></table>';
        body += '</body></html>';
        return body;
    }

    private static String buildBucketSection(String title, List<Task> tasks, Integer topN) {
        String section = '<div style="margin:16px 0 8px 0;">';
        section += '<div style="font-size:14px;font-weight:600;color:#0f172a;">' + TaskSlaUtils.escapeHtml(title)
            + ' <span style="background:#e2e8f0;color:#0f172a;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:600;">'
            + tasks.size() + '</span></div>';
        if (tasks.isEmpty()) {
            section += '<div style="font-size:12px;color:#6b7280;margin-top:6px;">Nenhuma tarefa.</div>';
            section += '</div>';
            return section;
        }
        List<Task> limited = limitTasks(tasks, topN);
        section += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:8px;">';
        for (Task t : limited) {
            String taskLink = buildTaskLink(t);
            String subject = TaskSlaUtils.escapeHtml(t.Subject);
            String dueDate = formatDateOrPlaceholder(t.ActivityDate);
            section += '<tr><td style="padding:8px 0;border-bottom:1px solid #e5e7eb;">';
            section += '<div style="font-size:13px;color:#111827;font-weight:600;">';
            if (!String.isBlank(taskLink)) {
                section += '<a href="' + taskLink + '" style="color:#2563eb;text-decoration:none;">' + subject + '</a>';
            } else {
                section += subject;
            }
            section += '</div>';
            section += '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' + TaskSlaUtils.escapeHtml(dueDate) + '</div>';
            section += '</td></tr>';
        }
        section += '</table>';
        section += '</div>';
        return section;
    }

    private static List<Task> limitTasks(List<Task> tasks, Integer topN) {
        if (tasks == null) {
            return new List<Task>();
        }
        if (topN == null || topN <= 0 || tasks.size() <= topN) {
            return tasks;
        }
        List<Task> limited = new List<Task>();
        Integer maxItems = Math.min(topN, tasks.size());
        for (Integer idx = 0; idx < maxItems; idx++) {
            limited.add(tasks[idx]);
        }
        return limited;
    }

    private static Integer resolveTopN(
        TaskSlaConfig.NotificationConfig config,
        Integer defaultTopN,
        Integer maxTopN
    ) {
        Integer result = defaultTopN != null ? defaultTopN : 10;
        if (config != null && config.topN != null && config.topN > 0) {
            result = config.topN;
        }
        if (maxTopN != null && result > maxTopN) {
            result = maxTopN;
        }
        return result;
    }

    private static String formatDescription(String description) {
        if (String.isBlank(description)) {
            return '';
        }
        String safe = TaskSlaUtils.escapeHtml(description);
        safe = safe.replace('\r\n', '<br/>');
        safe = safe.replace('\n', '<br/>');
        return safe;
    }

    private static Map<Id, String> fetchRelatedNames(List<Task> tasks) {
        Set<Id> relatedIds = new Set<Id>();
        if (tasks != null) {
            for (Task t : tasks) {
                if (t.WhatId != null) {
                    relatedIds.add(t.WhatId);
                }
                if (t.WhoId != null) {
                    relatedIds.add(t.WhoId);
                }
            }
        }
        return fetchRelatedNamesById(relatedIds);
    }

    private static Map<Id, String> fetchRelatedNamesById(Set<Id> relatedIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (relatedIds == null || relatedIds.isEmpty()) {
            return result;
        }

        Map<String, Set<Id>> idsByType = new Map<String, Set<Id>>();
        for (Id relId : relatedIds) {
            if (relId == null) {
                continue;
            }
            String apiName = relId.getSObjectType().getDescribe().getName();
            if (!idsByType.containsKey(apiName)) {
                idsByType.put(apiName, new Set<Id>());
            }
            idsByType.get(apiName).add(relId);
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (String apiName : idsByType.keySet()) {
            Schema.SObjectType sobjectType = globalDescribe.get(apiName);
            if (sobjectType == null) {
                continue;
            }
            Schema.DescribeSObjectResult describe = sobjectType.getDescribe();
            String nameField = resolveNameFieldApiName(describe);
            if (String.isBlank(nameField)) {
                continue;
            }
            Set<Id> idsForType = idsByType.get(apiName);
            if (idsForType == null || idsForType.isEmpty()) {
                continue;
            }
            String soql = 'SELECT Id, ' + nameField + ' FROM ' + apiName + ' WHERE Id IN :idsForType';
            List<SObject> records = Database.query(soql);
            for (SObject record : records) {
                Object value = record.get(nameField);
                if (value != null) {
                    result.put((Id) record.get('Id'), String.valueOf(value));
                }
            }
        }

        return result;
    }

    private static String resolveNameFieldApiName(Schema.DescribeSObjectResult describe) {
        if (describe == null) {
            return '';
        }
        Map<String, Schema.SObjectField> fields = describe.fields.getMap();
        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName).getDescribe();
            if (fieldDescribe != null && fieldDescribe.isNameField()) {
                return fieldDescribe.getName();
            }
        }
        return '';
    }

    private static String buildRelatedHtml(Task taskRecord, Map<Id, String> relatedNames) {
        if (taskRecord == null) {
            return '';
        }
        Id relatedId = taskRecord.WhatId != null ? taskRecord.WhatId : taskRecord.WhoId;
        if (relatedId == null) {
            return '';
        }
        String label = relatedId.getSObjectType().getDescribe().getLabel();
        String name = relatedNames != null ? relatedNames.get(relatedId) : null;
        String safeLabel = TaskSlaUtils.escapeHtml(label);
        String safeName = TaskSlaUtils.escapeHtml(name);
        String display = !String.isBlank(safeName) ? safeLabel + ' - ' + safeName : safeLabel;
        String link = buildRecordLink(relatedId);
        if (String.isBlank(link)) {
            return display;
        }
        return '<a href="' + link + '" style="color:#2563eb;text-decoration:none;">' + display + '</a>';
    }

    private static void addSummaryLogs(List<Log__c> logs, Id relatedId, String type, Integer count) {
        if (logs == null) {
            return;
        }
        Log__c log = new Log__c();
        log.Name = 'TaskSLA Summary';
        log.Type__c = type;
        log.RelatedId__c = relatedId != null ? String.valueOf(relatedId) : null;
        log.Message__c = 'TotalTasks=' + String.valueOf(count);
        logs.add(log);
    }

    private static String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }
        return dateValue.format();
    }

    private static String formatDateOrPlaceholder(Date dateValue) {
        if (dateValue == null) {
            return 'Sem data';
        }
        return dateValue.format();
    }

    private static String buildTaskLink(Task taskRecord) {
        if (taskRecord == null || taskRecord.Id == null) {
            return '';
        }
        return buildRecordLink(taskRecord.Id);
    }

    private static String buildRecordLink(Id recordId) {
        if (recordId == null) {
            return '';
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String objectName = recordId.getSObjectType().getDescribe().getName();
        return baseUrl + '/lightning/r/' + objectName + '/' + String.valueOf(recordId) + '/view';
    }

}