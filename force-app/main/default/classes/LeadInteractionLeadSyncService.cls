/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-25-2026
 * @last modified by  : Daniel Belini
 * @test              : LeadInteractionLeadSyncServiceTest
 **/
/**
 * @description Keeps Lead fields aligned with the latest AgentForce LeadInteraction data.
 * @test LeadInteractionLeadSyncServiceTest
 */
public without sharing class LeadInteractionLeadSyncService {
  private static final Integer CPF_LENGTH = 11;
  private static final Integer CNPJ_LENGTH = 14;
  private static final Integer BODY_LIMIT = 100000;
  private static final String EMAIL_REGEX = '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$';

  public static void syncToLeads(
    List<LeadInteraction__c> interactions,
    Map<Id, LeadInteraction__c> oldMap
  ) {
    if (interactions == null || interactions.isEmpty()) {
      return;
    }

    try {
      syncToLeadsSafely(interactions, oldMap);
    } catch (Exception ex) {
      List<Log__c> logs = new List<Log__c>{
        buildErrorLog(
          'syncToLeads',
          ex,
          null,
          null,
          buildPayload(null, null, interactions)
        )
      };
      insertLogsSafely(logs);
    }
  }

  private static void syncToLeadsSafely(
    List<LeadInteraction__c> interactions,
    Map<Id, LeadInteraction__c> oldMap
  ) {
    Map<Id, LeadInteraction__c> interactionByLeadId = new Map<Id, LeadInteraction__c>();
    List<Log__c> logs = new List<Log__c>();
    for (LeadInteraction__c interaction : interactions) {
      if (interaction == null || !shouldSync(interaction, oldMap)) {
        continue;
      }
      if (interaction.Lead__c == null) {
        logs.add(
          buildErrorLog(
            'syncToLeadsSafely',
            'LeadInteraction sem Lead__c. Sincronizacao ignorada para nao bloquear a gravacao da interacao.',
            null,
            interaction.Id,
            buildPayload(null, interaction, null)
          )
        );
        continue;
      }
      interactionByLeadId.put(interaction.Lead__c, interaction);
    }

    if (interactionByLeadId.isEmpty()) {
      insertLogsSafely(logs);
      return;
    }

    Map<Id, Lead> existingLeads = new Map<Id, Lead>(
      [
        SELECT Id, LeadSource
        FROM Lead
        WHERE Id IN :interactionByLeadId.keySet()
      ]
    );

    List<Lead> leadsToUpdate = new List<Lead>();
    Map<Id, String> payloadByLeadId = new Map<Id, String>();
    for (Id leadId : interactionByLeadId.keySet()) {
      if (!existingLeads.containsKey(leadId)) {
        LeadInteraction__c missingLeadInteraction = interactionByLeadId.get(
          leadId
        );
        logs.add(
          buildErrorLog(
            'syncToLeadsSafely',
            'Lead informado no LeadInteraction nao foi encontrado.',
            leadId,
            missingLeadInteraction.Id,
            buildPayload(null, missingLeadInteraction, null)
          )
        );
        continue;
      }

      LeadInteraction__c interaction = interactionByLeadId.get(leadId);
      Lead leadUpdate = new Lead(Id = leadId);
      Boolean hasChanges = applyInteractionFields(
        leadUpdate,
        existingLeads.get(leadId),
        interaction,
        logs
      );

      if (hasChanges) {
        leadUpdate.Lab065_IntegracaoDistribuicaoLead__c = false;
        leadUpdate.SDRAgent__c = true;
        leadsToUpdate.add(leadUpdate);
        payloadByLeadId.put(
          leadId,
          buildPayload(leadUpdate, interaction, null)
        );
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      Database.SaveResult[] results = Database.update(leadsToUpdate, false);
      List<Lead> failedLeadsToRetry = new List<Lead>();
      for (Integer index = 0; index < results.size(); index++) {
        if (results[index].isSuccess()) {
          continue;
        }

        Lead failedLead = leadsToUpdate[index];
        failedLeadsToRetry.add(failedLead);
        for (Database.Error error : results[index].getErrors()) {
          logs.add(
            buildErrorLog(
              'syncToLeadsSafely',
              error.getMessage(),
              failedLead.Id,
              interactionByLeadId.get(failedLead.Id).Id,
              payloadByLeadId.get(failedLead.Id)
            )
          );
        }
      }
      retryFailedLeadUpdates(failedLeadsToRetry, interactionByLeadId, logs);
    }

    insertLogsSafely(logs);
  }

  private static void retryFailedLeadUpdates(
    List<Lead> failedLeadUpdates,
    Map<Id, LeadInteraction__c> interactionByLeadId,
    List<Log__c> logs
  ) {
    if (failedLeadUpdates == null || failedLeadUpdates.isEmpty()) {
      return;
    }

    List<String> retryFieldNames = new List<String>{
      'FirstName',
      'LastName',
      'Email',
      'CPFCNPJ__c',
      'CPF__c',
      'CNPJ__c',
      'MobilePhone',
      'Phone',
      'City',
      'Cidade__c',
      'State',
      'Estado__c',
      'Lb065_Estado__c',
      'Lb065_HistoricoLead__c',
      'ResumoInteracao__c',
      'Lb065_ProdutoInteresse__c',
      'TipoDeImovel__c',
      'Lb065_FaturaEnergia__c',
      'CustoEnergiaMes__c',
      'ValorContaEnergia__c',
      'Lb065_PontuacaoFatura__c',
      'Lb065_PontuacaoOrigem__c',
      'Lab065_IntegracaoDistribuicaoLead__c',
      'SDRAgent__c'
    };

    for (String fieldName : retryFieldNames) {
      List<Lead> singleFieldUpdates = new List<Lead>();
      Map<Id, Lead> sourceLeadById = new Map<Id, Lead>();
      for (Lead failedLead : failedLeadUpdates) {
        Map<String, Object> populatedFields = failedLead.getPopulatedFieldsAsMap();
        if (!populatedFields.containsKey(fieldName)) {
          continue;
        }

        Lead singleFieldUpdate = new Lead(Id = failedLead.Id);
        singleFieldUpdate.put(fieldName, populatedFields.get(fieldName));
        singleFieldUpdates.add(singleFieldUpdate);
        sourceLeadById.put(failedLead.Id, failedLead);
      }

      if (singleFieldUpdates.isEmpty()) {
        continue;
      }

      Database.SaveResult[] retryResults = Database.update(
        singleFieldUpdates,
        false
      );
      for (Integer index = 0; index < retryResults.size(); index++) {
        if (retryResults[index].isSuccess()) {
          continue;
        }

        Lead failedSingleFieldLead = singleFieldUpdates[index];
        for (Database.Error error : retryResults[index].getErrors()) {
          logs.add(
            buildErrorLog(
              'retryFailedLeadUpdates',
              fieldName + ': ' + error.getMessage(),
              failedSingleFieldLead.Id,
              interactionByLeadId.get(failedSingleFieldLead.Id).Id,
              buildPayload(
                sourceLeadById.get(failedSingleFieldLead.Id),
                interactionByLeadId.get(failedSingleFieldLead.Id),
                null
              )
            )
          );
        }
      }
    }
  }

  private static Boolean shouldSync(
    LeadInteraction__c interaction,
    Map<Id, LeadInteraction__c> oldMap
  ) {
    if (oldMap == null || !oldMap.containsKey(interaction.Id)) {
      return true;
    }

    LeadInteraction__c oldInteraction = oldMap.get(interaction.Id);
    return changed(interaction.Lead__c, oldInteraction.Lead__c) ||
      changed(interaction.Nome__c, oldInteraction.Nome__c) ||
      changed(interaction.Sobrenome__c, oldInteraction.Sobrenome__c) ||
      changed(interaction.Email__c, oldInteraction.Email__c) ||
      changed(interaction.CPF_CNPJ__c, oldInteraction.CPF_CNPJ__c) ||
      changed(interaction.Telefone__c, oldInteraction.Telefone__c) ||
      changed(interaction.ValorConta__c, oldInteraction.ValorConta__c) ||
      changed(interaction.Cidade__c, oldInteraction.Cidade__c) ||
      changed(interaction.Estado__c, oldInteraction.Estado__c) ||
      changed(
        interaction.ResumoInteracao__c,
        oldInteraction.ResumoInteracao__c
      ) ||
      changed(
        interaction.Produtinteresse__c,
        oldInteraction.Produtinteresse__c
      ) ||
      changed(interaction.TipoImovel__c, oldInteraction.TipoImovel__c);
  }

  private static Boolean applyInteractionFields(
    Lead leadUpdate,
    Lead existingLead,
    LeadInteraction__c interaction,
    List<Log__c> logs
  ) {
    Boolean hasChanges = false;
    Boolean hasInvalidEmail = false;
    String firstName = interaction.Nome__c;
    String lastName = interaction.Sobrenome__c;
    if (String.isBlank(firstName) && !String.isBlank(lastName)) {
      List<String> nameParts = splitFullName(lastName);
      firstName = nameParts[0];
      lastName = nameParts[1];
    }

    hasChanges =
      assignText(leadUpdate, Lead.FirstName, firstName) || hasChanges;
    hasChanges = assignText(leadUpdate, Lead.LastName, lastName) || hasChanges;
    if (!String.isBlank(interaction.Email__c)) {
      if (isValidEmail(interaction.Email__c)) {
        leadUpdate.Email = interaction.Email__c.trim();
        hasChanges = true;
      } else {
        hasInvalidEmail = true;
      }
    }
    hasChanges =
      assignText(leadUpdate, Lead.CPFCNPJ__c, interaction.CPF_CNPJ__c) ||
      hasChanges;
    hasChanges =
      assignDocumentFields(leadUpdate, interaction.CPF_CNPJ__c) || hasChanges;

    String phone = normalizePhone(interaction.Telefone__c);
    if (!String.isBlank(phone)) {
      leadUpdate.MobilePhone = phone;
      leadUpdate.Phone = phone;
      hasChanges = true;
    }

    hasChanges =
      assignText(leadUpdate, Lead.City, interaction.Cidade__c) || hasChanges;
    hasChanges =
      assignText(leadUpdate, Lead.Cidade__c, interaction.Cidade__c) ||
      hasChanges;
    hasChanges =
      assignText(leadUpdate, Lead.State, interaction.Estado__c) || hasChanges;
    hasChanges =
      assignText(leadUpdate, Lead.Estado__c, interaction.Estado__c) ||
      hasChanges;
    hasChanges =
      assignText(leadUpdate, Lead.Lb065_Estado__c, interaction.Estado__c) ||
      hasChanges;
    hasChanges =
      assignText(
        leadUpdate,
        Lead.Lb065_HistoricoLead__c,
        interaction.ResumoInteracao__c
      ) || hasChanges;
    hasChanges =
      assignText(
        leadUpdate,
        Lead.ResumoInteracao__c,
        interaction.ResumoInteracao__c
      ) || hasChanges;
    hasChanges =
      assignText(
        leadUpdate,
        Lead.Lb065_ProdutoInteresse__c,
        interaction.Produtinteresse__c
      ) || hasChanges;
    hasChanges =
      assignText(leadUpdate, Lead.TipoDeImovel__c, interaction.TipoImovel__c) ||
      hasChanges;

    Decimal invoiceAmount = parseCurrency(interaction.ValorConta__c);
    if (invoiceAmount != null) {
      leadUpdate.Lb065_FaturaEnergia__c = invoiceAmount;
      leadUpdate.CustoEnergiaMes__c = classifyMonthlyEnergyCost(invoiceAmount);
      leadUpdate.ValorContaEnergia__c = classifyEnergyBill(invoiceAmount);
      leadUpdate.Lb065_PontuacaoFatura__c = scoreInvoice(invoiceAmount);
      hasChanges = true;
    }

    Integer sourceScore = scoreLeadSource(existingLead.LeadSource);
    if (sourceScore > 0) {
      leadUpdate.Lb065_PontuacaoOrigem__c = sourceScore;
      hasChanges = true;
    }

    if (hasInvalidEmail) {
      logs.add(
        buildErrorLog(
          'applyInteractionFields',
          'Email fora do padrao. Campo Email do Lead nao foi atualizado.',
          leadUpdate.Id,
          interaction.Id,
          buildPayload(leadUpdate, interaction, null)
        )
      );
    }

    return hasChanges;
  }

  private static Boolean assignText(
    SObject target,
    Schema.SObjectField field,
    String value
  ) {
    if (String.isBlank(value)) {
      return false;
    }
    String trimmedValue = value.trim();
    if (!isAssignablePicklistValue(field, trimmedValue)) {
      return false;
    }
    target.put(field, trimmedValue);
    return true;
  }

  private static Boolean assignDocumentFields(
    Lead leadUpdate,
    String document
  ) {
    String digits = onlyDigits(document);
    if (String.isBlank(digits)) {
      return false;
    }
    if (digits.length() == CPF_LENGTH) {
      leadUpdate.CPF__c = digits;
      return true;
    }
    if (digits.length() == CNPJ_LENGTH) {
      leadUpdate.CNPJ__c = digits;
      return true;
    }
    return false;
  }

  private static List<String> splitFullName(String rawName) {
    String normalizedName = String.isBlank(rawName)
      ? null
      : rawName.trim().replaceAll('\\s+', ' ');
    if (String.isBlank(normalizedName)) {
      return new List<String>{ null, null };
    }

    Integer firstSeparatorIndex = normalizedName.indexOf(' ');
    if (firstSeparatorIndex <= 0) {
      return new List<String>{ null, normalizedName };
    }
    return new List<String>{
      normalizedName.substring(0, firstSeparatorIndex),
      normalizedName.substring(firstSeparatorIndex + 1)
    };
  }

  private static Boolean isAssignablePicklistValue(
    Schema.SObjectField field,
    String value
  ) {
    Schema.DescribeFieldResult describeResult = field.getDescribe();
    Schema.DisplayType fieldType = describeResult.getType();
    if (
      (fieldType != Schema.DisplayType.Picklist &&
      fieldType != Schema.DisplayType.MultiPicklist) ||
      !describeResult.isRestrictedPicklist()
    ) {
      return true;
    }

    for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
      if (entry.isActive() && entry.getValue() == value) {
        return true;
      }
    }
    return false;
  }

  private static Boolean changed(Object currentValue, Object oldValue) {
    return currentValue != oldValue;
  }

  private static String normalizePhone(String rawPhone) {
    if (
      String.isBlank(rawPhone) ||
      rawPhone.startsWith('0Mw') ||
      rawPhone.startsWith('0PA')
    ) {
      return null;
    }
    String digits = onlyDigits(rawPhone);
    return digits != null && digits.length() >= 8 ? digits : null;
  }

  private static Boolean isValidEmail(String email) {
    return !String.isBlank(email) &&
      Pattern.compile(EMAIL_REGEX)
        .matcher(email.trim().toLowerCase())
        .matches();
  }

  private static String onlyDigits(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String digits = value.replaceAll('[^0-9]', '');
    return String.isBlank(digits) ? null : digits;
  }

  private static Decimal parseCurrency(String rawValue) {
    if (String.isBlank(rawValue)) {
      return null;
    }

    String normalized = rawValue.trim().replaceAll('[^0-9,.-]', '');
    if (String.isBlank(normalized)) {
      return null;
    }
    if (normalized.contains(',')) {
      normalized = normalized.replace('.', '').replace(',', '.');
    }

    try {
      return Decimal.valueOf(normalized);
    } catch (Exception ex) {
      return null;
    }
  }

  private static String classifyMonthlyEnergyCost(Decimal invoiceAmount) {
    if (invoiceAmount <= 300) {
      return 'até R$ 300';
    }
    if (invoiceAmount <= 500) {
      return 'até R$ 300 a R$ 500';
    }
    if (invoiceAmount <= 1000) {
      return 'de R$ 500 a R$ 1.000';
    }
    return 'mais de R$ 1.000';
  }

  private static String classifyEnergyBill(Decimal invoiceAmount) {
    if (invoiceAmount <= 200) {
      return 'Até R$ 200';
    }
    if (invoiceAmount <= 499) {
      return 'Entre R$ 200 e R$ 499';
    }
    return 'Acima de R$ 500';
  }

  private static Integer scoreInvoice(Decimal invoiceAmount) {
    if (invoiceAmount <= 300) {
      return 2;
    }
    if (invoiceAmount <= 500) {
      return 5;
    }
    if (invoiceAmount <= 1000) {
      return 10;
    }
    if (invoiceAmount <= 5000) {
      return 15;
    }
    return 20;
  }

  private static Integer scoreLeadSource(String leadSource) {
    if (String.isBlank(leadSource)) {
      return 0;
    }

    Set<String> highIntentSources = new Set<String>{
      'Customer Event',
      'Employee Referral',
      'Partner',
      'Webinar',
      'Trade Show',
      'Website',
      'WhatsApp via botão no site / link direto'
    };
    Set<String> paidAdSources = new Set<String>{
      'Advertisement',
      'Anúncio',
      'Google AdWords',
      'Facebook Consultor - Empreenda',
      'Facebook Consultor - Reunião Online',
      'Facebook Super Black - Consumidor Final',
      'Anúncio patrocinado com preenchimento completo'
    };
    Set<String> lowDataSources = new Set<String>{
      'Quero Ser Enerzee',
      'Nivello',
      'Purchased List',
      'Web-To-Lead Integrador',
      'Web-To-Lead Cliente',
      'Acesso direto ao site ou via busca orgânica'
    };
    Set<String> coldSources = new Set<String>{
      'Other',
      'Base antiga sem nova ação'
    };

    if (highIntentSources.contains(leadSource)) {
      return 10;
    }
    if (paidAdSources.contains(leadSource)) {
      return 6;
    }
    if (lowDataSources.contains(leadSource)) {
      return 3;
    }
    if (coldSources.contains(leadSource)) {
      return 1;
    }
    return 0;
  }

  private static Log__c buildErrorLog(
    String methodName,
    Exception ex,
    Id leadId,
    Id interactionId,
    String payloadJson
  ) {
    Log__c logRecord = buildErrorLog(
      methodName,
      ex.getMessage(),
      leadId,
      interactionId,
      payloadJson
    );
    logRecord.Type__c = ex.getTypeName();
    logRecord.LineNumber__c = String.valueOf(ex.getLineNumber());
    logRecord.StackTraceString__c = ex.getStackTraceString();
    return logRecord;
  }

  private static Log__c buildErrorLog(
    String methodName,
    String message,
    Id leadId,
    Id interactionId,
    String payloadJson
  ) {
    Log__c logRecord = new Log__c(
      Class__c = 'LeadInteractionLeadSyncService',
      Method__c = methodName,
      Message__c = trimToLimit(message, BODY_LIMIT),
      RequestBody__c = trimToLimit(payloadJson, BODY_LIMIT),
      ResponseBody__c = trimToLimit(payloadJson, BODY_LIMIT),
      Status__c = 'Error'
    );
    if (leadId != null) {
      logRecord.RelatedId__c = String.valueOf(leadId);
      logRecord.Lab065_LeadRelated__c = leadId;
    } else if (interactionId != null) {
      logRecord.RelatedId__c = String.valueOf(interactionId);
    }
    return logRecord;
  }

  private static String buildPayload(
    Lead leadUpdate,
    LeadInteraction__c interaction,
    List<LeadInteraction__c> interactions
  ) {
    Map<String, Object> payload = new Map<String, Object>{
      'source' => 'LeadInteractionLeadSyncService',
      'leadFieldsAttempted' => leadUpdate != null
        ? leadUpdate.getPopulatedFieldsAsMap()
        : null,
      'leadInteraction' => interaction != null
        ? interaction.getPopulatedFieldsAsMap()
        : null,
      'leadInteractions' => interactions != null
        ? buildInteractionPayloads(interactions)
        : null
    };
    return JSON.serialize(payload);
  }

  private static List<Map<String, Object>> buildInteractionPayloads(
    List<LeadInteraction__c> interactions
  ) {
    List<Map<String, Object>> payloads = new List<Map<String, Object>>();
    if (interactions == null) {
      return payloads;
    }
    for (LeadInteraction__c interaction : interactions) {
      payloads.add(
        interaction != null ? interaction.getPopulatedFieldsAsMap() : null
      );
    }
    return payloads;
  }

  private static void insertLogsSafely(List<Log__c> logs) {
    if (logs == null || logs.isEmpty()) {
      return;
    }
    try {
      Database.insert(logs, false);
    } catch (Exception ignored) {
      // Logging must never block LeadInteraction persistence.
    }
  }

  private static String trimToLimit(String value, Integer limitSize) {
    if (
      String.isBlank(value) ||
      limitSize == null ||
      value.length() <= limitSize
    ) {
      return value;
    }
    return value.substring(0, limitSize);
  }
}
