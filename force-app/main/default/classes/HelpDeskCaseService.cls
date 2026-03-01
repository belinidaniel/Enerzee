/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 01-05-2026
 * @last modified by	 : Daniel Belini
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
    if (String.isNotBlank(typeValue)) {
      newCase.Type = typeValue;
    }
    if (String.isNotBlank(subtypeValue)) {
      newCase.Reason = subtypeValue;
    }
    if (
      String.isNotBlank(systemValue) &&
      Schema.SObjectType.Case.fields.getMap().containsKey('HelpDesk_Sistema__c')
    ) {
      newCase.put('HelpDesk_Sistema__c', systemValue);
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
    uploadFilesInternal(caseId, files, contactId, ctx, false);
  }

  public static void uploadFilesBypassLicense(
    Id caseId,
    List<HelpDeskFilePayload> files,
    Id contactId,
    UserContext ctx
  ) {
    uploadFilesInternal(caseId, files, contactId, ctx, true);
  }

  private static void uploadFilesInternal(
    Id caseId,
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
          LinkedEntityId = caseId,
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
  }

  public static UserContext loadUserContext() {
    UserContext ctx = new UserContext();
    ctx.userId = UserInfo.getUserId();
    User u = [
      SELECT Id, ContactId, Email
      FROM User
      WHERE Id = :ctx.userId
    ];
    ctx.contactId = u.ContactId;
    ctx.email = u.Email;
    return ctx;
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
}
