public with sharing class TaskSlaConfig {
    public static final String TYPE_BEFORE_DUE = 'TASK_BEFORE_DUE';
    public static final String TYPE_AFTER_DUE = 'TASK_AFTER_DUE';
    public static final String TYPE_MANAGER_OVERDUE = 'TASK_DAILY_MANAGER_OVERDUE';
    public static final String TYPE_MANAGER_DUE_TOMORROW = 'TASK_DAILY_MANAGER_DUE_TOMORROW';
    public static final String TYPE_OWNER_OPEN_DAILY = 'TASK_DAILY_OWNER_OPEN';
    public static final String TYPE_SLA_ALERT = 'TASK_SLA_ALERT';

    public static final String OWNER_TYPE_ANY = 'ANY';
    public static final String OWNER_TYPE_USER = 'USER';
    public static final String OWNER_TYPE_QUEUE = 'QUEUE';

    public static final String ROUTE_MEMBERS = 'MEMBERS';
    public static final String ROUTE_QUEUE_EMAIL = 'QUEUE_EMAIL';
    public static final String ROUTE_NONE = 'NONE';

    public class NotificationConfig {
        public String developerName;
        public Boolean enabled;
        public Integer minutesBeforeDue;
        public Integer minutesAfterDue;
        public Boolean notifyOwner;
        public Boolean notifyManager;
        public Boolean notifyQueue;
        public Boolean sendEmail;
        public Boolean sendBell;
        public Integer topN;
        public String ownerType;
        public String reportLink;
        public String customNotificationTypeDevName;
        public Set<String> subjectContains;
        public Set<String> subjectNotContains;
        public Set<String> priorityIn;
        public Set<String> taskSubtypeIn;
        public Set<String> taskTypeIn;
        public Set<String> queueDeveloperNames;

        public Boolean isOwnerTypeUser() {
            return OWNER_TYPE_USER.equalsIgnoreCase(ownerType);
        }

        public Boolean isOwnerTypeQueue() {
            return OWNER_TYPE_QUEUE.equalsIgnoreCase(ownerType);
        }
    }

    public class QueueRoutingConfig {
        public String routingMode;
        public String fallbackMode;
    }

    private static Map<String, NotificationConfig> cachedConfigs;
    private static Set<String> cachedClosedStatuses;
    private static Set<String> cachedCanceledStatuses;
    private static Set<String> cachedClosedStatusValues;
    private static Set<String> cachedCanceledStatusValues;
    private static Map<String, QueueRoutingConfig> cachedQueueRouting;
    private static Boolean cachedIsSandbox;

    private static final String SANDBOX_OVERRIDE_EMAIL = 'daniel.belini@enerzee.com.br';

    public static NotificationConfig getNotificationConfig(String developerName) {
        if (cachedConfigs == null) {
            cachedConfigs = new Map<String, NotificationConfig>();
        }
        String key = developerName != null ? developerName.toUpperCase() : '';
        if (cachedConfigs.containsKey(key)) {
            return cachedConfigs.get(key);
        }

        NotificationConfig config = defaultsFor(key);
        SLA_Notification_Config__mdt record = SLA_Notification_Config__mdt.getInstance(key);
        if (record != null) {
            config.developerName = key;
            config.enabled = record.Enabled__c;
            if (record.MinutesBeforeDue__c != null) {
                config.minutesBeforeDue = Integer.valueOf(record.MinutesBeforeDue__c);
            }
            if (record.MinutesAfterDue__c != null) {
                config.minutesAfterDue = Integer.valueOf(record.MinutesAfterDue__c);
            }
            if (record.NotifyOwner__c != null) {
                config.notifyOwner = record.NotifyOwner__c;
            }
            if (record.NotifyManager__c != null) {
                config.notifyManager = record.NotifyManager__c;
            }
            if (record.NotifyQueue__c != null) {
                config.notifyQueue = record.NotifyQueue__c;
            }
            if (record.SendEmail__c != null) {
                config.sendEmail = record.SendEmail__c;
            }
            if (record.SendBell__c != null) {
                config.sendBell = record.SendBell__c;
            }
            if (record.TopN__c != null) {
                config.topN = Integer.valueOf(record.TopN__c);
            }
            if (record.OwnerType__c != null) {
                config.ownerType = record.OwnerType__c;
            }
            config.reportLink = record.ReportLink__c;
            config.customNotificationTypeDevName = record.CustomNotificationTypeDevName__c;
            config.subjectContains = parseSet(record.SubjectContains__c);
            config.subjectNotContains = parseSet(record.SubjectNotContains__c);
            config.priorityIn = parseSet(record.PriorityIn__c);
            config.taskSubtypeIn = parseSet(record.TaskSubtypeIn__c);
            config.taskTypeIn = parseSet(record.TaskTypeIn__c);
            config.queueDeveloperNames = parseSet(record.QueueDeveloperNames__c);
        }

        cachedConfigs.put(key, config);
        return config;
    }

    public static Set<String> getClosedStatuses() {
        if (cachedClosedStatuses != null) {
            return cachedClosedStatuses;
        }
        cachedClosedStatuses = new Set<String>();
        cachedCanceledStatuses = new Set<String>();
        cachedClosedStatusValues = new Set<String>();
        cachedCanceledStatusValues = new Set<String>();
        for (SLA_Status_Config__mdt statusRecord : SLA_Status_Config__mdt.getAll().values()) {
            if (statusRecord.Status__c == null) {
                continue;
            }
            String raw = statusRecord.Status__c.trim();
            String normalized = normalizeToken(statusRecord.Status__c);
            if (statusRecord.IsClosed__c) {
                cachedClosedStatuses.add(normalized);
                cachedClosedStatusValues.add(raw);
            }
            if (statusRecord.IsCanceled__c) {
                cachedCanceledStatuses.add(normalized);
                cachedCanceledStatusValues.add(raw);
            }
        }

        if (cachedClosedStatuses.isEmpty()) {
            cachedClosedStatuses.add(normalizeToken('Completed'));
            cachedClosedStatuses.add(normalizeToken('Closed'));
            cachedClosedStatuses.add(normalizeToken('Concluida'));
            cachedClosedStatusValues.add('Completed');
            cachedClosedStatusValues.add('Closed');
            cachedClosedStatusValues.add('Concluida');
        }
        if (cachedCanceledStatuses.isEmpty()) {
            cachedCanceledStatuses.add(normalizeToken('Canceled'));
            cachedCanceledStatuses.add(normalizeToken('Cancelled'));
            cachedCanceledStatuses.add(normalizeToken('Cancelada'));
            cachedCanceledStatuses.add(normalizeToken('Cancelado'));
            cachedCanceledStatusValues.add('Canceled');
            cachedCanceledStatusValues.add('Cancelled');
            cachedCanceledStatusValues.add('Cancelada');
            cachedCanceledStatusValues.add('Cancelado');
        }

        return cachedClosedStatuses;
    }

    public static Set<String> getCanceledStatuses() {
        if (cachedCanceledStatuses == null) {
            getClosedStatuses();
        }
        return cachedCanceledStatuses;
    }

    public static Set<String> getClosedStatusValues() {
        if (cachedClosedStatusValues == null) {
            getClosedStatuses();
        }
        return cachedClosedStatusValues;
    }

    public static Set<String> getCanceledStatusValues() {
        if (cachedCanceledStatusValues == null) {
            getClosedStatuses();
        }
        return cachedCanceledStatusValues;
    }

    public static QueueRoutingConfig getQueueRoutingConfig(String queueDeveloperName) {
        if (cachedQueueRouting == null) {
            cachedQueueRouting = new Map<String, QueueRoutingConfig>();
            for (SLA_Queue_Routing_Config__mdt routing : SLA_Queue_Routing_Config__mdt.getAll().values()) {
                QueueRoutingConfig cfg = new QueueRoutingConfig();
                cfg.routingMode = routing.RoutingMode__c;
                cfg.fallbackMode = routing.FallbackMode__c;
                cachedQueueRouting.put(routing.DeveloperName != null ? routing.DeveloperName.toUpperCase() : '', cfg);
            }
        }

        String key = queueDeveloperName != null ? queueDeveloperName.toUpperCase() : '';
        QueueRoutingConfig result = cachedQueueRouting.get(key);
        if (result == null) {
            result = cachedQueueRouting.get('DEFAULT');
        }
        if (result == null) {
            result = new QueueRoutingConfig();
            result.routingMode = ROUTE_MEMBERS;
            result.fallbackMode = ROUTE_NONE;
        }
        if (String.isBlank(result.routingMode)) {
            result.routingMode = ROUTE_MEMBERS;
        }
        if (String.isBlank(result.fallbackMode)) {
            result.fallbackMode = ROUTE_NONE;
        }
        return result;
    }

    public static String getSandboxEmailOverride() {
        if (isSandbox()) {
            return SANDBOX_OVERRIDE_EMAIL;
        }
        return null;
    }

    public static Boolean isSandbox() {
        if (cachedIsSandbox != null) {
            return cachedIsSandbox;
        }
        Boolean result = false;
        try {
            Organization orgInfo = [SELECT IsSandbox FROM Organization LIMIT 1];
            result = orgInfo != null && orgInfo.IsSandbox;
        } catch (Exception e) {
            result = false;
        }
        cachedIsSandbox = result;
        return cachedIsSandbox;
    }

    private static NotificationConfig defaultsFor(String developerName) {
        NotificationConfig config = new NotificationConfig();
        config.developerName = developerName;
        config.enabled = false;
        config.minutesBeforeDue = 30;
        config.minutesAfterDue = 0;
        config.notifyOwner = true;
        config.notifyManager = false;
        config.notifyQueue = true;
        config.sendEmail = true;
        config.sendBell = true;
        config.topN = 10;
        config.ownerType = OWNER_TYPE_ANY;
        config.subjectContains = new Set<String>();
        config.subjectNotContains = new Set<String>();
        config.priorityIn = new Set<String>();
        config.taskSubtypeIn = new Set<String>();
        config.taskTypeIn = new Set<String>();
        config.queueDeveloperNames = new Set<String>();

        if (TYPE_BEFORE_DUE.equalsIgnoreCase(developerName)) {
            config.enabled = true;
            config.notifyManager = true;
        } else if (TYPE_AFTER_DUE.equalsIgnoreCase(developerName)) {
            config.enabled = true;
        }
        return config;
    }

    private static Set<String> parseSet(String value) {
        Set<String> result = new Set<String>();
        if (String.isBlank(value)) {
            return result;
        }
        for (String token : value.split('[,;]')) {
            String normalized = normalizeToken(token);
            if (!String.isBlank(normalized)) {
                result.add(normalized);
            }
        }
        return result;
    }

    private static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.trim().toLowerCase();
    }
}
