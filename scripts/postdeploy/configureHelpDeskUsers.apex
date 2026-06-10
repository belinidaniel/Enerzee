Map<Id, UserRole> rolesById = new Map<Id, UserRole>(
  [SELECT Id, Name, ParentRoleId FROM UserRole]
);
List<User> activeUsers = [
  SELECT Id, Name, UserRoleId, ManagerId
  FROM User
  WHERE IsActive = TRUE AND UserType = 'Standard' AND UserRoleId != NULL
];

Map<Id, List<User>> usersByRole = new Map<Id, List<User>>();
for (User userRecord : activeUsers) {
  if (!usersByRole.containsKey(userRecord.UserRoleId)) {
    usersByRole.put(userRecord.UserRoleId, new List<User>());
  }
  usersByRole.get(userRecord.UserRoleId).add(userRecord);
}

Set<Id> managerUserIds = new Set<Id>();
List<User> usersToUpdate = new List<User>();
List<String> ambiguousUsers = new List<String>();
List<String> managerUpdateFailures = new List<String>();

for (User subordinate : activeUsers) {
  Id currentRoleId = subordinate.UserRoleId;
  Boolean resolved = false;

  while (
    currentRoleId != null &&
    rolesById.containsKey(currentRoleId) &&
    rolesById.get(currentRoleId).ParentRoleId != null
  ) {
    Id parentRoleId = rolesById.get(currentRoleId).ParentRoleId;
    List<User> candidates = usersByRole.get(parentRoleId);

    if (candidates != null && !candidates.isEmpty()) {
      for (User candidate : candidates) {
        managerUserIds.add(candidate.Id);
      }

      if (subordinate.ManagerId == null) {
        if (candidates.size() == 1) {
          subordinate.ManagerId = candidates[0].Id;
          usersToUpdate.add(subordinate);
        } else {
          ambiguousUsers.add(
            subordinate.Name +
            ' (' +
            rolesById.get(subordinate.UserRoleId).Name +
            ')'
          );
        }
      }
      resolved = true;
      break;
    }

    currentRoleId = parentRoleId;
  }

  if (!resolved && subordinate.ManagerId != null) {
    managerUserIds.add(subordinate.ManagerId);
  }
}

if (!usersToUpdate.isEmpty()) {
  Database.SaveResult[] managerUpdateResults = Database.update(
    usersToUpdate,
    false
  );
  for (Integer i = 0; i < managerUpdateResults.size(); i++) {
    if (!managerUpdateResults[i].isSuccess()) {
      managerUpdateFailures.add(
        usersToUpdate[i].Name +
        ': ' +
        managerUpdateResults[i].getErrors()[0].getMessage()
      );
    }
  }
}

Map<String, PermissionSet> permissionSetsByName = new Map<String, PermissionSet>();
for (PermissionSet permissionSetRecord : [
  SELECT Id, Name
  FROM PermissionSet
  WHERE Name IN ('HelpDesk_Aprovacao_Admin', 'HelpDesk_Usuario_Interno')
]) {
  permissionSetsByName.put(permissionSetRecord.Name, permissionSetRecord);
}

Id managerPermissionSetId = permissionSetsByName.get(
    'HelpDesk_Aprovacao_Admin'
  )
  .Id;
Id userPermissionSetId = permissionSetsByName.get('HelpDesk_Usuario_Interno')
  .Id;
Set<Id> scopedUserIds = new Map<Id, User>(activeUsers).keySet();
Map<Id, PermissionSetAssignment> managerAssignmentByUser = new Map<Id, PermissionSetAssignment>();
Map<Id, PermissionSetAssignment> userAssignmentByUser = new Map<Id, PermissionSetAssignment>();

for (PermissionSetAssignment assignment : [
  SELECT Id, AssigneeId, PermissionSetId
  FROM PermissionSetAssignment
  WHERE
    AssigneeId IN :scopedUserIds
    AND PermissionSetId IN :new Set<Id>{
      managerPermissionSetId,
      userPermissionSetId
    }
]) {
  if (assignment.PermissionSetId == managerPermissionSetId) {
    managerAssignmentByUser.put(assignment.AssigneeId, assignment);
  } else {
    userAssignmentByUser.put(assignment.AssigneeId, assignment);
  }
}

