/**
 * @description       : Tests for ProductUpdateEntryRest using productCode/externalId
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public with sharing class ProductUpdateEntryRestTest {
  // Util: busca o PBE do PB padrão para um Product2
  private static PricebookEntry getStdPbe(Id productId) {
    Id stdPbId = Test.getStandardPricebookId();
    List<PricebookEntry> pbes = [
      SELECT Id, UnitPrice, Pricebook2Id, Product2Id, IsActive
      FROM PricebookEntry
      WHERE Pricebook2Id = :stdPbId AND Product2Id = :productId
      LIMIT 1
    ];
    return pbes.isEmpty() ? null : pbes[0];
  }

  private static Product2 createProduct(
    String name,
    String productCode,
    String externalId,
    Decimal price
  ) {
    Product2 productRecord = new Product2(
      Name = name,
      ProductCode = productCode,
      IsActive = true,
      ExternalId__c = externalId,
      Id_Externo__c = externalId,
      Preco_Unitario__c = price
    );
    insert productRecord;
    return productRecord;
  }

  @IsTest
  static void testUpdatePrice_ByProductCode() {
    Product2 p = createProduct('KIT 5,0 kWp', 'PC-001', 'EXT-001', 100);

    String payload = '[{"productCode":"PC-001","price":1234.56,"name":"KIT 5,0 kWp"}]';

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    PricebookEntry pbe = getStdPbe(p.Id);
    System.assertNotEquals(null, pbe);
    System.assertEquals(1234.56, pbe.UnitPrice);
  }

  @IsTest
  static void testCreateProduct_AndPbe_ByProductCode() {
    String payload = '[{"productCode":"NEW-100","externalId":"EXT-NEW-100","name":"KIT NEW 10,0 kWp","price":9876.54,"productFamily":"Metálico - NORTE"}]';

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    Product2 created = [
      SELECT Id, Name, ProductCode, Family, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE ProductCode = 'NEW-100'
      LIMIT 1
    ];

    PricebookEntry pbe = getStdPbe(created.Id);
    System.assertEquals('EXT-NEW-100', created.Id_Externo__c);
    System.assertNotEquals(null, pbe);
    System.assertEquals(9876.54, pbe.UnitPrice);
  }

  @IsTest
  static void testCreateProduct_ByExternalId_FallbackWhenNoProductCode() {
    String payload = '[{"externalId":"EXT-777","name":"KIT Fallback","price":2222.00,"productFamily":"Fibrocimento - NORTE"}]';

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    Product2 created = [
      SELECT Id, Name, ProductCode, Family, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE ProductCode = 'EXT-777'
      LIMIT 1
    ];
    PricebookEntry pbe = getStdPbe(created.Id);
    System.assertEquals('EXT-777', created.Id_Externo__c);
    System.assertNotEquals(null, pbe);
    System.assertEquals(2222.00, pbe.UnitPrice);
  }

  @IsTest
  static void testUpdatePrice_ByName_WhenNoProductCode() {
    Product2 p = createProduct('KIT POR NOME 7,2 kWp', null, 'EXT-90210', 200);

    String payload = '[{"name":"KIT POR NOME 7,2 kWp","price":3333.33}]';

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    PricebookEntry pbe = getStdPbe(p.Id);
    System.assertNotEquals(null, pbe);
    System.assertEquals(3333.33, pbe.UnitPrice);
  }

  @IsTest
  static void testEmptyPayloadReturnsError() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices('[]');
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    System.assert(responseBody.contains('"status"'));
    System.assert(responseBody.contains('Error'));
  }

  @IsTest
  static void testSingleObjectPayloadCreatesProduct() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '{"productCode":"ONE-1","externalId":"ONE-EXT-1","name":"Produto Unitario","price":99.9,"productFamily":"Solar"}'
    );
    Test.stopTest();

    Product2 created = [
      SELECT Id, ProductCode, Id_Externo__c
      FROM Product2
      WHERE ProductCode = 'ONE-1'
      LIMIT 1
    ];
    System.assertEquals('ONE-EXT-1', created.Id_Externo__c);
    System.assertNotEquals(null, getStdPbe(created.Id));
  }
}
