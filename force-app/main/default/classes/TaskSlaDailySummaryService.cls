/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-11-2026
 * @last modified by  : Daniel Belini
 **/
public with sharing class TaskSlaDailySummaryService {
  private static final String DAILY_CONSOLIDATED_LOG_TYPE = 'TASK_DAILY_CONSOLIDATED';

  public static void runDaily() {
    Date today = Date.today();
    Date tomorrow = today.addDays(1);

    sendManagerSummary(today, tomorrow, false);
  }

  public static void runManagerOverdue() {
    Date today = Date.today();
    Date tomorrow = today.addDays(1);
    sendManagerSummary(today, tomorrow, false);
  }

  public static void runManagerDueTomorrow() {
    Date today = Date.today();
    Date tomorrow = today.addDays(1);
    sendManagerSummary(today, tomorrow, false);
  }

  public static void runOwnerOpenSummary() {
    Date today = Date.today();
    Date tomorrow = today.addDays(1);
    sendManagerSummary(today, tomorrow, false);
  }

  public static void sendPreviewByRole(
    String roleNameOrDeveloperName,
    String recipientEmail
  ) {
    if (
      String.isBlank(roleNameOrDeveloperName) || String.isBlank(recipientEmail)
    ) {
      throw new TaskSlaPreviewException('Informe os parametros papel e email.');
    }
    String roleKey = roleNameOrDeveloperName.trim();
    String targetEmail = recipientEmail.trim();

    UserRole selectedRole = findRoleByIdentifier(roleKey);
    if (selectedRole == null) {
      throw new TaskSlaPreviewException('Papel nao encontrado: ' + roleKey);
    }

    TaskSlaConfig.NotificationConfig config = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
    );
    Set<String> closedStatuses = TaskSlaConfig.getClosedStatusValues();
    Set<String> canceledStatuses = TaskSlaConfig.getCanceledStatusValues();

    List<Task> tasks = queryOpenTasks(closedStatuses, canceledStatuses);
    if (tasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'preview by role sem tarefas. role=' + selectedRole.Name
      );
      return;
    }

    Set<Id> ownerIds = new Set<Id>();
    for (Task taskRecord : tasks) {
      ownerIds.add(taskRecord.OwnerId);
    }
    TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(
      ownerIds,
      false
    );
    List<Task> filteredTasks = applyConfigFilter(
      tasks,
      config,
      context.queueDeveloperNameById
    );
    if (filteredTasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'preview by role sem tarefas apos filtro. role=' + selectedRole.Name
      );
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
    Map<Id, List<Task>> tasksByOwnerId = buildUserTaskMapByOwner(ownerToTasks);
    Map<Id, List<Task>> tasksByRoleId = buildTaskMapByRole(
      tasksByOwnerId,
      context.ownersById
    );
    RoleHierarchySnapshot snapshot = buildRoleHierarchySnapshot();
    UserTeamSummary summary = buildRolePreviewSummary(
      selectedRole,
      tasksByRoleId,
      snapshot
    );
    if (summary.totalTasks <= 0) {
      TaskSlaUtils.debug(
        'DailySummary',
        'preview by role sem visibilidade para o papel. role=' +
        selectedRole.Name
      );
      return;
    }

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ targetEmail });
    email.setSaveAsActivity(false);
    email.setSubject(
      'Preview SLA - Papel ' +
        selectedRole.Name +
        ' - ' +
        formatDate(Date.today())
    );
    String previewRecipientName = resolvePreviewRecipientName(targetEmail);
    email.setHtmlBody(
      buildManagerSummaryBody(
        previewRecipientName,
        summary,
        config,
        relatedNames,
        true
      )
    );
    TaskSlaNotificationService.applySystemSender(email);
    if (!Test.isRunningTest()) {
      TaskSlaNotificationService.sendEmailsInChunks(
        new List<Messaging.SingleEmailMessage>{ email }
      );
    }
  }

  private static String resolvePreviewRecipientName(String recipientEmail) {
    if (String.isBlank(recipientEmail)) {
      return 'Destinatario';
    }
    List<User> users = [
      SELECT Name
      FROM User
      WHERE IsActive = TRUE AND Email = :recipientEmail
      LIMIT 1
    ];
    if (!users.isEmpty() && !String.isBlank(users[0].Name)) {
      return users[0].Name;
    }
    return recipientEmail;
  }

  private class RoleHierarchySnapshot {
    public Map<Id, UserRole> rolesById = new Map<Id, UserRole>();
    public Map<Id, Id> parentByRoleId = new Map<Id, Id>();
    public Map<Id, Set<Id>> descendantRoleIdsByRoleId = new Map<Id, Set<Id>>();
  }

  private class UserTeamSummary {
    public User recipientUser;
    public String personalSectionTitle;
    public List<Task> personalTasks = new List<Task>();
    public Map<String, List<Task>> teamTasksByRole = new Map<String, List<Task>>();
    public Integer totalTasks = 0;
  }

  public class TaskSlaPreviewException extends Exception {
  }

  private static void sendManagerSummary(
    Date today,
    Date tomorrow,
    Boolean overdue
  ) {
    TaskSlaConfig.NotificationConfig config = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_MANAGER_OVERDUE
    );
    if (config == null || !config.enabled) {
      TaskSlaUtils.debug(
        'DailySummary',
        'manager summary disabled. key=' + DAILY_CONSOLIDATED_LOG_TYPE
      );
      return;
    }
    if (
      (config.notifyManager == null || !config.notifyManager) &&
      (config.notifyQueue == null || !config.notifyQueue)
    ) {
      TaskSlaUtils.debug(
        'DailySummary',
        'manager summary recipients disabled. key=' +
        DAILY_CONSOLIDATED_LOG_TYPE
      );
      return;
    }
    String emailOverride = TaskSlaConfig.getSandboxEmailOverride();

    Set<String> closedStatuses = TaskSlaConfig.getClosedStatusValues();
    Set<String> canceledStatuses = TaskSlaConfig.getCanceledStatusValues();

    List<Task> tasks = queryOpenTasks(closedStatuses, canceledStatuses);
    if (tasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'manager summary empty. key=' + DAILY_CONSOLIDATED_LOG_TYPE
      );
      return;
    }

    Set<Id> ownerIds = new Set<Id>();
    for (Task taskRecord : tasks) {
      ownerIds.add(taskRecord.OwnerId);
    }

    TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(
      ownerIds,
      true
    );
    Map<Id, String> queueDevNames = context.queueDeveloperNameById;

    List<Task> filteredTasks = applyConfigFilter(tasks, config, queueDevNames);
    if (filteredTasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'manager summary filtered empty. key=' + DAILY_CONSOLIDATED_LOG_TYPE
      );
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
    Map<Id, List<Task>> queueToTasks = new Map<Id, List<Task>>();
    for (Id ownerId : ownerToTasks.keySet()) {
      if (
        TaskSlaUtils.isQueueOwner(ownerId) &&
        config.notifyQueue != null &&
        config.notifyQueue
      ) {
        queueToTasks.put(ownerId, ownerToTasks.get(ownerId));
      }
    }

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<Log__c> logs = new List<Log__c>();
    String subjectPrefix = 'SLA - Resumo diario';

    Map<Id, UserTeamSummary> roleHierarchySummariesByUserId = new Map<Id, UserTeamSummary>();
    if (config.notifyManager != null && config.notifyManager) {
      roleHierarchySummariesByUserId = buildRoleHierarchySummaries(
        ownerToTasks,
        context
      );
    }

    Set<String> relatedIdsToCheck = new Set<String>();
    if (!roleHierarchySummariesByUserId.isEmpty()) {
      for (Id recipientUserId : roleHierarchySummariesByUserId.keySet()) {
        relatedIdsToCheck.add(String.valueOf(recipientUserId));
      }
    }
    for (Id queueId : queueToTasks.keySet()) {
      relatedIdsToCheck.add(String.valueOf(queueId));
    }

    Map<Id, List<Task>> managerToTasksFallback = new Map<Id, List<Task>>();
    if (
      roleHierarchySummariesByUserId.isEmpty() &&
      config.notifyManager != null &&
      config.notifyManager
    ) {
      managerToTasksFallback = buildDirectManagerSummary(ownerToTasks, context);
      for (Id managerId : managerToTasksFallback.keySet()) {
        relatedIdsToCheck.add(String.valueOf(managerId));
      }
    }
    Set<String> alreadySentToday = getSentRelatedIdsToday(
      DAILY_CONSOLIDATED_LOG_TYPE,
      relatedIdsToCheck
    );

    if (!roleHierarchySummariesByUserId.isEmpty()) {
      for (Id recipientUserId : roleHierarchySummariesByUserId.keySet()) {
        if (alreadySentToday.contains(String.valueOf(recipientUserId))) {
          continue;
        }
        User recipient = roleHierarchySummariesByUserId.get(recipientUserId)
          .recipientUser;
        if (
          recipient == null ||
          !recipient.IsActive ||
          String.isBlank(recipient.Email)
        ) {
          continue;
        }
        UserTeamSummary summary = roleHierarchySummariesByUserId.get(
          recipientUserId
        );
        Messaging.SingleEmailMessage email = buildManagerSummaryEmail(
          recipient,
          summary,
          subjectPrefix,
          config,
          emailOverride,
          relatedNames
        );
        emails.add(email);
        addSummaryLogs(
          logs,
          recipientUserId,
          DAILY_CONSOLIDATED_LOG_TYPE,
          summary.totalTasks
        );
      }
    } else if (config.notifyManager != null && config.notifyManager) {
      for (Id managerId : managerToTasksFallback.keySet()) {
        if (alreadySentToday.contains(String.valueOf(managerId))) {
          continue;
        }
        User manager = context.managersById.get(managerId);
        if (
          manager == null ||
          !manager.IsActive ||
          String.isBlank(manager.Email)
        ) {
          continue;
        }
        List<Task> managerTasks = managerToTasksFallback.get(managerId);
        UserTeamSummary fallbackSummary = new UserTeamSummary();
        fallbackSummary.recipientUser = manager;
        fallbackSummary.personalSectionTitle = 'Tarefas do time';
        fallbackSummary.personalTasks = managerTasks != null
          ? managerTasks
          : new List<Task>();
        fallbackSummary.teamTasksByRole = new Map<String, List<Task>>();
        fallbackSummary.totalTasks = fallbackSummary.personalTasks.size();
        Messaging.SingleEmailMessage email = buildManagerSummaryEmail(
          manager,
          fallbackSummary,
          subjectPrefix,
          config,
          emailOverride,
          relatedNames
        );
        emails.add(email);
        addSummaryLogs(
          logs,
          managerId,
          DAILY_CONSOLIDATED_LOG_TYPE,
          managerTasks.size()
        );
      }
    }

    for (Id queueId : queueToTasks.keySet()) {
      if (alreadySentToday.contains(String.valueOf(queueId))) {
        continue;
      }
      List<Task> queueTasks = queueToTasks.get(queueId);
      TaskSlaRecipientResolver.RecipientResult recipients = TaskSlaRecipientResolver.resolveRecipients(
        new Task(OwnerId = queueId),
        config,
        context
      );
      if (recipients.userIds.isEmpty() && recipients.emailAddresses.isEmpty()) {
        continue;
      }
      String queueName = context.queuesById.containsKey(queueId)
        ? context.queuesById.get(queueId).Name
        : 'Fila';
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
            Messaging.SingleEmailMessage cloneEmail = cloneEmailForUser(
              email,
              userId
            );
            emails.add(cloneEmail);
          }
        }
        if (!recipients.emailAddresses.isEmpty()) {
          for (String address : recipients.emailAddresses) {
            Messaging.SingleEmailMessage cloneEmail = cloneEmailForAddress(
              email,
              address
            );
            emails.add(cloneEmail);
          }
        }
      }
      addSummaryLogs(
        logs,
        queueId,
        DAILY_CONSOLIDATED_LOG_TYPE,
        queueTasks.size()
      );
    }

    if (!emails.isEmpty() && !Test.isRunningTest()) {
      TaskSlaNotificationService.sendEmailsInChunks(emails);
    }

    if (!logs.isEmpty()) {
      Database.insert(logs, false);
    }

    Integer managerCount = !roleHierarchySummariesByUserId.isEmpty()
      ? roleHierarchySummariesByUserId.size()
      : managerToTasksFallback.size();
    TaskSlaUtils.debug(
      'DailySummary',
      'manager summary done. key=' +
        DAILY_CONSOLIDATED_LOG_TYPE +
        ' tasks=' +
        tasks.size() +
        ' filtered=' +
        filteredTasks.size() +
        ' managers=' +
        managerCount +
        ' queues=' +
        queueToTasks.size() +
        ' emails=' +
        emails.size() +
        ' logs=' +
        logs.size() +
        ' override=' +
        (String.isBlank(emailOverride) ? 'none' : emailOverride)
    );
  }

  private static void sendOwnerOpenSummary(Date today, Date tomorrow) {
    TaskSlaConfig.NotificationConfig config = TaskSlaConfig.getNotificationConfig(
      TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
    );
    if (config == null || !config.enabled) {
      TaskSlaUtils.debug(
        'DailySummary',
        'owner summary disabled. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
      );
      return;
    }
    if (
      (config.notifyOwner == null || !config.notifyOwner) &&
      (config.notifyQueue == null || !config.notifyQueue)
    ) {
      TaskSlaUtils.debug(
        'DailySummary',
        'owner summary recipients disabled. key=' +
        TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
      );
      return;
    }
    String emailOverride = TaskSlaConfig.getSandboxEmailOverride();

    Set<String> closedStatuses = TaskSlaConfig.getClosedStatusValues();
    Set<String> canceledStatuses = TaskSlaConfig.getCanceledStatusValues();

    List<Task> tasks = queryOpenTasks(closedStatuses, canceledStatuses);
    if (tasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'owner summary empty. key=' + TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
      );
      return;
    }

    Set<Id> ownerIds = new Set<Id>();
    for (Task taskRecord : tasks) {
      ownerIds.add(taskRecord.OwnerId);
    }

    TaskSlaRecipientResolver.Context context = TaskSlaRecipientResolver.buildContext(
      ownerIds,
      true
    );
    Map<Id, String> queueDevNames = context.queueDeveloperNameById;

    List<Task> filteredTasks = applyConfigFilter(tasks, config, queueDevNames);
    if (filteredTasks.isEmpty()) {
      TaskSlaUtils.debug(
        'DailySummary',
        'owner summary filtered empty. key=' +
        TaskSlaConfig.TYPE_OWNER_OPEN_DAILY
      );
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
        addSummaryLogs(
          logs,
          ownerId,
          TaskSlaConfig.TYPE_OWNER_OPEN_DAILY,
          ownerTasks.size()
        );
      } else if (TaskSlaUtils.isQueueOwner(ownerId)) {
        if (config.notifyQueue == null || !config.notifyQueue) {
          continue;
        }
        TaskSlaRecipientResolver.RecipientResult recipients = TaskSlaRecipientResolver.resolveRecipients(
          new Task(OwnerId = ownerId),
          config,
          context
        );
        if (
          recipients.userIds.isEmpty() && recipients.emailAddresses.isEmpty()
        ) {
          continue;
        }
        String queueName = context.queuesById.containsKey(ownerId)
          ? context.queuesById.get(ownerId).Name
          : 'Fila';
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
        addSummaryLogs(
          logs,
          ownerId,
          TaskSlaConfig.TYPE_OWNER_OPEN_DAILY,
          ownerTasks.size()
        );
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
      'owner summary done. key=' +
        TaskSlaConfig.TYPE_OWNER_OPEN_DAILY +
        ' tasks=' +
        tasks.size() +
        ' filtered=' +
        filteredTasks.size() +
        ' owners=' +
        ownerToTasks.size() +
        ' emails=' +
        emails.size() +
        ' logs=' +
        logs.size() +
        ' override=' +
        (String.isBlank(emailOverride) ? 'none' : emailOverride)
    );
  }

  private static Map<Id, UserTeamSummary> buildRoleHierarchySummaries(
    Map<Id, List<Task>> ownerToTasks,
    TaskSlaRecipientResolver.Context context
  ) {
    Map<Id, UserTeamSummary> result = new Map<Id, UserTeamSummary>();
    if (ownerToTasks == null || ownerToTasks.isEmpty() || context == null) {
      return result;
    }

    Map<Id, List<Task>> tasksByOwnerId = buildUserTaskMapByOwner(ownerToTasks);
    if (tasksByOwnerId.isEmpty()) {
      return result;
    }

    Map<Id, List<Task>> tasksByRoleId = buildTaskMapByRole(
      tasksByOwnerId,
      context.ownersById
    );
    if (tasksByRoleId.isEmpty()) {
      return result;
    }

    Set<Id> ownerRoleIds = new Set<Id>(tasksByRoleId.keySet());
    RoleHierarchySnapshot snapshot = buildRoleHierarchySnapshot();
    Set<Id> recipientRoleIds = collectAncestorRoleIds(
      ownerRoleIds,
      snapshot.parentByRoleId
    );
    Map<Id, User> recipientsById = queryActiveUsersByRoleIds(recipientRoleIds);
    for (User recipient : recipientsById.values()) {
      UserTeamSummary summary = buildUserHierarchySummary(
        recipient,
        tasksByOwnerId,
        tasksByRoleId,
        snapshot
      );
      if (summary.totalTasks > 0) {
        result.put(recipient.Id, summary);
      }
    }

    return result;
  }

  private static Map<Id, List<Task>> buildDirectManagerSummary(
    Map<Id, List<Task>> ownerToTasks,
    TaskSlaRecipientResolver.Context context
  ) {
    Map<Id, List<Task>> managerToTasks = new Map<Id, List<Task>>();
    if (ownerToTasks == null || ownerToTasks.isEmpty() || context == null) {
      return managerToTasks;
    }
    for (Id ownerId : ownerToTasks.keySet()) {
      if (!TaskSlaUtils.isUserOwner(ownerId)) {
        continue;
      }
      User owner = context.ownersById.get(ownerId);
      if (
        owner == null ||
        owner.ManagerId == null ||
        !context.managersById.containsKey(owner.ManagerId)
      ) {
        continue;
      }
      if (!managerToTasks.containsKey(owner.ManagerId)) {
        managerToTasks.put(owner.ManagerId, new List<Task>());
      }
      managerToTasks.get(owner.ManagerId).addAll(ownerToTasks.get(ownerId));
    }
    return managerToTasks;
  }

  private static Map<Id, List<Task>> buildUserTaskMapByOwner(
    Map<Id, List<Task>> ownerToTasks
  ) {
    Map<Id, List<Task>> result = new Map<Id, List<Task>>();
    if (ownerToTasks == null || ownerToTasks.isEmpty()) {
      return result;
    }
    for (Id ownerId : ownerToTasks.keySet()) {
      if (!TaskSlaUtils.isUserOwner(ownerId)) {
        continue;
      }
      result.put(ownerId, ownerToTasks.get(ownerId));
    }
    return result;
  }

  private static Map<Id, List<Task>> buildTaskMapByRole(
    Map<Id, List<Task>> tasksByOwnerId,
    Map<Id, User> ownersById
  ) {
    Map<Id, List<Task>> result = new Map<Id, List<Task>>();
    if (
      tasksByOwnerId == null ||
      tasksByOwnerId.isEmpty() ||
      ownersById == null
    ) {
      return result;
    }
    for (Id ownerId : tasksByOwnerId.keySet()) {
      User owner = ownersById.get(ownerId);
      if (owner == null || owner.UserRoleId == null) {
        continue;
      }
      if (!result.containsKey(owner.UserRoleId)) {
        result.put(owner.UserRoleId, new List<Task>());
      }
      result.get(owner.UserRoleId).addAll(tasksByOwnerId.get(ownerId));
    }
    return result;
  }

  private static UserTeamSummary buildUserHierarchySummary(
    User recipient,
    Map<Id, List<Task>> tasksByOwnerId,
    Map<Id, List<Task>> tasksByRoleId,
    RoleHierarchySnapshot snapshot
  ) {
    UserTeamSummary summary = new UserTeamSummary();
    summary.recipientUser = recipient;
    summary.personalSectionTitle = 'Minhas tarefas';
    summary.personalTasks = tasksByOwnerId != null &&
      tasksByOwnerId.containsKey(recipient.Id)
      ? tasksByOwnerId.get(recipient.Id)
      : new List<Task>();

    Set<Id> descendantRoleIds = new Set<Id>();
    if (
      snapshot != null &&
      recipient.UserRoleId != null &&
      snapshot.descendantRoleIdsByRoleId.containsKey(recipient.UserRoleId)
    ) {
      descendantRoleIds = snapshot.descendantRoleIdsByRoleId.get(
        recipient.UserRoleId
      );
    }
    summary.teamTasksByRole = buildTeamTasksByRole(
      descendantRoleIds,
      tasksByRoleId,
      snapshot != null ? snapshot.rolesById : null
    );
    summary.totalTasks =
      summary.personalTasks.size() + countTasks(summary.teamTasksByRole);
    return summary;
  }

  private static UserTeamSummary buildRolePreviewSummary(
    UserRole selectedRole,
    Map<Id, List<Task>> tasksByRoleId,
    RoleHierarchySnapshot snapshot
  ) {
    UserTeamSummary summary = new UserTeamSummary();
    summary.personalSectionTitle =
      'Tarefas do papel ' + (selectedRole != null ? selectedRole.Name : '');
    summary.personalTasks = new List<Task>();
    summary.teamTasksByRole = new Map<String, List<Task>>();
    if (selectedRole == null) {
      return summary;
    }

    if (tasksByRoleId != null && tasksByRoleId.containsKey(selectedRole.Id)) {
      summary.personalTasks = tasksByRoleId.get(selectedRole.Id);
    }
    Set<Id> descendantRoleIds = snapshot != null &&
      snapshot.descendantRoleIdsByRoleId.containsKey(selectedRole.Id)
      ? snapshot.descendantRoleIdsByRoleId.get(selectedRole.Id)
      : new Set<Id>();
    summary.teamTasksByRole = buildTeamTasksByRole(
      descendantRoleIds,
      tasksByRoleId,
      snapshot != null ? snapshot.rolesById : null
    );
    summary.totalTasks =
      summary.personalTasks.size() + countTasks(summary.teamTasksByRole);
    return summary;
  }

  private static Map<String, List<Task>> buildTeamTasksByRole(
    Set<Id> descendantRoleIds,
    Map<Id, List<Task>> tasksByRoleId,
    Map<Id, UserRole> rolesById
  ) {
    Map<String, List<Task>> result = new Map<String, List<Task>>();
    if (
      descendantRoleIds == null ||
      descendantRoleIds.isEmpty() ||
      tasksByRoleId == null ||
      tasksByRoleId.isEmpty()
    ) {
      return result;
    }

    for (Id roleId : descendantRoleIds) {
      List<Task> roleTasks = tasksByRoleId.get(roleId);
      if (roleTasks == null || roleTasks.isEmpty()) {
        continue;
      }
      UserRole roleRecord = rolesById != null ? rolesById.get(roleId) : null;
      String roleName = roleRecord != null ? roleRecord.Name : 'Papel sem nome';
      if (!result.containsKey(roleName)) {
        result.put(roleName, new List<Task>());
      }
      result.get(roleName).addAll(roleTasks);
    }

    return result;
  }

  private static Integer countTasks(Map<String, List<Task>> tasksByRole) {
    Integer total = 0;
    if (tasksByRole == null || tasksByRole.isEmpty()) {
      return total;
    }
    for (List<Task> roleTasks : tasksByRole.values()) {
      total += roleTasks != null ? roleTasks.size() : 0;
    }
    return total;
  }

  private static Map<Id, User> queryActiveUsersByRoleIds(Set<Id> roleIds) {
    Map<Id, User> result = new Map<Id, User>();
    if (roleIds == null || roleIds.isEmpty()) {
      return result;
    }
    for (User usr : [
      SELECT Id, Name, Email, IsActive, UserRoleId
      FROM User
      WHERE IsActive = TRUE AND UserRoleId IN :roleIds
    ]) {
      result.put(usr.Id, usr);
    }
    return result;
  }

  private static RoleHierarchySnapshot buildRoleHierarchySnapshot() {
    RoleHierarchySnapshot snapshot = new RoleHierarchySnapshot();
    List<UserRole> roles = [
      SELECT Id, Name, DeveloperName, ParentRoleId
      FROM UserRole
    ];
    Map<Id, Set<Id>> childrenByParentRoleId = new Map<Id, Set<Id>>();
    for (UserRole roleRecord : roles) {
      snapshot.rolesById.put(roleRecord.Id, roleRecord);
      snapshot.parentByRoleId.put(roleRecord.Id, roleRecord.ParentRoleId);
      if (roleRecord.ParentRoleId == null) {
        continue;
      }
      if (!childrenByParentRoleId.containsKey(roleRecord.ParentRoleId)) {
        childrenByParentRoleId.put(roleRecord.ParentRoleId, new Set<Id>());
      }
      childrenByParentRoleId.get(roleRecord.ParentRoleId).add(roleRecord.Id);
    }

    for (Id roleId : snapshot.rolesById.keySet()) {
      Set<Id> descendants = new Set<Id>();
      List<Id> pending = new List<Id>();
      if (childrenByParentRoleId.containsKey(roleId)) {
        pending.addAll(childrenByParentRoleId.get(roleId));
      }
      while (!pending.isEmpty()) {
        Id childRoleId = pending.remove(pending.size() - 1);
        if (!descendants.add(childRoleId)) {
          continue;
        }
        if (childrenByParentRoleId.containsKey(childRoleId)) {
          pending.addAll(childrenByParentRoleId.get(childRoleId));
        }
      }
      snapshot.descendantRoleIdsByRoleId.put(roleId, descendants);
    }
    return snapshot;
  }

  private static Set<Id> collectAncestorRoleIds(
    Set<Id> baseRoleIds,
    Map<Id, Id> parentByRoleId
  ) {
    Set<Id> result = new Set<Id>();
    if (baseRoleIds == null || baseRoleIds.isEmpty()) {
      return result;
    }
    for (Id roleId : baseRoleIds) {
      Id currentRoleId = roleId;
      while (currentRoleId != null && !result.contains(currentRoleId)) {
        result.add(currentRoleId);
        currentRoleId = parentByRoleId != null
          ? parentByRoleId.get(currentRoleId)
          : null;
      }
    }
    return result;
  }

  private static UserRole findRoleByIdentifier(String roleIdentifier) {
    if (String.isBlank(roleIdentifier)) {
      return null;
    }
    List<UserRole> roles = [
      SELECT Id, Name, DeveloperName, ParentRoleId
      FROM UserRole
      WHERE Name = :roleIdentifier OR DeveloperName = :roleIdentifier
      LIMIT 1
    ];
    if (!roles.isEmpty()) {
      return roles[0];
    }
    String normalizedName = roleIdentifier.replace('_', ' ');
    if (normalizedName == roleIdentifier) {
      return null;
    }
    List<UserRole> normalizedRoles = [
      SELECT Id, Name, DeveloperName, ParentRoleId
      FROM UserRole
      WHERE Name = :normalizedName
      LIMIT 1
    ];
    return normalizedRoles.isEmpty() ? null : normalizedRoles[0];
  }

  private static List<Task> queryManagerTasks(
    Date today,
    Date tomorrow,
    Boolean overdue,
    Set<String> closedStatuses,
    Set<String> canceledStatuses
  ) {
    String dateFilter = overdue
      ? 'ActivityDate < :today'
      : 'ActivityDate = :tomorrow';
    String baseQuery =
      'SELECT Id, Subject, Description, ActivityDate, OwnerId, Owner.Name, ' +
      'WhatId, WhoId, Priority, TaskSubtype, Type, Status ' +
      'FROM Task WHERE ActivityDate != null AND ' +
      dateFilter;

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
    String baseQuery =
      'SELECT Id, Subject, Description, ActivityDate, OwnerId, Owner.Name, ' +
      'WhatId, WhoId, Priority, TaskSubtype, Type, Status ' +
      'FROM Task WHERE Id != null';

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
    UserTeamSummary summary,
    String subjectPrefix,
    TaskSlaConfig.NotificationConfig config,
    String emailOverride,
    Map<Id, String> relatedNames
  ) {
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    if (!String.isBlank(emailOverride)) {
      email.setToAddresses(new List<String>{ emailOverride });
    } else {
      email.setTargetObjectId(manager.Id);
      email.setTreatTargetObjectAsRecipient(true);
    }
    email.setSaveAsActivity(false);
    email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
    email.setHtmlBody(
      buildManagerSummaryBody(
        manager.Name,
        summary,
        config,
        relatedNames,
        false
      )
    );
    TaskSlaNotificationService.applySystemSender(email);
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
      email.setToAddresses(new List<String>{ emailOverride });
    }
    UserTeamSummary summary = new UserTeamSummary();
    summary.personalSectionTitle = 'Tarefas da fila';
    summary.personalTasks = tasks != null ? tasks : new List<Task>();
    summary.teamTasksByRole = new Map<String, List<Task>>();
    summary.totalTasks = summary.personalTasks.size();
    email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
    email.setHtmlBody(
      buildManagerSummaryBody(queueName, summary, config, relatedNames, false)
    );
    email.setSaveAsActivity(false);
    TaskSlaNotificationService.applySystemSender(email);
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
      email.setToAddresses(new List<String>{ emailOverride });
    }
    email.setSubject(subjectPrefix + ' - ' + formatDate(Date.today()));
    email.setHtmlBody(buildSummaryBody(queueName, tasks, config));
    email.setSaveAsActivity(false);
    TaskSlaNotificationService.applySystemSender(email);
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
      email.setToAddresses(new List<String>{ emailOverride });
    } else {
      email.setTargetObjectId(owner.Id);
      email.setTreatTargetObjectAsRecipient(true);
    }
    email.setSaveAsActivity(false);
    email.setSubject('Resumo Diario - ' + formatDate(today));
    email.setHtmlBody(
      buildOwnerSummaryBody(owner.Name, tasks, config, today, tomorrow)
    );
    TaskSlaNotificationService.applySystemSender(email);
    return email;
  }

  private static Messaging.SingleEmailMessage cloneEmailForUser(
    Messaging.SingleEmailMessage baseEmail,
    Id userId
  ) {
    Messaging.SingleEmailMessage cloneEmail = new Messaging.SingleEmailMessage();
    cloneEmail.setSubject(baseEmail.getSubject());
    cloneEmail.setHtmlBody(baseEmail.getHtmlBody());
    cloneEmail.setTargetObjectId(userId);
    cloneEmail.setTreatTargetObjectAsRecipient(true);
    cloneEmail.setSaveAsActivity(false);
    TaskSlaNotificationService.applySystemSender(cloneEmail);
    return cloneEmail;
  }

  private static Messaging.SingleEmailMessage cloneEmailForAddress(
    Messaging.SingleEmailMessage baseEmail,
    String address
  ) {
    Messaging.SingleEmailMessage cloneEmail = new Messaging.SingleEmailMessage();
    cloneEmail.setSubject(baseEmail.getSubject());
    cloneEmail.setHtmlBody(baseEmail.getHtmlBody());
    cloneEmail.setToAddresses(new List<String>{ address });
    cloneEmail.setSaveAsActivity(false);
    TaskSlaNotificationService.applySystemSender(cloneEmail);
    return cloneEmail;
  }

  private static String buildManagerSummaryBody(
    String recipientName,
    UserTeamSummary summary,
    TaskSlaConfig.NotificationConfig config,
    Map<Id, String> relatedNames,
    Boolean isPreview
  ) {
    UserTeamSummary effectiveSummary = summary != null
      ? summary
      : new UserTeamSummary();
    List<Task> personalTasks = effectiveSummary.personalTasks != null
      ? effectiveSummary.personalTasks
      : new List<Task>();
    Map<String, List<Task>> teamTasksByRole = effectiveSummary.teamTasksByRole !=
      null
      ? effectiveSummary.teamTasksByRole
      : new Map<String, List<Task>>();
    Integer teamTotal = countTasks(teamTasksByRole);
    Integer totalTasks = personalTasks.size() + teamTotal;
    Integer topN = resolveTopN(config, 15, 30);
    String link = config != null ? config.reportLink : null;
    Date today = Date.today();
    Integer overdueCount = countTasksByDueDate(
      personalTasks,
      teamTasksByRole,
      today,
      true
    );
    Integer dueTodayCount = countTasksByDueDate(
      personalTasks,
      teamTasksByRole,
      today,
      false
    );

    String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
    body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
    body += '<tr><td align="center">';
    body += '<table role="presentation" width="640" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
    body += '<tr><td style="padding:20px 24px;background:#0f172a;color:#ffffff;">';
    body += '<div style="font-size:20px;font-weight:700;">Resumo diario de tarefas</div>';
    body +=
      '<div style="font-size:13px;opacity:.9;margin-top:6px;">Ola, ' +
      TaskSlaUtils.escapeHtml(recipientName) +
      '</div>';
    if (isPreview) {
      body += '<div style="font-size:12px;opacity:.85;margin-top:8px;">Modo preview por papel</div>';
    }
    body += '</td></tr>';
    body += '<tr><td style="padding:20px 24px;">';
    body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>';
    body += '<td style="padding:0 8px 8px 0;"><div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px 12px;">';
    body +=
      '<div style="font-size:11px;color:#64748b;">Total</div><div style="font-size:18px;color:#0f172a;font-weight:700;">' +
      totalTasks +
      '</div></div></td>';
    body += '<td style="padding:0 8px 8px 0;"><div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px 12px;">';
    body +=
      '<div style="font-size:11px;color:#64748b;">Minhas</div><div style="font-size:18px;color:#0f172a;font-weight:700;">' +
      personalTasks.size() +
      '</div></div></td>';
    body += '<td style="padding:0 0 8px 0;"><div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px 12px;">';
    body +=
      '<div style="font-size:11px;color:#64748b;">Do time</div><div style="font-size:18px;color:#0f172a;font-weight:700;">' +
      teamTotal +
      '</div></div></td>';
    body += '</tr></table>';
    body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>';
    body += '<td style="padding:0 8px 8px 0;"><div style="background:#fff7ed;border:1px solid #fdba74;border-radius:10px;padding:10px 12px;">';
    body +=
      '<div style="font-size:11px;color:#9a3412;">Atrasadas</div><div style="font-size:18px;color:#9a3412;font-weight:700;">' +
      overdueCount +
      '</div></div></td>';
    body += '<td style="padding:0 0 8px 0;"><div style="background:#ecfeff;border:1px solid #67e8f9;border-radius:10px;padding:10px 12px;">';
    body +=
      '<div style="font-size:11px;color:#155e75;">Vencem hoje</div><div style="font-size:18px;color:#155e75;font-weight:700;">' +
      dueTodayCount +
      '</div></div></td>';
    body += '</tr></table>';

    String personalTitle = String.isBlank(effectiveSummary.personalSectionTitle)
      ? 'Minhas tarefas'
      : effectiveSummary.personalSectionTitle;
    Boolean showOwnerOnPersonal = !'Minhas tarefas'
      .equalsIgnoreCase(personalTitle);
    body += buildDetailedTaskSection(
      personalTitle,
      personalTasks,
      topN,
      relatedNames,
      showOwnerOnPersonal
    );

    if (teamTotal > 0) {
      body += '<div style="margin-top:20px;font-size:16px;font-weight:700;color:#0f172a;">Tarefas do time (por papel)</div>';
      List<String> orderedRoles = sortRoleNames(teamTasksByRole);
      for (String roleName : orderedRoles) {
        body += buildDetailedTaskSection(
          'Papel: ' + roleName,
          teamTasksByRole.get(roleName),
          topN,
          relatedNames,
          true
        );
      }
    } else {
      body += '<div style="margin-top:18px;font-size:13px;color:#64748b;">Nao existem tarefas em papeis abaixo na hierarquia.</div>';
    }

    if (!String.isBlank(link)) {
      body += '<div style="margin-top:16px;">';
      body +=
        '<a href="' +
        link +
        '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Abrir relatorio completo</a>';
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

  private static List<String> sortRoleNames(
    Map<String, List<Task>> teamTasksByRole
  ) {
    List<String> roleNames = new List<String>();
    if (teamTasksByRole == null || teamTasksByRole.isEmpty()) {
      return roleNames;
    }
    roleNames.addAll(teamTasksByRole.keySet());
    roleNames.sort();
    return roleNames;
  }

  private static String buildDetailedTaskSection(
    String title,
    List<Task> tasks,
    Integer topN,
    Map<Id, String> relatedNames,
    Boolean showOwner
  ) {
    List<Task> safeTasks = tasks != null ? tasks : new List<Task>();
    String section = '<div style="margin-top:18px;">';
    section +=
      '<div style="font-size:14px;font-weight:700;color:#0f172a;">' +
      TaskSlaUtils.escapeHtml(title) +
      ' <span style="display:inline-block;background:#e2e8f0;color:#0f172a;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:600;">' +
      safeTasks.size() +
      '</span></div>';
    if (safeTasks.isEmpty()) {
      section += '<div style="font-size:12px;color:#6b7280;margin-top:6px;">Nenhuma tarefa.</div>';
      section += '</div>';
      return section;
    }

    List<Task> limitedTasks = limitTasks(safeTasks, topN);
    for (Task taskRecord : limitedTasks) {
      String taskLink = buildTaskLink(taskRecord);
      String subject = TaskSlaUtils.escapeHtml(taskRecord.Subject);
      String dueDate = formatDateOrPlaceholder(taskRecord.ActivityDate);
      String ownerName = taskRecord.Owner != null
        ? TaskSlaUtils.escapeHtml(taskRecord.Owner.Name)
        : '';
      String relatedHtml = buildRelatedHtml(taskRecord, relatedNames);
      String descriptionHtml = formatDescription(taskRecord.Description, 220);

      section += '<div style="padding:10px 0;border-bottom:1px solid #e5e7eb;">';
      section += '<div style="font-size:14px;color:#111827;font-weight:600;">';
      if (!String.isBlank(taskLink)) {
        section +=
          '<a href="' +
          taskLink +
          '" style="color:#2563eb;text-decoration:none;">' +
          subject +
          '</a>';
      } else {
        section += subject;
      }
      section += '</div>';
      section +=
        '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' +
        TaskSlaUtils.escapeHtml(dueDate);
      if (showOwner && !String.isBlank(ownerName)) {
        section += ' | Owner: ' + ownerName;
      }
      section += '</div>';
      if (!String.isBlank(relatedHtml)) {
        section +=
          '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Relacionado: ' +
          relatedHtml +
          '</div>';
      }
      if (!String.isBlank(descriptionHtml)) {
        section +=
          '<div style="font-size:12px;color:#334155;margin-top:6px;line-height:1.4;">' +
          descriptionHtml +
          '</div>';
      }
      section += '</div>';
    }
    section += '</div>';
    return section;
  }

  private static String buildSummaryBody(
    String recipientName,
    List<Task> tasks,
    TaskSlaConfig.NotificationConfig config
  ) {
    Integer topN = config != null && config.topN != null ? config.topN : 10;
    List<Task> limited = limitTasks(tasks, topN);
    String link = config != null ? config.reportLink : null;
    String body = '<html><body style="margin:0;padding:0;background:#f4f6f9;">';
    body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;">';
    body += '<tr><td align="center">';
    body += '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 8px 24px rgba(16,24,40,0.08);overflow:hidden;">';
    body += '<tr><td style="padding:20px 24px;background:linear-gradient(135deg,#0f172a,#1e293b);color:#ffffff;">';
    body += '<div style="font-size:18px;font-weight:600;">Resumo de tarefas</div>';
    body +=
      '<div style="font-size:13px;opacity:.85;margin-top:6px;">Ola, ' +
      TaskSlaUtils.escapeHtml(recipientName) +
      '</div>';
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
        body +=
          '<a href="' +
          taskLink +
          '" style="color:#2563eb;text-decoration:none;">' +
          subject +
          '</a>';
      } else {
        body += subject;
      }
      body += '</div>';
      body +=
        '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' +
        TaskSlaUtils.escapeHtml(dueDate) +
        '</div>';
      body += '</td>';
      body += '</tr>';
    }
    body += '</table>';
    if (!String.isBlank(link)) {
      body += '<div style="margin-top:16px;">';
      body +=
        '<a href="' +
        link +
        '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Ver lista completa</a>';
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
    body +=
      '<div style="font-size:13px;opacity:.85;margin-top:6px;">Ola, ' +
      TaskSlaUtils.escapeHtml(recipientName) +
      '</div>';
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
      body +=
        '<a href="' +
        link +
        '" style="display:inline-block;background:#2563eb;color:#ffffff;padding:10px 16px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;">Ver lista completa</a>';
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

  private static String buildBucketSection(
    String title,
    List<Task> tasks,
    Integer topN
  ) {
    String section = '<div style="margin:16px 0 8px 0;">';
    section +=
      '<div style="font-size:14px;font-weight:600;color:#0f172a;">' +
      TaskSlaUtils.escapeHtml(title) +
      ' <span style="background:#e2e8f0;color:#0f172a;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:600;">' +
      tasks.size() +
      '</span></div>';
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
        section +=
          '<a href="' +
          taskLink +
          '" style="color:#2563eb;text-decoration:none;">' +
          subject +
          '</a>';
      } else {
        section += subject;
      }
      section += '</div>';
      section +=
        '<div style="font-size:12px;color:#6b7280;margin-top:4px;">Vencimento: ' +
        TaskSlaUtils.escapeHtml(dueDate) +
        '</div>';
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
    return formatDescription(description, null);
  }

  private static String formatDescription(
    String description,
    Integer maxLength
  ) {
    if (String.isBlank(description)) {
      return '';
    }
    String normalized = description.trim();
    if (maxLength != null && maxLength > 0 && normalized.length() > maxLength) {
      normalized = normalized.substring(0, maxLength) + '...';
    }
    String safe = TaskSlaUtils.escapeHtml(normalized);
    safe = safe.replace('\r\n', '<br/>');
    safe = safe.replace('\n', '<br/>');
    return safe;
  }

  private static Integer countTasksByDueDate(
    List<Task> personalTasks,
    Map<String, List<Task>> teamTasksByRole,
    Date referenceDate,
    Boolean overdue
  ) {
    Integer total = 0;
    List<Task> safePersonal = personalTasks != null
      ? personalTasks
      : new List<Task>();
    for (Task taskRecord : safePersonal) {
      if (matchesDueBucket(taskRecord, referenceDate, overdue)) {
        total++;
      }
    }
    if (teamTasksByRole != null && !teamTasksByRole.isEmpty()) {
      for (List<Task> roleTasks : teamTasksByRole.values()) {
        if (roleTasks == null || roleTasks.isEmpty()) {
          continue;
        }
        for (Task taskRecord : roleTasks) {
          if (matchesDueBucket(taskRecord, referenceDate, overdue)) {
            total++;
          }
        }
      }
    }
    return total;
  }

  private static Boolean matchesDueBucket(
    Task taskRecord,
    Date referenceDate,
    Boolean overdue
  ) {
    if (
      taskRecord == null ||
      taskRecord.ActivityDate == null ||
      referenceDate == null
    ) {
      return false;
    }
    if (overdue) {
      return taskRecord.ActivityDate < referenceDate;
    }
    return taskRecord.ActivityDate == referenceDate;
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
      String soql =
        'SELECT Id, ' +
        nameField +
        ' FROM ' +
        apiName +
        ' WHERE Id IN :idsForType';
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

  private static String resolveNameFieldApiName(
    Schema.DescribeSObjectResult describe
  ) {
    if (describe == null) {
      return '';
    }
    Map<String, Schema.SObjectField> fields = describe.fields.getMap();
    for (String fieldName : fields.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName)
        .getDescribe();
      if (fieldDescribe != null && fieldDescribe.isNameField()) {
        return fieldDescribe.getName();
      }
    }
    return '';
  }

  private static String buildRelatedHtml(
    Task taskRecord,
    Map<Id, String> relatedNames
  ) {
    if (taskRecord == null) {
      return '';
    }
    Id relatedId = taskRecord.WhatId != null
      ? taskRecord.WhatId
      : taskRecord.WhoId;
    if (relatedId == null) {
      return '';
    }
    String label = relatedId.getSObjectType().getDescribe().getLabel();
    String name = relatedNames != null ? relatedNames.get(relatedId) : null;
    String safeLabel = TaskSlaUtils.escapeHtml(label);
    String safeName = TaskSlaUtils.escapeHtml(name);
    String display = !String.isBlank(safeName)
      ? safeLabel + ' - ' + safeName
      : safeLabel;
    String link = buildRecordLink(relatedId);
    if (String.isBlank(link)) {
      return display;
    }
    return '<a href="' +
      link +
      '" style="color:#2563eb;text-decoration:none;">' +
      display +
      '</a>';
  }

  private static void addSummaryLogs(
    List<Log__c> logs,
    Id relatedId,
    String type,
    Integer count
  ) {
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

  private static Set<String> getSentRelatedIdsToday(
    String logType,
    Set<String> relatedIds
  ) {
    Set<String> sentRelatedIds = new Set<String>();
    if (String.isBlank(logType) || relatedIds == null || relatedIds.isEmpty()) {
      return sentRelatedIds;
    }
    for (Log__c logRecord : [
      SELECT RelatedId__c
      FROM Log__c
      WHERE
        Type__c = :logType
        AND RelatedId__c IN :relatedIds
        AND CreatedDate = TODAY
    ]) {
      if (!String.isBlank(logRecord.RelatedId__c)) {
        sentRelatedIds.add(logRecord.RelatedId__c);
      }
    }
    return sentRelatedIds;
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
    return baseUrl +
      '/lightning/r/' +
      objectName +
      '/' +
      String.valueOf(recordId) +
      '/view';
  }
}
