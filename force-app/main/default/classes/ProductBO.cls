/**
 * @description  Camada de regra de negócio para integração de Product2.
 *               Regras em BO; SELECT de Product2/PricebookEntry ficam no ProductDAO.
 **/
public with sharing class ProductBO {
  private static final String STATUS_SUCCESS = 'Success';
  private static final String STATUS_PARTIAL = 'Partial';
  private static final String STATUS_ERROR = 'Error';

  public class ProductPayload {
    public String externalId;
    public String productCode;
    public String name;
    public Decimal price;
    public String productFamily;
    public String description;
    public Boolean isActive;
  }

  public class ProductResult {
    public String externalId;
    public String productCode;
    public String name;
    public String family;
    public String status;
    public String message;
    public String productId;
    public String pricebookEntryId;
    public Decimal unitPrice;
  }

  public class ProductResponse {
    public String status;
    public String message;
    public Integer successCount;
    public Integer errorCount;
    public List<ProductResult> results;
  }

  private class ValidatedPayload {
    public Integer index;
    public String externalId;
    public ProductPayload item;
  }

  private class ValidationResult {
    public List<ValidatedPayload> validItems;
    public Set<String> externalIds;
  }

  private class CandidateSets {
    public Set<Id> pbeIds;
  }

  private class ProcessingContext {
    public Id standardPricebookId;
    public Map<String, Product2> existingByExternalId;
    public Map<Id, PricebookEntry> existingPbeByProductId;
    public List<Product2> productsToInsert;
    public List<Product2> productsToUpdate;
    public List<PricebookEntry> pbeToInsert;
    public Map<Id, PricebookEntry> pbeToUpdateById;
    public Set<Id> seenProductIdsInPayload;
    public Map<String, Decimal> pendingPriceByExternalId;
    public Map<String, ProductResult> successByExternalId;
  }

  private class UpdatePreparation {
    public Product2 record;
    public Boolean hasChanges;
    public String productCode;
    public String name;
    public String family;
  }

  public static void activateProducts(List<Product2> newProductsList) {
    for (Product2 product : newProductsList) {
      product.IsActive = true;
    }
  }

  public static void assignPricebookToProduct(List<Product2> newProductsList) {
    Id standardPricebookId = ProductDAO.getStandardPricebookId();
    List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
    for (Product2 product : newProductsList) {
      if (product.Preco_Unitario__c != null) {
        entriesToInsert.add(
          newPricebookEntry(
            standardPricebookId,
            product.Id,
            product.Preco_Unitario__c
          )
        );
      }
    }
    if (!entriesToInsert.isEmpty()) {
      insert entriesToInsert;
    }
  }

  public static ProductResponse searchProducts(
    String productCode,
    String family,
    Boolean isActive
  ) {
    ProductResponse response = initResponse();
    try {
      List<Product2> products = ProductDAO.searchProducts(
        productCode,
        family,
        isActive
      );
      for (Product2 product : products) {
        addSuccess(response, buildSearchResult(product));
      }
      response.status = STATUS_SUCCESS;
      response.message = 'Products fetched.';
    } catch (Exception e) {
      response.status = STATUS_ERROR;
      response.message = 'Error searching products: ' + e.getMessage();
    }
    return response;
  }

  public static ProductResponse processUpdates(List<ProductPayload> payloads) {
    ProductResponse response = initResponse();
    if (payloads == null || payloads.isEmpty()) {
      addNoProductsError(response);
      finalizeResponse(response);
      return response;
    }
    try {
      ValidationResult validation = validatePayloads(payloads, response);
      if (validation.validItems.isEmpty()) {
        finalizeResponse(response);
        return response;
      }
      ProcessingContext context = buildProcessingContext(validation);
      processValidItems(validation.validItems, response, context);
      persistAndHydrateResults(response, context);
    } catch (Exception e) {
      addInternalError(response, e);
    }
    finalizeResponse(response);
    return response;
  }

  private static ProductResult buildSearchResult(Product2 product) {
    ProductResult result = new ProductResult();
    result.externalId = canonicalExternalId(product);
    result.productCode = product.ProductCode;
    result.name = product.Name;
    result.family = product.Family;
    result.status = product.IsActive ? 'Active' : 'Inactive';
    result.productId = String.valueOf(product.Id);
    return result;
  }

  private static void addNoProductsError(ProductResponse response) {
    addError(
      response,
      buildResult(
        null,
        null,
        null,
        null,
        'InvalidPayload',
        'No products provided.'
      )
    );
  }

  private static void addInternalError(ProductResponse response, Exception e) {
    addError(
      response,
      buildResult(
        null,
        null,
        null,
        null,
        'InternalError',
        'Error processing products: ' + e.getMessage()
      )
    );
  }

  private static ValidationResult validatePayloads(
    List<ProductPayload> payloads,
    ProductResponse response
  ) {
    ValidationResult output = new ValidationResult();
    output.validItems = new List<ValidatedPayload>();
    output.externalIds = new Set<String>();
    Set<String> seenExternalIds = new Set<String>();
    for (Integer i = 0; i < payloads.size(); i++) {
      validateSinglePayload(payloads[i], i, seenExternalIds, response, output);
    }
    return output;
  }

  private static void validateSinglePayload(
    ProductPayload item,
    Integer index,
    Set<String> seenExternalIds,
    ProductResponse response,
    ValidationResult output
  ) {
    if (item == null) {
      addError(
        response,
        buildResult(
          null,
          null,
          null,
          null,
          'InvalidPayload',
          'Payload item is null.'
        )
      );
      return;
    }
    String extId = normalize(item.externalId);
    if (String.isBlank(extId)) {
      addError(
        response,
        buildResult(
          null,
          item.productCode,
          item.name,
          item.productFamily,
          'InvalidPayload',
          'externalId is required.'
        )
      );
      return;
    }
    if (seenExternalIds.contains(extId)) {
      addError(
        response,
        buildResult(
          extId,
          item.productCode,
          item.name,
          item.productFamily,
          'DuplicateExternalId',
          'Duplicate externalId in payload.'
        )
      );
      return;
    }
    seenExternalIds.add(extId);
    output.externalIds.add(extId);
    ValidatedPayload validItem = new ValidatedPayload();
    validItem.index = index;
    validItem.externalId = extId;
    validItem.item = item;
    output.validItems.add(validItem);
  }

  private static ProcessingContext buildProcessingContext(
    ValidationResult validation
  ) {
    ProcessingContext context = initProcessingContext();
    context.standardPricebookId = ProductDAO.getStandardPricebookId();
    context.existingByExternalId = ProductDAO.getProductsByExternalId(
      validation.externalIds
    );
    CandidateSets candidates = collectCandidateSets(
      validation.validItems,
      context.existingByExternalId
    );
    context.existingPbeByProductId = ProductDAO.getPbeByProductId(
      candidates.pbeIds,
      context.standardPricebookId
    );
    return context;
  }

  private static ProcessingContext initProcessingContext() {
    ProcessingContext context = new ProcessingContext();
    context.productsToInsert = new List<Product2>();
    context.productsToUpdate = new List<Product2>();
    context.pbeToInsert = new List<PricebookEntry>();
    context.pbeToUpdateById = new Map<Id, PricebookEntry>();
    context.seenProductIdsInPayload = new Set<Id>();
    context.pendingPriceByExternalId = new Map<String, Decimal>();
    context.successByExternalId = new Map<String, ProductResult>();
    return context;
  }

  private static CandidateSets collectCandidateSets(
    List<ValidatedPayload> validItems,
    Map<String, Product2> existingByExternalId
  ) {
    CandidateSets candidates = new CandidateSets();
    candidates.pbeIds = new Set<Id>();
    for (ValidatedPayload validItem : validItems) {
      Product2 existing = existingByExternalId.get(validItem.externalId);
      if (existing == null) {
        continue;
      }
      if (
        validItem.item.isActive == false ||
        validItem.item.isActive == true ||
        (validItem.item.price != null &&
        validItem.item.price >= 0)
      ) {
        candidates.pbeIds.add(existing.Id);
      }
    }
    return candidates;
  }

  private static void processValidItems(
    List<ValidatedPayload> validItems,
    ProductResponse response,
    ProcessingContext context
  ) {
    for (ValidatedPayload validItem : validItems) {
      processSingleItem(validItem, response, context);
    }
  }

  private static void processSingleItem(
    ValidatedPayload validItem,
    ProductResponse response,
    ProcessingContext context
  ) {
    Product2 existing = context.existingByExternalId.get(validItem.externalId);
    if (!registerExistingReference(validItem, existing, response, context)) {
      return;
    }
    if (validItem.item.isActive == false) {
      processDeactivation(validItem, existing, response, context);
      return;
    }
    if (existing == null) {
      processCreate(validItem, response, context);
      return;
    }
    processUpdate(validItem, existing, response, context);
  }

  private static Boolean registerExistingReference(
    ValidatedPayload validItem,
    Product2 existing,
    ProductResponse response,
    ProcessingContext context
  ) {
    if (existing == null) {
      return true;
    }
    if (context.seenProductIdsInPayload.contains(existing.Id)) {
      addError(
        response,
        buildResult(
          validItem.externalId,
          existing.ProductCode,
          existing.Name,
          existing.Family,
          'DuplicateProductReference',
          'Payload references the same Product2 more than once.'
        )
      );
      return false;
    }
    context.seenProductIdsInPayload.add(existing.Id);
    return true;
  }

  private static void processDeactivation(
    ValidatedPayload validItem,
    Product2 existing,
    ProductResponse response,
    ProcessingContext context
  ) {
    if (existing == null) {
      addError(
        response,
        buildResult(
          validItem.externalId,
          validItem.item.productCode,
          validItem.item.name,
          validItem.item.productFamily,
          'NotFound',
          'Product not found for deactivation.'
        )
      );
      return;
    }
    PricebookEntry existingPbe = context.existingPbeByProductId.get(
      existing.Id
    );
    if (existingPbe == null) {
      addError(
        response,
        buildResult(
          validItem.externalId,
          existing.ProductCode,
          existing.Name,
          existing.Family,
          'NotFoundPricebookEntry',
          'Standard PricebookEntry not found for deactivation.'
        )
      );
      return;
    }
    context.pbeToUpdateById.put(
      existingPbe.Id,
      new PricebookEntry(Id = existingPbe.Id, IsActive = false)
    );
    ProductResult result = buildResult(
      validItem.externalId,
      existing.ProductCode,
      existing.Name,
      existing.Family,
      'Deactivated',
      'Pricebook entry deactivated.'
    );
    result.productId = String.valueOf(existing.Id);
    addSuccess(response, result);
  }

  private static void processCreate(
    ValidatedPayload validItem,
    ProductResponse response,
    ProcessingContext context
  ) {
    Product2 toCreate = buildProductToInsert(validItem);
    context.productsToInsert.add(toCreate);
    if (validItem.item.price != null && validItem.item.price >= 0) {
      context.pendingPriceByExternalId.put(
        validItem.externalId,
        validItem.item.price
      );
    }
    ProductResult result = buildResult(
      validItem.externalId,
      toCreate.ProductCode,
      toCreate.Name,
      toCreate.Family,
      'Created',
      null
    );
    result.unitPrice = validItem.item.price;
    addSuccess(response, result);
    context.successByExternalId.put(validItem.externalId, result);
  }

  private static Product2 buildProductToInsert(ValidatedPayload validItem) {
    String finalProductCode = defaultIfBlank(
      normalize(validItem.item.productCode),
      validItem.externalId
    );
    String finalName = defaultIfBlank(
      normalize(validItem.item.name),
      finalProductCode
    );
    return new Product2(
      ProductCode = finalProductCode,
      Name = finalName,
      Family = normalize(validItem.item.productFamily),
      Description = validItem.item.description,
      IsActive = validItem.item.isActive == null
        ? true
        : validItem.item.isActive,
      ExternalId__c = validItem.externalId
    );
  }

  private static void processUpdate(
    ValidatedPayload validItem,
    Product2 existing,
    ProductResponse response,
    ProcessingContext context
  ) {
    UpdatePreparation prep = prepareUpdate(existing, validItem);
    if (prep.hasChanges) {
      context.productsToUpdate.add(prep.record);
    }
    registerPriceChange(
      existing.Id,
      validItem.item.price,
      validItem.item.isActive,
      context
    );
    ProductResult result = buildUpdateResult(validItem, existing, prep);
    addSuccess(response, result);
    context.successByExternalId.put(validItem.externalId, result);
  }

  private static UpdatePreparation prepareUpdate(
    Product2 existing,
    ValidatedPayload validItem
  ) {
    UpdatePreparation prep = new UpdatePreparation();
    prep.record = new Product2(Id = existing.Id);
    prep.hasChanges = false;
    prep.productCode = computeProductCode(existing, validItem.item);
    prep.name = computeName(existing, validItem.item);
    prep.family = computeFamily(existing, validItem.item);
    prep.hasChanges = applyMutableFields(
      prep.record,
      existing,
      validItem.item,
      validItem.externalId
    );
    return prep;
  }

  private static String computeProductCode(
    Product2 existing,
    ProductPayload item
  ) {
    String normalized = normalize(item.productCode);
    return String.isBlank(normalized) ? existing.ProductCode : normalized;
  }

  private static String computeName(Product2 existing, ProductPayload item) {
    String normalized = normalize(item.name);
    return String.isBlank(normalized) ? existing.Name : normalized;
  }

  private static String computeFamily(Product2 existing, ProductPayload item) {
    if (item.productFamily == null) {
      return existing.Family;
    }
    return normalize(item.productFamily);
  }

  private static Boolean applyMutableFields(
    Product2 toUpdate,
    Product2 existing,
    ProductPayload item,
    String externalId
  ) {
    Boolean hasChanges = false;
    hasChanges =
      applyFieldIfChanged(
        toUpdate,
        'ProductCode',
        normalize(item.productCode),
        existing.ProductCode
      ) || hasChanges;
    hasChanges =
      applyFieldIfChanged(
        toUpdate,
        'Name',
        normalize(item.name),
        existing.Name
      ) || hasChanges;
    if (item.productFamily != null) {
      hasChanges =
        applyFieldIfChanged(
          toUpdate,
          'Family',
          normalize(item.productFamily),
          existing.Family
        ) || hasChanges;
    }
    if (item.description != null) {
      hasChanges =
        applyFieldIfChanged(
          toUpdate,
          'Description',
          item.description,
          existing.Description
        ) || hasChanges;
    }
    if (item.isActive == true && !existing.IsActive) {
      toUpdate.IsActive = true;
      hasChanges = true;
    }
    hasChanges =
      applyFieldIfChanged(
        toUpdate,
        'ExternalId__c',
        externalId,
        existing.ExternalId__c
      ) || hasChanges;
    return hasChanges;
  }

  private static Boolean applyFieldIfChanged(
    Product2 target,
    String fieldName,
    Object newValue,
    Object oldValue
  ) {
    if (newValue == null || newValue == oldValue) {
      return false;
    }
    target.put(fieldName, newValue);
    return true;
  }

  private static void registerPriceChange(
    Id productId,
    Decimal incomingPrice,
    Boolean isActive,
    ProcessingContext context
  ) {
    if (isActive == true) {
      activateExistingPbe(productId, context);
    }
    if (incomingPrice == null || incomingPrice < 0) {
      return;
    }
    if (context.existingPbeByProductId.containsKey(productId)) {
      Id pbeId = context.existingPbeByProductId.get(productId).Id;
      context.pbeToUpdateById.put(
        pbeId,
        new PricebookEntry(
          Id = pbeId,
          UnitPrice = incomingPrice,
          IsActive = true
        )
      );
      return;
    }
    context.pbeToInsert.add(
      newPricebookEntry(context.standardPricebookId, productId, incomingPrice)
    );
  }

  private static void activateExistingPbe(
    Id productId,
    ProcessingContext context
  ) {
    if (!context.existingPbeByProductId.containsKey(productId)) {
      return;
    }
    Id pbeId = context.existingPbeByProductId.get(productId).Id;
    if (context.pbeToUpdateById.containsKey(pbeId)) {
      PricebookEntry pending = context.pbeToUpdateById.get(pbeId);
      pending.IsActive = true;
      context.pbeToUpdateById.put(pbeId, pending);
      return;
    }
    context.pbeToUpdateById.put(
      pbeId,
      new PricebookEntry(Id = pbeId, IsActive = true)
    );
  }

  private static ProductResult buildUpdateResult(
    ValidatedPayload validItem,
    Product2 existing,
    UpdatePreparation prep
  ) {
    Decimal price = validItem.item.price;
    String message = price != null &&
      price < 0
      ? 'Negative price ignored.'
      : null;
    ProductResult result = buildResult(
      validItem.externalId,
      prep.productCode,
      prep.name,
      prep.family,
      'Updated',
      message
    );
    result.productId = String.valueOf(existing.Id);
    if (price != null && price >= 0) {
      result.unitPrice = price;
    }
    return result;
  }

  private static PricebookEntry newPricebookEntry(
    Id pricebookId,
    Id productId,
    Decimal unitPrice
  ) {
    return new PricebookEntry(
      Pricebook2Id = pricebookId,
      Product2Id = productId,
      UnitPrice = unitPrice,
      IsActive = true
    );
  }

  private static void persistAndHydrateResults(
    ProductResponse response,
    ProcessingContext context
  ) {
    insertCreatedProducts(context);
    updateProducts(context.productsToUpdate);
    commitPbeChanges(context);
    hydrateResultPricebookIds(response, context);
  }

  private static void insertCreatedProducts(ProcessingContext context) {
    if (context.productsToInsert.isEmpty()) {
      return;
    }
    insert context.productsToInsert;
    for (Product2 created : context.productsToInsert) {
      String externalId = canonicalExternalId(created);
      ProductResult result = context.successByExternalId.get(externalId);
      if (result != null) {
        result.productId = String.valueOf(created.Id);
      }
      if (context.pendingPriceByExternalId.containsKey(externalId)) {
        context.pbeToInsert.add(
          newPricebookEntry(
            context.standardPricebookId,
            created.Id,
            context.pendingPriceByExternalId.get(externalId)
          )
        );
      }
    }
  }

  private static void updateProducts(List<Product2> productsToUpdate) {
    if (!productsToUpdate.isEmpty()) {
      update productsToUpdate;
    }
  }

  private static void commitPbeChanges(ProcessingContext context) {
    if (!context.pbeToInsert.isEmpty()) {
      insert context.pbeToInsert;
    }
    if (!context.pbeToUpdateById.isEmpty()) {
      update context.pbeToUpdateById.values();
    }
  }

  private static void hydrateResultPricebookIds(
    ProductResponse response,
    ProcessingContext context
  ) {
    Map<Id, PricebookEntry> insertedByProductId = mapInsertedPbeByProductId(
      context.pbeToInsert
    );
    for (ProductResult result : response.results) {
      updateResultPricebookInfo(
        result,
        insertedByProductId,
        context.existingPbeByProductId
      );
    }
  }

  private static Map<Id, PricebookEntry> mapInsertedPbeByProductId(
    List<PricebookEntry> pbeToInsert
  ) {
    Map<Id, PricebookEntry> output = new Map<Id, PricebookEntry>();
    for (PricebookEntry inserted : pbeToInsert) {
      output.put(inserted.Product2Id, inserted);
    }
    return output;
  }

  private static void updateResultPricebookInfo(
    ProductResult result,
    Map<Id, PricebookEntry> insertedByProductId,
    Map<Id, PricebookEntry> existingPbeByProductId
  ) {
    Id productId = parseProductId(result);
    if (productId == null) {
      return;
    }
    if (insertedByProductId.containsKey(productId)) {
      PricebookEntry inserted = insertedByProductId.get(productId);
      result.pricebookEntryId = String.valueOf(inserted.Id);
      if (result.unitPrice == null) {
        result.unitPrice = inserted.UnitPrice;
      }
      return;
    }
    if (existingPbeByProductId.containsKey(productId)) {
      PricebookEntry existing = existingPbeByProductId.get(productId);
      result.pricebookEntryId = String.valueOf(existing.Id);
      if (result.unitPrice == null && result.status != 'Deactivated') {
        result.unitPrice = existing.UnitPrice;
      }
    }
  }

  private static Id parseProductId(ProductResult result) {
    if (result == null || String.isBlank(result.productId)) {
      return null;
    }
    try {
      return (Id) result.productId;
    } catch (Exception e) {
      return null;
    }
  }

  private static ProductResponse initResponse() {
    ProductResponse response = new ProductResponse();
    response.status = STATUS_SUCCESS;
    response.message = '';
    response.successCount = 0;
    response.errorCount = 0;
    response.results = new List<ProductResult>();
    return response;
  }

  private static void addSuccess(
    ProductResponse response,
    ProductResult result
  ) {
    response.successCount++;
    response.results.add(result);
  }

  private static void addError(ProductResponse response, ProductResult result) {
    response.errorCount++;
    response.results.add(result);
  }

  private static ProductResult buildResult(
    String externalId,
    String productCode,
    String name,
    String family,
    String status,
    String message
  ) {
    ProductResult result = new ProductResult();
    result.externalId = externalId;
    result.productCode = productCode;
    result.name = name;
    result.family = family;
    result.status = status;
    result.message = message;
    return result;
  }

  private static void finalizeResponse(ProductResponse response) {
    if (response.errorCount == 0) {
      response.status = STATUS_SUCCESS;
      if (String.isBlank(response.message)) {
        response.message = 'Products processed successfully.';
      }
      return;
    }
    if (response.successCount > 0) {
      response.status = STATUS_PARTIAL;
      response.message = 'Products processed with partial success.';
      return;
    }
    response.status = STATUS_ERROR;
    if (String.isBlank(response.message)) {
      response.message = 'No products were processed.';
    }
  }

  private static String canonicalExternalId(Product2 product) {
    if (product == null) {
      return null;
    }
    return product.ExternalId__c;
  }

  private static String defaultIfBlank(String value, String fallback) {
    return String.isBlank(value) ? fallback : value;
  }

  private static String normalize(String value) {
    if (value == null) {
      return null;
    }
    String trimmed = value.trim();
    return trimmed == '' ? null : trimmed;
  }
}