List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
List<PermissionSetAssignment> assignmentsToDelete = new List<PermissionSetAssignment>();
Map<Id, PermissionSetAssignment> conflictingAssignmentByUser = new Map<Id, PermissionSetAssignment>();
for (User userRecord : activeUsers) {
  Boolean isManager = managerUserIds.contains(userRecord.Id);
  if (isManager) {
    if (!managerAssignmentByUser.containsKey(userRecord.Id)) {
      assignmentsToInsert.add(
        new PermissionSetAssignment(
          AssigneeId = userRecord.Id,
          PermissionSetId = managerPermissionSetId
        )
      );
    }
    if (userAssignmentByUser.containsKey(userRecord.Id)) {
      conflictingAssignmentByUser.put(
        userRecord.Id,
        userAssignmentByUser.get(userRecord.Id)
      );
    }
  } else {
    if (!userAssignmentByUser.containsKey(userRecord.Id)) {
      assignmentsToInsert.add(
        new PermissionSetAssignment(
          AssigneeId = userRecord.Id,
          PermissionSetId = userPermissionSetId
        )
      );
    }
    if (managerAssignmentByUser.containsKey(userRecord.Id)) {
      conflictingAssignmentByUser.put(
        userRecord.Id,
        managerAssignmentByUser.get(userRecord.Id)
      );
    }
  }
}

Integer assignmentsInserted = 0;
List<String> assignmentFailures = new List<String>();
if (!assignmentsToInsert.isEmpty()) {
  Database.SaveResult[] assignmentResults = Database.insert(
    assignmentsToInsert,
    false
  );
  for (Integer i = 0; i < assignmentResults.size(); i++) {
    PermissionSetAssignment attemptedAssignment = assignmentsToInsert[i];
    if (assignmentResults[i].isSuccess()) {
      assignmentsInserted++;
      if (
        conflictingAssignmentByUser.containsKey(
          attemptedAssignment.AssigneeId
        )
      ) {
        assignmentsToDelete.add(
          conflictingAssignmentByUser.get(attemptedAssignment.AssigneeId)
        );
      }
    } else {
      assignmentFailures.add(
        String.valueOf(attemptedAssignment.AssigneeId) +
        ': ' +
        assignmentResults[i].getErrors()[0].getMessage()
      );
    }
  }
}
if (!assignmentsToDelete.isEmpty()) {
  Database.delete(assignmentsToDelete, false);
}

Group managerGroup = [
  SELECT Id
  FROM Group
  WHERE DeveloperName = 'HelpDesk_Managers'
  LIMIT 1
];
Set<Id> existingGroupMemberIds = new Set<Id>();
for (GroupMember groupMember : [
  SELECT UserOrGroupId
  FROM GroupMember
  WHERE GroupId = :managerGroup.Id
]) {
  existingGroupMemberIds.add(groupMember.UserOrGroupId);
}

List<GroupMember> groupMembersToInsert = new List<GroupMember>();
for (Id managerUserId : managerUserIds) {
  if (
    scopedUserIds.contains(managerUserId) &&
    !existingGroupMemberIds.contains(managerUserId)
  ) {
    groupMembersToInsert.add(
      new GroupMember(
        GroupId = managerGroup.Id,
        UserOrGroupId = managerUserId
      )
    );
  }
}
if (!groupMembersToInsert.isEmpty()) {
  insert groupMembersToInsert;
}

User fallbackApprover = [
  SELECT Id, Name, IsActive
  FROM User
  WHERE Email = 'elenara.rodrigues@enerzee.com.br' AND IsActive = TRUE
  LIMIT 1
];

System.debug(
  LoggingLevel.ERROR,
  'HELPDESK_POST_DEPLOY usersUpdated=' +
  usersToUpdate.size() +
  ', managerUsers=' +
  managerUserIds.size() +
  ', assignmentsInserted=' +
  assignmentsInserted +
  ', assignmentsDeleted=' +
  assignmentsToDelete.size() +
  ', groupMembersInserted=' +
  groupMembersToInsert.size() +
  ', fallbackApprover=' +
  fallbackApprover.Name +
  ', managerUpdateFailures=' +
  JSON.serialize(managerUpdateFailures) +
  ', assignmentFailures=' +
  JSON.serialize(assignmentFailures) +
  ', ambiguousUsers=' +
  JSON.serialize(ambiguousUsers)
);
