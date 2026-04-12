/**
 * @description       : Tests for ProductUpdateEntryRest using PricebookEntry externalId.
 * @author            : Codex
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : Codex
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public with sharing class ProductUpdateEntryRestTest {
  private static PricebookEntry getStdPbe(Id productId) {
    Id standardPricebookId = Test.getStandardPricebookId();
    List<PricebookEntry> pricebookEntries = [
      SELECT Id, UnitPrice, Pricebook2Id, Product2Id, IsActive, ExternalId__c
      FROM PricebookEntry
      WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :productId
      LIMIT 1
    ];
    return pricebookEntries.isEmpty() ? null : pricebookEntries[0];
  }

  private static List<PricebookEntry> getStdPbes(Id productId) {
    return [
      SELECT Id, UnitPrice, Pricebook2Id, Product2Id, IsActive, ExternalId__c
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND Product2Id = :productId
      ORDER BY CreatedDate ASC
    ];
  }

  private static Product2 createProduct(
    String name,
    String productCode,
    String legacyExternalId,
    Decimal price
  ) {
    Product2 productRecord = new Product2(
      Name = name,
      ProductCode = productCode,
      IsActive = true,
      ExternalId__c = legacyExternalId,
      Id_Externo__c = legacyExternalId,
      Preco_Unitario__c = price
    );
    insert productRecord;
    return productRecord;
  }

  private static void updatePbeExternalId(
    Id productId,
    String externalId,
    Boolean isActive
  ) {
    PricebookEntry pricebookEntry = getStdPbe(productId);
    pricebookEntry.ExternalId__c = externalId;
    pricebookEntry.IsActive = isActive;
    update pricebookEntry;
  }

  @IsTest
  static void testUpdatePrice_ByPricebookEntryExternalId() {
    Product2 productRecord = createProduct(
      'KIT 5,0 kWp',
      'PC-001',
      'LEG-001',
      100
    );
    updatePbeExternalId(productRecord.Id, 'PBE-001', true);

    String payload = '[{"productCode":"PC-001","externalId":"PBE-001","name":"KIT Atualizado","price":1234.56,"productFamily":"SUL","Category__c":"3"}]';

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    PricebookEntry pricebookEntry = getStdPbe(productRecord.Id);
    Product2 updatedProduct = [
      SELECT Name, Family, Category__c
      FROM Product2
      WHERE Id = :productRecord.Id
    ];

    System.assertNotEquals(null, pricebookEntry);
    System.assertEquals('PBE-001', pricebookEntry.ExternalId__c);
    System.assertEquals(1234.56, pricebookEntry.UnitPrice);
    System.assertEquals(true, pricebookEntry.IsActive);
    System.assertEquals('KIT Atualizado', updatedProduct.Name);
    System.assertEquals('SUL', updatedProduct.Family);
    System.assertEquals('3', updatedProduct.Category__c);
  }

  @IsTest
  static void testAdoptsLegacyActivePricebookEntry_WhenProductCodeMatches() {
    Product2 productRecord = createProduct(
      'Produto legado',
      'PC-LEGACY',
      'LEG-LEGACY',
      50
    );

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"productCode":"PC-LEGACY","externalId":"PBE-LEGACY-001","name":"Produto legado atualizado","price":200,"productFamily":"Solar"}]'
    );
    Test.stopTest();

    List<PricebookEntry> pricebookEntries = getStdPbes(productRecord.Id);
    Product2 updatedProduct = [
      SELECT Name, Family
      FROM Product2
      WHERE Id = :productRecord.Id
    ];

    System.assertEquals(1, pricebookEntries.size());
    System.assertEquals('PBE-LEGACY-001', pricebookEntries[0].ExternalId__c);
    System.assertEquals(200, pricebookEntries[0].UnitPrice);
    System.assertEquals(true, pricebookEntries[0].IsActive);
    System.assertEquals('Produto legado atualizado', updatedProduct.Name);
    System.assertEquals('Solar', updatedProduct.Family);
  }

  @IsTest
  static void testCreateProductAndPricebookEntry_WhenProductCodeMissing() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"externalId":"PBE-777","name":"KIT Fallback","price":2222.00,"productFamily":"Fibrocimento - NORTE","Category__c":"1"}]'
    );
    Test.stopTest();

    PricebookEntry createdEntry = [
      SELECT
        Id,
        Product2Id,
        UnitPrice,
        IsActive,
        ExternalId__c,
        Product2.Name,
        Product2.ProductCode,
        Product2.Category__c
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND ExternalId__c = 'PBE-777'
      LIMIT 1
    ];

    System.assertNotEquals(null, createdEntry);
    System.assertEquals('PBE-777', createdEntry.ExternalId__c);
    System.assertEquals(2222.00, createdEntry.UnitPrice);
    System.assertEquals(true, createdEntry.IsActive);
    System.assertEquals('KIT Fallback', createdEntry.Product2.Name);
    System.assertEquals(null, createdEntry.Product2.ProductCode);
    System.assertEquals('1', createdEntry.Product2.Category__c);
  }

  @IsTest
  static void testRejectsNewExternalId_WhenAnotherActiveEntryExists() {
    Product2 productRecord = createProduct(
      'Produto conflito',
      'PC-CONFLICT',
      'LEG-CONFLICT',
      80
    );
    updatePbeExternalId(productRecord.Id, 'PBE-ACTIVE', true);

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"productCode":"PC-CONFLICT","externalId":"PBE-NEW","name":"Produto conflito","price":300}]'
    );
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    List<PricebookEntry> pricebookEntries = getStdPbes(productRecord.Id);

    System.assert(responseBody.contains('"Conflict"'));
    System.assertEquals(1, pricebookEntries.size());
    System.assertEquals('PBE-ACTIVE', pricebookEntries[0].ExternalId__c);
    System.assertEquals(80, pricebookEntries[0].UnitPrice);
  }

  @IsTest
  static void testReusesInactivePricebookEntry_WhenNewExternalIdArrives() {
    Product2 productRecord = createProduct(
      'Produto inativo',
      'PC-INACTIVE',
      'LEG-INACTIVE',
      120
    );
    updatePbeExternalId(productRecord.Id, 'PBE-OLD-INACTIVE', false);

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"productCode":"PC-INACTIVE","externalId":"PBE-NEW-INACTIVE","name":"Produto inativo atualizado","price":321.45,"productFamily":"Solar"}]'
    );
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    List<PricebookEntry> pricebookEntries = getStdPbes(productRecord.Id);
    Product2 updatedProduct = [
      SELECT Name, Family
      FROM Product2
      WHERE Id = :productRecord.Id
    ];

    System.assert(responseBody.contains('"Updated"'));
    System.assertEquals(1, pricebookEntries.size());
    System.assertEquals('PBE-NEW-INACTIVE', pricebookEntries[0].ExternalId__c);
    System.assertEquals(321.45, pricebookEntries[0].UnitPrice);
    System.assertEquals(true, pricebookEntries[0].IsActive);
    System.assertEquals('Produto inativo atualizado', updatedProduct.Name);
    System.assertEquals('Solar', updatedProduct.Family);
  }

  @IsTest
  static void testSingleObjectPayloadCreatesProductAndEntry() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '{"productCode":"ONE-1","externalId":"PBE-ONE-1","name":"Produto Unitario","price":99.9,"productFamily":"Solar"}'
    );
    Test.stopTest();

    PricebookEntry createdEntry = [
      SELECT Id, Product2Id, ExternalId__c, Product2.ProductCode
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND ExternalId__c = 'PBE-ONE-1'
      LIMIT 1
    ];

    System.assertEquals('PBE-ONE-1', createdEntry.ExternalId__c);
    System.assertEquals('ONE-1', createdEntry.Product2.ProductCode);
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
}
