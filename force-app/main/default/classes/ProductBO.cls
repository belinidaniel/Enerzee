public with sharing class ProductBO {
  public static void activateProducts(List<Product2> newProductsList) {
    for (Product2 product : newProductsList) {
      product.IsActive = true;
    }
  }

  public static void assignPricebookToProduct(List<Product2> newProductsList) {
    Id standardPricebookId = Test.isRunningTest()
      ? Test.getStandardPricebookId()
      : ([
            SELECT Id
            FROM Pricebook2
            WHERE Name = 'Standard Price Book'
            LIMIT 1
          ])
          .Id;

    List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
    for (Product2 product : newProductsList) {
      if (product.Preco_Unitario__c != null) {
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
    insert entriesToInsert;
  }
}
