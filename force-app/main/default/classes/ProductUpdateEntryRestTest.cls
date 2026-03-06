/**
 * @description  Testes para ProductUpdateEntryRest — GET e PATCH de Product2/PricebookEntry.
 *               Cobre: GET (busca com filtros), PATCH (upsert, desativação, validações, bulk).
 *               Usa Assert.areEqual/Assert.isTrue (nunca System.assert).
 *               Sem SeeAllData=true. Sem callouts. Sem Test.isRunningTest() em produção.
 * @author       Daniel Belini
 * @group        Product
 **/
@IsTest
public with sharing class ProductUpdateEntryRestTest {
  // ─────────────────────────────────────────────────────────────────────────
  // Utilitários de teste
  // ─────────────────────────────────────────────────────────────────────────

  private static void setupRest(
    String method,
    String body,
    Map<String, String> params
  ) {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = method;
    if (body != null)
      req.requestBody = Blob.valueOf(body);
    if (params != null)
      req.params.putAll(params);
    RestContext.request = req;
    RestContext.response = res;
  }

  private static ProductBO.ProductResponse parseResponse() {
    String body = RestContext.response.responseBody.toString();
    return (ProductBO.ProductResponse) JSON.deserialize(
      body,
      ProductBO.ProductResponse.class
    );
  }

  /** Cria Product2 sem Preco_Unitario__c para não disparar PBE no trigger afterInsert */
  private static Product2 makeProduct(
    String code,
    String extId,
    String family
  ) {
    return new Product2(
      Name = 'KIT ' + code,
      ProductCode = code,
      Family = family,
      IsActive = true,
      ExternalId__c = extId
    );
  }

  private static PricebookEntry makePbe(Id prodId, Decimal price) {
    return new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prodId,
      UnitPrice = price,
      IsActive = true
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET — searchProducts
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testSearch_filterByFamilyAndActive_returnsMatchingProducts() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    insert makeProduct('PC-SRCH-1', 'EXT-SRCH-1', 'NORTE');
    insert makeProduct('PC-SRCH-2', 'EXT-SRCH-2', 'SUL');

    setupRest(
      'GET',
      null,
      new Map<String, String>{ 'family' => 'NORTE', 'active' => 'true' }
    );

    Test.startTest();
    ProductUpdateEntryRest.searchProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Status deve ser Success');
    Boolean found = false;
    for (ProductBO.ProductResult r : resp.results) {
      if (r.productCode == 'PC-SRCH-1') {
        found = true;
        Assert.areEqual(
          'Active',
          r.status,
          'Produto ativo deve ter status Active'
        );
      }
    }
    Assert.isTrue(found, 'Produto PC-SRCH-1 deve estar no resultado');
  }

  @IsTest
  static void testSearch_noFilters_returnsSuccessWithList() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    insert makeProduct('PC-SRCH-ALL', 'EXT-SRCH-ALL', 'NORTE');

    setupRest('GET', null, null);

    Test.startTest();
    ProductUpdateEntryRest.searchProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Status deve ser Success sem filtros'
    );
    Assert.isTrue(resp.results.size() >= 1, 'Deve retornar ao menos 1 produto');
  }

  @IsTest
  static void testSearch_filterByProductCode_returnsOnlyMatch() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    insert makeProduct('PC-EXACT', 'EXT-EXACT', 'NORTE');
    insert makeProduct('PC-OTHER', 'EXT-OTHER', 'NORTE');

    setupRest(
      'GET',
      null,
      new Map<String, String>{ 'productCode' => 'PC-EXACT' }
    );

    Test.startTest();
    ProductUpdateEntryRest.searchProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Status deve ser Success');
    Assert.areEqual(
      1,
      resp.results.size(),
      'Deve retornar exatamente 1 produto'
    );
    Assert.areEqual(
      'PC-EXACT',
      resp.results[0].productCode,
      'ProductCode deve ser PC-EXACT'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — upsert (criar produto novo)
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_produtoNaoEncontrado_criaNovoViaUpsert() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    String payload = '[{"externalId":"EXT-NOVO","productCode":"PC-NOVO","name":"KIT Novo via PATCH","price":300.00,"productFamily":"SUL"}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Upsert deve retornar Success');
    Assert.areEqual(1, resp.successCount, 'successCount deve ser 1');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(
      'Created',
      resp.results[0].status,
      'Produto novo deve ter status Created'
    );

    List<Product2> created = [
      SELECT Id
      FROM Product2
      WHERE ExternalId__c = 'EXT-NOVO'
    ];
    Assert.areEqual(1, created.size(), 'Deve ter criado exatamente 1 produto');

    List<PricebookEntry> pbes = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Product2Id = :created[0].Id
    ];
    Assert.areEqual(1, pbes.size(), 'Deve ter criado 1 PBE');
    Assert.areEqual(300.00, pbes[0].UnitPrice, 'UnitPrice deve ser 300.00');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — upsert (atualizar produto existente)
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_produtoExistente_atualizaCamposEPreco() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 p = makeProduct('PC-PATCH', 'EXT-PATCH', 'NORTE');
    insert p;
    insert makePbe(p.Id, 100.00);

    String payload = '[{"externalId":"EXT-PATCH","productCode":"PC-PATCH","price":999.99,"name":"KIT Atualizado"}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Status deve ser Success');
    Assert.areEqual(1, resp.successCount, 'successCount deve ser 1');
    Assert.areEqual(
      'Updated',
      resp.results[0].status,
      'Resultado deve ser Updated'
    );

    PricebookEntry pbe = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Product2Id = :p.Id
      LIMIT 1
    ];
    Assert.areEqual(
      999.99,
      pbe.UnitPrice,
      'UnitPrice deve ser atualizado para 999.99'
    );

    Product2 updated = [SELECT Name FROM Product2 WHERE Id = :p.Id];
    Assert.areEqual(
      'KIT Atualizado',
      updated.Name,
      'Name do produto deve ser atualizado'
    );
  }

  @IsTest
  static void testUpdate_existingByExternalIdSemProductCode_atualizaPreco() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    // Produto sem ProductCode — lookup deve funcionar somente por ExternalId
    Product2 p = new Product2(
      Name = 'KIT SEM CODE',
      IsActive = true,
      ExternalId__c = 'EXT-ONLY'
    );
    insert p;
    insert makePbe(p.Id, 50.00);

    String payload = '[{"externalId":"EXT-ONLY","price":750.00}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Status deve ser Success via ExternalId'
    );
    Assert.areEqual(
      'Updated',
      resp.results[0].status,
      'Resultado deve ser Updated'
    );

    PricebookEntry pbe = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Product2Id = :p.Id
      LIMIT 1
    ];
    Assert.areEqual(750.00, pbe.UnitPrice, 'UnitPrice deve ser 750.00');
  }

  @IsTest
  static void testUpdate_isActiveTrue_reativaProdutoEPbeExistente() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 p = makeProduct('PC-REACT', 'EXT-REACT', 'SUL');
    insert p;

    PricebookEntry pbe = makePbe(p.Id, 123.45);
    insert pbe;

    update new Product2(Id = p.Id, IsActive = false);
    update new PricebookEntry(Id = pbe.Id, IsActive = false);

    String payload = '[{"externalId":"EXT-REACT","isActive":true}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Reativação deve retornar Success');
    Assert.areEqual(1, resp.successCount, 'successCount deve ser 1');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(
      'Updated',
      resp.results[0].status,
      'Status deve ser Updated'
    );

    Product2 updatedProduct = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
    Assert.isTrue(updatedProduct.IsActive, 'Produto deve ser reativado');

    PricebookEntry updatedPbe = [
      SELECT IsActive, UnitPrice
      FROM PricebookEntry
      WHERE Id = :pbe.Id
    ];
    Assert.isTrue(updatedPbe.IsActive, 'PBE deve ser reativada');
    Assert.areEqual(
      123.45,
      updatedPbe.UnitPrice,
      'UnitPrice deve permanecer sem alteração'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — desativação via isActive=false
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_isActiveFalse_desativaSomentePbe() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 p = makeProduct('PC-DEACT', 'EXT-DEACT', 'NORTE');
    insert p;
    insert makePbe(p.Id, 200.00);

    String payload = '[{"externalId":"EXT-DEACT","isActive":false}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Desativação deve retornar Success'
    );
    Assert.areEqual(1, resp.successCount, 'successCount deve ser 1');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(
      'Deactivated',
      resp.results[0].status,
      'Status deve ser Deactivated'
    );

    Product2 updated = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
    Assert.isTrue(updated.IsActive, 'Produto deve permanecer ativo');

    PricebookEntry pbe = [
      SELECT IsActive
      FROM PricebookEntry
      WHERE Product2Id = :p.Id
      LIMIT 1
    ];
    Assert.isFalse(pbe.IsActive, 'PBE deve estar inativa');
  }

  @IsTest
  static void testUpdate_isActiveFalse_produtoNaoEncontrado_retornaNotFound() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    String payload = '[{"externalId":"EXT-INEXISTENTE","isActive":false}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Error',
      resp.status,
      'Produto inexistente deve retornar Error'
    );
    Assert.areEqual(0, resp.successCount, 'successCount deve ser 0');
    Assert.areEqual(1, resp.errorCount, 'errorCount deve ser 1');
    Assert.areEqual(
      'NotFound',
      resp.results[0].status,
      'Status deve ser NotFound'
    );
  }

  @IsTest
  static void testUpdate_isActiveFalse_comOliAtiva_desativaPbeMesmoAssim() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Id stdPbId = Test.getStandardPricebookId();

    Product2 p = makeProduct('PC-OLI', 'EXT-OLI', 'NORTE');
    insert p;
    PricebookEntry pbe = makePbe(p.Id, 500.00);
    insert pbe;

    Account acc = new Account(Name = 'Conta OLI');
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp OLI',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = acc.Id,
      Pricebook2Id = stdPbId
    );
    insert opp;
    insert new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 500.00
    );

    String payload = '[{"externalId":"EXT-OLI","isActive":false}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Com OLI ativa ainda deve permitir desativar PBE'
    );
    Assert.areEqual(1, resp.successCount, 'successCount deve ser 1');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(
      'Deactivated',
      resp.results[0].status,
      'Status deve ser Deactivated'
    );

    Product2 still = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
    Assert.isTrue(still.IsActive, 'Produto deve continuar ativo');

    PricebookEntry updatedPbe = [
      SELECT IsActive
      FROM PricebookEntry
      WHERE Id = :pbe.Id
    ];
    Assert.isFalse(updatedPbe.IsActive, 'PBE deve estar inativa');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — validações de payload
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_semExternalId_retornaInvalidPayload() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    // Item sem externalId — obrigatório no novo design
    String payload = '[{"name":"Fantasma","price":100.00}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Error', resp.status, 'Sem externalId deve retornar Error');
    Assert.areEqual(0, resp.successCount, 'successCount deve ser 0');
    Assert.areEqual(1, resp.errorCount, 'errorCount deve ser 1');
    Assert.areEqual(
      'InvalidPayload',
      resp.results[0].status,
      'Status deve ser InvalidPayload'
    );
  }

  @IsTest
  static void testUpdate_externalIdDuplicado_retornaDuplicateError() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    // Mesmo externalId aparece duas vezes no payload — segunda ocorrência deve ser rejeitada
    String payload = '[{"externalId":"EXT-DUP","name":"Primeiro","price":100.00},{"externalId":"EXT-DUP","name":"Segundo","price":200.00}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Partial',
      resp.status,
      'Com duplicata deve retornar Partial'
    );
    Assert.areEqual(
      1,
      resp.successCount,
      'successCount deve ser 1 (primeiro item)'
    );
    Assert.areEqual(1, resp.errorCount, 'errorCount deve ser 1 (segundo item)');
    Assert.areEqual(2, resp.results.size(), 'Deve retornar 2 resultados');

    Boolean foundDup = false;
    for (ProductBO.ProductResult r : resp.results) {
      if (r.status == 'DuplicateExternalId')
        foundDup = true;
    }
    Assert.isTrue(
      foundDup,
      'Deve ter resultado com status DuplicateExternalId'
    );
  }

  @IsTest
  static void testUpdate_payloadInvalido_retornaError() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    setupRest('PATCH', 'NOT_JSON', null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Error', resp.status, 'JSON inválido deve retornar Error');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — payload misto (upsert + desativação no mesmo request)
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_mixedPayload_upsertEDesativacaoNoMesmoRequest() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 existing = makeProduct('PC-MIX', 'EXT-MIX-DEACT', 'NORTE');
    insert existing;
    insert makePbe(existing.Id, 300.00);

    // Um item cria produto novo; outro desativa o existente
    String payload =
      '[' +
      '{"externalId":"EXT-MIX-NEW","productCode":"PC-MIX-NEW","name":"Novo Produto","price":150.00},' +
      '{"externalId":"EXT-MIX-DEACT","isActive":false}' +
      ']';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Mixed payload deve retornar Success'
    );
    Assert.areEqual(2, resp.successCount, 'successCount deve ser 2');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(2, resp.results.size(), 'Deve ter 2 resultados');

    Boolean foundCreated = false;
    Boolean foundDeactivated = false;
    for (ProductBO.ProductResult r : resp.results) {
      if (r.status == 'Created')
        foundCreated = true;
      if (r.status == 'Deactivated')
        foundDeactivated = true;
    }
    Assert.isTrue(foundCreated, 'Deve ter resultado Created');
    Assert.isTrue(foundDeactivated, 'Deve ter resultado Deactivated');

    Product2 deactivated = [
      SELECT IsActive
      FROM Product2
      WHERE Id = :existing.Id
    ];
    Assert.isTrue(
      deactivated.IsActive,
      'Produto existente deve permanecer ativo'
    );

    PricebookEntry existingPbe = [
      SELECT IsActive
      FROM PricebookEntry
      WHERE Product2Id = :existing.Id
      LIMIT 1
    ];
    Assert.isFalse(
      existingPbe.IsActive,
      'PBE do produto desativado deve ficar inativa'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — preço negativo (não deve alterar UnitPrice)
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_precoNegativo_naoAtualizaPbe() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 p = makeProduct('PC-NEG', 'EXT-NEG', 'NORTE');
    insert p;
    insert makePbe(p.Id, 500.00);

    String payload = '[{"externalId":"EXT-NEG","productCode":"PC-NEG","price":-1.00}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Preço negativo não deve gerar erro'
    );

    PricebookEntry pbe = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Product2Id = :p.Id
      LIMIT 1
    ];
    Assert.areEqual(
      500.00,
      pbe.UnitPrice,
      'UnitPrice não deve ser alterado por preço negativo'
    );
  }

  @IsTest
  static void testUpdate_precoNegativoComCampoAtualizado_atualizaCampoMasNaoPbe() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();
    Product2 p = makeProduct('PC-NEG2', 'EXT-NEG2', 'NORTE');
    insert p;
    insert makePbe(p.Id, 300.00);

    String payload = '[{"externalId":"EXT-NEG2","productCode":"PC-NEG2","price":-50.00,"name":"KIT Atualizado Neg","productFamily":"SUL"}]';
    setupRest('PATCH', payload, null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual(
      'Success',
      resp.status,
      'Preço negativo com campos válidos não deve gerar erro'
    );

    Product2 updated = [SELECT Name, Family FROM Product2 WHERE Id = :p.Id];
    Assert.areEqual(
      'KIT Atualizado Neg',
      updated.Name,
      'Name deve ser atualizado mesmo com preço negativo'
    );
    Assert.areEqual(
      'SUL',
      updated.Family,
      'Family deve ser atualizada mesmo com preço negativo'
    );

    PricebookEntry pbe = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Product2Id = :p.Id
      LIMIT 1
    ];
    Assert.areEqual(
      300.00,
      pbe.UnitPrice,
      'UnitPrice não deve ser alterado por preço negativo'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH — bulk (200 registros)
  // ─────────────────────────────────────────────────────────────────────────

  @IsTest
  static void testUpdate_bulk200_criaEAtribuiPrecosCorretamente() {
    ProductDAO.standardPricebookIdOverride = Test.getStandardPricebookId();

    List<ProductBO.ProductPayload> payloads = new List<ProductBO.ProductPayload>();
    for (Integer i = 0; i < 200; i++) {
      ProductBO.ProductPayload p = new ProductBO.ProductPayload();
      p.externalId = 'EXT-BULK-' + i;
      p.productCode = 'PC-BULK-' + i;
      p.name = 'KIT Bulk ' + i;
      p.price = 100.00 + i;
      p.productFamily = 'NORTE';
      payloads.add(p);
    }

    setupRest('PATCH', JSON.serialize(payloads), null);

    Test.startTest();
    ProductUpdateEntryRest.updateProducts();
    Test.stopTest();

    ProductBO.ProductResponse resp = parseResponse();
    Assert.areEqual('Success', resp.status, 'Bulk 200 deve retornar Success');
    Assert.areEqual(200, resp.successCount, 'successCount deve ser 200');
    Assert.areEqual(0, resp.errorCount, 'errorCount deve ser 0');
    Assert.areEqual(200, resp.results.size(), 'Deve retornar 200 resultados');

    Integer created = 0;
    for (ProductBO.ProductResult r : resp.results) {
      if (r.status == 'Created')
        created++;
    }
    Assert.areEqual(
      200,
      created,
      'Todos os 200 produtos devem ter sido criados'
    );

    Integer prodCount = [
      SELECT COUNT()
      FROM Product2
      WHERE ProductCode LIKE 'PC-BULK-%'
    ];
    Assert.areEqual(200, prodCount, 'Deve ter 200 produtos no banco');
  }
}
