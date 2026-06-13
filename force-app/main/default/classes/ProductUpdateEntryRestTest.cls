/**
 * @description       : Tests for ProductUpdateEntryRest using externalId as the unique product and price entry key.
 * @author            : Codex
 * @group             :
 * @last modified on  : 06-13-2026
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
  static void testRejectsUpdate_WhenProductHasActivePricebookEntry() {
    Product2 productRecord = createProduct(
      'KIT 5,0 kWp',
      'PC-001',
      'PBE-001',
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

    Assert.isNotNull(pricebookEntry);
    Assert.areEqual('PBE-001', pricebookEntry.ExternalId__c);
    Assert.areEqual(100, pricebookEntry.UnitPrice);
    Assert.isTrue(pricebookEntry.IsActive);
    Assert.areEqual('KIT 5,0 kWp', updatedProduct.Name);
    Assert.isNull(updatedProduct.Family);
    Assert.isNull(updatedProduct.Category__c);
    String responseBody = RestContext.response.responseBody.toString();
    Assert.isTrue(responseBody.contains('"Success" : false'));
    Assert.isTrue(
      responseBody.contains(
        'There is already an active PricebookEntry for the product.'
      )
    );
  }

  @IsTest
  static void testCreatesPricebookEntry_WhenProductExistsWithoutEntry() {
    Product2 productRecord = createProduct(
      'Produto sem entrada',
      'PC-NO-PBE',
      'PBE-NEW-001',
      null
    );

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"productCode":"PC-NO-PBE","externalId":"PBE-NEW-001","name":"Produto atualizado","price":200,"productFamily":"Solar","Description":"Descricao atualizada"}]'
    );
    Test.stopTest();

    List<PricebookEntry> pricebookEntries = getStdPbes(productRecord.Id);
    Product2 updatedProduct = [
      SELECT
        Name,
        Family,
        Description,
        Preco_Unitario__c,
        ProductCode,
        ExternalId__c,
        Id_Externo__c
      FROM Product2
      WHERE Id = :productRecord.Id
    ];

    Assert.areEqual(1, pricebookEntries.size());
    Assert.areEqual('PBE-NEW-001', pricebookEntries[0].ExternalId__c);
    Assert.areEqual(200, pricebookEntries[0].UnitPrice);
    Assert.isTrue(pricebookEntries[0].IsActive);
    Assert.areEqual('Produto atualizado', updatedProduct.Name);
    Assert.areEqual('Solar', updatedProduct.Family);
    Assert.areEqual('Descricao atualizada', updatedProduct.Description);
    Assert.areEqual(200, updatedProduct.Preco_Unitario__c);
    Assert.areEqual('PC-NO-PBE', updatedProduct.ProductCode);
    Assert.areEqual('PBE-NEW-001', updatedProduct.ExternalId__c);
    Assert.areEqual('PBE-NEW-001', updatedProduct.Id_Externo__c);
    Assert.isTrue(
      RestContext.response.responseBody.toString().contains('"Success" : true')
    );
  }

  @IsTest
  static void testCreatesProduct_WhenProductCodeMissing() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"externalId":"PBE-777","name":"KIT Fallback","price":2222.00,"productFamily":"Fibrocimento - NORTE","Category__c":"1"}]'
    );
    Test.stopTest();

    PricebookEntry createdEntry = [
      SELECT
        ExternalId__c,
        Product2.ProductCode,
        Product2.ExternalId__c,
        Product2.Id_Externo__c
      FROM PricebookEntry
      WHERE ExternalId__c = 'PBE-777'
      LIMIT 1
    ];
    Assert.areEqual('PBE-777', createdEntry.ExternalId__c);
    Assert.isNull(createdEntry.Product2.ProductCode);
    Assert.areEqual('PBE-777', createdEntry.Product2.ExternalId__c);
    Assert.areEqual('PBE-777', createdEntry.Product2.Id_Externo__c);
    Assert.isTrue(
      RestContext.response.responseBody.toString().contains('"Success" : true')
    );
  }

  @IsTest
  static void testReusesInactivePricebookEntry_WhenNewExternalIdArrives() {
    Product2 productRecord = createProduct(
      'Produto inativo',
      'PC-INACTIVE',
      'PBE-NEW-INACTIVE',
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
      SELECT Name, Family, ProductCode, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE Id = :productRecord.Id
    ];

    Assert.isTrue(responseBody.contains('"Success" : true'));
    Assert.isTrue(responseBody.contains('"Id"'));
    Assert.isTrue(
      responseBody.contains(String.valueOf(pricebookEntries[0].Id))
    );
    Assert.areEqual(1, pricebookEntries.size());
    Assert.areEqual('PBE-NEW-INACTIVE', pricebookEntries[0].ExternalId__c);
    Assert.areEqual(321.45, pricebookEntries[0].UnitPrice);
    Assert.isTrue(pricebookEntries[0].IsActive);
    Assert.areEqual('Produto inativo atualizado', updatedProduct.Name);
    Assert.areEqual('Solar', updatedProduct.Family);
    Assert.areEqual('PC-INACTIVE', updatedProduct.ProductCode);
    Assert.areEqual('PBE-NEW-INACTIVE', updatedProduct.ExternalId__c);
    Assert.areEqual('PBE-NEW-INACTIVE', updatedProduct.Id_Externo__c);
  }

  @IsTest
  static void testSingleObjectPayloadCreatesProductAndEntry() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '{"productCode":"ONE-1","externalId":"PBE-ONE-1","name":"Produto Unitario","price":99.9,"productFamily":"Solar"}'
    );
    Test.stopTest();

    PricebookEntry createdEntry = [
      SELECT
        Id,
        Product2Id,
        ExternalId__c,
        Product2.ProductCode,
        Product2.ExternalId__c,
        Product2.Id_Externo__c
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND ExternalId__c = 'PBE-ONE-1'
      LIMIT 1
    ];

    Assert.areEqual('PBE-ONE-1', createdEntry.ExternalId__c);
    Assert.areEqual('ONE-1', createdEntry.Product2.ProductCode);
    Assert.areEqual('PBE-ONE-1', createdEntry.Product2.ExternalId__c);
    Assert.areEqual('PBE-ONE-1', createdEntry.Product2.Id_Externo__c);
    Assert.isTrue(
      RestContext.response.responseBody.toString().contains('"Success" : true')
    );
  }

  @IsTest
  static void testMigratesLegacyProductCode_WhenExternalIdMatchesInactiveEntry() {
    Product2 productRecord = createProduct(
      '635 Wp - LONGI',
      'ITM10663NORTE',
      'LEG-LONGI',
      500
    );
    updatePbeExternalId(productRecord.Id, '58825NORTE', false);

    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '{"productCode":"ITM10663NORTE","externalId":"58825NORTE","name":"635 Wp - LONGI","price":625.03,"productFamily":"NORTE"}'
    );
    Test.stopTest();

    Product2 updatedProduct = [
      SELECT ProductCode, Name, Family, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE Id = :productRecord.Id
    ];
    PricebookEntry updatedEntry = getStdPbe(productRecord.Id);

    Assert.areEqual('ITM10663NORTE', updatedProduct.ProductCode);
    Assert.areEqual('58825NORTE', updatedProduct.ExternalId__c);
    Assert.areEqual('58825NORTE', updatedProduct.Id_Externo__c);
    Assert.areEqual('635 Wp - LONGI', updatedProduct.Name);
    Assert.areEqual('NORTE', updatedProduct.Family);
    Assert.areEqual('58825NORTE', updatedEntry.ExternalId__c);
    Assert.areEqual(625.03, updatedEntry.UnitPrice);
    Assert.isTrue(updatedEntry.IsActive);
  }

  @IsTest
  static void testCreatesDistinctProducts_WhenItmIsRepeated() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(
      '[{"productCode":"ITM10663NORTE","externalId":"58824NORTE","name":"710 Wp - ASTRONERGY BIFACIAL","price":714.48,"productFamily":"NORTE"},{"productCode":"ITM10663NORTE","externalId":"58825NORTE","name":"635 Wp - LONGI","price":625.03,"productFamily":"NORTE"}]'
    );
    Test.stopTest();

    List<Product2> products = [
      SELECT Id, Name, ProductCode, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE
        ExternalId__c IN ('58824NORTE', '58825NORTE')
        OR Id_Externo__c IN ('58824NORTE', '58825NORTE')
    ];
    List<PricebookEntry> entries = [
      SELECT Id, ExternalId__c, Product2.ProductCode
      FROM PricebookEntry
      WHERE ExternalId__c IN ('58824NORTE', '58825NORTE')
    ];

    Assert.areEqual(2, products.size());
    Assert.areEqual(2, entries.size());
    for (Product2 productRecord : products) {
      Assert.areEqual('ITM10663NORTE', productRecord.ProductCode);
      Assert.areEqual(productRecord.ExternalId__c, productRecord.Id_Externo__c);
    }
    Assert.isTrue(
      RestContext.response.responseBody.toString()
        .contains('"productCode" : "ITM10663NORTE"')
    );
  }

  @IsTest
  static void testEmptyPayloadReturnsError() {
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices('[]');
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    Assert.isTrue(responseBody.contains('"Success" : false'));
    Assert.isTrue(responseBody.contains('No products provided.'));
  }
}
