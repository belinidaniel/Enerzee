public with sharing class TaskSlaRecipientResolver {
    public class Context {
        public Map<Id, User> ownersById = new Map<Id, User>();
        public Map<Id, User> managersById = new Map<Id, User>();
        public Map<Id, Group> queuesById = new Map<Id, Group>();
        public Map<Id, Set<Id>> queueMembersById = new Map<Id, Set<Id>>();
        public Map<Id, String> queueDeveloperNameById = new Map<Id, String>();
        public Map<Id, String> queueEmailById = new Map<Id, String>();
    }

    public class RecipientResult {
        public Set<Id> userIds = new Set<Id>();
        public Set<String> emailAddresses = new Set<String>();
    }

    public static Context buildContext(Set<Id> ownerIds, Boolean loadQueueMembers) {
        Context context = new Context();
        if (ownerIds == null || ownerIds.isEmpty()) {
            return context;
        }

        Set<Id> userOwnerIds = new Set<Id>();
        Set<Id> queueOwnerIds = new Set<Id>();
        for (Id ownerId : ownerIds) {
            if (TaskSlaUtils.isUserOwner(ownerId)) {
                userOwnerIds.add(ownerId);
            } else if (TaskSlaUtils.isQueueOwner(ownerId)) {
                queueOwnerIds.add(ownerId);
            }
        }

        if (!userOwnerIds.isEmpty()) {
            for (User usr : [
                SELECT Id, Name, Email, ManagerId, IsActive
                FROM User
                WHERE Id IN :userOwnerIds
            ]) {
                context.ownersById.put(usr.Id, usr);
            }
        }

        Set<Id> managerIds = new Set<Id>();
        for (User owner : context.ownersById.values()) {
            if (owner.ManagerId != null) {
                managerIds.add(owner.ManagerId);
            }
        }
        if (!managerIds.isEmpty()) {
            for (User mgr : [
                SELECT Id, Name, Email, ManagerId, IsActive
                FROM User
                WHERE Id IN :managerIds
            ]) {
                context.managersById.put(mgr.Id, mgr);
            }
        }

        if (!queueOwnerIds.isEmpty()) {
            for (Group queue : [
                SELECT Id, Name, DeveloperName, Email, Type
                FROM Group
                WHERE Id IN :queueOwnerIds
                AND Type = 'Queue'
            ]) {
                context.queuesById.put(queue.Id, queue);
                context.queueDeveloperNameById.put(queue.Id, queue.DeveloperName);
                context.queueEmailById.put(queue.Id, queue.Email);
            }
        }

        if (loadQueueMembers && !queueOwnerIds.isEmpty()) {
            loadQueueMembers(queueOwnerIds, context);
        }

        return context;
    }

    public static RecipientResult resolveRecipients(
        Task task,
        TaskSlaConfig.NotificationConfig config,
        Context context
    ) {
        RecipientResult result = new RecipientResult();
        if (task == null || config == null || context == null) {
            return result;
        }

        if (TaskSlaUtils.isUserOwner(task.OwnerId)) {
            if (config.notifyOwner) {
                addUser(result, task.OwnerId, context.ownersById);
            }
            if (config.notifyManager) {
                User owner = context.ownersById.get(task.OwnerId);
                if (owner != null && owner.ManagerId != null) {
                    addUser(result, owner.ManagerId, context.managersById);
                }
            }
        } else if (TaskSlaUtils.isQueueOwner(task.OwnerId)) {
            if (config.notifyQueue) {
                addQueueRecipients(result, task.OwnerId, config, context);
            }
        }

        return result;
    }

    private static void addUser(RecipientResult result, Id userId, Map<Id, User> userMap) {
        if (result == null || userId == null) {
            return;
        }
        User usr = userMap != null ? userMap.get(userId) : null;
        if (usr != null && usr.IsActive) {
            result.userIds.add(usr.Id);
        }
    }

    private static void addQueueRecipients(
        RecipientResult result,
        Id queueId,
        TaskSlaConfig.NotificationConfig config,
        Context context
    ) {
        if (result == null || queueId == null || config == null || context == null) {
            return;
        }

        Group queue = context.queuesById.get(queueId);
        TaskSlaConfig.QueueRoutingConfig routing = TaskSlaConfig.getQueueRoutingConfig(
            queue != null ? queue.DeveloperName : null
        );

        Boolean added = applyQueueRouting(result, queueId, routing.routingMode, context);
        if (!added) {
            applyQueueRouting(result, queueId, routing.fallbackMode, context);
        }
    }

    private static Boolean applyQueueRouting(
        RecipientResult result,
        Id queueId,
        String mode,
        Context context
    ) {
        if (String.isBlank(mode)) {
            return false;
        }
        if (TaskSlaConfig.ROUTE_NONE.equalsIgnoreCase(mode)) {
            return true;
        }
        if (TaskSlaConfig.ROUTE_QUEUE_EMAIL.equalsIgnoreCase(mode)) {
            String email = context.queueEmailById != null ? context.queueEmailById.get(queueId) : null;
            if (!String.isBlank(email)) {
                result.emailAddresses.add(email.trim());
                return true;
            }
            return false;
        }
        if (TaskSlaConfig.ROUTE_MEMBERS.equalsIgnoreCase(mode)) {
            Set<Id> members = context.queueMembersById != null ? context.queueMembersById.get(queueId) : null;
            if (members != null && !members.isEmpty()) {
                result.userIds.addAll(members);
                return true;
            }
            return false;
        }
        return false;
    }

    private static void loadQueueMembers(Set<Id> queueIds, Context context) {
        List<GroupMember> members = [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queueIds
        ];

        Map<Id, Set<Id>> queueToUserIds = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> queueToRoleIds = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> queueToGroupIds = new Map<Id, Set<Id>>();
        Set<Id> directUserIds = new Set<Id>();
        Set<Id> publicGroupIds = new Set<Id>();
        Set<Id> roleIds = new Set<Id>();
        Map<Id, Set<Id>> groupToQueues = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> roleToQueues = new Map<Id, Set<Id>>();

        for (GroupMember member : members) {
            if (member.UserOrGroupId == null) {
                continue;
            }
            String prefix = String.valueOf(member.UserOrGroupId).left(3);
            if (prefix == '005') {
                addToQueueMap(queueToUserIds, member.GroupId, member.UserOrGroupId);
                directUserIds.add(member.UserOrGroupId);
            } else if (prefix == '00G') {
                addToQueueMap(queueToGroupIds, member.GroupId, member.UserOrGroupId);
                publicGroupIds.add(member.UserOrGroupId);
                addToQueueMap(groupToQueues, member.UserOrGroupId, member.GroupId);
            } else if (prefix == '00E') {
                addToQueueMap(queueToRoleIds, member.GroupId, member.UserOrGroupId);
                roleIds.add(member.UserOrGroupId);
                addToQueueMap(roleToQueues, member.UserOrGroupId, member.GroupId);
            }
        }

        if (!publicGroupIds.isEmpty()) {
            List<GroupMember> nestedMembers = [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :publicGroupIds
            ];
            for (GroupMember nested : nestedMembers) {
                if (nested.UserOrGroupId == null) {
                    continue;
                }
                Set<Id> queues = groupToQueues.get(nested.GroupId);
                if (queues == null || queues.isEmpty()) {
                    continue;
                }
                String prefix = String.valueOf(nested.UserOrGroupId).left(3);
                if (prefix == '005') {
                    for (Id queueId : queues) {
                        addToQueueMap(queueToUserIds, queueId, nested.UserOrGroupId);
                    }
                    directUserIds.add(nested.UserOrGroupId);
                } else if (prefix == '00E') {
                    for (Id queueId : queues) {
                        addToQueueMap(queueToRoleIds, queueId, nested.UserOrGroupId);
                    }
                    roleIds.add(nested.UserOrGroupId);
                    addToQueueMap(roleToQueues, nested.UserOrGroupId, queues);
                }
            }
        }

        if (!roleIds.isEmpty()) {
            Map<Id, User> usersById = new Map<Id, User>();
            for (User usr : [
                SELECT Id, UserRoleId, IsActive
                FROM User
                WHERE UserRoleId IN :roleIds
                AND IsActive = true
            ]) {
                usersById.put(usr.Id, usr);
                Set<Id> queues = roleToQueues.get(usr.UserRoleId);
                if (queues != null) {
                    for (Id queueId : queues) {
                        addToQueueMap(queueToUserIds, queueId, usr.Id);
                    }
                }
            }
        }

        if (!directUserIds.isEmpty()) {
            Set<Id> activeUserIds = new Set<Id>();
            for (User usr : [
                SELECT Id, IsActive
                FROM User
                WHERE Id IN :directUserIds
                AND IsActive = true
            ]) {
                activeUserIds.add(usr.Id);
            }
            for (Id queueId : queueToUserIds.keySet()) {
                Set<Id> membersForQueue = queueToUserIds.get(queueId);
                if (membersForQueue == null) {
                    continue;
                }
                membersForQueue.retainAll(activeUserIds);
            }
        }

        context.queueMembersById = queueToUserIds;
    }

    private static void addToQueueMap(Map<Id, Set<Id>> mapRef, Id key, Id value) {
        if (mapRef == null || key == null || value == null) {
            return;
        }
        if (!mapRef.containsKey(key)) {
            mapRef.put(key, new Set<Id>());
        }
        mapRef.get(key).add(value);
    }

    private static void addToQueueMap(Map<Id, Set<Id>> mapRef, Id key, Set<Id> values) {
        if (mapRef == null || key == null || values == null || values.isEmpty()) {
            return;
        }
        if (!mapRef.containsKey(key)) {
            mapRef.put(key, new Set<Id>());
        }
        mapRef.get(key).addAll(values);
    }
}