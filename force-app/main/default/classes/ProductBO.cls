public with sharing class ProductBO {
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

    return [
      SELECT Id
      FROM Pricebook2
      WHERE IsStandard = TRUE
      LIMIT 1
    ]
    .Id;
  }
}
