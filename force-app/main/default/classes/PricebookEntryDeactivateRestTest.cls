/**
 * @description       : Tests for PricebookEntryDeactivateRest.
 * @author            : Codex
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : Codex
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class PricebookEntryDeactivateRestTest {
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

  private static PricebookEntry preparePricebookEntry(
    Product2 productRecord,
    String externalId,
    Boolean isActive
  ) {
    PricebookEntry pricebookEntry = [
      SELECT Id, Product2Id, ExternalId__c, IsActive
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND Product2Id = :productRecord.Id
      LIMIT 1
    ];
    pricebookEntry.ExternalId__c = externalId;
    pricebookEntry.IsActive = isActive;
    update pricebookEntry;
    return pricebookEntry;
  }

  @IsTest
  static void testDeactivateActivePricebookEntry() {
    Product2 productRecord = createProduct('Produto 1', 'PBE-001', 'LEG-1', 10);
    PricebookEntry pricebookEntry = preparePricebookEntry(
      productRecord,
      'ACTIVE-PBE-1',
      true
    );

    Test.startTest();
    PricebookEntryDeactivateRest.testDeactivatePricebookEntries(
      '[{"externalId":"ACTIVE-PBE-1"}]'
    );
    Test.stopTest();

    PricebookEntry updatedEntry = [
      SELECT IsActive
      FROM PricebookEntry
      WHERE Id = :pricebookEntry.Id
    ];

    System.assertEquals(false, updatedEntry.IsActive);
    System.assert(
      RestContext.response.responseBody.toString().contains('"Deactivated"')
    );
  }

  @IsTest
  static void testReturnsAlreadyInactiveAndNotFoundStatuses() {
    Product2 productRecord = createProduct('Produto 2', 'PBE-002', 'LEG-2', 20);
    preparePricebookEntry(productRecord, 'INACTIVE-PBE-2', false);

    Test.startTest();
    PricebookEntryDeactivateRest.testDeactivatePricebookEntries(
      '[{"externalId":"INACTIVE-PBE-2"},{"externalId":"UNKNOWN-PBE"}]'
    );
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    System.assert(responseBody.contains('"AlreadyInactive"'));
    System.assert(responseBody.contains('"NotFound"'));
  }

  @IsTest
  static void testAcceptsStringArrayPayload() {
    Product2 productRecord = createProduct('Produto 3', 'PBE-003', 'LEG-3', 30);
    PricebookEntry pricebookEntry = preparePricebookEntry(
      productRecord,
      'ACTIVE-PBE-3',
      true
    );

    Test.startTest();
    PricebookEntryDeactivateRest.testDeactivatePricebookEntries(
      '["ACTIVE-PBE-3"]'
    );
    Test.stopTest();

    PricebookEntry updatedEntry = [
      SELECT IsActive
      FROM PricebookEntry
      WHERE Id = :pricebookEntry.Id
    ];
    System.assertEquals(false, updatedEntry.IsActive);
  }

  @IsTest
  static void testReturnsMissingExternalIdForSingleObjectPayload() {
    Test.startTest();
    PricebookEntryDeactivateRest.testDeactivatePricebookEntries('{}');
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    System.assert(responseBody.contains('Missing externalId.'));
  }

  @IsTest
  static void testEmptyPayloadReturnsError() {
    Test.startTest();
    PricebookEntryDeactivateRest.testDeactivatePricebookEntries('[]');
    Test.stopTest();

    String responseBody = RestContext.response.responseBody.toString();
    System.assert(responseBody.contains('No pricebook entries provided.'));
  }
}
