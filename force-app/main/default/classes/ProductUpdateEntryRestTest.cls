/**
 * @description						 : Tests for ProductUpdateEntryRest using productCode/externalId
 * @author											 : Daniel Belini
 * @last modified on	 : 10-23-2025
 * @last modified by	 : Daniel Belini
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

  @IsTest
  static void testUpdatePrice_ByProductCode() {
    // Arrange
    Id stdPbId = Test.getStandardPricebookId();

    Product2 p = new Product2(
      Name = 'KIT 5,0 kWp',
      ProductCode = 'PC-001',
      IsActive = true,
      ExternalId__c = 'EXT-001',
      Id_Externo__c = 'EXT-001' // << obrigatório na tua org
    );
    insert p;

    String payload = '[{"productCode":"PC-001","price":1234.56,"name":"KIT 5,0 kWp"}]';

    // Act
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    // Assert
    PricebookEntry pbe = getStdPbe(p.Id);
  }

  @IsTest
  static void testCreateProduct_AndPbe_ByProductCode() {
    // Arrange
    Id stdPbId = Test.getStandardPricebookId();

    // IMPORTANTE: incluir externalId para cumprir o campo obrigatório Id_Externo__c na criação
    String payload = '[{"productCode":"NEW-100","externalId":"EXT-NEW-100","name":"KIT NEW 10,0 kWp","price":9876.54,"productFamily":"Metálico - NORTE"}]';

    // Act
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    // Assert: produto criado
    Product2 created = [
      SELECT Id, Name, ProductCode, Family, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE ProductCode = 'NEW-100'
      LIMIT 1
    ];

    // PBE criado
    PricebookEntry pbe = getStdPbe(created.Id);
  }

  @IsTest
  static void testCreateProduct_ByExternalId_FallbackWhenNoProductCode() {
    // Arrange
    Id stdPbId = Test.getStandardPricebookId();

    // Sem productCode: rota faz fallback ProductCode = externalId
    String payload = '[{"externalId":"EXT-777","name":"KIT Fallback","price":2222.00,"productFamily":"Fibrocimento - NORTE"}]';

    // Act
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    // Assert: produto criado com ProductCode = externalId
    Product2 created = [
      SELECT Id, Name, ProductCode, Family, ExternalId__c, Id_Externo__c
      FROM Product2
      WHERE ProductCode = 'EXT-777'
      LIMIT 1
    ];
    PricebookEntry pbe = getStdPbe(created.Id);
  }

  @IsTest
  static void testUpdatePrice_ByName_WhenNoProductCode() {
    // Arrange
    Id stdPbId = Test.getStandardPricebookId();

    Product2 p = new Product2(
      Name = 'KIT POR NOME 7,2 kWp',
      IsActive = true,
      ExternalId__c = 'EXT-90210',
      Id_Externo__c = 'EXT-90210' // << obrigatório
      // sem ProductCode de propósito
    );
    insert p;

    String payload = '[{"name":"KIT POR NOME 7,2 kWp","price":3333.33}]';

    // Act
    Test.startTest();
    ProductUpdateEntryRest.testUpdateProductPrices(payload);
    Test.stopTest();

    // Assert
    PricebookEntry pbe = getStdPbe(p.Id);
  }
}
