/**
 * @description       : Test class for ProductBO.processUpdates via ProductUpdateEntryRest. Covers: create, update,
 *                       deactivate, mixed payload, guards, and edge cases.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class ProductUpdateEntryRestTest {
  // ─── Helpers ────────────────────────────────────────────────────────────────

  private static Product2 createProduct(
    String name,
    String productCode,
    String externalId
  ) {
    Product2 p = new Product2(
      Name = name,
      ProductCode = productCode,
      IsActive = true,
      ExternalId__c = externalId
    );
    insert p;
    return p;
  }

  private static void createPbe(Id productId, Decimal price) {
    insert new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = productId,
      UnitPrice = price,
      IsActive = true
    );
  }

  private static PricebookEntry getStdPbe(Id productId) {
    List<PricebookEntry> pbes = [
      SELECT Id, UnitPrice, IsActive
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND Product2Id = :productId
      LIMIT 1
    ];
    return pbes.isEmpty() ? null : pbes[0];
  }

  // ─── Tests ──────────────────────────────────────────────────────────────────

  /**
   * Cenário 1: produto novo — deve criar Product2 + PBE com status Created
   */
  @isTest
  static void testProcessUpdates_newProduct_createsProductAndPbe() {
    String payload = '[{"externalId":"EXT-NEW-001","productCode":"PC-NEW-001","name":"Produto Novo","price":1500.00,"productFamily":"SUL"}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Product2 created = [
      SELECT Id, Name, ProductCode, IsActive, ExternalId__c, Family
      FROM Product2
      WHERE ExternalId__c = 'EXT-NEW-001'
      LIMIT 1
    ];
    Assert.areEqual('PC-NEW-001', created.ProductCode, 'ProductCode incorreto');
    Assert.areEqual('Produto Novo', created.Name, 'Name incorreto');
    Assert.areEqual(true, created.IsActive, 'Produto deve estar ativo');
    Assert.areEqual('SUL', created.Family, 'Family incorreto');

    PricebookEntry pbe = getStdPbe(created.Id);
    Assert.isNotNull(pbe, 'PBE deve ter sido criada');
    Assert.areEqual(1500.00, pbe.UnitPrice, 'UnitPrice incorreto');

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(respBody.contains('"Success"'), 'Status deve ser Success');
    Assert.isTrue(
      respBody.contains('"Created"'),
      'Resultado deve conter Created'
    );
  }

  /**
   * Cenário 2: produto existente — deve atualizar preço da PBE, sem duplicar Product2
   */
  @isTest
  static void testProcessUpdates_existingProduct_updatesPbePrice() {
    Product2 existing = createProduct(
      'Produto Existente',
      'PC-EXIST-001',
      'EXT-EXIST-001'
    );
    createPbe(existing.Id, 100.00);

    String payload = '[{"externalId":"EXT-EXIST-001","price":999.99}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Product2
      WHERE ExternalId__c = 'EXT-EXIST-001'
    ];
    Assert.areEqual(1, count, 'Não deve duplicar Product2');

    PricebookEntry pbe = getStdPbe(existing.Id);
    Assert.isNotNull(pbe, 'PBE deve existir');
    Assert.areEqual(999.99, pbe.UnitPrice, 'Preço deve ter sido atualizado');

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(
      respBody.contains('"Updated"'),
      'Resultado deve conter Updated'
    );
  }

  /**
   * Cenário 3: isActive false — deve desativar Product2 e todas as PBEs
   */
  @isTest
  static void testProcessUpdates_deactivate_deactivatesProductAndPbes() {
    Product2 existing = createProduct(
      'Produto Ativo',
      'PC-DEACT-001',
      'EXT-DEACT-001'
    );
    createPbe(existing.Id, 500.00);

    String payload = '[{"externalId":"EXT-DEACT-001","isActive":false}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Product2 updated = [
      SELECT Id, IsActive
      FROM Product2
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(false, updated.IsActive, 'Produto deve estar desativado');

    PricebookEntry pbe = [
      SELECT Id, IsActive
      FROM PricebookEntry
      WHERE Product2Id = :existing.Id
      LIMIT 1
    ];
    Assert.areEqual(false, pbe.IsActive, 'PBE deve estar desativada');

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(
      respBody.contains('"Deactivated"'),
      'Resultado deve conter Deactivated'
    );
  }

  /**
   * Mixed: payload com os 3 cenários juntos
   */
  @isTest
  static void testProcessUpdates_mixedPayload_handlesAllScenarios() {
    Product2 toUpdate = createProduct(
      'Produto Editar',
      'PC-UPD-MIX',
      'EXT-UPD-MIX'
    );
    createPbe(toUpdate.Id, 200.00);
    Product2 toDeact = createProduct(
      'Produto Desativar',
      'PC-DEACT-MIX',
      'EXT-DEACT-MIX'
    );
    createPbe(toDeact.Id, 300.00);

    String payload =
      '[' +
      '{"externalId":"EXT-NEW-MIX","productCode":"PC-NEW-MIX","name":"Produto Novo Mix","price":1234.00},' +
      '{"externalId":"EXT-UPD-MIX","price":888.00},' +
      '{"externalId":"EXT-DEACT-MIX","isActive":false}' +
      ']';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Product2 created = [
      SELECT Id, IsActive
      FROM Product2
      WHERE ExternalId__c = 'EXT-NEW-MIX'
      LIMIT 1
    ];
    Assert.areEqual(true, created.IsActive, 'Novo produto deve estar ativo');
    Assert.areEqual(
      1234.00,
      getStdPbe(created.Id).UnitPrice,
      'Preço do novo produto incorreto'
    );

    Assert.areEqual(
      888.00,
      getStdPbe(toUpdate.Id).UnitPrice,
      'Preço atualizado incorreto'
    );

    Assert.areEqual(
      false,
      [SELECT IsActive FROM Product2 WHERE Id = :toDeact.Id].IsActive,
      'Produto deve estar desativado'
    );

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(respBody.contains('"Success"'), 'Status deve ser Success');
    Assert.isTrue(
      respBody.contains('"Created"'),
      'Resultado deve conter Created'
    );
    Assert.isTrue(
      respBody.contains('"Updated"'),
      'Resultado deve conter Updated'
    );
    Assert.isTrue(
      respBody.contains('"Deactivated"'),
      'Resultado deve conter Deactivated'
    );
  }

  /**
   * Guard: desativar produto inexistente — retorna NotFound sem erro
   */
  @isTest
  static void testProcessUpdates_deactivateNotFound_returnsNotFound() {
    String payload = '[{"externalId":"EXT-GHOST-999","isActive":false}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(
      respBody.contains('"NotFound"'),
      'Deve retornar NotFound para produto inexistente'
    );
    Assert.isTrue(
      respBody.contains('"Success"'),
      'Status geral deve ser Success'
    );
  }

  /**
   * Guard: payload vazio — retorna Error
   */
  @isTest
  static void testProcessUpdates_emptyPayload_returnsError() {
    Test.startTest();
    ProductUpdateEntryRest.callPatch('[]');
    Test.stopTest();

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(
      respBody.contains('"Error"'),
      'Deve retornar Error para payload vazio'
    );
  }

  /**
   * Guard: JSON inválido — retorna Error sem inserção parcial
   */
  @isTest
  static void testProcessUpdates_invalidJson_returnsError() {
    Test.startTest();
    ProductUpdateEntryRest.callPatch('{invalid-json}');
    Test.stopTest();

    String respBody = RestContext.response.responseBody.toString();
    Assert.isTrue(
      respBody.contains('"Error"'),
      'Deve retornar Error para JSON inválido'
    );

    Integer count = [SELECT COUNT() FROM Product2];
    Assert.areEqual(0, count, 'Nenhum produto deve ter sido criado');
  }

  /**
   * Edge: busca por productCode quando payload não contém externalId
   */
  @isTest
  static void testProcessUpdates_matchByProductCode_updatesCorrectly() {
    Product2 existing = createProduct(
      'Produto por Código',
      'PC-CODE-001',
      'EXT-CODE-001'
    );
    createPbe(existing.Id, 50.00);

    String payload = '[{"productCode":"PC-CODE-001","price":777.00}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    PricebookEntry pbe = getStdPbe(existing.Id);
    Assert.areEqual(
      777.00,
      pbe.UnitPrice,
      'Preço deve ter sido atualizado via productCode'
    );
  }

  /**
   * Edge: criar produto sem price — Product2 criado, PBE não criada, sem erro
   */
  @isTest
  static void testProcessUpdates_createWithoutPrice_createsProductOnly() {
    String payload = '[{"externalId":"EXT-NOPRICE","productCode":"PC-NOPRICE","name":"Sem Preco"}]';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Product2 created = [
      SELECT Id
      FROM Product2
      WHERE ExternalId__c = 'EXT-NOPRICE'
      LIMIT 1
    ];
    Assert.isNotNull(created.Id, 'Produto deve ter sido criado');
    Assert.isNull(
      getStdPbe(created.Id),
      'PBE não deve ter sido criada sem price'
    );
  }

  /**
   * Bulk: 10 produtos novos em um único payload — sem SOQL/DML em loop
   */
  @isTest
  static void testProcessUpdates_bulkCreate_insertsAll() {
    List<String> payloadItems = new List<String>();
    for (Integer i = 1; i <= 10; i++) {
      payloadItems.add(
        '{"externalId":"BULK-EXT-' +
          i +
          '","productCode":"BULK-PC-' +
          i +
          '","name":"Produto Bulk ' +
          i +
          '","price":' +
          (i * 100) +
          '}'
      );
    }
    String payload = '[' + String.join(payloadItems, ',') + ']';

    Test.startTest();
    ProductUpdateEntryRest.callPatch(payload);
    Test.stopTest();

    Integer productCount = [
      SELECT COUNT()
      FROM Product2
      WHERE ProductCode LIKE 'BULK-PC-%'
    ];
    Assert.areEqual(10, productCount, 'Devem ter sido criados 10 produtos');

    Integer pbeCount = [
      SELECT COUNT()
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :Test.getStandardPricebookId()
        AND Product2.ProductCode LIKE 'BULK-PC-%'
    ];
    Assert.areEqual(10, pbeCount, 'Devem ter sido criadas 10 PBEs');
  }
}
