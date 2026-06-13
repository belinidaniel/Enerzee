/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-13-2026
 * @last modified by  : Daniel Belini
 * @test              : ProductUpdateEntryRestTest
 **/
@RestResource(urlMapping='/ProductUpdateEntry/*')
global with sharing class ProductUpdateEntryRest {
  global class ProductPriceUpdate {
    public String externalId;
    public String productCode;
    public String name;
    public Decimal price;
    public String productFamily;
    public String description;
    public String categoryValue;
  }

  global class ResponseWrapper {
    public Map<String, String> Content;
    public List<String> Errors;
    public String Id;
    public String ProposalNumber;
    public Boolean Success;
  }

  private class ProcessingItem {
    Integer index;
    ProductPriceUpdate payload;
    String externalId;
    String productCode;
    String productKey;
    String status;
    String message;
    Id productId;
    Id pricebookEntryId;
  }

  private class PricebookEntryAction {
    Integer itemIndex;
    String successStatus;
    PricebookEntry record;
  }

  @HttpPatch
  global static void updateProductPrices() {
    RestRequest req = RestContext.request;
    String body = req.requestBody != null ? req.requestBody.toString() : '';
    List<ResponseWrapper> responseItems = new List<ResponseWrapper>();

    try {
      List<ProductPriceUpdate> updates = parsePayload(body);
      if (updates.isEmpty()) {
        RestContext.response.responseBody = Blob.valueOf(
          JSON.serializePretty(buildErrorResponse('No products provided.'))
        );
        return;
      }

      Id standardPricebookId = getStandardPricebookId();

      Set<String> requestedExternalIds = new Set<String>();
      Set<String> requestedProductExternalIds = new Set<String>();
      Map<String, Integer> firstItemIndexByExternalId = new Map<String, Integer>();

      for (Integer idx = 0; idx < updates.size(); idx++) {
        ProductPriceUpdate updatePayload = updates[idx];
        if (updatePayload == null) {
          continue;
        }

        String normalizedExternalId = normalize(updatePayload.externalId);
        if (!String.isBlank(normalizedExternalId)) {
          requestedExternalIds.add(normalizedExternalId);
          if (!firstItemIndexByExternalId.containsKey(normalizedExternalId)) {
            firstItemIndexByExternalId.put(normalizedExternalId, idx);
          }
        }
        if (!String.isBlank(normalizedExternalId)) {
          requestedProductExternalIds.add(normalizedExternalId);
        }
      }

      Map<String, Product2> externalIdToProduct = new Map<String, Product2>();
      Map<Id, Product2> productIdToProduct = new Map<Id, Product2>();
      Set<Id> existingProductIds = new Set<Id>();
      if (!requestedProductExternalIds.isEmpty()) {
        for (Product2 productRecord : [
          SELECT
            Id,
            Name,
            Family,
            ProductCode,
            IsActive,
            Category__c,
            Description,
            ExternalId__c,
            Id_Externo__c,
            Preco_Unitario__c
          FROM Product2
          WHERE
            ExternalId__c IN :requestedProductExternalIds
            OR Id_Externo__c IN :requestedProductExternalIds
        ]) {
          productIdToProduct.put(productRecord.Id, productRecord);
          existingProductIds.add(productRecord.Id);
          if (
            !String.isBlank(productRecord.ExternalId__c) &&
            requestedProductExternalIds.contains(productRecord.ExternalId__c)
          ) {
            externalIdToProduct.put(productRecord.ExternalId__c, productRecord);
          }
          if (
            !String.isBlank(productRecord.Id_Externo__c) &&
            requestedProductExternalIds.contains(productRecord.Id_Externo__c) &&
            !externalIdToProduct.containsKey(productRecord.Id_Externo__c)
          ) {
            externalIdToProduct.put(productRecord.Id_Externo__c, productRecord);
          }
        }
      }

      Map<Id, List<PricebookEntry>> initialProductIdToPricebookEntries = new Map<Id, List<PricebookEntry>>();
      Map<String, PricebookEntry> requestedExternalIdToPricebookEntry = new Map<String, PricebookEntry>();
      Set<Id> queriedPricebookEntryIds = new Set<Id>();
      if (!existingProductIds.isEmpty() || !requestedExternalIds.isEmpty()) {
        for (PricebookEntry pricebookEntry : [
          SELECT Id, Product2Id, UnitPrice, IsActive, ExternalId__c
          FROM PricebookEntry
          WHERE
            Pricebook2Id = :standardPricebookId
            AND (Product2Id IN :existingProductIds
            OR ExternalId__c IN :requestedExternalIds)
        ]) {
          queriedPricebookEntryIds.add(pricebookEntry.Id);
          if (
            !initialProductIdToPricebookEntries.containsKey(
              pricebookEntry.Product2Id
            )
          ) {
            initialProductIdToPricebookEntries.put(
              pricebookEntry.Product2Id,
              new List<PricebookEntry>()
            );
          }
          initialProductIdToPricebookEntries.get(pricebookEntry.Product2Id)
            .add(pricebookEntry);

          String pricebookEntryExternalId = normalize(
            pricebookEntry.ExternalId__c
          );
          if (!String.isBlank(pricebookEntryExternalId)) {
            requestedExternalIdToPricebookEntry.put(
              pricebookEntryExternalId,
              pricebookEntry
            );
          }
        }
      }

      Set<Id> legacyProductIds = new Set<Id>(
        initialProductIdToPricebookEntries.keySet()
      );
      legacyProductIds.removeAll(existingProductIds);
      if (!legacyProductIds.isEmpty()) {
        for (Product2 productRecord : [
          SELECT
            Id,
            Name,
            Family,
            ProductCode,
            IsActive,
            Category__c,
            Description,
            ExternalId__c,
            Id_Externo__c,
            Preco_Unitario__c
          FROM Product2
          WHERE Id IN :legacyProductIds
        ]) {
          productIdToProduct.put(productRecord.Id, productRecord);
        }

        for (PricebookEntry pricebookEntry : [
          SELECT Id, Product2Id, UnitPrice, IsActive, ExternalId__c
          FROM PricebookEntry
          WHERE
            Pricebook2Id = :standardPricebookId
            AND Product2Id IN :legacyProductIds
        ]) {
          if (queriedPricebookEntryIds.contains(pricebookEntry.Id)) {
            continue;
          }
          initialProductIdToPricebookEntries.get(pricebookEntry.Product2Id)
            .add(pricebookEntry);
          String pricebookEntryExternalId = normalize(
            pricebookEntry.ExternalId__c
          );
          if (!String.isBlank(pricebookEntryExternalId)) {
            requestedExternalIdToPricebookEntry.put(
              pricebookEntryExternalId,
              pricebookEntry
            );
          }
        }
      }

      List<ProcessingItem> items = new List<ProcessingItem>();
      Map<String, Product2> productKeyToProduct = new Map<String, Product2>();
      Map<String, List<Integer>> productKeyToItemIndexes = new Map<String, List<Integer>>();
      Map<Id, Product2> existingProductsToUpdateById = new Map<Id, Product2>();
      List<Product2> existingProductsToUpdate = new List<Product2>();
      List<String> existingProductKeys = new List<String>();
      Map<String, Product2> pendingNewProductsByExternalId = new Map<String, Product2>();
      List<Product2> newProductsToInsert = new List<Product2>();
      List<String> newProductKeys = new List<String>();

      for (Integer idx = 0; idx < updates.size(); idx++) {
        ProductPriceUpdate updatePayload = updates[idx];
        ProcessingItem item = new ProcessingItem();
        item.index = idx;
        item.payload = updatePayload;
        item.externalId = normalize(
          updatePayload != null ? updatePayload.externalId : null
        );
        item.productCode = normalize(
          updatePayload != null ? updatePayload.productCode : null
        );
        items.add(item);

        if (updatePayload == null) {
          markItemError(item, 'Error', 'Payload item is null.');
          continue;
        }
        if (String.isBlank(item.externalId)) {
          markItemError(item, 'Error', 'Missing externalId.');
          continue;
        }
        if (updatePayload.price == null) {
          markItemError(item, 'Error', 'Missing price.');
          continue;
        }
        if (firstItemIndexByExternalId.get(item.externalId) != idx) {
          markItemError(
            item,
            'Error',
            'Duplicate externalId in payload: ' + item.externalId
          );
          continue;
        }

        Product2 resolvedProduct;
        if (pendingNewProductsByExternalId.containsKey(item.externalId)) {
          resolvedProduct = pendingNewProductsByExternalId.get(item.externalId);
        } else {
          resolvedProduct = externalIdToProduct.get(item.externalId);
        }

        PricebookEntry requestedPricebookEntry = requestedExternalIdToPricebookEntry.get(
          item.externalId
        );
        if (resolvedProduct == null && requestedPricebookEntry != null) {
          resolvedProduct = productIdToProduct.get(
            requestedPricebookEntry.Product2Id
          );
        }
        if (resolvedProduct != null && resolvedProduct.Id != null) {
          PricebookEntry activePricebookEntry = findActivePricebookEntry(
            initialProductIdToPricebookEntries.get(resolvedProduct.Id),
            null
          );
          if (activePricebookEntry != null) {
            markItemError(
              item,
              'Conflict',
              'There is already an active PricebookEntry for the product.'
            );
            item.productId = resolvedProduct.Id;
            item.pricebookEntryId = activePricebookEntry.Id;
            continue;
          }
          if (
            requestedPricebookEntry != null &&
            requestedPricebookEntry.Product2Id != resolvedProduct.Id
          ) {
            markItemError(
              item,
              'Conflict',
              'The externalId is already assigned to another product.'
            );
            item.productId = resolvedProduct.Id;
            item.pricebookEntryId = requestedPricebookEntry.Id;
            continue;
          }
        } else if (requestedPricebookEntry != null) {
          markItemError(
            item,
            'Conflict',
            'The externalId is already assigned to another product.'
          );
          item.pricebookEntryId = requestedPricebookEntry.Id;
          continue;
        }

        if (resolvedProduct == null) {
          Product2 newProduct = buildNewProduct(updatePayload, item.externalId);
          item.productKey = String.isBlank(item.externalId)
            ? buildNewProductKey(item.index)
            : buildPendingProductKey(item.externalId);
          if (!productKeyToProduct.containsKey(item.productKey)) {
            productKeyToProduct.put(item.productKey, newProduct);
            newProductsToInsert.add(newProduct);
            newProductKeys.add(item.productKey);
            if (!String.isBlank(item.externalId)) {
              pendingNewProductsByExternalId.put(item.externalId, newProduct);
            }
          }
          resolvedProduct = productKeyToProduct.get(item.productKey);
        } else {
          item.productKey = buildExistingProductKey(resolvedProduct.Id);
          if (!productKeyToProduct.containsKey(item.productKey)) {
            productKeyToProduct.put(item.productKey, resolvedProduct);
          }
        }

        applyProductFields(resolvedProduct, updatePayload, item.externalId);
        if (
          resolvedProduct.Id != null &&
          !existingProductsToUpdateById.containsKey(resolvedProduct.Id)
        ) {
          existingProductsToUpdateById.put(resolvedProduct.Id, resolvedProduct);
          existingProductsToUpdate.add(resolvedProduct);
          existingProductKeys.add(item.productKey);
        }

        if (!productKeyToItemIndexes.containsKey(item.productKey)) {
          productKeyToItemIndexes.put(item.productKey, new List<Integer>());
        }
        productKeyToItemIndexes.get(item.productKey).add(item.index);
      }

      if (!existingProductsToUpdate.isEmpty()) {
        Database.SaveResult[] updateResults = Database.update(
          existingProductsToUpdate,
          false
        );
        for (Integer idx = 0; idx < updateResults.size(); idx++) {
          if (updateResults[idx].isSuccess()) {
            continue;
          }
          markProductKeyErrors(
            items,
            productKeyToItemIndexes.get(existingProductKeys[idx]),
            'Error',
            firstErrorMessage(updateResults[idx].getErrors())
          );
        }
      }

      if (!newProductsToInsert.isEmpty()) {
        ProductTriggerHandler.disableTrigger();
        try {
          Database.SaveResult[] insertResults = Database.insert(
            newProductsToInsert,
            false
          );
          for (Integer idx = 0; idx < insertResults.size(); idx++) {
            if (insertResults[idx].isSuccess()) {
              continue;
            }
            markProductKeyErrors(
              items,
              productKeyToItemIndexes.get(newProductKeys[idx]),
              'Error',
              firstErrorMessage(insertResults[idx].getErrors())
            );
          }
        } finally {
          ProductTriggerHandler.enableTrigger();
        }
      }

      Set<Id> resolvedProductIds = new Set<Id>();
      for (ProcessingItem item : items) {
        if (item.status != null) {
          continue;
        }
        Product2 productRecord = productKeyToProduct.get(item.productKey);
        if (productRecord == null || productRecord.Id == null) {
          markItemError(
            item,
            'Error',
            'Unable to resolve a product for the payload item.'
          );
          continue;
        }
        item.productId = productRecord.Id;
        resolvedProductIds.add(productRecord.Id);
        productIdToProduct.put(productRecord.Id, productRecord);
      }

      Map<Id, List<PricebookEntry>> productIdToPricebookEntries = new Map<Id, List<PricebookEntry>>();
      if (!resolvedProductIds.isEmpty()) {
        for (PricebookEntry pricebookEntry : [
          SELECT Id, Product2Id, UnitPrice, IsActive, ExternalId__c
          FROM PricebookEntry
          WHERE
            Pricebook2Id = :standardPricebookId
            AND Product2Id IN :resolvedProductIds
        ]) {
          if (
            !productIdToPricebookEntries.containsKey(pricebookEntry.Product2Id)
          ) {
            productIdToPricebookEntries.put(
              pricebookEntry.Product2Id,
              new List<PricebookEntry>()
            );
          }
          productIdToPricebookEntries.get(pricebookEntry.Product2Id)
            .add(pricebookEntry);
        }
      }

      List<PricebookEntryAction> entriesToUpdate = new List<PricebookEntryAction>();
      List<PricebookEntryAction> entriesToInsert = new List<PricebookEntryAction>();
      Map<Id, String> plannedExternalIdByProductId = new Map<Id, String>();

      for (ProcessingItem item : items) {
        if (item.status != null) {
          continue;
        }

        Product2 productRecord = productIdToProduct.get(item.productId);
        if (productRecord == null) {
          markItemError(item, 'Error', 'Resolved product not available.');
          continue;
        }

        if (
          plannedExternalIdByProductId.containsKey(item.productId) &&
          plannedExternalIdByProductId.get(item.productId) != item.externalId
        ) {
          markItemError(
            item,
            'Conflict',
            'Only one active PricebookEntry is allowed per product.'
          );
          continue;
        }

        List<PricebookEntry> candidateEntries = productIdToPricebookEntries.get(
          item.productId
        );
        PricebookEntry activeEntry = findActivePricebookEntry(
          candidateEntries,
          null
        );
        PricebookEntry inactiveEntry = findInactivePricebookEntry(
          candidateEntries,
          null
        );

        if (activeEntry != null) {
          markItemError(
            item,
            'Conflict',
            'There is already an active PricebookEntry for the product.'
          );
          item.pricebookEntryId = activeEntry.Id;
          continue;
        }

        if (inactiveEntry != null) {
          inactiveEntry.ExternalId__c = item.externalId;
          inactiveEntry.UnitPrice = item.payload.price;
          inactiveEntry.IsActive = true;
          item.pricebookEntryId = inactiveEntry.Id;
          entriesToUpdate.add(
            buildPricebookEntryAction(item.index, 'Updated', inactiveEntry)
          );
          plannedExternalIdByProductId.put(item.productId, item.externalId);
          continue;
        }

        PricebookEntry newPricebookEntry = new PricebookEntry(
          Pricebook2Id = standardPricebookId,
          Product2Id = item.productId,
          UnitPrice = item.payload.price,
          IsActive = true,
          ExternalId__c = item.externalId
        );
        entriesToInsert.add(
          buildPricebookEntryAction(item.index, 'Created', newPricebookEntry)
        );
        plannedExternalIdByProductId.put(item.productId, item.externalId);
      }

      if (!entriesToUpdate.isEmpty()) {
        List<PricebookEntry> recordsToUpdate = new List<PricebookEntry>();
        for (PricebookEntryAction action : entriesToUpdate) {
          recordsToUpdate.add(action.record);
        }

        Database.SaveResult[] updateResults = Database.update(
          recordsToUpdate,
          false
        );
        for (Integer idx = 0; idx < updateResults.size(); idx++) {
          ProcessingItem item = items[entriesToUpdate[idx].itemIndex];
          if (updateResults[idx].isSuccess()) {
            item.status = entriesToUpdate[idx].successStatus;
            item.pricebookEntryId = entriesToUpdate[idx].record.Id;
            continue;
          }
          markItemError(
            item,
            'Error',
            firstErrorMessage(updateResults[idx].getErrors())
          );
        }
      }

      if (!entriesToInsert.isEmpty()) {
        List<PricebookEntry> recordsToInsert = new List<PricebookEntry>();
        for (PricebookEntryAction action : entriesToInsert) {
          recordsToInsert.add(action.record);
        }

        Database.SaveResult[] insertResults = Database.insert(
          recordsToInsert,
          false
        );
        for (Integer idx = 0; idx < insertResults.size(); idx++) {
          ProcessingItem item = items[entriesToInsert[idx].itemIndex];
          if (insertResults[idx].isSuccess()) {
            item.status = entriesToInsert[idx].successStatus;
            item.pricebookEntryId = entriesToInsert[idx].record.Id;
            continue;
          }
          markItemError(
            item,
            'Error',
            firstErrorMessage(insertResults[idx].getErrors())
          );
        }
      }

      Integer successCount = 0;
      for (ProcessingItem item : items) {
        Product2 productRecord = item.productId != null
          ? productIdToProduct.get(item.productId)
          : productKeyToProduct.get(item.productKey);
        if (String.isBlank(item.status)) {
          markItemError(item, 'Error', 'No action was executed for the item.');
        }
        if (item.status == 'Created' || item.status == 'Updated') {
          successCount++;
        }
        responseItems.add(buildResponseItem(item, productRecord));
      }
      RestContext.response.responseBody = Blob.valueOf(
        JSON.serializePretty(responseItems)
      );
    } catch (Exception e) {
      RestContext.response.responseBody = Blob.valueOf(
        JSON.serializePretty(buildErrorResponse('Error: ' + e.getMessage()))
      );
    }
  }

  private static ResponseWrapper buildResponseItem(
    ProcessingItem item,
    Product2 productRecord
  ) {
    ResponseWrapper responseItem = new ResponseWrapper();
    responseItem.Content = new Map<String, String>{
      'name' => productRecord != null
        ? productRecord.Name
        : item.payload != null ? item.payload.name : null,
      'productCode' => productRecord != null
        ? productRecord.ProductCode
        : item.productCode,
      'externalId' => item.externalId,
      'family' => productRecord != null
        ? productRecord.Family
        : item.payload != null ? item.payload.productFamily : null,
      'status' => item.status,
      'message' => item.message,
      'unitPrice' => item.payload != null &&
        item.payload.price != null
        ? String.valueOf(item.payload.price)
        : null,
      'productId' => productRecord != null ? productRecord.Id : null
    };
    responseItem.Errors = String.isBlank(item.message)
      ? null
      : new List<String>{ item.message };
    responseItem.Id = item.pricebookEntryId != null
      ? String.valueOf(item.pricebookEntryId)
      : null;
    responseItem.ProposalNumber = null;
    responseItem.Success = item.status == 'Created' || item.status == 'Updated';
    return responseItem;
  }

  private static List<ResponseWrapper> buildErrorResponse(String message) {
    ResponseWrapper responseItem = new ResponseWrapper();
    responseItem.Content = null;
    responseItem.Errors = new List<String>{ message };
    responseItem.Id = null;
    responseItem.ProposalNumber = null;
    responseItem.Success = false;
    return new List<ResponseWrapper>{ responseItem };
  }

  private static void applyProductFields(
    Product2 productRecord,
    ProductPriceUpdate payload,
    String externalId
  ) {
    if (payload == null || productRecord == null) {
      return;
    }

    if (!String.isBlank(payload.name)) {
      productRecord.Name = payload.name.trim();
    } else if (String.isBlank(productRecord.Name)) {
      productRecord.Name = !String.isBlank(payload.productCode)
        ? payload.productCode.trim()
        : buildFallbackProductName(payload.externalId);
    }

    if (!String.isBlank(externalId)) {
      productRecord.ExternalId__c = externalId;
      productRecord.Id_Externo__c = externalId;
    }

    productRecord.Family = payload.productFamily;
    productRecord.Description = payload.description;
    productRecord.Category__c = payload.categoryValue;
    productRecord.IsActive = true;
    productRecord.Preco_Unitario__c = payload.price;
  }

  private static Product2 buildNewProduct(
    ProductPriceUpdate payload,
    String normalizedExternalId
  ) {
    Product2 productRecord = new Product2(
      ProductCode = normalize(payload != null ? payload.productCode : null),
      Name = !String.isBlank(payload != null ? payload.name : null)
        ? payload.name.trim()
        : (!String.isBlank(normalizedExternalId)
            ? normalizedExternalId
            : buildFallbackProductName(
                payload != null ? payload.externalId : null
              )),
      Family = payload != null ? payload.productFamily : null,
      IsActive = true,
      ExternalId__c = normalizedExternalId,
      Id_Externo__c = normalizedExternalId,
      Description = payload != null ? payload.description : null,
      Category__c = payload != null ? payload.categoryValue : null,
      Preco_Unitario__c = payload != null ? payload.price : null
    );
    return productRecord;
  }

  private static String buildFallbackProductName(String rawExternalId) {
    String normalizedExternalId = normalize(rawExternalId);
    return !String.isBlank(normalizedExternalId)
      ? normalizedExternalId
      : 'Produto sem codigo';
  }

  private static PricebookEntryAction buildPricebookEntryAction(
    Integer itemIndex,
    String successStatus,
    PricebookEntry record
  ) {
    PricebookEntryAction action = new PricebookEntryAction();
    action.itemIndex = itemIndex;
    action.successStatus = successStatus;
    action.record = record;
    return action;
  }

  private static PricebookEntry findActivePricebookEntry(
    List<PricebookEntry> entries,
    Id ignoredId
  ) {
    if (entries == null || entries.isEmpty()) {
      return null;
    }
    for (PricebookEntry entry : entries) {
      if (entry.IsActive && (ignoredId == null || entry.Id != ignoredId)) {
        return entry;
      }
    }
    return null;
  }

  private static PricebookEntry findInactivePricebookEntry(
    List<PricebookEntry> entries,
    Id ignoredId
  ) {
    if (entries == null || entries.isEmpty()) {
      return null;
    }
    for (PricebookEntry entry : entries) {
      if (!entry.IsActive && (ignoredId == null || entry.Id != ignoredId)) {
        return entry;
      }
    }
    return null;
  }

  private static void markProductKeyErrors(
    List<ProcessingItem> items,
    List<Integer> indexes,
    String status,
    String message
  ) {
    if (indexes == null) {
      return;
    }
    for (Integer itemIndex : indexes) {
      markItemError(items[itemIndex], status, message);
    }
  }

  private static void markItemError(
    ProcessingItem item,
    String status,
    String message
  ) {
    if (item == null) {
      return;
    }
    item.status = status;
    item.message = message;
  }

  private static String firstErrorMessage(Database.Error[] errors) {
    return errors != null &&
      errors.size() > 0
      ? errors[0].getMessage()
      : 'Unknown error';
  }

  private static String buildExistingProductKey(Id productId) {
    return 'ID:' + String.valueOf(productId);
  }

  private static String buildPendingProductKey(String productCode) {
    return 'CODE:' + productCode;
  }

  private static String buildNewProductKey(Integer itemIndex) {
    return 'NEW:' + String.valueOf(itemIndex);
  }

  private static String normalize(String value) {
    return String.isBlank(value) ? null : value.trim();
  }

  private static Id getStandardPricebookId() {
    return Test.isRunningTest()
      ? Test.getStandardPricebookId()
      : [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
  }

  private static List<ProductPriceUpdate> parsePayload(String body) {
    List<ProductPriceUpdate> out = new List<ProductPriceUpdate>();
    if (String.isBlank(body)) {
      return out;
    }

    String trimmed = body.trim();
    try {
      if (trimmed.startsWith('[')) {
        Object rawPayload = JSON.deserializeUntyped(trimmed);
        if (rawPayload instanceof List<Object>) {
          for (Object rawItem : (List<Object>) rawPayload) {
            if (rawItem instanceof Map<String, Object>) {
              out.add(buildPayloadFromMap((Map<String, Object>) rawItem));
            }
          }
        }
      } else if (trimmed.startsWith('{')) {
        Object rawPayload = JSON.deserializeUntyped(trimmed);
        if (rawPayload instanceof Map<String, Object>) {
          out.add(buildPayloadFromMap((Map<String, Object>) rawPayload));
        }
      } else {
        for (String line : trimmed.split('[\\r\\n]+')) {
          String cleanedLine = line != null ? line.trim() : '';
          if (cleanedLine.startsWith('{') && cleanedLine.endsWith('}')) {
            Object rawLine = JSON.deserializeUntyped(cleanedLine);
            if (rawLine instanceof Map<String, Object>) {
              out.add(buildPayloadFromMap((Map<String, Object>) rawLine));
            }
          }
        }
      }
    } catch (Exception ex) {
      // Keep compatibility with the previous behavior: invalid lines are ignored.
    }

    List<ProductPriceUpdate> clean = new List<ProductPriceUpdate>();
    for (ProductPriceUpdate updatePayload : out) {
      if (updatePayload != null) {
        clean.add(updatePayload);
      }
    }
    return clean;
  }

  private static ProductPriceUpdate buildPayloadFromMap(
    Map<String, Object> rawItem
  ) {
    ProductPriceUpdate payload = new ProductPriceUpdate();
    payload.externalId = stringOrNull(rawItem.get('externalId'));
    payload.productCode = stringOrNull(rawItem.get('productCode'));
    payload.name = stringOrNull(rawItem.get('name'));
    payload.price = decimalOrNull(rawItem.get('price'));
    payload.productFamily = stringOrNull(rawItem.get('productFamily'));
    payload.description = stringOrNull(
      rawItem.containsKey('description')
        ? rawItem.get('description')
        : rawItem.get('Description')
    );
    payload.categoryValue = stringOrNull(rawItem.get('Category__c'));
    return payload;
  }

  private static String stringOrNull(Object rawValue) {
    return rawValue == null ? null : String.valueOf(rawValue);
  }

  private static Decimal decimalOrNull(Object rawValue) {
    return rawValue == null ? null : Decimal.valueOf(String.valueOf(rawValue));
  }

  public static void testUpdateProductPrices(String jsonPayload) {
    RestRequest req = new RestRequest();
    req.requestBody = Blob.valueOf(jsonPayload);
    RestContext.request = req;
    if (RestContext.response == null) {
      RestContext.response = new RestResponse();
    }

    updateProductPrices();

    String respBody = 'No response set.';
    if (
      RestContext.response != null &&
      RestContext.response.responseBody != null
    ) {
      respBody = RestContext.response.responseBody.toString();
    }
    System.debug('Response: ' + respBody);
  }
}
