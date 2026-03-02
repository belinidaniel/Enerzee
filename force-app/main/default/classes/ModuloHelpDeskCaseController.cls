public without sharing class ModuloHelpDeskCaseController {
  @AuraEnabled(cacheable=true)
  public static List<Case> getCases(
    String filterType,
    String searchTerm,
    Id contactId
  ) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    return HelpDeskCaseService.getCases(filterType, searchTerm, contactId, ctx);
  }

  @AuraEnabled(cacheable=true)
  public static Case getCaseDetail(Id caseId, Id contactId) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    return HelpDeskCaseService.getCaseDetail(caseId, contactId, ctx);
  }

  @AuraEnabled(cacheable=true)
  public static List<CaseComment> getCaseComments(Id caseId, Id contactId) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    return HelpDeskCaseService.getCaseComments(caseId, contactId, ctx);
  }

  @AuraEnabled(cacheable=true)
  public static List<ContentDocumentLink> getCaseAttachments(
    Id caseId,
    Id contactId
  ) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    return HelpDeskCaseService.getCaseAttachments(caseId, contactId, ctx);
  }

  @AuraEnabled
  public static CaseComment addComment(
    Id caseId,
    String commentBody,
    Id contactId
  ) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    return HelpDeskCaseService.addComment(caseId, commentBody, contactId, ctx);
  }

  @AuraEnabled
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
    return HelpDeskCaseService.createCase(
      subject,
      description,
      richDescription,
      systemValue,
      typeValue,
      subtypeValue,
      priorityValue,
      suppliedEmail,
      suppliedPhone,
      contactId,
      accountId
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<HelpDeskCaseService.CaseCategoryOptionDTO> getCaseCategoryOptions() {
    return HelpDeskCaseService.getCaseCategoryOptions();
  }

  @AuraEnabled
  public static void uploadFiles(
    Id caseId,
    List<HelpDeskFilePayload> files,
    Id contactId
  ) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    HelpDeskCaseService.uploadFiles(caseId, files, contactId, ctx);
  }

  @AuraEnabled
  public static void uploadFilesBypassLicense(
    Id caseId,
    List<HelpDeskFilePayload> files,
    Id contactId
  ) {
    HelpDeskCaseService.UserContext ctx = HelpDeskCaseService.loadUserContext();
    HelpDeskCaseService.uploadFilesBypassLicense(caseId, files, contactId, ctx);
  }

  @AuraEnabled
  public static HelpDeskCaseService.DefaultEntitiesDTO getDefaultEntities(
    Id contactId
  ) {
    return HelpDeskCaseService.getDefaultEntities(contactId);
  }

  @AuraEnabled
  public static void requestAccessCode(
    String email,
    String firstName,
    String lastName,
    String mobilePhone
  ) {
    HelpDeskAuthService.requestAccessCode(
      email,
      firstName,
      lastName,
      mobilePhone
    );
  }

  @AuraEnabled(cacheable=false)
  public static Id validateAccessCode(String email, String code) {
    return HelpDeskAuthService.validateAccessCode(email, code);
  }
}
