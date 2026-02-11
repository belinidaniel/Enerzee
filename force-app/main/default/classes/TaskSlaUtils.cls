public with sharing class TaskSlaUtils {
    private static final String DEBUG_PREFIX = '[TaskSLA] ';

    public static Boolean isUserOwner(Id ownerId) {
        return ownerId != null && String.valueOf(ownerId).startsWith('005');
    }

    public static Boolean isQueueOwner(Id ownerId) {
        return ownerId != null && String.valueOf(ownerId).startsWith('00G');
    }

    public static Boolean isClosedOrCanceled(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        String normalized = normalizeToken(status);
        return TaskSlaConfig.getClosedStatuses().contains(normalized)
            || TaskSlaConfig.getCanceledStatuses().contains(normalized);
    }

    public static Boolean matchesConfig(
        Task task,
        TaskSlaConfig.NotificationConfig config,
        Map<Id, String> queueDeveloperNameById
    ) {
        if (task == null || config == null) {
            return false;
        }

        if (!matchesOwnerType(task.OwnerId, config)) {
            return false;
        }

        if (!matchesQueueFilter(task.OwnerId, config, queueDeveloperNameById)) {
            return false;
        }

        if (!matchesStringSet(task.Priority, config.priorityIn)) {
            return false;
        }

        if (!matchesStringSet(task.TaskSubtype, config.taskSubtypeIn)) {
            return false;
        }

        if (!matchesStringSet(task.Type, config.taskTypeIn)) {
            return false;
        }

        if (!matchesContains(task.Subject, config.subjectContains, true)) {
            return false;
        }

        if (!matchesContains(task.Subject, config.subjectNotContains, false)) {
            return false;
        }

        return true;
    }

    private static Boolean matchesOwnerType(Id ownerId, TaskSlaConfig.NotificationConfig config) {
        if (config == null || String.isBlank(config.ownerType)
            || TaskSlaConfig.OWNER_TYPE_ANY.equalsIgnoreCase(config.ownerType)) {
            return true;
        }
        if (TaskSlaConfig.OWNER_TYPE_USER.equalsIgnoreCase(config.ownerType)) {
            return isUserOwner(ownerId);
        }
        if (TaskSlaConfig.OWNER_TYPE_QUEUE.equalsIgnoreCase(config.ownerType)) {
            return isQueueOwner(ownerId);
        }
        return true;
    }

    private static Boolean matchesQueueFilter(
        Id ownerId,
        TaskSlaConfig.NotificationConfig config,
        Map<Id, String> queueDeveloperNameById
    ) {
        if (config == null || config.queueDeveloperNames == null || config.queueDeveloperNames.isEmpty()) {
            return true;
        }
        if (!isQueueOwner(ownerId)) {
            return false;
        }
        if (queueDeveloperNameById == null) {
            return false;
        }
        String devName = queueDeveloperNameById.get(ownerId);
        if (String.isBlank(devName)) {
            return false;
        }
        return config.queueDeveloperNames.contains(normalizeToken(devName));
    }

    private static Boolean matchesStringSet(String value, Set<String> allowed) {
        if (allowed == null || allowed.isEmpty()) {
            return true;
        }
        if (String.isBlank(value)) {
            return false;
        }
        return allowed.contains(normalizeToken(value));
    }

    private static Boolean matchesContains(String value, Set<String> tokens, Boolean requireMatch) {
        if (tokens == null || tokens.isEmpty()) {
            return true;
        }
        if (String.isBlank(value)) {
            return !requireMatch;
        }
        String normalized = normalizeToken(value);
        Boolean matched = false;
        for (String token : tokens) {
            if (String.isBlank(token)) {
                continue;
            }
            if (normalized.contains(token)) {
                matched = true;
                break;
            }
        }
        return requireMatch ? matched : !matched;
    }

    public static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.trim().toLowerCase();
    }

    public static String escapeHtml(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
    }

    public static void debug(String context, String message) {
        System.debug(LoggingLevel.INFO, DEBUG_PREFIX + context + ' | ' + message);
    }
}
