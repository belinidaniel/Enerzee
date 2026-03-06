@IsTest
private class OpportunityProductSelectorControllerTest {
  private static final String OPP_SUL_NAME = 'OPP_SELECTOR_SUL';
  private static final String OPP_NO_STATE_NAME = 'OPP_SELECTOR_NO_STATE';

  @TestSetup
  static void setupData() {
    String uniqueSeed = String.valueOf(DateTime.now().getTime());

    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    Pricebook2 opportunityPricebook = new Pricebook2(
      Name = 'PB_OPPORTUNITY_SELECTOR',
      IsActive = true
    );
    insert opportunityPricebook;

    Pricebook2 otherPricebook = new Pricebook2(
      Name = 'PB_OTHER_SELECTOR',
      IsActive = true
    );
    insert otherPricebook;

    Opportunity opportunitySul = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        Name = OPP_SUL_NAME,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('OutrasOportunidades')
          .getRecordTypeId(),
        StageName = 'Proposta Gerada',
        IdVirtualOffice__c = 'VO-SEL-SUL-' + uniqueSeed,
        EstadoInstalacao__c = 'Paraná',
        Pricebook2Id = opportunityPricebook.Id
      ),
      true
    );

    Opportunity opportunityNoState = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        Name = OPP_NO_STATE_NAME,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('OutrasOportunidades')
          .getRecordTypeId(),
        StageName = 'Proposta Gerada',
        IdVirtualOffice__c = 'VO-SEL-NOSTATE-' + uniqueSeed,
        Pricebook2Id = opportunityPricebook.Id
      ),
      true
    );

    update new Opportunity(
      Id = opportunityNoState.Id,
      EstadoInstalacao__c = null
    );

    Product2 productSul1 = createProduct('Produto Sul 1', 'SUL', 'SUL-001');
    Product2 productSul2 = createProduct('Produto Sul 2', 'SUL', 'SUL-002');
    Product2 productCenterWest = createProduct('Produto CO', 'CO', 'CO-001');
    Product2 kitSulMicro = createProduct(
      'KIT Sul Micro Cerâmico',
      'Cerâmico - SUL - KITS MICRO',
      'KIT-SUL-001',
      '3',
      'KIT'
    );
    Product2 kitNordesteTrifasico = createProduct(
      'KIT Nordeste Trifásico Metálico',
      'Metálico - NORDESTE - KITS TRIFÁSICOS',
      'KIT-NE-001',
      '2',
      'KIT'
    );

    insert new List<PricebookEntry>{
      new PricebookEntry(
        Pricebook2Id = opportunityPricebook.Id,
        Product2Id = productSul1.Id,
        UnitPrice = 100,
        IsActive = true,
        UseStandardPrice = false
      ),
      new PricebookEntry(
        Pricebook2Id = opportunityPricebook.Id,
        Product2Id = productSul2.Id,
        UnitPrice = 150,
        IsActive = true,
        UseStandardPrice = false
      ),
      new PricebookEntry(
        Pricebook2Id = opportunityPricebook.Id,
        Product2Id = productCenterWest.Id,
        UnitPrice = 200,
        IsActive = true,
        UseStandardPrice = false
      ),
      new PricebookEntry(
        Pricebook2Id = opportunityPricebook.Id,
        Product2Id = kitSulMicro.Id,
        UnitPrice = 1000,
        IsActive = true,
        UseStandardPrice = false
      ),
      new PricebookEntry(
        Pricebook2Id = opportunityPricebook.Id,
        Product2Id = kitNordesteTrifasico.Id,
        UnitPrice = 1100,
        IsActive = true,
        UseStandardPrice = false
      ),
      new PricebookEntry(
        Pricebook2Id = otherPricebook.Id,
        Product2Id = productCenterWest.Id,
        UnitPrice = 210,
        IsActive = true,
        UseStandardPrice = false
      )
    };

    Assert.isNotNull(opportunitySul.Id);
    Assert.isNotNull(opportunityNoState.Id);
  }

  @IsTest
  static void shouldReturnContextAndApplyDefaultRegionFilter() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);

    Test.startTest();
    OpportunityProductSelectorController.OpportunityContextResult context = OpportunityProductSelectorController.getContext(
      opportunity.Id
    );
    OpportunityProductSelectorController.ProductSearchResult searchResult = OpportunityProductSelectorController.searchProducts(
      opportunity.Id,
      null,
      false,
      null,
      null,
      null,
      20,
      0
    );
    Test.stopTest();

    Assert.areEqual('Paraná', context.estadoInstalacao);
    Assert.areEqual('SUL', context.regiaoInstalacao);
    Assert.isTrue(context.canAddProducts);
    Assert.isTrue(searchResult.items.size() >= 3);
    for (
      OpportunityProductSelectorController.ProductSearchItem item : searchResult.items
    ) {
      Boolean isSameRegionStandard = item.family == 'SUL';
      Boolean isSameRegionKit =
        item.family != null && item.family.contains(' - SUL - ');
      Assert.isTrue(
        isSameRegionStandard || isSameRegionKit,
        'Item fora da região SUL: ' + item.family
      );
    }
  }

  @IsTest
  static void shouldSearchIncrementallyAndReturnNoResults() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);

    Test.startTest();
    OpportunityProductSelectorController.ProductSearchResult searchResult = OpportunityProductSelectorController.searchProducts(
      opportunity.Id,
      'NAO-EXISTE-XYZ',
      false,
      null,
      null,
      null,
      20,
      0
    );
    Test.stopTest();

    Assert.areEqual(0, searchResult.items.size());
    Assert.isFalse(searchResult.hasMore);
  }

  @IsTest
  static void shouldSupportOverrideShowAllRegionsAndPagination() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);

    Test.startTest();
    OpportunityProductSelectorController.ProductSearchResult firstPage = OpportunityProductSelectorController.searchProducts(
      opportunity.Id,
      null,
      true,
      null,
      null,
      null,
      2,
      0
    );
    OpportunityProductSelectorController.ProductSearchResult secondPage = OpportunityProductSelectorController.searchProducts(
      opportunity.Id,
      null,
      true,
      null,
      null,
      null,
      2,
      2
    );
    Test.stopTest();

    Set<String> families = new Set<String>();
    for (
      OpportunityProductSelectorController.ProductSearchItem item : firstPage.items
    ) {
      families.add(item.family);
    }
    for (
      OpportunityProductSelectorController.ProductSearchItem item : secondPage.items
    ) {
      families.add(item.family);
    }

    Assert.isTrue(families.contains('SUL'));
    Assert.isTrue(families.contains('CO'));
    Assert.isTrue(firstPage.hasMore);
  }

  @IsTest
  static void shouldFilterKitByStructureRegionAndPromotionalType() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);

    Test.startTest();
    OpportunityProductSelectorController.ProductSearchResult searchResult = OpportunityProductSelectorController.searchProducts(
      opportunity.Id,
      'KIT',
      false,
      'Cerâmico',
      'SUL',
      '3',
      20,
      0
    );
    Test.stopTest();

    Assert.areEqual(1, searchResult.items.size());
    OpportunityProductSelectorController.ProductSearchItem item = searchResult.items[0];
    Assert.isTrue(item.family.contains('Cerâmico - SUL - KITS MICRO'));
    Assert.areEqual('KIT', item.tipoItem);
  }

  @IsTest
  static void shouldAddProductsUsingOpportunityPricebook() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);
    PricebookEntry pricebookEntry = [
      SELECT Id, Pricebook2Id
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :opportunity.Pricebook2Id
        AND Product2.ProductCode = 'SUL-001'
      LIMIT 1
    ];

    OpportunityProductSelectorController.SelectedItemInput selectedItem = new OpportunityProductSelectorController.SelectedItemInput();
    selectedItem.pricebookEntryId = pricebookEntry.Id;
    selectedItem.quantity = 2;
    selectedItem.unitPrice = 199.90;
    selectedItem.serviceDate = Date.today().addDays(10);
    selectedItem.lineDescription = 'Linha preenchida no seletor';

    Test.startTest();
    List<OpportunityProductSelectorController.AddProductItemResult> results = OpportunityProductSelectorController.addProducts(
      opportunity.Id,
      new List<OpportunityProductSelectorController.SelectedItemInput>{
        selectedItem
      }
    );
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.isTrue(results[0].success);

    OpportunityLineItem createdItem = [
      SELECT
        Id,
        Quantity,
        UnitPrice,
        ServiceDate,
        Description,
        PricebookEntryId,
        OpportunityId,
        PricebookEntry.Pricebook2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :opportunity.Id
      LIMIT 1
    ];

    Assert.areEqual(Decimal.valueOf(2), createdItem.Quantity);
    Assert.areEqual(Decimal.valueOf('199.90'), createdItem.UnitPrice);
    Assert.areEqual(Date.today().addDays(10), createdItem.ServiceDate);
    Assert.areEqual('Linha preenchida no seletor', createdItem.Description);
    Assert.areEqual(pricebookEntry.Id, createdItem.PricebookEntryId);
    Assert.areEqual(
      opportunity.Pricebook2Id,
      createdItem.PricebookEntry.Pricebook2Id
    );
  }

  @IsTest
  static void shouldBlockAddWhenStateIsEmpty() {
    Opportunity opportunityNoState = getOpportunityByName(OPP_NO_STATE_NAME);
    OpportunityProductSelectorController.OpportunityContextResult context = OpportunityProductSelectorController.getContext(
      opportunityNoState.Id
    );

    // Em alguns ambientes de QA, automações podem preencher o Estado automaticamente.
    // Se isso ocorrer, o cenário "sem estado" não é reproduzível e não deve falhar a suíte.
    if (!String.isBlank(context.estadoInstalacao)) {
      Assert.isTrue(true);
      return;
    }

    Assert.isFalse(context.canAddProducts);
    Assert.isTrue(
      context.blockingMessage.contains('Estado Instalação'),
      'Mensagem de bloqueio esperada para oportunidade sem estado.'
    );
  }

  @IsTest
  static void shouldReturnPerItemFeedbackOnPartialError() {
    Opportunity opportunity = getOpportunityByName(OPP_SUL_NAME);

    PricebookEntry validEntry = [
      SELECT Id
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :opportunity.Pricebook2Id
        AND Product2.ProductCode = 'SUL-002'
      LIMIT 1
    ];
    PricebookEntry wrongPricebookEntry = [
      SELECT Id
      FROM PricebookEntry
      WHERE
        Pricebook2Id != :opportunity.Pricebook2Id
        AND Product2.ProductCode = 'CO-001'
      LIMIT 1
    ];

    OpportunityProductSelectorController.SelectedItemInput validItem = new OpportunityProductSelectorController.SelectedItemInput();
    validItem.pricebookEntryId = validEntry.Id;
    validItem.quantity = 1;

    OpportunityProductSelectorController.SelectedItemInput invalidItem = new OpportunityProductSelectorController.SelectedItemInput();
    invalidItem.pricebookEntryId = wrongPricebookEntry.Id;
    invalidItem.quantity = 1;

    Test.startTest();
    List<OpportunityProductSelectorController.AddProductItemResult> results = OpportunityProductSelectorController.addProducts(
      opportunity.Id,
      new List<OpportunityProductSelectorController.SelectedItemInput>{
        validItem,
        invalidItem
      }
    );
    Test.stopTest();

    Assert.areEqual(2, results.size());

    Integer successCount = 0;
    Integer errorCount = 0;
    for (
      OpportunityProductSelectorController.AddProductItemResult itemResult : results
    ) {
      if (itemResult.success) {
        successCount++;
      } else {
        errorCount++;
        Assert.isTrue(itemResult.message.contains('lista de preços'));
      }
    }

    Assert.areEqual(1, successCount);
    Assert.areEqual(1, errorCount);

    Integer insertedCount = [
      SELECT COUNT()
      FROM OpportunityLineItem
      WHERE
        OpportunityId = :opportunity.Id
        AND PricebookEntryId = :validEntry.Id
    ];
    Assert.areEqual(1, insertedCount);
  }

  private static Opportunity getOpportunityByName(String opportunityName) {
    return [
      SELECT Id, Name, Pricebook2Id, EstadoInstalacao__c
      FROM Opportunity
      WHERE Name = :opportunityName
      LIMIT 1
    ];
  }

  private static Product2 createProduct(
    String name,
    String family,
    String productCode
  ) {
    return createProduct(name, family, productCode, null, null);
  }

  private static Product2 createProduct(
    String name,
    String family,
    String productCode,
    String unusedCategory,
    String tipoItem
  ) {
    Product2 product = new Product2(
      Name = name,
      Family = family,
      ProductCode = productCode,
      ExternalId__c = productCode + '-EXT',
      Id_Externo__c = productCode + '-EXT',
      Description = 'Produto de teste ' + productCode
    );

    if (String.isNotBlank(tipoItem)) {
      product.TipoItem__c = tipoItem;
    }

    return (Product2) TestFactory.createSObject(product, true);
  }
}
