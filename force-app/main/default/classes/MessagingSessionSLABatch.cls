/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-05-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class MessagingSessionSLABatch implements Database.Batchable<SObject> {

    @TestVisible
    public static final String NOTIFICATION_TYPE_DEVELOPER_NAME = 'Padrao';

    private Id notificationTypeId;
    @TestVisible
    private static Id businessHoursId;

    public MessagingSessionSLABatch() {
        notificationTypeId = loadNotificationTypeId();
        if (businessHoursId == null) {
            businessHoursId = loadBusinessHoursId();
        }
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT  Id,
                    Name,
                    OwnerId,
                    EndTime,
                    OwnerAssignmentDate__c,
                    MinuteSLAN1__c,
                    MinuteSLAN2__c,
                    MinuteSLAN3__c,
                    NotifyN1__c,
                    NotifyN2__c,
                    NotifyN3__c,
                    QueueSupervisorRole__c,
                    QueueCoordinatorRole__c
            FROM    MessagingSession
            WHERE   OwnerAssignmentDate__c != null
                AND EndTime = null
                AND (
                        (MinuteSLAN1__c != null AND NotifyN1__c = false) OR
                        (MinuteSLAN2__c != null AND NotifyN2__c = false) OR
                        (MinuteSLAN3__c != null AND NotifyN3__c = false)
                    )
        ]);
    }

    public void execute(Database.BatchableContext context, List<MessagingSession> scope) {
        if (scope.isEmpty()) {
            return;
        }

        DateTime now = System.now();
        if (!isWithinBusinessHours(now)) {
            return;
        }

        List<PendingNotification> pendingNotifications = new List<PendingNotification>();
        Set<Id> queueIds = new Set<Id>();
        Set<String> roleNames = new Set<String>();

        for (MessagingSession session : scope) {
            if (session.OwnerAssignmentDate__c == null) {
                continue;
            }

            Long elapsedMinutes = (now.getTime() - session.OwnerAssignmentDate__c.getTime()) / 60000;
            if (elapsedMinutes < 0) {
                continue;
            }

            prepareStageNotification(session, 1, session.MinuteSLAN1__c, session.NotifyN1__c,
                elapsedMinutes, pendingNotifications, queueIds, roleNames);
            prepareStageNotification(session, 2, session.MinuteSLAN2__c, session.NotifyN2__c,
                elapsedMinutes, pendingNotifications, queueIds, roleNames);
            prepareStageNotification(session, 3, session.MinuteSLAN3__c, session.NotifyN3__c,
                elapsedMinutes, pendingNotifications, queueIds, roleNames);
        }

        if (pendingNotifications.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> queueRecipients = loadQueueRecipients(queueIds);
        Map<String, Set<Id>> roleRecipients = loadRoleRecipients(roleNames);

        Map<Id, MessagingSession> sessionsToUpdate = new Map<Id, MessagingSession>();

        for (PendingNotification notificationData : pendingNotifications) {
            Set<Id> recipients = notificationData.collectRecipients(queueRecipients, roleRecipients);
            if (recipients.isEmpty()) {
                continue;
            }

            Boolean sent = sendNotificationThroughFlow(notificationData, recipients);
            if (!sent) {
                continue;
            }

            notificationData.markStageAsNotified();
            sessionsToUpdate.put(notificationData.session.Id, notificationData.session);
        }

        if (!sessionsToUpdate.isEmpty()) {
            update sessionsToUpdate.values();
        }
    }

    public void finish(Database.BatchableContext context) {
        // No-op
    }

    private void prepareStageNotification(
        MessagingSession session,
        Integer stageNumber,
        Decimal configuredMinutes,
        Boolean alreadyNotified,
        Long elapsedMinutes,
        List<PendingNotification> pendingNotifications,
        Set<Id> queueIds,
        Set<String> roleNames
    ) {
        if (configuredMinutes == null || alreadyNotified == true) {
            return;
        }

        if (elapsedMinutes < configuredMinutes.longValue()) {
            return;
        }

        PendingNotification data = new PendingNotification(session, stageNumber, configuredMinutes, elapsedMinutes);

        if (stageNumber == 1) {
            if (session.OwnerId != null) {
                if (session.OwnerId.getSObjectType() == Group.SObjectType) {
                    queueIds.add(session.OwnerId);
                    data.queueId = session.OwnerId;
                } else {
                    data.directRecipientIds.add(session.OwnerId);
                }
            }
        } else if (stageNumber == 2) {
            if (String.isNotBlank(session.QueueSupervisorRole__c)) {
                data.roleName = session.QueueSupervisorRole__c;
                roleNames.add(session.QueueSupervisorRole__c);
            }
        } else if (stageNumber == 3) {
            if (String.isNotBlank(session.QueueCoordinatorRole__c)) {
                data.roleName = session.QueueCoordinatorRole__c;
                roleNames.add(session.QueueCoordinatorRole__c);
            }
        }

        pendingNotifications.add(data);
    }

    private Map<Id, Set<Id>> loadQueueRecipients(Set<Id> queueIds) {
        Map<Id, Set<Id>> recipientsByQueue = new Map<Id, Set<Id>>();
        if (queueIds.isEmpty()) {
            return recipientsByQueue;
        }

        for (GroupMember member : [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queueIds
        ]) {
            if (member.UserOrGroupId == null || member.UserOrGroupId.getSObjectType() != User.SObjectType) {
                continue;
            }

            if (!recipientsByQueue.containsKey(member.GroupId)) {
                recipientsByQueue.put(member.GroupId, new Set<Id>());
            }
            recipientsByQueue.get(member.GroupId).add(member.UserOrGroupId);
        }

        return recipientsByQueue;
    }

    private Map<String, Set<Id>> loadRoleRecipients(Set<String> roleNames) {
        Map<String, Set<Id>> recipientsByRole = new Map<String, Set<Id>>();
        if (roleNames.isEmpty()) {
            return recipientsByRole;
        }

        for (User roleUser : [
            SELECT Id, UserRole.Name
            FROM User
            WHERE IsActive = true
                AND UserRole.Name IN :roleNames
        ]) {
            if (roleUser.UserRole == null || String.isBlank(roleUser.UserRole.Name)) {
                continue;
            }

            if (!recipientsByRole.containsKey(roleUser.UserRole.Name)) {
                recipientsByRole.put(roleUser.UserRole.Name, new Set<Id>());
            }
            recipientsByRole.get(roleUser.UserRole.Name).add(roleUser.Id);
        }

        return recipientsByRole;
    }

    private Boolean sendNotificationThroughFlow(PendingNotification data, Set<Id> recipients) {
        if (notificationTypeId == null) {
            return false;
        }

        Map<String, Object> inputs = new Map<String, Object>{
            'NotificationTypeId' => notificationTypeId,
            'NotificationTitle' => 'SLA N' + data.stageNumber + ' ultrapassado - ' + data.session.Name,
            'NotificationBody' => 'A sessão ' + data.session.Name +
                ' excedeu o SLA N' + data.stageNumber +
                ' após ' + String.valueOf(data.elapsedMinutes) + ' minutos (limite configurado: ' +
                String.valueOf(data.configuredMinutes.intValue()) + ' minutos).',
            'TargetId' => data.session.Id,
            'RecipientIds' => new List<String>()
        };

        for (Id recipientId : recipients) {
            ((List<String>) inputs.get('RecipientIds')).add((String) recipientId);
        }

        if (Test.isRunningTest()) {
            return true;
        }

        try {
            Flow.Interview interview = Flow.Interview.createInterview('Send_Custom_Notification', inputs);
            if (interview != null) {
                interview.start();
                return true;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Falha ao enviar notificação para sessão ' + data.session.Id + ': ' + e.getMessage());
        }

        return false;
    }

    private Id loadNotificationTypeId() {
        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = :NOTIFICATION_TYPE_DEVELOPER_NAME
            LIMIT 1
        ];

        return notificationTypes.isEmpty() ? null : notificationTypes[0].Id;
    }

    private static Id loadBusinessHoursId() {
        if (businessHoursId != null) {
            return businessHoursId;
        }

        List<BusinessHours> records = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        businessHoursId = records.isEmpty() ? null : records[0].Id;
        return businessHoursId;
    }

    @TestVisible
    public static void setBusinessHoursId(Id newId) {
        businessHoursId = newId;
    }

    @TestVisible
    public static Boolean isWithinBusinessHours(DateTime moment) {
        if (moment == null) {
            return false;
        }

        Id bhId = loadBusinessHoursId();
        if (bhId == null) {
            return false;
        }

        return BusinessHours.isWithin(bhId, moment);
    }

    private class PendingNotification {
        final MessagingSession session;
        final Integer stageNumber;
        final Decimal configuredMinutes;
        final Long elapsedMinutes;
        Id queueId;
        String roleName;
        Set<Id> directRecipientIds = new Set<Id>();

        PendingNotification(
            MessagingSession session,
            Integer stageNumber,
            Decimal configuredMinutes,
            Long elapsedMinutes
        ) {
            this.session = session;
            this.stageNumber = stageNumber;
            this.configuredMinutes = configuredMinutes;
            this.elapsedMinutes = elapsedMinutes;
        }

        Set<Id> collectRecipients(Map<Id, Set<Id>> queueRecipients, Map<String, Set<Id>> roleRecipients) {
            Set<Id> recipients = new Set<Id>();
            recipients.addAll(directRecipientIds);

            if (queueId != null && queueRecipients.containsKey(queueId)) {
                recipients.addAll(queueRecipients.get(queueId));
            }

            if (String.isNotBlank(roleName) && roleRecipients.containsKey(roleName)) {
                recipients.addAll(roleRecipients.get(roleName));
            }

            return recipients;
        }

        void markStageAsNotified() {
            if (stageNumber == 1) {
                session.NotifyN1__c = true;
            } else if (stageNumber == 2) {
                session.NotifyN2__c = true;
            } else if (stageNumber == 3) {
                session.NotifyN3__c = true;
            }
        }
    }
}
