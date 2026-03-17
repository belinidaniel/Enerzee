/**
 * @description       : Business Object for Product2 lifecycle — trigger callbacks and REST upsert/deactivation
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : ProductTriggerTest, ProductUpdateEntryRestTest
 **/
public with sharing class ProductBO {
  // ─── DTO ────────────────────────────────────────────────────────────────────

  /**
   * Payload for a single product item in the PATCH endpoint.
   * Routing rules:
   *   isActive == false  → deactivate Product2 + all PBEs
   *   product found      → update PBE price
   *   product not found  → create Product2 + PBE
   */
  public class ProductPayload {
    public String externalId;
    public String productCode;
    public String name;
    public Decimal price;
    public String productFamily;
    public String description;
    public Boolean isActive;
  }

  // ─── REST Business Logic ─────────────────────────────────────────────────────

  public static List<Map<String, String>> processUpdates(
    List<ProductPayload> updates
  ) {
    List<Map<String, String>> results = new List<Map<String, String>>();
    if (updates == null || updates.isEmpty()) {
      return results;
    }

    // 1. Collect identifiers for a single batch SOQL
    Set<String> extIds = new Set<String>();
    Set<String> codes = new Set<String>();
    for (ProductPayload u : updates) {
      if (u == null) {
        continue;
      }
      if (!String.isBlank(u.externalId)) {
        extIds.add(u.externalId.trim());
      }
      if (!String.isBlank(u.productCode)) {
        codes.add(u.productCode.trim());
      }
    }

    // 2. Batch SOQL — ExternalId OR ProductCode
    Map<String, Product2> byExtId = new Map<String, Product2>();
    Map<String, Product2> byCode = new Map<String, Product2>();
    if (!extIds.isEmpty() || !codes.isEmpty()) {
      for (Product2 p : [
        SELECT Id, Name, Family, ProductCode, IsActive, ExternalId__c
        FROM Product2
        WHERE ExternalId__c IN :extIds OR ProductCode IN :codes
        WITH SECURITY_ENFORCED
      ]) {
        if (!String.isBlank(p.ExternalId__c)) {
          byExtId.put(p.ExternalId__c, p);
        }
        if (!String.isBlank(p.ProductCode)) {
          byCode.put(p.ProductCode, p);
        }
      }
    }

    // 3. Categorize items: deactivate / update-existing / create-new
    List<Product2> toDeactivate = new List<Product2>();
    List<Product2> toCreate = new List<Product2>();
    List<ProductPayload> createPayloads = new List<ProductPayload>();
    Map<Id, Product2> existingById = new Map<Id, Product2>();
    Map<Id, ProductPayload> payloadById = new Map<Id, ProductPayload>();

    for (ProductPayload u : updates) {
      if (u == null) {
        continue;
      }
      Product2 found = resolveProduct(u, byExtId, byCode);

      if (u.isActive == false) {
        if (found == null) {
          results.add(makeResult('NotFound', u, null));
        } else {
          found.IsActive = false;
          toDeactivate.add(found);
        }
      } else if (found != null) {
        existingById.put(found.Id, found);
        payloadById.put(found.Id, u);
      } else {
        // Create: need at least one identifier to use as ProductCode
        String finalCode = !String.isBlank(u.productCode)
          ? u.productCode.trim()
          : (!String.isBlank(u.externalId) ? u.externalId.trim() : null);
        if (String.isBlank(finalCode)) {
          results.add(makeResult('Error', u, null));
          continue;
        }
        String finalExt = !String.isBlank(u.externalId)
          ? u.externalId.trim()
          : finalCode;
        toCreate.add(
          new Product2(
            ProductCode = finalCode,
            Name = !String.isBlank(u.name) ? u.name.trim() : finalCode,
            Family = u.productFamily,
            IsActive = true,
            ExternalId__c = finalExt,
            Description = u.description
          )
        );
        createPayloads.add(u);
      }
    }

    // 4. DML: deactivate products + their PBEs
    if (!toDeactivate.isEmpty()) {
      update Security.stripInaccessible(AccessType.UPDATABLE, toDeactivate)
        .getRecords();

      Set<Id> deactivatedIds = new Set<Id>();
      for (Product2 p : toDeactivate) {
        deactivatedIds.add(p.Id);
      }
      List<PricebookEntry> pbes = [
        SELECT Id, IsActive
        FROM PricebookEntry
        WHERE Product2Id IN :deactivatedIds
        WITH SECURITY_ENFORCED
      ];
      for (PricebookEntry pbe : pbes) {
        pbe.IsActive = false;
      }
      if (!pbes.isEmpty()) {
        update Security.stripInaccessible(AccessType.UPDATABLE, pbes)
          .getRecords();
      }
      for (Product2 p : toDeactivate) {
        results.add(makeResult('Deactivated', null, p));
      }
    }

    // 5. DML: insert new products (direct insert to get IDs on list items)
    if (!toCreate.isEmpty()) {
      insert toCreate;
    }

    // 6. PBE upsert for active (updated + created) products
    Id stdPbId = getStandardPricebookId();
    Set<Id> activeIds = new Set<Id>(existingById.keySet());
    for (Product2 p : toCreate) {
      activeIds.add(p.Id);
    }

    Map<Id, PricebookEntry> pbeByProdId = new Map<Id, PricebookEntry>();
    if (!activeIds.isEmpty()) {
      for (PricebookEntry pbe : [
        SELECT Id, Product2Id, UnitPrice, IsActive
        FROM PricebookEntry
        WHERE Pricebook2Id = :stdPbId AND Product2Id IN :activeIds
        WITH SECURITY_ENFORCED
      ]) {
        pbeByProdId.put(pbe.Product2Id, pbe);
      }
    }

    List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
    List<PricebookEntry> pbesToUpdate = new List<PricebookEntry>();

    for (Id prodId : payloadById.keySet()) {
      ProductPayload u = payloadById.get(prodId);
      if (u.price == null) {
        continue;
      }
      if (pbeByProdId.containsKey(prodId)) {
        PricebookEntry pbe = pbeByProdId.get(prodId);
        pbe.UnitPrice = u.price;
        pbe.IsActive = true;
        pbesToUpdate.add(pbe);
      } else {
        pbesToInsert.add(
          new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prodId,
            UnitPrice = u.price,
            IsActive = true
          )
        );
      }
    }

    for (Integer i = 0; i < toCreate.size(); i++) {
      ProductPayload u = createPayloads[i];
      if (u.price == null) {
        continue;
      }
      pbesToInsert.add(
        new PricebookEntry(
          Pricebook2Id = stdPbId,
          Product2Id = toCreate[i].Id,
          UnitPrice = u.price,
          IsActive = true
        )
      );
    }

    if (!pbesToInsert.isEmpty()) {
      insert pbesToInsert;
    }
    if (!pbesToUpdate.isEmpty()) {
      update Security.stripInaccessible(AccessType.UPDATABLE, pbesToUpdate)
        .getRecords();
    }

    // 7. Build results for updates and creates
    for (Id prodId : payloadById.keySet()) {
      results.add(
        makeResult('Updated', payloadById.get(prodId), existingById.get(prodId))
      );
    }
    for (Product2 p : toCreate) {
      results.add(makeResult('Created', null, p));
    }

    return results;
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  private static Product2 resolveProduct(
    ProductPayload u,
    Map<String, Product2> byExtId,
    Map<String, Product2> byCode
  ) {
    if (
      !String.isBlank(u.externalId) && byExtId.containsKey(u.externalId.trim())
    ) {
      return byExtId.get(u.externalId.trim());
    }
    if (
      !String.isBlank(u.productCode) && byCode.containsKey(u.productCode.trim())
    ) {
      return byCode.get(u.productCode.trim());
    }
    return null;
  }

  private static Map<String, String> makeResult(
    String status,
    ProductPayload payload,
    Product2 product
  ) {
    return new Map<String, String>{
      'status' => status,
      'externalId' => product != null
        ? product.ExternalId__c
        : (payload != null ? payload.externalId : null),
      'productCode' => product != null
        ? product.ProductCode
        : (payload != null ? payload.productCode : null),
      'productId' => product != null ? String.valueOf(product.Id) : null
    };
  }

  // ─── Trigger Methods ─────────────────────────────────────────────────────────

  public static void activateProducts(List<Product2> newProductsList) {
    for (Product2 product : newProductsList) {
      product.IsActive = true;
    }
  }

  public static void assignPricebookToProduct(List<Product2> newProductsList) {
    if (newProductsList == null || newProductsList.isEmpty()) {
      return;
    }

    Id standardPricebookId = getStandardPricebookId();
    Set<Id> productIds = new Set<Id>();
    for (Product2 product : newProductsList) {
      if (product != null && product.Id != null) {
        productIds.add(product.Id);
      }
    }

    Map<Id, PricebookEntry> existingByProductId = new Map<Id, PricebookEntry>();
    if (!productIds.isEmpty()) {
      for (PricebookEntry entry : [
        SELECT Id, Product2Id
        FROM PricebookEntry
        WHERE Pricebook2Id = :standardPricebookId AND Product2Id IN :productIds
      ]) {
        existingByProductId.put(entry.Product2Id, entry);
      }
    }

    List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
    for (Product2 product : newProductsList) {
      if (
        product != null &&
        product.Id != null &&
        product.Preco_Unitario__c != null &&
        !existingByProductId.containsKey(product.Id)
      ) {
        entriesToInsert.add(
          new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = product.Preco_Unitario__c,
            IsActive = true
          )
        );
      }
    }
    if (!entriesToInsert.isEmpty()) {
      insert entriesToInsert;
    }
  }

  @TestVisible
  private static Id getStandardPricebookId() {
    if (Test.isRunningTest()) {
      return Test.getStandardPricebookId();
    }
    return [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
  }
}
