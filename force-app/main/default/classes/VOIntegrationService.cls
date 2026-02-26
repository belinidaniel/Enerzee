/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-26-2026
 * @last modified by  : Daniel Belini
 **/
public with sharing class VOIntegrationService {
  private static final String CLASS_NAME = 'VOIntegrationService';
  private static final String OPERATION_SEND_CLIENTE = 'sendCliente';
  private static final String OPERATION_SEND_PLANO = 'sendPlano';

  private static final Map<String, String> PLANO_BY_RECORD_TYPE = new Map<String, String>{
    'Solar' => 'Direct',
    'Produtos' => 'Transition',
    'Servicos' => 'Transition',
    'ServicosEPC' => 'Transition',
    'EzeeSolarA' => 'Ezee Solar',
    'EzeeSolarB' => 'Ezee Solar',
    'EzeeLivre' => 'Ezee Livre',
    'EzeeConnect' => 'Ezee Coonect'
  };

  private static final Map<String, Integer> PLANO_ID_BY_NAME = new Map<String, Integer>{
    'Transition' => 1,
    'Ezee Solar' => 3,
    'Integrador' => 4,
    'Ezee Coonect' => 5,
    'Ezee Livre' => 7,
    'Direct' => 84,
    'BusinessPlus' => 99
  };

  private static final Map<String, Integer> PAYMENT_METHOD_BY_LABEL = new Map<String, Integer>{
    'PayPal' => 1,
    'SALDO + E-CASH' => 2,
    'Boleto' => 3,
    'Transferência Bancária' => 6,
    'PIX' => 10,
    'Cartão Crédito' => 11,
    'Financiamento Bancário' => 12,
    'E-cash' => 13,
    'Aguardando Pagamento' => 14,
    'Parcial E-cash e Saldo Virtual' => 15,
    'Manual' => 16,
    'Pix e Saldo' => 17
  };

  public class IntegrationResult {
    public Integer processed = 0;
    public Integer success = 0;
    public Integer failed = 0;
    public Integer skipped = 0;
  }

  private class AccountSyncOutcome {
    public Boolean success;
    public Account updateRecord;
    public String newVirtualOfficeId;
  }

  public static void enqueueAccountSync(
    Set<Id> accountIds,
    String origin,
    Boolean forceSync
  ) {
    if (accountIds == null || accountIds.isEmpty()) {
      return;
    }

    System.enqueueJob(
      new VOAccountSyncQueueable(accountIds, origin, forceSync, null)
    );
  }

  public static void enqueueOpportunitySync(
    Set<Id> opportunityIds,
    String origin,
    Boolean forceSync
  ) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return;
    }

    System.enqueueJob(
      new VOOpportunitySyncQueueable(opportunityIds, origin, forceSync, null)
    );
  }

  public static IntegrationResult syncAccounts(
    Set<Id> accountIds,
    String origin,
    Boolean forceSync
  ) {
    return syncAccounts(accountIds, origin, forceSync, null);
  }

  public static IntegrationResult syncAccounts(
    Set<Id> accountIds,
    String origin,
    Boolean forceSync,
    Map<Id, String> correlationByRecordId
  ) {
    IntegrationResult result = new IntegrationResult();

    if (accountIds == null || accountIds.isEmpty()) {
      return result;
    }

    List<Log__c> logs = new List<Log__c>();
    Map<Id, Account> accountUpdates = new Map<Id, Account>();
    Map<Id, String> accountCorrelationIds = new Map<Id, String>();

    Map<Id, Account> accountById = new Map<Id, Account>(
      [
        SELECT
          Id,
          Name,
          Email__c,
          DataNascimento__c,
          SeCPFouCNPJ__c,
          ShippingStreet,
          NumeroRuaEntrega__c,
          ShippingPostalCode,
          ComplementoEntrega__c,
          IdVirtualOffice2__c,
          Consultor__r.Login_no_virtual__c,
          Consultor__r.IdVirtualOffice2__c
        FROM Account
        WHERE Id IN :accountIds
      ]
    );

    for (Id accountId : accountIds) {
      result.processed++;

      String correlationId = resolveCorrelationId(
        correlationByRecordId,
        accountId,
        'ACC'
      );
      accountCorrelationIds.put(accountId, correlationId);

      Account accountRecord = accountById.get(accountId);
      if (accountRecord == null) {
        result.failed++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_CLIENTE,
          VOLogService.TYPE_ACCOUNT_SYNC,
          accountId,
          origin,
          correlationId,
          'PRECONDITION_FAILED: Account não encontrado para sincronização.',
          true
        );
        continue;
      }

      AccountSyncOutcome accountOutcome = syncSingleAccount(
        accountRecord,
        origin,
        correlationId,
        forceSync,
        true,
        logs
      );

      if (accountOutcome.updateRecord != null) {
        accountUpdates.put(
          accountOutcome.updateRecord.Id,
          accountOutcome.updateRecord
        );
      }

      if (accountOutcome.success == true) {
        result.success++;
      } else {
        result.failed++;
      }
    }

    updateAccounts(
      accountUpdates.values(),
      logs,
      origin,
      accountCorrelationIds,
      OPERATION_SEND_CLIENTE
    );
    VOLogService.flush(logs);
    return result;
  }

  public static IntegrationResult syncOpportunities(
    Set<Id> opportunityIds,
    String origin,
    Boolean forceSync
  ) {
    return syncOpportunities(opportunityIds, origin, forceSync, null);
  }

  public static IntegrationResult syncOpportunities(
    Set<Id> opportunityIds,
    String origin,
    Boolean forceSync,
    Map<Id, String> correlationByRecordId
  ) {
    IntegrationResult result = new IntegrationResult();

    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return result;
    }

    List<Log__c> logs = new List<Log__c>();

    List<Opportunity> opportunities = [
      SELECT
        Id,
        AccountId,
        Name,
        StageName,
        IdVirtualOffice__c,
        Numeroproposta__c,
        PotenciaPicoSistema__c,
        SubTipo__c,
        TipoKitPromocional__c,
        paymentMethod__c,
        ValorTotalProposta__c,
        Rede__c,
        RecordType.DeveloperName,
        RecordType.Name,
        ConsultorOportunidade__r.IdVirtualOffice2__c,
        Parceiro__r.Name,
        Account.Id,
        Account.Name,
        Account.Email__c,
        Account.DataNascimento__c,
        Account.SeCPFouCNPJ__c,
        Account.ShippingStreet,
        Account.NumeroRuaEntrega__c,
        Account.ShippingPostalCode,
        Account.ComplementoEntrega__c,
        Account.IdVirtualOffice2__c,
        Account.Consultor__r.Login_no_virtual__c,
        Account.Consultor__r.IdVirtualOffice2__c
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ];

    Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>(
      opportunities
    );

    Map<Id, Account> accountById = new Map<Id, Account>();
    for (Opportunity opportunityRecord : opportunities) {
      if (
        opportunityRecord.AccountId != null &&
        opportunityRecord.Account != null &&
        !accountById.containsKey(opportunityRecord.AccountId)
      ) {
        accountById.put(opportunityRecord.AccountId, opportunityRecord.Account);
      }
    }

    Map<Id, Account> accountUpdates = new Map<Id, Account>();
    Map<Id, Opportunity> opportunityUpdates = new Map<Id, Opportunity>();
    Map<Id, String> accountCorrelationIds = new Map<Id, String>();
    Map<Id, String> opportunityCorrelationIds = new Map<Id, String>();

    for (Id opportunityId : opportunityIds) {
      result.processed++;

      Opportunity opportunityRecord = opportunityById.get(opportunityId);
      String correlationId = resolveCorrelationId(
        correlationByRecordId,
        opportunityId,
        'OPP'
      );
      opportunityCorrelationIds.put(opportunityId, correlationId);

      if (opportunityRecord == null) {
        result.failed++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityId,
          origin,
          correlationId,
          'PRECONDITION_FAILED: Opportunity não encontrada para sincronização.',
          true
        );
        continue;
      }

      if (
        !forceSync && !isOpportunityAutomaticallyEligible(opportunityRecord)
      ) {
        result.skipped++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          'SKIPPED_STAGE_NOT_ELIGIBLE: Stage atual não atende critérios de envio automático.',
          false
        );
        continue;
      }

      String planoName = PLANO_BY_RECORD_TYPE.get(
        opportunityRecord.RecordType.DeveloperName
      );
      if (
        String.isBlank(planoName) || !PLANO_ID_BY_NAME.containsKey(planoName)
      ) {
        result.failed++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          'PRECONDITION_FAILED: RecordType sem mapeamento de plano VO.',
          true
        );
        continue;
      }

      Account relatedAccount = accountById.get(opportunityRecord.AccountId);
      if (relatedAccount == null) {
        result.failed++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          'PRECONDITION_FAILED: Opportunity sem Account vinculada.',
          true
        );
        continue;
      }

      if (String.isBlank(relatedAccount.IdVirtualOffice2__c)) {
        String accountCorrelationId = accountCorrelationIds.containsKey(
            relatedAccount.Id
          )
          ? accountCorrelationIds.get(relatedAccount.Id)
          : correlationId;
        accountCorrelationIds.put(relatedAccount.Id, accountCorrelationId);

        AccountSyncOutcome accountOutcome = syncSingleAccount(
          relatedAccount,
          origin + '::OPP_DEPENDENCY',
          accountCorrelationId,
          false,
          false,
          logs
        );

        if (accountOutcome.updateRecord != null) {
          accountUpdates.put(
            accountOutcome.updateRecord.Id,
            accountOutcome.updateRecord
          );
        }

        if (!String.isBlank(accountOutcome.newVirtualOfficeId)) {
          relatedAccount.IdVirtualOffice2__c = accountOutcome.newVirtualOfficeId;
        }

        if (
          accountOutcome.success != true ||
          String.isBlank(relatedAccount.IdVirtualOffice2__c)
        ) {
          result.failed++;
          VOLogService.addNoEndpointLog(
            logs,
            CLASS_NAME,
            OPERATION_SEND_PLANO,
            VOLogService.TYPE_OPP_SYNC,
            opportunityRecord.Id,
            origin,
            correlationId,
            'PRECONDITION_FAILED: Account não sincronizada com VO para envio de plano.',
            true
          );
          continue;
        }
      }

      if (!isIntegerValue(relatedAccount.IdVirtualOffice2__c)) {
        result.failed++;
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          'PRECONDITION_FAILED: IdVirtualOffice2__c da Account inválido para envio de plano.',
          true
        );
        continue;
      }

      String requestPayload = buildOpportunityPayload(
        opportunityRecord,
        relatedAccount,
        planoName
      );
      String maskedPayload = VOLogService.maskPayload(requestPayload);
      HttpRequest requestForLog = null;

      try {
        VOClient.CalloutResult planCalloutResult = VOClient.sendJson(
          'PlanoVO',
          requestPayload
        );
        requestForLog = planCalloutResult.request;
        HttpResponse response = planCalloutResult.response;

        Map<String, Object> responseBodyMap = VOClient.parseBodyAsMap(
          response != null ? response.getBody() : null
        );
        Boolean hasBusinessError = parseBusinessError(responseBodyMap);
        String businessErrorMessage = getBusinessErrorMessage(responseBodyMap);

        String normalizedError = VOLogService.normalizeHttpError(
          response,
          hasBusinessError,
          businessErrorMessage
        );
        Boolean success = String.isBlank(normalizedError);

        String returnedOpportunityExternalId = VOClient.extractStringValue(
          responseBodyMap,
          new List<String>{
            'id',
            'idproposta',
            'idProposta',
            'proposalId',
            'IdOportunidade',
            'idOportunidade'
          }
        );

        if (success && String.isBlank(returnedOpportunityExternalId)) {
          returnedOpportunityExternalId = resolveOpportunityExternalId(
            opportunityRecord
          );
        }

        if (success && String.isBlank(returnedOpportunityExternalId)) {
          success = false;
          normalizedError = 'VO_SUCCESS_WITHOUT_ID: Resposta sem identificador para Opportunity.';
        }

        if (
          success &&
          !hasSyncedOpportunityVoId(opportunityRecord.IdVirtualOffice__c)
        ) {
          opportunityUpdates.put(
            opportunityRecord.Id,
            new Opportunity(
              Id = opportunityRecord.Id,
              IdVirtualOffice__c = returnedOpportunityExternalId
            )
          );
        }

        VOLogService.addResponseLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          requestForLog,
          maskedPayload,
          response,
          normalizedError,
          !success
        );

        if (success) {
          result.success++;
        } else {
          result.failed++;
        }
      } catch (Exception ex) {
        result.failed++;
        VOLogService.addExceptionLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_PLANO,
          VOLogService.TYPE_OPP_SYNC,
          opportunityRecord.Id,
          origin,
          correlationId,
          requestForLog,
          maskedPayload,
          ex
        );
      }
    }

    updateAccounts(
      accountUpdates.values(),
      logs,
      origin,
      accountCorrelationIds,
      OPERATION_SEND_CLIENTE
    );
    updateOpportunities(
      opportunityUpdates.values(),
      logs,
      origin,
      opportunityCorrelationIds
    );

    VOLogService.flush(logs);
    return result;
  }

  private static AccountSyncOutcome syncSingleAccount(
    Account accountRecord,
    String origin,
    String correlationId,
    Boolean forceSync,
    Boolean logSkipWhenAlreadySynced,
    List<Log__c> logs
  ) {
    AccountSyncOutcome outcome = new AccountSyncOutcome();

    if (accountRecord == null) {
      outcome.success = false;
      return outcome;
    }

    if (!forceSync && String.isNotBlank(accountRecord.IdVirtualOffice2__c)) {
      outcome.success = true;
      outcome.newVirtualOfficeId = accountRecord.IdVirtualOffice2__c;

      if (logSkipWhenAlreadySynced) {
        VOLogService.addNoEndpointLog(
          logs,
          CLASS_NAME,
          OPERATION_SEND_CLIENTE,
          VOLogService.TYPE_ACCOUNT_SYNC,
          accountRecord.Id,
          origin,
          correlationId,
          'SKIPPED_ALREADY_SYNCED: Account já possui IdVirtualOffice2__c.',
          false
        );
      }

      return outcome;
    }

    String requestPayload = buildAccountPayload(accountRecord);
    String maskedPayload = VOLogService.maskPayload(requestPayload);
    HttpRequest requestForLog = null;

    try {
      VOClient.CalloutResult clientCalloutResult = VOClient.sendJson(
        'ClienteVO',
        requestPayload
      );
      requestForLog = clientCalloutResult.request;
      HttpResponse response = clientCalloutResult.response;

      Map<String, Object> responseBodyMap = VOClient.parseBodyAsMap(
        response != null ? response.getBody() : null
      );
      Boolean hasBusinessError = parseBusinessError(responseBodyMap);
      String businessErrorMessage = getBusinessErrorMessage(responseBodyMap);
      String normalizedError = VOLogService.normalizeHttpError(
        response,
        hasBusinessError,
        businessErrorMessage
      );

      String newVirtualOfficeId = VOClient.extractStringValue(
        responseBodyMap,
        new List<String>{ 'idusuario', 'idUsuario', 'id', 'usuarioId' }
      );
      Boolean success = String.isBlank(normalizedError);

      if (success && String.isBlank(newVirtualOfficeId)) {
        success = false;
        normalizedError = 'VO_SUCCESS_WITHOUT_ID: Resposta sem idusuario para Account.';
      }

      Account accountUpdate = new Account(Id = accountRecord.Id);
      accountUpdate.SucessoIntegracaoVO__c = success;
      accountUpdate.StatusBodyIntegracaoVO__c = buildStatusBody(
        response,
        normalizedError
      );

      if (success) {
        accountUpdate.IdVirtualOffice2__c = newVirtualOfficeId;
        accountUpdate.LoginVirtualOffice__c = accountRecord.Email__c;
        outcome.newVirtualOfficeId = newVirtualOfficeId;
      }

      outcome.success = success;
      outcome.updateRecord = accountUpdate;

      VOLogService.addResponseLog(
        logs,
        CLASS_NAME,
        OPERATION_SEND_CLIENTE,
        VOLogService.TYPE_ACCOUNT_SYNC,
        accountRecord.Id,
        origin,
        correlationId,
        requestForLog,
        maskedPayload,
        response,
        normalizedError,
        !success
      );

      return outcome;
    } catch (Exception ex) {
      Account accountUpdate = new Account(Id = accountRecord.Id);
      accountUpdate.SucessoIntegracaoVO__c = false;
      accountUpdate.StatusBodyIntegracaoVO__c = VOLogService.normalizeException(
        ex
      );

      outcome.success = false;
      outcome.updateRecord = accountUpdate;

      VOLogService.addExceptionLog(
        logs,
        CLASS_NAME,
        OPERATION_SEND_CLIENTE,
        VOLogService.TYPE_ACCOUNT_SYNC,
        accountRecord.Id,
        origin,
        correlationId,
        requestForLog,
        maskedPayload,
        ex
      );

      return outcome;
    }
  }

  private static void updateAccounts(
    List<Account> accountUpdates,
    List<Log__c> logs,
    String origin,
    Map<Id, String> correlationByRecordId,
    String operation
  ) {
    if (accountUpdates == null || accountUpdates.isEmpty()) {
      return;
    }

    Database.SaveResult[] saveResults;

    try {
      AccountTriggerHandler.disableTrigger();
      saveResults = Database.update(accountUpdates, false);
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    List<SObject> accountSObjects = new List<SObject>();
    accountSObjects.addAll(accountUpdates);

    VOLogService.addDmlResultErrors(
      logs,
      CLASS_NAME,
      operation + ':updateAccount',
      VOLogService.TYPE_ACCOUNT_SYNC,
      accountSObjects,
      saveResults,
      origin,
      correlationByRecordId
    );
  }

  private static void updateOpportunities(
    List<Opportunity> opportunityUpdates,
    List<Log__c> logs,
    String origin,
    Map<Id, String> correlationByRecordId
  ) {
    if (opportunityUpdates == null || opportunityUpdates.isEmpty()) {
      return;
    }

    Database.SaveResult[] saveResults = Database.update(
      opportunityUpdates,
      false
    );

    List<SObject> opportunitySObjects = new List<SObject>();
    opportunitySObjects.addAll(opportunityUpdates);

    VOLogService.addDmlResultErrors(
      logs,
      CLASS_NAME,
      OPERATION_SEND_PLANO + ':updateOpportunity',
      VOLogService.TYPE_OPP_SYNC,
      opportunitySObjects,
      saveResults,
      origin,
      correlationByRecordId
    );
  }

  private static String buildAccountPayload(Account accountRecord) {
    Map<String, Object> payload = new Map<String, Object>();
    payload.put('IdAccountSalesForce', accountRecord.Id);
    payload.put('NomeCompleto', accountRecord.Name);
    payload.put('email', accountRecord.Email__c);
    payload.put(
      'DataNascimento',
      accountRecord.DataNascimento__c == null
        ? '2000-01-01'
        : String.valueOf(accountRecord.DataNascimento__c)
    );
    payload.put('Documento', accountRecord.SeCPFouCNPJ__c);
    payload.put(
      'LoginUsuarioPai',
      accountRecord.Consultor__r != null
        ? accountRecord.Consultor__r.Login_no_virtual__c
        : null
    );

    if (
      accountRecord.Consultor__r != null &&
      isIntegerValue(accountRecord.Consultor__r.IdVirtualOffice2__c)
    ) {
      payload.put(
        'IdUsuarioPai',
        Integer.valueOf(accountRecord.Consultor__r.IdVirtualOffice2__c)
      );
    }

    Map<String, Object> endereco = new Map<String, Object>();
    endereco.put('Rua', accountRecord.ShippingStreet);
    endereco.put('Numero', accountRecord.NumeroRuaEntrega__c);
    endereco.put('Cep', accountRecord.ShippingPostalCode);
    endereco.put('Complemento', accountRecord.ComplementoEntrega__c);

    payload.put('Endereco', endereco);
    return JSON.serialize(payload);
  }

  private static String buildOpportunityPayload(
    Opportunity opportunityRecord,
    Account relatedAccount,
    String planoName
  ) {
    Map<String, Object> payload = new Map<String, Object>();

    payload.put(
      'IdOportunidade',
      resolveOpportunityExternalId(opportunityRecord)
    );
    payload.put(
      'idusuario',
      Integer.valueOf(relatedAccount.IdVirtualOffice2__c)
    );
    payload.put('nomeCliente', relatedAccount.Name);
    payload.put('idplano', PLANO_ID_BY_NAME.get(planoName));
    payload.put(
      'parceiro',
      normalizePartner(
        opportunityRecord.Parceiro__r != null
          ? opportunityRecord.Parceiro__r.Name
          : null
      )
    );
    payload.put('etapaSalesForce', opportunityRecord.StageName);
    payload.put(
      'tipopagamento',
      PAYMENT_METHOD_BY_LABEL.get(opportunityRecord.paymentMethod__c)
    );
    payload.put('kw', opportunityRecord.PotenciaPicoSistema__c);
    payload.put(
      'tipodoKitPromocional',
      getPicklistLabel(
        Opportunity.TipoKitPromocional__c,
        opportunityRecord.TipoKitPromocional__c
      )
    );

    if (planoName == 'Ezee Livre') {
      payload.put('valor', opportunityRecord.Rede__c);
    } else {
      payload.put('valor', opportunityRecord.ValorTotalProposta__c);
    }

    if (planoName == 'Direct') {
      payload.put(
        'tipoContrato',
        String.isNotBlank(opportunityRecord.SubTipo__c)
          ? opportunityRecord.SubTipo__c
          : opportunityRecord.RecordType.Name
      );
    }

    if (
      opportunityRecord.ConsultorOportunidade__r != null &&
      isIntegerValue(
        opportunityRecord.ConsultorOportunidade__r.IdVirtualOffice2__c
      )
    ) {
      payload.put(
        'idConsultorMMN',
        Integer.valueOf(
          opportunityRecord.ConsultorOportunidade__r.IdVirtualOffice2__c
        )
      );
    }

    return JSON.serialize(payload);
  }

  private static String resolveOpportunityExternalId(
    Opportunity opportunityRecord
  ) {
    if (opportunityRecord == null) {
      return null;
    }

    if (String.isNotBlank(opportunityRecord.IdVirtualOffice__c)) {
      return opportunityRecord.IdVirtualOffice__c;
    }

    if (String.isNotBlank(opportunityRecord.Numeroproposta__c)) {
      return opportunityRecord.Numeroproposta__c;
    }

    return String.valueOf(opportunityRecord.Id);
  }

  private static Boolean isOpportunityAutomaticallyEligible(
    Opportunity opportunityRecord
  ) {
    if (opportunityRecord == null) {
      return false;
    }

    if (OpportunityUtils.isStatusClosedWon(opportunityRecord)) {
      return true;
    }

    return OpportunityUtils.isStatusAccessOpinion(opportunityRecord) &&
      opportunityRecord.RecordType != null &&
      opportunityRecord.RecordType.DeveloperName == 'EzeeSolarB';
  }

  private static Boolean parseBusinessError(
    Map<String, Object> responseBodyMap
  ) {
    if (responseBodyMap == null || !responseBodyMap.containsKey('erro')) {
      return false;
    }

    Object errorValue = responseBodyMap.get('erro');
    if (errorValue == null) {
      return false;
    }

    return String.valueOf(errorValue).toLowerCase() == 'true';
  }

  private static String getBusinessErrorMessage(
    Map<String, Object> responseBodyMap
  ) {
    if (responseBodyMap == null || responseBodyMap.isEmpty()) {
      return null;
    }

    String explicitMessage = VOClient.extractStringValue(
      responseBodyMap,
      new List<String>{ 'retorno', 'message', 'erroMensagem', 'error', 'msg' }
    );

    if (String.isNotBlank(explicitMessage)) {
      return explicitMessage;
    }

    return null;
  }

  private static String buildStatusBody(
    HttpResponse response,
    String normalizedError
  ) {
    if (response == null) {
      return normalizedError;
    }

    return String.valueOf(response.getStatusCode()) +
      ' ' +
      response.getBody() +
      ' ' +
      response.getStatus();
  }

  private static String resolveCorrelationId(
    Map<Id, String> correlationByRecordId,
    Id recordId,
    String prefix
  ) {
    if (
      correlationByRecordId != null &&
      correlationByRecordId.containsKey(recordId)
    ) {
      return correlationByRecordId.get(recordId);
    }

    return VOLogService.newCorrelationId(prefix, recordId);
  }

  private static String normalizePartner(String partnerName) {
    if (
      partnerName == 'Enerzee - Grupo A' ||
      partnerName == 'Enerzee - Grupo B'
    ) {
      return 'Enerzee';
    }

    return partnerName;
  }

  private static String getPicklistLabel(SObjectField field, String value) {
    if (String.isBlank(value) || field == null) {
      return null;
    }

    for (
      Schema.PicklistEntry option : field.getDescribe().getPicklistValues()
    ) {
      if (option.getValue() == value) {
        return option.getLabel();
      }
    }

    return value;
  }

  private static Boolean isIntegerValue(String value) {
    return String.isNotBlank(value) && Pattern.matches('^[0-9]+$', value);
  }

  public static Boolean hasSyncedOpportunityVoId(String opportunityVoId) {
    if (String.isBlank(opportunityVoId)) {
      return false;
    }

    String trimmedValue = opportunityVoId.trim();
    String normalizedValue = trimmedValue.toLowerCase();

    Set<String> invalidPlaceholders = new Set<String>{
      'null',
      'n/a',
      'na',
      'none',
      'undefined',
      '-',
      '--'
    };

    if (invalidPlaceholders.contains(normalizedValue)) {
      return false;
    }

    if (Pattern.matches('^0+$', trimmedValue)) {
      return false;
    }

    return Pattern.matches('.*[a-zA-Z0-9].*', trimmedValue);
  }
}
