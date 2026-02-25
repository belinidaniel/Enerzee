/**
 * @description       : Solicitação de desconto da proposta na Opportunity via endpoint externo.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-23-2026
 * @last modified by  : Daniel Belini
 **/
public with sharing class OpportunityDiscountRequestController {
  private static final List<String> TARGET_STAGES = new List<String>{
    OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
    OpportunityUtils.STATUS_PROPOSTA_GERADA
  };
  private static final String TARGET_STAGES_LABEL = String.join(
    TARGET_STAGES,
    '" ou "'
  );
  private static final String INTEGRATOR_DEVELOPER_NAME = 'ProposalDiscount';
  private static final String PROPOSAL_ATTACHMENT_TYPE = 'Proposal';
  private static final String LOG_CLASS_NAME = 'ProposalDiscountService';
  private static final String LOG_METHOD_NAME = 'requestDiscount';
  private static final Pattern URL_PATTERN = Pattern.compile(
    '^(?i)https?://\\S+$'
  );
  private static final Pattern PROPOSAL_NUMBER_PREFIX_PATTERN = Pattern.compile(
    '^(?i)p-\\d+.*$'
  );
  private static final Integer PROPOSAL_LOOKBACK_LIMIT = 50;

  public class DiscountContext {
    @AuraEnabled
    public Id opportunityId;
    @AuraEnabled
    public String stageName;
    @AuraEnabled
    public String externalProposalId;
    @AuraEnabled
    public Decimal originalProposalValue;
    @AuraEnabled
    public Boolean hasLatestProposal;
    @AuraEnabled
    public Boolean isEligibleStage;
  }

  public class DiscountSubmitResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Integer statusCode;
    @AuraEnabled
    public Decimal requestDiscount;
  }

  private class DiscountPayload {
    public String id;
    public Integer StatusDiscount;
    public String JustifyObs;
    public String discountApprovalComments;
    public Decimal requestDiscount;
    public String urlFile;
    public String FileProposal;
  }

  private class ProposalAttachmentInfo {
    public Boolean hasLatestProposal;
    public String latestProposalUrl;
  }

  @AuraEnabled(cacheable=true)
  public static DiscountContext getContext(Id opportunityId) {
    Opportunity opportunity = loadOpportunity(opportunityId);
    ProposalAttachmentInfo proposalAttachmentInfo = resolveLatestProposalInfo(
      opportunity.Id,
      false
    );
    DiscountContext context = new DiscountContext();
    context.opportunityId = opportunity.Id;
    context.stageName = opportunity.StageName;
    context.externalProposalId = opportunity.IdVirtualOffice__c;
    context.originalProposalValue = resolveOriginalProposalValue(opportunity);
    context.hasLatestProposal = proposalAttachmentInfo.hasLatestProposal;
    context.isEligibleStage = isEligibleStage(opportunity.StageName);
    return context;
  }

  @AuraEnabled
  public static DiscountSubmitResult submitDiscountRequest(
    Id opportunityId,
    Decimal discountValue,
    Decimal discountPercent,
    String comments
  ) {
    Opportunity opportunity = loadOpportunity(opportunityId);
    Decimal originalProposalValue = resolveOriginalProposalValue(opportunity);
    validateOpportunityState(opportunity, originalProposalValue);

    Decimal requestDiscount = resolveRequestDiscount(
      discountValue,
      discountPercent,
      originalProposalValue
    );
    String finalUrl = resolveLatestProposalUrl(opportunity.Id);
    String normalizedComments = normalizeText(comments);

    DiscountPayload payload = new DiscountPayload();
    payload.id = opportunity.IdVirtualOffice__c;
    payload.StatusDiscount = 1;
    payload.JustifyObs = null;
    payload.discountApprovalComments = normalizedComments;
    payload.requestDiscount = requestDiscount;
    payload.urlFile = finalUrl;
    payload.FileProposal = null;

    String payloadJson = JSON.serialize(payload);
    Integrador__mdt integration = loadIntegrationMetadata();
    HttpRequest request = buildHttpRequest(integration, payloadJson);
    HttpResponse response;

    try {
      System.debug(' payloadJson ' + payloadJson);

      response = sendRequest(request);
      registerLog(opportunity.Id, request, response, null);
    } catch (CalloutException ex) {
      registerLog(opportunity.Id, request, null, ex);
      throw new AuraHandledException(
        'Timeout ou falha de comunicação com o serviço de desconto. Tente novamente.'
      );
    } catch (Exception ex) {
      registerLog(opportunity.Id, request, null, ex);
      throw new AuraHandledException(
        'Não foi possível enviar a solicitação de desconto: ' + ex.getMessage()
      );
    }

    Integer statusCode = response != null ? response.getStatusCode() : null;
    if (response == null) {
      throw new AuraHandledException(
        'A integração de desconto não retornou resposta.'
      );
    }

    if (statusCode >= 200 && statusCode < 300) {
      DiscountSubmitResult result = new DiscountSubmitResult();
      result.success = true;
      result.statusCode = statusCode;
      result.requestDiscount = requestDiscount;
      result.message = 'Solicitação enviada com sucesso.';
      return result;
    }

    if (statusCode >= 400 && statusCode < 500) {
      throw new AuraHandledException(
        buildHttpErrorMessage(statusCode, response.getBody())
      );
    }

    if (statusCode >= 500) {
      throw new AuraHandledException(
        buildHttpErrorMessage(statusCode, response.getBody())
      );
    }

    throw new AuraHandledException(
      'Falha inesperada ao enviar solicitação de desconto (' + statusCode + ').'
    );
  }

  private static Opportunity loadOpportunity(Id opportunityId) {
    if (opportunityId == null) {
      throw new AuraHandledException('Informe uma oportunidade válida.');
    }

    validateOpportunityReadAccess();
    List<Opportunity> opportunities = [
      SELECT
        Id,
        StageName,
        IdVirtualOffice__c,
        ValorTotalPropostaOriginal__c,
        ValorTotalProposta__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    if (opportunities.isEmpty()) {
      throw new AuraHandledException('Oportunidade não encontrada.');
    }

    return opportunities[0];
  }

  private static void validateOpportunityReadAccess() {
    if (!Opportunity.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(
        'Sem permissão para acessar a oportunidade.'
      );
    }

    ensureReadableField(Opportunity.StageName.getDescribe(), 'StageName');
    ensureReadableField(
      Opportunity.IdVirtualOffice__c.getDescribe(),
      'IdVirtualOffice__c'
    );

    Boolean canReadOriginalValue = Opportunity.ValorTotalPropostaOriginal__c.getDescribe()
      .isAccessible();
    Boolean canReadCurrentValue = Opportunity.ValorTotalProposta__c.getDescribe()
      .isAccessible();
    if (!canReadOriginalValue && !canReadCurrentValue) {
      throw new AuraHandledException(
        'Sem permissão para acessar o valor original da proposta.'
      );
    }
  }

  private static void ensureReadableField(
    Schema.DescribeFieldResult fieldDescribe,
    String apiName
  ) {
    if (fieldDescribe == null || !fieldDescribe.isAccessible()) {
      throw new AuraHandledException(
        'Sem permissão para acessar o campo ' + apiName + '.'
      );
    }
  }

  private static Decimal resolveOriginalProposalValue(Opportunity opp) {
    Decimal originalValue;
    if (
      Opportunity.ValorTotalPropostaOriginal__c.getDescribe().isAccessible()
    ) {
      originalValue = opp.ValorTotalPropostaOriginal__c;
    }

    if (
      originalValue == null &&
      Opportunity.ValorTotalProposta__c.getDescribe().isAccessible()
    ) {
      originalValue = opp.ValorTotalProposta__c;
    }

    return originalValue != null
      ? originalValue.setScale(2, RoundingMode.HALF_UP)
      : null;
  }

  private static void validateOpportunityState(
    Opportunity opportunity,
    Decimal originalProposalValue
  ) {
    if (!isEligibleStage(opportunity.StageName)) {
      throw new AuraHandledException(
        'A ação está disponível apenas nas etapas "' +
          TARGET_STAGES_LABEL +
          '". Etapa atual: "' +
          opportunity.StageName +
          '".'
      );
    }

    if (String.isBlank(opportunity.IdVirtualOffice__c)) {
      throw new AuraHandledException(
        'A oportunidade não possui "ID Virtual Office" preenchido.'
      );
    }

    if (originalProposalValue == null || originalProposalValue <= 0) {
      throw new AuraHandledException(
        'Não foi possível determinar o valor original da proposta.'
      );
    }
  }

  private static Boolean isEligibleStage(String stageName) {
    if (String.isBlank(stageName)) {
      return false;
    }

    for (String targetStage : TARGET_STAGES) {
      if (stageName.equalsIgnoreCase(targetStage)) {
        return true;
      }
    }

    return false;
  }

  private static Decimal resolveRequestDiscount(
    Decimal discountValue,
    Decimal discountPercent,
    Decimal originalProposalValue
  ) {
    Decimal normalizedValue = normalizePositiveDecimal(
      discountValue,
      'desconto em valor'
    );
    Decimal normalizedPercent = normalizePositiveDecimal(
      discountPercent,
      'desconto em porcentagem'
    );

    if (normalizedValue == null && normalizedPercent == null) {
      throw new AuraHandledException(
        'Informe desconto em valor (R$) e/ou porcentagem (%).'
      );
    }

    Decimal requestDiscount = normalizedValue;
    if (requestDiscount == null && normalizedPercent != null) {
      requestDiscount = (originalProposalValue *
        normalizedPercent /
        100)
        .setScale(2, RoundingMode.HALF_UP);
    } else if (requestDiscount != null) {
      requestDiscount = requestDiscount.setScale(2, RoundingMode.HALF_UP);
    }

    if (requestDiscount == null || requestDiscount <= 0) {
      throw new AuraHandledException(
        'O valor do desconto deve ser maior que zero.'
      );
    }

    if (requestDiscount > originalProposalValue) {
      throw new AuraHandledException(
        'O valor do desconto não pode ser maior que o valor original da proposta.'
      );
    }

    return requestDiscount;
  }

  private static Decimal normalizePositiveDecimal(
    Decimal value,
    String fieldLabel
  ) {
    if (value == null) {
      return null;
    }

    if (value <= 0) {
      throw new AuraHandledException(
        'O campo "' + fieldLabel + '" deve ser maior que zero.'
      );
    }

    return value;
  }

  private static String resolveLatestProposalUrl(Id opportunityId) {
    ProposalAttachmentInfo proposalAttachmentInfo = resolveLatestProposalInfo(
      opportunityId,
      true
    );
    return proposalAttachmentInfo.latestProposalUrl;
  }

  private static ProposalAttachmentInfo resolveLatestProposalInfo(
    Id opportunityId,
    Boolean throwWhenMissing
  ) {
    Boolean canReadAttachmentLink = hasAttachmentLinkReadAccess();
    if (!canReadAttachmentLink && !throwWhenMissing) {
      ProposalAttachmentInfo info = new ProposalAttachmentInfo();
      info.hasLatestProposal = false;
      info.latestProposalUrl = null;
      return info;
    }

    List<OpportunityAttachmentLink__c> links = new List<OpportunityAttachmentLink__c>();
    Boolean foundInvalidUrl = false;
    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    try {
      links = [
        SELECT
          Name,
          AttachmentDescription__c,
          Type__c,
          AttachmentURL__c,
          InternalAttachmentURL__c
        FROM OpportunityAttachmentLink__c
        WHERE OpportunityId__c = :opportunityId
        ORDER BY CreatedDate DESC
        LIMIT :PROPOSAL_LOOKBACK_LIMIT
      ];
    } catch (Exception ex) {
      if (throwWhenMissing) {
        throw new AuraHandledException(
          'Sem permissão para acessar os anexos externos da oportunidade.'
        );
      }
    }

    ProposalAttachmentInfo info = new ProposalAttachmentInfo();
    info.hasLatestProposal = false;
    info.latestProposalUrl = null;

    for (OpportunityAttachmentLink__c link : links) {
      if (!isProposalAttachment(link)) {
        continue;
      }

      List<String> candidateUrls = new List<String>{
        normalizeUrl(link.AttachmentURL__c, baseUrl),
        normalizeUrl(link.InternalAttachmentURL__c, baseUrl)
      };

      for (String candidateUrl : candidateUrls) {
        if (String.isBlank(candidateUrl)) {
          continue;
        }

        if (!URL_PATTERN.matcher(candidateUrl).matches()) {
          foundInvalidUrl = true;
          continue;
        }

        info.hasLatestProposal = true;
        info.latestProposalUrl = candidateUrl;
        return info;
      }
    }

    if (throwWhenMissing) {
      if (foundInvalidUrl) {
        throw new AuraHandledException(
          'A URL da última proposta gerada é inválida (deve iniciar com http:// ou https://).'
        );
      }
      throw new AuraHandledException(
        'Não foi encontrada uma proposta gerada com URL para esta oportunidade. Gere/envie a proposta antes de solicitar desconto.'
      );
    }

    return info;
  }

  private static Boolean isProposalAttachment(
    OpportunityAttachmentLink__c link
  ) {
    if (link == null) {
      return false;
    }

    String normalizedType = normalizeText(link.Type__c);
    if (
      String.isNotBlank(normalizedType) &&
      normalizedType.equalsIgnoreCase(PROPOSAL_ATTACHMENT_TYPE)
    ) {
      return true;
    }

    String normalizedName = normalizeText(link.Name);
    String normalizedDescription = normalizeText(link.AttachmentDescription__c);
    return (String.isNotBlank(normalizedName) &&
      PROPOSAL_NUMBER_PREFIX_PATTERN.matcher(normalizedName).matches()) ||
      (String.isNotBlank(normalizedDescription) &&
      PROPOSAL_NUMBER_PREFIX_PATTERN.matcher(normalizedDescription).matches());
  }

  private static Boolean hasAttachmentLinkReadAccess() {
    Boolean canReadAttachmentUrl = OpportunityAttachmentLink__c.AttachmentURL__c.getDescribe()
      .isAccessible();
    Boolean canReadInternalAttachmentUrl = OpportunityAttachmentLink__c.InternalAttachmentURL__c.getDescribe()
      .isAccessible();
    Boolean canReadType = OpportunityAttachmentLink__c.Type__c.getDescribe()
      .isAccessible();
    Boolean canReadName = OpportunityAttachmentLink__c.Name.getDescribe()
      .isAccessible();
    Boolean canReadDescription = OpportunityAttachmentLink__c.AttachmentDescription__c.getDescribe()
      .isAccessible();

    return OpportunityAttachmentLink__c.SObjectType.getDescribe()
        .isAccessible() &&
      OpportunityAttachmentLink__c.OpportunityId__c.getDescribe()
        .isAccessible() &&
      (canReadType ||
      canReadName ||
      canReadDescription) &&
      (canReadAttachmentUrl || canReadInternalAttachmentUrl);
  }

  private static String normalizeUrl(String rawValue, String baseUrl) {
    String normalizedValue = normalizeText(rawValue);
    if (String.isBlank(normalizedValue)) {
      return null;
    }

    String lowerValue = normalizedValue.toLowerCase();
    if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
      return normalizedValue;
    }
    if (normalizedValue.startsWith('/')) {
      return baseUrl + normalizedValue;
    }
    return baseUrl + '/' + normalizedValue;
  }

  private static String normalizeText(String value) {
    return value == null ? null : value.trim();
  }

  private static Integrador__mdt loadIntegrationMetadata() {
    if (!Integrador__mdt.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(
        'Sem permissão para acessar a configuração de integração.'
      );
    }

    List<Integrador__mdt> integrations = [
      SELECT URL__c, Method__c, ContentType__c
      FROM Integrador__mdt
      WHERE DeveloperName = :INTEGRATOR_DEVELOPER_NAME
      LIMIT 1
    ];

    if (integrations.isEmpty()) {
      throw new AuraHandledException(
        'Integração de desconto não configurada (Integrador__mdt.' +
          INTEGRATOR_DEVELOPER_NAME +
          ').'
      );
    }

    Integrador__mdt integration = integrations[0];
    if (String.isBlank(integration.URL__c)) {
      throw new AuraHandledException(
        'A URL da integração de desconto não foi configurada.'
      );
    }

    return integration;
  }

  private static HttpRequest buildHttpRequest(
    Integrador__mdt integration,
    String payloadJson
  ) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(integration.URL__c);
    request.setMethod(
      String.isBlank(integration.Method__c) ? 'POST' : integration.Method__c
    );
    request.setHeader(
      'Content-Type',
      String.isBlank(integration.ContentType__c)
        ? 'application/json'
        : integration.ContentType__c
    );
    request.setBody(payloadJson);
    request.setTimeout(120000);
    return request;
  }

  private static HttpResponse sendRequest(HttpRequest request) {
    String endpoint = request.getEndpoint() != null
      ? request.getEndpoint().toLowerCase()
      : '';
    Boolean useNivello = endpoint.contains('geradorproposta');
    return useNivello
      ? Utils.callIntegrationNivello(request)
      : Utils.callIntegrationVO(request);
  }

  private static void registerLog(
    Id opportunityId,
    HttpRequest request,
    HttpResponse response,
    Exception ex
  ) {
    Utils.LogDTO logDTO = new Utils.LogDTO();
    logDTO.className = LOG_CLASS_NAME;
    logDTO.methodName = LOG_METHOD_NAME;
    logDTO.relatedId = String.valueOf(opportunityId);

    if (request != null) {
      logDTO.httpMethod = request.getMethod();
      logDTO.requestURI = request.getEndpoint();
      logDTO.requestBody = trimBody(request.getBody());
    }

    if (response != null) {
      logDTO.statusCode = response.getStatusCode();
      logDTO.status = response.getStatus();
      logDTO.responseBody = trimBody(response.getBody());
      logDTO.message = buildHttpErrorLogMessage(response);
      logDTO.typeName = response.getStatusCode() >= 400
        ? 'IntegrationHttpError'
        : null;
    }

    if (ex != null) {
      logDTO.message = ex.getMessage();
      logDTO.typeName = ex.getTypeName();
      logDTO.lineNumber = String.valueOf(ex.getLineNumber());
      logDTO.stackTraceString = ex.getStackTraceString();
    }

    try {
      Utils.createLog(logDTO);
    } catch (Exception ignored) {
      System.debug(
        LoggingLevel.WARN,
        'Falha ao registrar log de integração de desconto: ' +
        ignored.getMessage()
      );
    }
  }

  private static String trimBody(String content) {
    if (String.isBlank(content)) {
      return content;
    }
    return content.length() > 131072 ? content.substring(0, 131072) : content;
  }

  private static String summarizeBody(String body) {
    if (String.isBlank(body)) {
      return null;
    }
    String trimmed = body.trim();
    return trimmed.length() > 300 ? trimmed.substring(0, 300) : trimmed;
  }

  private static String buildHttpErrorLogMessage(HttpResponse response) {
    if (response == null) {
      return null;
    }

    Integer statusCode = response.getStatusCode();
    if (statusCode == null || statusCode < 400) {
      return null;
    }

    return buildHttpErrorMessage(statusCode, response.getBody());
  }

  private static String buildHttpErrorMessage(
    Integer statusCode,
    String responseBody
  ) {
    String summary = normalizeResponseSummary(responseBody);
    String baseMessage =
      'Erro de integração de desconto. HTTP ' +
      String.valueOf(statusCode) +
      '.';
    if (String.isBlank(summary)) {
      return baseMessage;
    }
    return baseMessage + ' Response: ' + summary;
  }

  private static String normalizeResponseSummary(String responseBody) {
    String summary = summarizeBody(responseBody);
    if (String.isBlank(summary)) {
      return null;
    }

    String normalized = summary.replace('"', '').trim();
    if (
      normalized == '{}' ||
      normalized == '[]' ||
      normalized.equalsIgnoreCase('null')
    ) {
      return null;
    }

    return summary;
  }
}
