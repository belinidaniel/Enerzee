public with sharing class OpportunityCommentNotificationService {
  @TestVisible
  private static final String NOTIFICATION_TYPE_DEVELOPER_NAME = 'Padrao';
  private static final String LOG_NAME = 'Opportunity Comment Notification';
  private static final String LOG_CLASS = 'OpportunityCommentNotificationService';
  private static final String LOG_METHOD = 'notifyOnConsultantCommentChange';
  private static final String LOG_TYPE = 'OPP_COMMENT_NOTIFICATION';
  private static final String SYSTEM_SENDER_DISPLAY_NAME = 'Enerzee Sistema';
  private static final Integer COMMENT_PREVIEW_LENGTH = 220;
  private static final Integer IN_APP_BODY_MAX_LENGTH = 700;
  private static final Integer EMAIL_SUBJECT_MAX_LENGTH = 250;
  @TestVisible
  private static Id notificationTypeIdOverride;
  private static Boolean orgWideSenderResolved = false;
  private static Id cachedOrgWideSenderId;

  public static void notifyOnConsultantCommentChange(
    List<Opportunity> newRecords,
    Map<Id, Opportunity> oldRecordsMap
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    List<Opportunity> opportunitiesToNotify = new List<Opportunity>();
    Set<Id> ownerIds = new Set<Id>();

    for (Opportunity opportunityRecord : newRecords) {
      if (!isEligibleForNotification(opportunityRecord, oldRecordsMap)) {
        continue;
      }
      opportunitiesToNotify.add(opportunityRecord);
      if (opportunityRecord.OwnerId != null) {
        ownerIds.add(opportunityRecord.OwnerId);
      }
    }

    if (opportunitiesToNotify.isEmpty()) {
      return;
    }

    ownerIds.add(UserInfo.getUserId());

    Map<Id, User> activeUsersById = new Map<Id, User>();
    if (!ownerIds.isEmpty()) {
      for (User userRecord : [
        SELECT Id, IsActive, Email
        FROM User
        WHERE Id IN :ownerIds
      ]) {
        if (userRecord.IsActive) {
          activeUsersById.put(userRecord.Id, userRecord);
        }
      }
    }

    Id notificationTypeId = resolveNotificationTypeId();
    List<Log__c> logs = new List<Log__c>();

    for (Opportunity opportunityRecord : opportunitiesToNotify) {
      Id recipientId = resolveRecipientId(
        opportunityRecord.OwnerId,
        activeUsersById
      );
      User recipientUser = activeUsersById.get(recipientId);
      Boolean usedFallback = recipientId != opportunityRecord.OwnerId;
      Boolean inAppSent = false;
      Boolean emailSent = false;
      List<String> channelErrors = new List<String>();

      if (notificationTypeId == null) {
        channelErrors.add(
          'InAppError=Tipo de notificacao nao encontrado. Esperado DeveloperName=' +
          NOTIFICATION_TYPE_DEVELOPER_NAME
        );
      } else {
        try {
          if (Test.isRunningTest()) {
            inAppSent = true;
          } else {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(buildTitle(opportunityRecord));
            notification.setBody(buildInAppBody(opportunityRecord));
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetId(opportunityRecord.Id);
            notification.send(new Set<String>{ String.valueOf(recipientId) });
            inAppSent = true;
          }
        } catch (Exception inAppException) {
          channelErrors.add('InAppError=' + inAppException.getMessage());
        }
      }

      if (recipientUser == null || String.isBlank(recipientUser.Email)) {
        channelErrors.add('EmailError=Destinatario sem e-mail valido');
      } else {
        try {
          if (Test.isRunningTest()) {
            emailSent = true;
          } else {
            Messaging.SingleEmailMessage emailMessage = buildEmailMessage(
              opportunityRecord,
              recipientUser.Email
            );
            applySystemSender(emailMessage);
            Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(
              new List<Messaging.SingleEmailMessage>{ emailMessage },
              false
            );
            emailSent = !emailResults.isEmpty() && emailResults[0].isSuccess();
            if (!emailSent) {
              channelErrors.add(
                'EmailError=' + buildEmailErrorMessage(emailResults)
              );
            }
          }
        } catch (Exception emailException) {
          channelErrors.add('EmailError=' + emailException.getMessage());
        }
      }

      String logStatus = inAppSent && emailSent
        ? 'SUCCESS'
        : ((inAppSent || emailSent) ? 'PARTIAL_SUCCESS' : 'FAILURE');

      String logMessage =
        'InAppSent=' +
        String.valueOf(inAppSent) +
        '|EmailSent=' +
        String.valueOf(emailSent) +
        '|RecipientId=' +
        String.valueOf(recipientId) +
        '|RecipientEmail=' +
        (recipientUser != null ? recipientUser.Email : null) +
        '|OwnerId=' +
        String.valueOf(opportunityRecord.OwnerId) +
        '|FallbackUsed=' +
        String.valueOf(usedFallback) +
        '|CommentHash=' +
        EncodingUtil.convertToHex(
          Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(
              normalizeComment(opportunityRecord.ComentarioSolicitante__c)
            )
          )
        );

      if (!channelErrors.isEmpty()) {
        logMessage += '|Errors=' + String.join(channelErrors, ';');
      }

      logs.add(buildLog(opportunityRecord, logStatus, logMessage));
    }

    if (!logs.isEmpty()) {
      Database.insert(logs, false);
    }
  }

  private static Boolean isEligibleForNotification(
    Opportunity newOpportunity,
    Map<Id, Opportunity> oldRecordsMap
  ) {
    if (newOpportunity == null) {
      return false;
    }

    String newComment = normalizeComment(
      newOpportunity.ComentarioSolicitante__c
    );
    if (String.isBlank(newComment)) {
      return false;
    }

    Opportunity oldOpportunity = oldRecordsMap != null
      ? oldRecordsMap.get(newOpportunity.Id)
      : null;
    String oldComment = normalizeComment(
      oldOpportunity != null ? oldOpportunity.ComentarioSolicitante__c : null
    );

    return newComment != oldComment;
  }

  private static Id resolveRecipientId(
    Id ownerId,
    Map<Id, User> activeUsersById
  ) {
    if (
      ownerId != null &&
      activeUsersById != null &&
      activeUsersById.containsKey(ownerId)
    ) {
      return ownerId;
    }
    return UserInfo.getUserId();
  }

  @TestVisible
  private static String normalizeComment(String commentText) {
    if (String.isBlank(commentText)) {
      return '';
    }
    return commentText.replaceAll('[\\r\\n\\t]+', ' ')
      .replaceAll('\\s+', ' ')
      .trim();
  }

  private static Id resolveNotificationTypeId() {
    if (Test.isRunningTest() && notificationTypeIdOverride != null) {
      return notificationTypeIdOverride;
    }

    List<CustomNotificationType> typesByDeveloperName = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :NOTIFICATION_TYPE_DEVELOPER_NAME
      LIMIT 1
    ];
    if (!typesByDeveloperName.isEmpty()) {
      return typesByDeveloperName[0].Id;
    }

    List<CustomNotificationType> fallbackTypes = [
      SELECT Id
      FROM CustomNotificationType
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    return fallbackTypes.isEmpty() ? null : fallbackTypes[0].Id;
  }

  private static String buildTitle(Opportunity opportunityRecord) {
    String proposalIdentifier = !String.isBlank(
        opportunityRecord.Numeroproposta__c
      )
      ? opportunityRecord.Numeroproposta__c
      : (opportunityRecord.Name != null
          ? opportunityRecord.Name
          : 'Oportunidade');
    return 'Novo comentario do consultor - ' + proposalIdentifier;
  }

  private static String buildInAppBody(Opportunity opportunityRecord) {
    String normalizedComment = normalizeComment(
      opportunityRecord.ComentarioSolicitante__c
    );
    if (normalizedComment.length() > COMMENT_PREVIEW_LENGTH) {
      normalizedComment =
        normalizedComment.substring(0, COMMENT_PREVIEW_LENGTH) + '...';
    }

    String opportunityName = opportunityRecord.Name != null
      ? opportunityRecord.Name
      : '';
    String body =
      'Oportunidade: ' +
      opportunityName +
      ' | Comentario: ' +
      normalizedComment;

    if (body.length() > IN_APP_BODY_MAX_LENGTH) {
      return body.substring(0, IN_APP_BODY_MAX_LENGTH);
    }
    return body;
  }

  private static Messaging.SingleEmailMessage buildEmailMessage(
    Opportunity opportunityRecord,
    String recipientEmail
  ) {
    String title = buildTitle(opportunityRecord);
    if (title.length() > EMAIL_SUBJECT_MAX_LENGTH) {
      title = title.substring(0, EMAIL_SUBJECT_MAX_LENGTH);
    }

    Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
    emailMessage.setToAddresses(new List<String>{ recipientEmail });
    emailMessage.setSaveAsActivity(false);
    emailMessage.setSubject(title);
    String opportunityLink = buildOpportunityLink(opportunityRecord);
    emailMessage.setPlainTextBody(
      buildEmailPlainTextBody(opportunityRecord, opportunityLink)
    );
    emailMessage.setHtmlBody(
      buildEmailHtmlBody(opportunityRecord, opportunityLink)
    );
    return emailMessage;
  }

  private static String buildEmailPlainTextBody(
    Opportunity opportunityRecord,
    String opportunityLink
  ) {
    String normalizedComment = normalizeComment(
      opportunityRecord.ComentarioSolicitante__c
    );
    if (normalizedComment.length() > COMMENT_PREVIEW_LENGTH) {
      normalizedComment =
        normalizedComment.substring(0, COMMENT_PREVIEW_LENGTH) + '...';
    }

    String opportunityName = opportunityRecord.Name != null
      ? opportunityRecord.Name
      : '';
    return 'Oportunidade: ' +
      opportunityName +
      ' | Comentario: ' +
      normalizedComment +
      ' | Abrir oportunidade: ' +
      opportunityLink;
  }

  private static String buildEmailHtmlBody(
    Opportunity opportunityRecord,
    String opportunityLink
  ) {
    String opportunityName = escapeHtml(
      opportunityRecord != null ? opportunityRecord.Name : null
    );
    String normalizedComment = normalizeComment(
      opportunityRecord != null
        ? opportunityRecord.ComentarioSolicitante__c
        : null
    );
    if (normalizedComment.length() > COMMENT_PREVIEW_LENGTH) {
      normalizedComment =
        normalizedComment.substring(0, COMMENT_PREVIEW_LENGTH) + '...';
    }

    String html = '<html><body>';
    html += '<p><strong>Oportunidade:</strong> ' + opportunityName + '</p>';
    html +=
      '<p><strong>Comentario:</strong> ' +
      escapeHtml(normalizedComment) +
      '</p>';
    html += '<p><a href="' + opportunityLink + '">Abrir oportunidade</a></p>';
    html += '</body></html>';
    return html;
  }

  private static String buildOpportunityLink(Opportunity opportunityRecord) {
    if (opportunityRecord == null || opportunityRecord.Id == null) {
      return URL.getOrgDomainUrl().toExternalForm();
    }
    return URL.getOrgDomainUrl().toExternalForm() +
      '/lightning/r/Opportunity/' +
      String.valueOf(opportunityRecord.Id) +
      '/view';
  }

  private static String escapeHtml(String value) {
    if (value == null) {
      return '';
    }
    return value
      .replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;')
      .replace('\'', '&#39;');
  }

  private static void applySystemSender(
    Messaging.SingleEmailMessage emailMessage
  ) {
    if (emailMessage == null) {
      return;
    }

    Id orgWideSenderId = resolveSystemOrgWideEmailAddressId();
    if (orgWideSenderId != null) {
      emailMessage.setOrgWideEmailAddressId(orgWideSenderId);
      return;
    }

    emailMessage.setSenderDisplayName(SYSTEM_SENDER_DISPLAY_NAME);
  }

  private static Id resolveSystemOrgWideEmailAddressId() {
    if (orgWideSenderResolved) {
      return cachedOrgWideSenderId;
    }

    orgWideSenderResolved = true;
    cachedOrgWideSenderId = null;

    try {
      List<OrgWideEmailAddress> addresses = [
        SELECT Id, DisplayName, Address
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = TRUE
        ORDER BY DisplayName ASC, Address ASC
        LIMIT 50
      ];

      if (addresses.isEmpty()) {
        return null;
      }

      for (OrgWideEmailAddress address : addresses) {
        if (
          !String.isBlank(address.DisplayName) &&
          address.DisplayName.equalsIgnoreCase(SYSTEM_SENDER_DISPLAY_NAME)
        ) {
          cachedOrgWideSenderId = address.Id;
          return cachedOrgWideSenderId;
        }
      }

      for (OrgWideEmailAddress address : addresses) {
        String normalizedAddress = address.Address != null
          ? address.Address.toLowerCase()
          : '';
        if (
          normalizedAddress.contains('no-reply') ||
          normalizedAddress.contains('noreply')
        ) {
          cachedOrgWideSenderId = address.Id;
          return cachedOrgWideSenderId;
        }
      }

      cachedOrgWideSenderId = addresses[0].Id;
      return cachedOrgWideSenderId;
    } catch (Exception e) {
      return null;
    }
  }

  private static String buildEmailErrorMessage(
    List<Messaging.SendEmailResult> results
  ) {
    if (results == null || results.isEmpty() || results[0] == null) {
      return 'Falha no envio sem detalhe';
    }
    if (results[0].isSuccess()) {
      return '';
    }

    List<String> errorMessages = new List<String>();
    for (Messaging.SendEmailError sendError : results[0].getErrors()) {
      if (sendError != null && !String.isBlank(sendError.getMessage())) {
        errorMessages.add(sendError.getMessage());
      }
    }

    return errorMessages.isEmpty()
      ? 'Falha no envio sem detalhe'
      : String.join(errorMessages, ' | ');
  }

  private static Log__c buildLog(
    Opportunity opportunityRecord,
    String status,
    String message
  ) {
    Log__c logRecord = new Log__c();
    logRecord.Name = LOG_NAME;
    logRecord.Class__c = LOG_CLASS;
    logRecord.Method__c = LOG_METHOD;
    logRecord.Type__c = LOG_TYPE;
    logRecord.Status__c = status;
    logRecord.RelatedId__c = opportunityRecord != null &&
      opportunityRecord.Id != null
      ? String.valueOf(opportunityRecord.Id)
      : null;
    logRecord.Message__c = message;
    return logRecord;
  }
}
