@isTest
public class ProductTriggerTest {
  @TestSetup
  static void makeData() {
  }

  @isTest
  static void activateProductsTest() {
    Product2 product = (Product2) TestFactory.createSObject(
      new Product2(
        ExternalId__c = 'prod-trigger-1-' +
          String.valueOf(DateTime.now().getTime())
      ),
      true
    );

    product = [
      SELECT Id, IsActive
      FROM Product2
      WHERE Id = :product.Id
    ];
    System.assert(product.IsActive);
  }

  @isTest
  static void assignPricebookToProductTest() {
    Product2 product = (Product2) TestFactory.createSObject(
      new Product2(
        ExternalId__c = 'prod-trigger-2-' +
          String.valueOf(DateTime.now().getTime())
      ),
      true
    );

    List<PricebookEntry> entries = [
      SELECT Id, Product2Id, UnitPrice, IsActive, Pricebook2Id
      FROM PricebookEntry
    ];

    System.assertEquals(1, entries.size());

    PricebookEntry entry = entries[0];
    System.assert(entry.IsActive);
    System.assertEquals(product.Preco_Unitario__c, entry.UnitPrice);
    System.assertEquals(product.Id, entry.Product2Id);
    System.assertEquals(Test.getStandardPricebookId(), entry.Pricebook2Id);
  }

  @isTest
  static void coverageOtherTriggerMethods() {
    Product2 product = (Product2) TestFactory.createSObject(
      new Product2(
        ExternalId__c = 'prod-trigger-3-' +
          String.valueOf(DateTime.now().getTime())
      ),
      true
    );

    product.Name = 'Teste 2';
    update product;

    delete product;

    ProductTriggerHandler.disableTrigger();
    System.assert(!ProductTriggerHandler.isTriggerEnabled());

    ProductTriggerHandler.enableTrigger();
    System.assert(ProductTriggerHandler.isTriggerEnabled());
  }
}
