/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-26-2026
 * @last modified by  : Daniel Belini
 * @test              : HelpDeskCaseServiceTest, ModuloHelpDeskCaseControllerTest
 **/
public without sharing class HelpDeskCaseService {
  public class DefaultEntitiesDTO {
    @AuraEnabled
    public Id contactId;
    @AuraEnabled
    public String contactName;
    @AuraEnabled
    public String contactEmail;
    @AuraEnabled
    public String contactPhone;
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public String accountName;
  }

  public class CaseCategoryOptionDTO {
    @AuraEnabled
    public String systemValue;
    @AuraEnabled
    public String typeValue;
    @AuraEnabled
    public String subtypeValue;
    @AuraEnabled
    public Integer sortOrder;
  }

  public class ApprovalStatusDTO {
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String currentApproverName;
    @AuraEnabled
    public String currentApproverId;
    @AuraEnabled
    public String supervisorName;
    @AuraEnabled
    public String gerenteName;
  }

  public static List<Case> getCases(
    String filterType,
    String searchTerm,
    Id contactId,
    UserContext ctx
  ) {
    String ownershipFilter = buildOwnershipFilter(ctx, contactId);
    Boolean closed = (filterType != null &&
    filterType.toLowerCase() == 'closed');
    List<Case> raw = HelpDeskCaseDAO.queryCases(
      ownershipFilter,
      closed,
      searchTerm
    );
    return (List<Case>) Security.stripInaccessible(AccessType.READABLE, raw)
      .getRecords();
  }

  public static Case getCaseDetail(Id caseId, Id contactId, UserContext ctx) {
    enforceVisibility(caseId, contactId, ctx);
    Case detail = HelpDeskCaseDAO.queryCaseDetail(caseId);
    List<Case> sanitized = (List<Case>) Security.stripInaccessible(
        AccessType.READABLE,
        new List<Case>{ detail }
      )
      .getRecords();
    return sanitized.isEmpty() ? null : sanitized[0];
  }

  public static List<CaseComment> getCaseComments(
    Id caseId,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    List<CaseComment> comments = HelpDeskCaseDAO.queryComments(caseId);
    return (List<CaseComment>) Security.stripInaccessible(
        AccessType.READABLE,
        comments
      )
      .getRecords();
  }

  public static List<ContentDocumentLink> getCaseAttachments(
    Id caseId,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    // Bypass de leitura para Experience Cloud com autenticacao custom (sem User real do portal).
    return HelpDeskCaseDAO.queryAttachments(caseId);
  }

  public static CaseComment addComment(
    Id caseId,
    String commentBody,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    if (String.isBlank(commentBody)) {
      throw new AuraHandledException('O comentário não pode estar vazio.');
    }
    CaseComment comment = new CaseComment();
    comment.ParentId = caseId;
    comment.CommentBody = commentBody;
    comment.IsPublished = true;
    List<CaseComment> sanitized = (List<CaseComment>) Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<CaseComment>{ comment }
      )
      .getRecords();
    if (sanitized.isEmpty()) {
      throw new AuraHandledException(
        'Você não tem permissão para criar comentários.'
      );
    }
    HelpDeskCaseDAO.insertComment(sanitized[0]);
    return sanitized[0];
  }

  public static Id addMessage(
    Id caseId,
    String body,
    String authorName,
    String authorType,
    Boolean isPublic,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    if (String.isBlank(body)) {
      throw new AuraHandledException('O comentário não pode estar vazio.');
    }
    HelpDeskMessage__c msg = new HelpDeskMessage__c();
    msg.Case__c = caseId;
    msg.Body__c = body;
    String normalizedAuthorType = String.isNotBlank(authorType)
      ? authorType
      : 'Cliente';
    msg.AuthorType__c = normalizedAuthorType;
    msg.AuthorName__c = resolveMessageAuthorName(
      authorName,
      normalizedAuthorType,
      contactId,
      ctx
    );
    msg.IsPublic__c = isPublic != null ? isPublic : true;
    HelpDeskCaseDAO.insertMessage(msg);
    return msg.Id;
  }

  public static List<HelpDeskMessage__c> getMessages(
    Id caseId,
    Id contactId,
    UserContext ctx,
    Boolean includePrivate
  ) {
    enforceVisibility(caseId, contactId, ctx);
    if (includePrivate == true) {
      return HelpDeskCaseDAO.queryAllMessages(caseId);
    }
    return HelpDeskCaseDAO.queryMessages(caseId);
  }

  public static ApprovalStatusDTO getApprovalStatus(
    Id caseId,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    Case detail = HelpDeskCaseDAO.queryApprovalDetail(caseId);
    ApprovalStatusDTO dto = new ApprovalStatusDTO();
    dto.status = detail.StatusAprovacao__c;

    List<ProcessInstanceWorkitem> workitems = HelpDeskCaseDAO.queryPendingApprovalWorkitems(
      caseId
    );
    Id currentApproverId = workitems.isEmpty() ? null : workitems[0].ActorId;
    if (currentApproverId != null) {
      dto.currentApproverId = String.valueOf(currentApproverId);
    }

    dto.supervisorName = resolveApprovalDisplayName(
      detail.SupervisorNome__c,
      detail.Contact != null &&
        detail.Contact.Supervisor__r != null
        ? detail.Contact.Supervisor__r.Name
        : null
    );
    dto.gerenteName = resolveApprovalDisplayName(
      detail.GerenteNome__c,
      detail.Contact != null &&
        detail.Contact.Gerente__r != null
        ? detail.Contact.Gerente__r.Name
        : null
    );

    // Fallback para casos antigos (criados antes do snapshot) ou usuários
    // internos: resolve via helper, em contexto de sistema.
    if (
      isMaskedUserName(dto.supervisorName) || isMaskedUserName(dto.gerenteName)
    ) {
      Map<Id, String> userNames = HelpDeskApproverHelper.getUserNames(
        new Set<Id>{ detail.Supervisor__c, detail.Gerente__c }
      );
      if (isMaskedUserName(dto.supervisorName)) {
        dto.supervisorName = userNames.get(detail.Supervisor__c);
      }
      if (isMaskedUserName(dto.gerenteName)) {
        dto.gerenteName = userNames.get(detail.Gerente__c);
      }
    }

    // O aprovador atual é o Supervisor (etapa 1) ou o Gerente (etapa 2):
    // resolve a partir do snapshot, comparando o ActorId do workitem pendente.
    if (currentApproverId == detail.Supervisor__c) {
      dto.currentApproverName = dto.supervisorName;
    } else if (currentApproverId == detail.Gerente__c) {
      dto.currentApproverName = dto.gerenteName;
    } else if (currentApproverId != null) {
      Map<Id, String> approverNames = HelpDeskApproverHelper.getUserNames(
        new Set<Id>{ currentApproverId }
      );
      dto.currentApproverName = approverNames.get(currentApproverId);
    }
    return dto;
  }

  private static String resolveApprovalDisplayName(
    String caseSnapshotName,
    String contactLookupName
  ) {
    if (
      String.isNotBlank(contactLookupName) && isMaskedUserName(caseSnapshotName)
    ) {
      return contactLookupName;
    }
    return String.isNotBlank(caseSnapshotName)
      ? caseSnapshotName
      : contactLookupName;
  }

  private static Boolean isMaskedUserName(String value) {
    return String.isBlank(value) || value.startsWith('Usuário');
  }

  /**
   * Retorna os anexos (AttachmentLink__c) vinculados às mensagens do caso, agrupados por mensagem.
   */
  public static List<AttachmentLink__c> getCaseAttachmentLinks(
    Id caseId,
    Id contactId,
    UserContext ctx,
    Boolean includePrivate
  ) {
    enforceVisibility(caseId, contactId, ctx);
    List<HelpDeskMessage__c> messages = includePrivate == true
      ? HelpDeskCaseDAO.queryAllMessages(caseId)
      : HelpDeskCaseDAO.queryMessages(caseId);
    Set<Id> messageIds = new Set<Id>();
    for (HelpDeskMessage__c m : messages) {
      messageIds.add(m.Id);
    }
    if (messageIds.isEmpty()) {
      return new List<AttachmentLink__c>();
    }
    return HelpDeskCaseDAO.queryAttachmentLinksByParents(messageIds);
  }

  public static List<CaseCategoryOptionDTO> getCaseCategoryOptions() {
    List<CaseCategoryOptionDTO> options = new List<CaseCategoryOptionDTO>();
    for (HelpDesk_Case_Category__mdt row : [
      SELECT Sistema__c, Tipo__c, Subtipo__c, SortOrder__c
      FROM HelpDesk_Case_Category__mdt
      WHERE Active__c = TRUE
      ORDER BY
        SortOrder__c ASC NULLS LAST,
        Sistema__c ASC,
        Tipo__c ASC,
        Subtipo__c ASC
    ]) {
      if (
        String.isBlank(row.Sistema__c) ||
        String.isBlank(row.Tipo__c) ||
        String.isBlank(row.Subtipo__c)
      ) {
        continue;
      }
      CaseCategoryOptionDTO dto = new CaseCategoryOptionDTO();
      dto.systemValue = row.Sistema__c;
      dto.typeValue = row.Tipo__c;
      dto.subtypeValue = row.Subtipo__c;
      dto.sortOrder = row.SortOrder__c == null
        ? null
        : Integer.valueOf(row.SortOrder__c);
      options.add(dto);
    }
    return options;
  }

  public static Id createCase(
    String subject,
    String description,
    String richDescription,
    String systemValue,
    String typeValue,
    String subtypeValue,
    String priorityValue,
    String suppliedEmail,
    String suppliedPhone,
    Id contactId,
    Id accountId
  ) {
    if (String.isBlank(subject)) {
      throw new AuraHandledException('Subject é obrigatório.');
    }
    Case newCase = new Case();
    newCase.Subject = subject;
    newCase.Description = buildCaseDescription(description, systemValue);
    if (String.isNotBlank(richDescription)) {
      newCase.Description_Rich__c = richDescription;
    }
    Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
    if (
      String.isNotBlank(systemValue) &&
      caseFields.containsKey('HelpDesk_Sistema__c')
    ) {
      newCase.put('HelpDesk_Sistema__c', systemValue);
    }
    if (String.isNotBlank(typeValue) && caseFields.containsKey('HelpDesk_Tipo__c')) {
      newCase.put('HelpDesk_Tipo__c', typeValue);
    }
    if (
      String.isNotBlank(subtypeValue) &&
      caseFields.containsKey('HelpDesk_Subtipo__c')
    ) {
      newCase.put('HelpDesk_Subtipo__c', subtypeValue);
    }
    if (String.isNotBlank(priorityValue)) {
      newCase.Priority = priorityValue;
    }
    newCase.SuppliedEmail = suppliedEmail;
    newCase.SuppliedPhone = suppliedPhone;
    newCase.Origin = 'Help Desk Salesforce';
    newCase.RecordTypeId = HelpDeskCaseDAO.resolveRecordTypeId(
      'Case',
      'Help_Desk_Salesforce'
    );
    if (contactId != null) {
      newCase.ContactId = contactId;
    }
    if (accountId != null) {
      newCase.AccountId = accountId;
    }
    List<Case> sanitized = (List<Case>) Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<Case>{ newCase }
      )
      .getRecords();
    if (sanitized.isEmpty()) {
      throw new AuraHandledException(
        'Você não tem permissão para criar casos.'
      );
    }
    HelpDeskCaseDAO.insertCase(sanitized[0]);
    return sanitized[0].Id;
  }

  public static void uploadFiles(
    Id caseId,
    List<HelpDeskFilePayload> files,
    Id contactId,
    UserContext ctx
  ) {
    uploadFilesInternal(caseId, null, files, contactId, ctx, false);
  }

  public static void uploadFilesBypassLicense(
    Id caseId,
    List<HelpDeskFilePayload> files,
    Id contactId,
    UserContext ctx
  ) {
    uploadFilesInternal(caseId, null, files, contactId, ctx, true);
  }

  public static void uploadFilesToMessage(
    Id caseId,
    Id messageId,
    List<HelpDeskFilePayload> files,
    Id contactId,
    UserContext ctx
  ) {
    uploadFilesInternal(caseId, messageId, files, contactId, ctx, true);
  }

  public static Id uploadMessageFileExternal(
    Id caseId,
    Id messageId,
    String fileName,
    String base64File,
    Id contactId,
    UserContext ctx
  ) {
    enforceVisibility(caseId, contactId, ctx);
    if (String.isBlank(base64File) || String.isBlank(fileName)) {
      throw new AuraHandledException('fileName e base64File são obrigatórios.');
    }

    // Vincula o anexo à mensagem (HelpDeskMessage__c) quando houver; senão, ao Case.
    Id linkParentId = messageId != null ? messageId : caseId;
    String linkParentType = messageId != null ? 'HelpDeskMessage__c' : 'Case';

    ExternalArchiveService.UploadResult result = ExternalArchiveService.uploadExternalArchiveForCase(
      caseId,
      fileName,
      base64File,
      'Help Desk',
      fileName,
      linkParentId,
      linkParentType
    );

    if (result == null || !result.success) {
      throw new AuraHandledException(
        result != null
          ? result.message
          : 'Falha ao enviar arquivo para API externa.'
      );
    }

    // Quando o anexo pertence a uma mensagem do portal, reescreve a seção
    // "Anexos:" do CaseComment espelhado com todos os anexos atuais, para que
    // cheguem ao Jira (conector Getint). O BO busca os AttachmentLink__c.
    if (messageId != null && result.attachmentId != null) {
      HelpDeskMessageBO.appendAttachmentUrlsToComment(messageId, null, null);
    }

    // result.attachmentId é o Id do AttachmentLink__c criado (SObjectId__c = messageId).
    return result.attachmentId;
  }

  private static void uploadFilesInternal(
    Id caseId,
    Id messageId,
    List<HelpDeskFilePayload> files,
    Id contactId,
    UserContext ctx,
    Boolean bypassSecurity
  ) {
    if (caseId == null) {
      throw new AuraHandledException(
        'caseId é obrigatório para anexar arquivos.'
      );
    }
    if (files == null || files.isEmpty()) {
      return;
    }
    enforceVisibility(caseId, contactId, ctx);
    Id linkedEntityId = messageId != null ? messageId : caseId;
    Id networkId = resolveCurrentNetworkId();
    List<ContentVersion> versions = new List<ContentVersion>();
    Integer receivedFiles = 0;
    Integer validFiles = 0;
    for (HelpDeskFilePayload file : files) {
      receivedFiles++;
      if (file == null) {
        continue;
      }
      String resolvedFileName = String.isNotBlank(file.fileName)
        ? file.fileName
        : file.name;
      if (String.isBlank(resolvedFileName) || String.isBlank(file.base64Data)) {
        continue;
      }
      ContentVersion cv = new ContentVersion();
      cv.Title = resolvedFileName;
      cv.PathOnClient = '/' + resolvedFileName;
      cv.VersionData = EncodingUtil.base64Decode(file.base64Data);
      if (networkId != null) {
        cv.NetworkId = networkId;
      }
      versions.add(cv);
      validFiles++;
    }
    if (versions.isEmpty()) {
      throw new AuraHandledException(
        'Nenhum arquivo válido recebido. Enviados: ' +
          String.valueOf(receivedFiles) +
          ', válidos: ' +
          String.valueOf(validFiles) +
          '. Verifique fileName/name e base64Data no payload.'
      );
    }

    List<ContentVersion> insertedVersions;
    if (bypassSecurity) {
      HelpDeskCaseDAO.insertVersions(versions);
      insertedVersions = versions;
    } else {
      List<ContentVersion> sanitized = (List<ContentVersion>) Security.stripInaccessible(
          AccessType.CREATABLE,
          versions
        )
        .getRecords();
      if (sanitized.isEmpty()) {
        throw new AuraHandledException(
          'Você não tem permissão para anexar arquivos.'
        );
      }
      HelpDeskCaseDAO.insertVersions(sanitized);
      insertedVersions = sanitized;
    }

    Set<Id> insertedVersionIds = new Set<Id>();
    for (ContentVersion cvInserted : insertedVersions) {
      if (cvInserted.Id != null) {
        insertedVersionIds.add(cvInserted.Id);
      }
    }
    if (insertedVersionIds.isEmpty()) {
      return;
    }

    List<ContentVersion> storedVersions = HelpDeskCaseDAO.queryVersionsById(
      insertedVersionIds
    );
    List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
    for (ContentVersion storedVersion : storedVersions) {
      if (storedVersion.ContentDocumentId == null) {
        continue;
      }
      linksToInsert.add(
        new ContentDocumentLink(
          ContentDocumentId = storedVersion.ContentDocumentId,
          LinkedEntityId = linkedEntityId,
          ShareType = 'V',
          Visibility = 'AllUsers'
        )
      );
    }

    if (linksToInsert.isEmpty()) {
      return;
    }

    if (bypassSecurity) {
      HelpDeskCaseDAO.insertLinks(linksToInsert);
      return;
    }

    List<ContentDocumentLink> sanitizedLinks = (List<ContentDocumentLink>) Security.stripInaccessible(
        AccessType.CREATABLE,
        linksToInsert
      )
      .getRecords();
    if (sanitizedLinks.isEmpty()) {
      throw new AuraHandledException(
        'Você não tem permissão para vincular anexos ao caso.'
      );
    }
    HelpDeskCaseDAO.insertLinks(sanitizedLinks);
  }

  public static DefaultEntitiesDTO getDefaultEntities(Id contactId) {
    DefaultEntitiesDTO dto = new DefaultEntitiesDTO();
    Account a = HelpDeskContactDAO.findEnerzeeAccount();
    Contact c = HelpDeskContactDAO.findById(contactId);
    if (a != null) {
      dto.accountId = a.Id;
      dto.accountName = a.Name;
    }
    if (c != null) {
      dto.contactId = c.Id;
      dto.contactName = c.Name;
      dto.contactEmail = c.Email;
      dto.contactPhone = String.isNotBlank(c.MobilePhone)
        ? c.MobilePhone
        : c.Phone;
    }
    return dto;
  }

  public class UserContext {
    public Id userId;
    public Id contactId;
    public String email;
    public String name;
  }

  public static UserContext loadUserContext() {
    UserContext ctx = new UserContext();
    ctx.userId = UserInfo.getUserId();
    List<User> users = [
      SELECT Id, ContactId, Email, Name
      FROM User
      WHERE Id = :ctx.userId
      LIMIT 1
    ];
    if (!users.isEmpty()) {
      ctx.contactId = users[0].ContactId;
      ctx.email = users[0].Email;
      ctx.name = users[0].Name;
    }
    return ctx;
  }

  private static String resolveMessageAuthorName(
    String authorName,
    String authorType,
    Id contactId,
    UserContext ctx
  ) {
    if (String.isNotBlank(authorName)) {
      return authorName;
    }
    if (authorType == 'Agente') {
      return String.isNotBlank(ctx.name) ? ctx.name : 'Agente';
    }
    Contact contactRecord = HelpDeskContactDAO.findById(contactId);
    if (contactRecord != null && String.isNotBlank(contactRecord.Name)) {
      return contactRecord.Name;
    }
    return 'Cliente';
  }

  private static String buildOwnershipFilter(
    UserContext ctx,
    Id overrideContactId
  ) {
    if (overrideContactId != null) {
      return 'ContactId = \'' +
        String.escapeSingleQuotes(String.valueOf(overrideContactId)) +
        '\'';
    }
    if (ctx.contactId != null) {
      return 'ContactId = \'' +
        String.escapeSingleQuotes(String.valueOf(ctx.contactId)) +
        '\'';
    }
    if (String.isNotBlank(ctx.email)) {
      String emailEscaped = String.escapeSingleQuotes(ctx.email);
      String userIdEscaped = String.escapeSingleQuotes(
        String.valueOf(ctx.userId)
      );
      return '(SuppliedEmail = \'' +
        emailEscaped +
        '\' OR CreatedById = \'' +
        userIdEscaped +
        '\')';
    }
    return 'CreatedById = \'' +
      String.escapeSingleQuotes(String.valueOf(ctx.userId)) +
      '\'';
  }

  private static String buildCaseDescription(
    String description,
    String systemValue
  ) {
    List<String> parts = new List<String>();
    if (String.isNotBlank(systemValue)) {
      parts.add('Sistema: ' + systemValue);
    }
    if (String.isNotBlank(description)) {
      parts.add(description);
    }
    return parts.isEmpty() ? null : String.join(parts, '\n');
  }

  private static Id resolveCurrentNetworkId() {
    try {
      return Network.getNetworkId();
    } catch (Exception e) {
      return null;
    }
  }

  private static void enforceVisibility(
    Id caseId,
    Id overrideContactId,
    UserContext ctx
  ) {
    if (isInternalUser()) {
      List<Case> rows = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
      if (rows.isEmpty()) {
        throw new AuraHandledException(
          'Caso não encontrado ou sem permissão de acesso.'
        );
      }
      return;
    }
    String ownershipFilter = buildOwnershipFilter(ctx, overrideContactId);
    String query =
      'SELECT Id FROM Case WHERE Id = :caseId AND ' +
      ownershipFilter +
      ' LIMIT 1';
    List<Case> rows = Database.query(query);
    if (rows.isEmpty()) {
      throw new AuraHandledException(
        'Caso não encontrado ou sem permissão de acesso.'
      );
    }
  }

  private static Boolean isInternalUser() {
    return !UserInfo.getUserType().equalsIgnoreCase('Guest') &&
      !UserInfo.getUserType().equalsIgnoreCase('PowerPartner') &&
      !UserInfo.getUserType().equalsIgnoreCase('CustomerSuccess');
  }
}
