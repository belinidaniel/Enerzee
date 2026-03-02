/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-04-2025
 * @last modified by	 : Daniel Belini
 **/
@RestResource(urlMapping='/OpportunityEntry/*')
global with sharing class OpportunityEntryRest {
  @HttpPost
  global static void makePost() {
    try {
      RestRequest request = RestContext.request;
      String body = request.requestBody.toString();
      Utils.createLog('OpportunityEntryRest', 'makePost', request);
      String stage;

      OpportunityRecordsTO.Opportunities results = (OpportunityRecordsTO.Opportunities) JSON.deserializeStrict(
        body,
        OpportunityRecordsTO.Opportunities.class
      );

      Id standardPricebookId = Test.isRunningTest()
        ? Test.getStandardPricebookId()
        : ([
              SELECT Id
              FROM Pricebook2
              WHERE Name = 'Standard Price Book'
              WITH SECURITY_ENFORCED
              LIMIT 1
            ])
            .Id;

      Set<String> productExternalIds = new Set<String>();

      // ID Externo do Produto -> ID do Produto
      Map<String, Id> externalIdToProductId = new Map<String, Id>();

      // Clientes da Integração
      Map<String, OpportunityRecordsTO.Client> externalCustomerIdsToCustomersRest = new Map<String, OpportunityRecordsTO.Client>();
      Map<String, OpportunityRecordsTO.Client> externalCustomerIdsCPFToCustomersRest = new Map<String, OpportunityRecordsTO.Client>();

      // Oportunidade a inserir -> ID externo do Cliente
      Map<Opportunity, String> newOpportunityToAccountExternalId = new Map<Opportunity, String>();

      // Oportunidade a inserir -> ID externo do Consultor
      Map<Opportunity, String> newOpportunityToSellerExternalId = new Map<Opportunity, String>();

      // ID externo da Oportunidade -> Oportunidade
      Map<String, Opportunity> externalIdToOpportunitiesToInsert = new Map<String, Opportunity>();

      // IDs dos Consultores da Oportunidade
      Set<String> sellerIds = new Set<String>();

      Date today = Date.today();

      Map<String, Account> accountsById = getAccountsByPayloadIds(
        results.SingleOpportunity
      );
      System.debug('accountsById ====' + accountsById);

      for (
        OpportunityRecordsTO.SingleOpportunity singleOpportunity : results.SingleOpportunity
      ) {
        for (
          OpportunityRecordsTO.Product product : singleOpportunity.Products
        ) {
          productExternalIds.add(String.valueOf(product.Id));
        }

        if (singleOpportunity.Client != null) {
          // Adicionar ID Externo dos Clientes
          externalCustomerIdsToCustomersRest.put(
            singleOpportunity?.Client?.Id,
            singleOpportunity?.Client
          );
          externalCustomerIdsCPFToCustomersRest.put(
            OpportunityBO.returnFormattedDocument(
              true,
              singleOpportunity?.Client?.Document
            ),
            singleOpportunity?.Client
          );
        }

        // Novo registro da Oportunidade
        Opportunity opportunity = new Opportunity(
          //CloseDate			 = System.today().addDays(3),
          Pricebook2Id = standardPricebookId,
          StatusAprovacaoDesconto__c = 'Não iniciado',
          Acrescimo__c = 1,
          AjusteAnualTarifa__c = 1,
          StageName = singleOpportunity.StageName,
          DataEntrega__c = today.addDays(120)
        );

        // Popular campos da Oportunidade
        OpportunityBO.mapOpportunityFieldsRest(singleOpportunity, opportunity);

        if (Test.isRunningTest()) {
          opportunity.StageName = 'Prospecção';
        }

        newOpportunityToAccountExternalId.put(
          opportunity,
          singleOpportunity?.Client?.Id
        );

        newOpportunityToSellerExternalId.put(
          opportunity,
          singleOpportunity.SellerId
        );

        // Adicionar no Map para inserção
        externalIdToOpportunitiesToInsert.put(
          opportunity.IdVirtualOffice__c,
          opportunity
        );
        // Adicionar no Map de Ids externos de Consultor
        sellerIds.add(singleOpportunity.SellerId);
      }

      // Id Externo da Conta -> Conta
      Map<String, Account> accountsByExternalId = OpportunityBO.mapAccountFieldsRest(
        externalCustomerIdsToCustomersRest,
        externalCustomerIdsCPFToCustomersRest
      );

      // Map de ID externo de Consultor -> ID do Consultor
      Map<String, Id> externalSellerIdToId = OpportunityBO.getOpportunitiesSellers(
        sellerIds
      );

      // Inserir Oportunidades
      for (
        Opportunity opportunity : newOpportunityToAccountExternalId.keySet()
      ) {
        Id sellerId = externalSellerIdToId.get(
          newOpportunityToSellerExternalId.get(opportunity)
        );
        Account account = accountsByExternalId.get(
          newOpportunityToAccountExternalId.get(opportunity)
        );

        if (opportunity.AccountId != null) {
          opportunity.Name =
            accountsById.get(opportunity.AccountId).Name +
            ' ' +
            System.now().addHours(-3);
        } else {
          opportunity.AccountId = account.Id;
          opportunity.Name = account.Name + ' ' + System.now().addHours(-3);
        }
        opportunity.ConsultorOportunidade__c = sellerId;
      }

      // Atualizar IDs das oportunidades existentes
      // for (Opportunity existingOpportunity : [
      //				 SELECT Id, IdVirtualOffice__c
      //				 FROM Opportunity
      //				 WHERE IdVirtualOffice__c IN :externalIdToOpportunitiesToInsert.keySet()
      // ]) {
      //				 externalIdToOpportunitiesToInsert.get(existingOpportunity.IdVirtualOffice__c).Id = existingOpportunity.Id;
      // }

      insert externalIdToOpportunitiesToInsert.values();

      // Coletar os IDs das Oportunidades upsertadas
      List<Id> opportunityIds = new List<Id>();
      for (Opportunity opp : externalIdToOpportunitiesToInsert.values()) {
        opportunityIds.add(opp.Id);
      }

      // IDs das novas oportunidades -> Objetos de Oportunidade da Integração
      Map<OpportunityRecordsTO.SingleOpportunity, Opportunity> restObjectsToInsertedOpportunity = new Map<OpportunityRecordsTO.SingleOpportunity, Opportunity>();

      // Iterar sobre todas as Oportunidades da Integração, para inserir os Produtos futuramente
      for (
        OpportunityRecordsTO.SingleOpportunity singleOpportunity : results.SingleOpportunity
      ) {
        restObjectsToInsertedOpportunity.put(
          singleOpportunity,
          externalIdToOpportunitiesToInsert.get(singleOpportunity.Id)
        );
      }

      // Popular Map de todos os Produtos
      for (Product2 product : [
        SELECT Id, ProductCode
        FROM Product2
        WHERE ProductCode IN :productExternalIds
        WITH SECURITY_ENFORCED
      ]) {
        externalIdToProductId.put(product.ProductCode, product.Id);
      }

      // Oportunidades da Integração, Map linkando com Oportunidades inseridas, e Map de todos os Produtos
      OpportunityBO.mapOpportunityLineItemFieldsRest(
        restObjectsToInsertedOpportunity,
        externalIdToProductId
      );

      // Consultar as Oportunidades para obter o campo Numeroproposta__c
      List<Opportunity> insertedOpportunities = [
        SELECT Id, Numeroproposta__c
        FROM Opportunity
        WHERE Id IN :opportunityIds
        WITH SECURITY_ENFORCED
      ];

      // Response customizada apresentando ID e Numeroproposta__c para cada Oportunidade inserida/atualizada
      List<Map<String, String>> responseMap = new List<Map<String, String>>();
      for (Opportunity opportunity : insertedOpportunities) {
        Map<String, String> oppDataMap = new Map<String, String>();
        oppDataMap.put('Id', opportunity.Id);
        oppDataMap.put(
          'proposalNumber',
          String.valueOf(opportunity.Numeroproposta__c)
        );

        responseMap.add(oppDataMap);
      }

      RestResponse res = RestContext.response;
      res.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
    } catch (Exception e) {
      Utils.createLog(
        'OpportunityEntryRest',
        'OpportunityEntryRest - ERRO ',
        e
      );
      RestContext.response.statusCode = 500;
      RestContext.response.responseBody = Blob.valueOf(
        'Erro: ' + e.getMessage()
      );
    }
  }

  /**
   * Atualiza os produtos de uma oportunidade existente via PUT
   * Espera um JSON com opportunityId e lista de Products
   */
  @HttpPut
  global static void updateOpportunityProducts() {
    RestRequest req = RestContext.request;
    String body = req.requestBody != null ? req.requestBody.toString() : '';
    Object rawPayload = JSON.deserializeUntyped(body);
    if (!(rawPayload instanceof Map<String, Object>)) {
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf(
        'Payload must be a JSON object'
      );
      return;
    }
    Map<String, Object> payload = (Map<String, Object>) rawPayload;

    String opportunityId = (String) payload.get('opportunityId');
    if (String.isBlank(opportunityId)) {
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf('Missing opportunityId');
      return;
    }

    // Buscar a oportunidade
    Opportunity opp = [
      SELECT Id, Name, Pricebook2Id
      FROM Opportunity
      WHERE Id = :opportunityId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    if (opp == null) {
      RestContext.response.statusCode = 404;
      RestContext.response.responseBody = Blob.valueOf('Opportunity not found');
      return;
    }
    Utils.createLog(
      'OpportunityEntryRest',
      'updateOpportunityProducts',
      req,
      opp.Id
    );

    // Buscar os produtos enviados
    List<Object> productsRaw = (List<Object>) payload.get('Products');
    if (productsRaw == null) {
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf('Missing Products');
      return;
    }

    // Mapear ProductCode -> Product2.Id
    Set<String> productCodes = new Set<String>();
    for (Object prodObj : productsRaw) {
      Map<String, Object> prodMap = (Map<String, Object>) prodObj;
      if (prodMap.containsKey('Id')) {
        productCodes.add((String) prodMap.get('Id'));
      }
    }
    Map<String, Id> productCodeToId = new Map<String, Id>();
    for (Product2 p : [
      SELECT Id, Id_Externo__c
      FROM Product2
      WHERE Id_Externo__c IN :productCodes
      WITH SECURITY_ENFORCED
    ]) {
      productCodeToId.put(p.Id_Externo__c, p.Id);
    }

    // Deletar OpportunityLineItems existentes da oportunidade
    List<OpportunityLineItem> itemsToDelete = [
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :opp.Id
      WITH SECURITY_ENFORCED
    ];
    if (!itemsToDelete.isEmpty()) {
      delete itemsToDelete;
    }

    // Criar novos OpportunityLineItems
    List<OpportunityLineItem> itemsToInsert = new List<OpportunityLineItem>();
    for (Object prodObj : productsRaw) {
      Map<String, Object> prodMap = (Map<String, Object>) prodObj;
      String prodCode = (String) prodMap.get('Id');
      Id product2Id = productCodeToId.get(prodCode);

      if (product2Id == null) {
        RestContext.response.statusCode = 400;
        RestContext.response.responseBody = Blob.valueOf(
          'Product with Id ' + prodCode + ' not found'
        );
        return;
      }

      if (product2Id == null)
        continue;
      OpportunityLineItem oli = new OpportunityLineItem();
      oli.OpportunityId = opp.Id;
      oli.Product2Id = product2Id;
      oli.Quantity = (prodMap.containsKey('Quantity') &&
        prodMap.get('Quantity') != null)
        ? Decimal.valueOf(String.valueOf(prodMap.get('Quantity')))
        : 1;
      oli.UnitPrice = (prodMap.containsKey('UnitaryValue') &&
        prodMap.get('UnitaryValue') != null)
        ? Decimal.valueOf(String.valueOf(prodMap.get('UnitaryValue')))
        : 0;
      if (
        prodMap.containsKey('Description') && prodMap.get('Description') != null
      ) {
        oli.Description = String.valueOf(prodMap.get('Description'));
      }
      itemsToInsert.add(oli);
    }
    if (!itemsToInsert.isEmpty()) {
      insert itemsToInsert;
    }

    // Retornar resposta
    Map<String, Object> resp = new Map<String, Object>();
    resp.put('opportunityId', opp.Id);
    resp.put('insertedItems', itemsToInsert.size());
    RestContext.response.responseBody = Blob.valueOf(
      JSON.serializePretty(resp)
    );
  }

  /**
   * Retorna um Map de contas baseado no AccountId informado no payload.
   * Chave = Account.Id | Valor = Account
   */
  public static Map<String, Account> getAccountsByPayloadIds(
    List<OpportunityRecordsTO.SingleOpportunity> singleOpportunities
  ) {
    Map<String, Account> externalIdToAccounts = new Map<String, Account>();
    Set<Id> accountIdsFromPayload = new Set<Id>();

    // Coletar todos os AccountIds vindos no payload
    for (
      OpportunityRecordsTO.SingleOpportunity singleOpportunity : singleOpportunities
    ) {
      accountIdsFromPayload.add(singleOpportunity.AccountId);
    }

    // Buscar contas existentes no Salesforce
    if (!accountIdsFromPayload.isEmpty()) {
      for (Account account : [
        SELECT Id, Name
        FROM Account
        WHERE Id IN :accountIdsFromPayload
        WITH SECURITY_ENFORCED
      ]) {
        externalIdToAccounts.put(account.Id, account);
      }
    }

    return externalIdToAccounts;
  }

  @HttpPatch
  global static void updateDiscount() {
    RestRequest req = RestContext.request;
    Opportunity opp = null;
    String requestBodyString = req.requestBody.toString();
    if (requestBodyString.startsWith('"') && requestBodyString.endsWith('"')) {
      requestBodyString = requestBodyString.substring(
        1,
        requestBodyString.length() - 1
      );
    }

    // Replace escaped double quotes
    requestBodyString = requestBodyString.replace('\\\"', '\"');

    System.debug('jsonSend ==>' + requestBodyString);

    ResponseWrapper response = new ResponseWrapper();

    try {
      DiscountRequestBody requestBody = (DiscountRequestBody) JSON.deserialize(
        requestBodyString,
        DiscountRequestBody.class
      );
      if (String.isBlank(requestBody.id) || requestBody.discount == null) {
        response.status = 'Error';
        response.message = 'Invalid input provided.';
        //return response;
      }
      opp = [
        SELECT Id, DescontoUFV__c
        FROM Opportunity
        WHERE IdVirtualOffice__c = :requestBody.id
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      if (opp == null) {
        response.status = 'Error';
        response.message = 'Opportunity not found for the provided Id.';
        //return response;
      }
      Utils.createLog(
        'OpportunityDiscountUpdate',
        'updateDiscount',
        req,
        opp.Id
      );
      opp.StatusAprovacaoDesconto__c = 'Pendente';
      opp.DescontoUFV__c = requestBody.discount;
      opp.ObservacaoSolicitacaoAprovacaoDesconto__c = requestBody.discountApprovalComments;
      opp.URL__c = requestBody.url;
      update opp;

      // Response customizada apresentando ID externo e ID Salesforce pra cada Oportunidade inserida/atualizada
      List<Map<String, String>> responseMap = new List<Map<String, String>>();
      Map<String, String> oppDataMap = new Map<String, String>();
      oppDataMap.put('Id', opp.Id);
      responseMap.add(oppDataMap);

      RestResponse res = RestContext.response;
      res.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
    } catch (Exception e) {
      Utils.createLog(
        'OpportunityEntryRest',
        'updateDiscount - ERRO ',
        e,
        opp != null ? opp.Id : null
      );
      response.status = 'Error';
      response.message = 'Error updating discount: ' + e.getMessage();
    }
  }

  global class DiscountRequestBody {
    public String id;
    public Decimal discount;
    public String discountApprovalComments;
    public String url;
  }

  global class ResponseWrapper {
    public String status;
    public String message;
  }
  // Test helper method to call updateDiscount internally
  public static void testPatchRequest(String jsonPayload) {
    RestRequest req = new RestRequest();
    req.requestBody = Blob.valueOf(jsonPayload);
    RestContext.request = req;
    updateDiscount();
    if (RestContext.response != null) {
      System.debug('Response: ' + RestContext.response.responseBody);
    } else {
      System.debug('No response set.');
    }
  }
}
