public with sharing class OpportunityProductSelectorController {
  private static final Integer DEFAULT_PAGE_SIZE = 20;
  private static final Integer MAX_PAGE_SIZE = 100;
  private static final Integer MAX_OFFSET = 2000;
  private static final String KIT_ITEM_TYPE = 'KIT';
  private static final String KIT_NAME_LIKE = 'KIT%';

  public class OpportunityContextResult {
    @AuraEnabled
    public Id opportunityId;
    @AuraEnabled
    public Id pricebook2Id;
    @AuraEnabled
    public String estadoInstalacao;
    @AuraEnabled
    public String regiaoInstalacao;
    @AuraEnabled
    public String tipoTelhadoEstrutura;
    @AuraEnabled
    public String tipoKitPromocional;
    @AuraEnabled
    public Boolean canAddProducts;
    @AuraEnabled
    public String blockingMessage;
  }

  public class ProductSearchResult {
    @AuraEnabled
    public List<ProductSearchItem> items;
    @AuraEnabled
    public Boolean hasMore;
    @AuraEnabled
    public Integer nextOffset;
    @AuraEnabled
    public Integer pageSize;
  }

  public class ProductSearchItem {
    @AuraEnabled
    public Id pricebookEntryId;
    @AuraEnabled
    public Id product2Id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String productCode;
    @AuraEnabled
    public String externalId;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String family;
    @AuraEnabled
    public String tipoItem;
    @AuraEnabled
    public Decimal unitPrice;
  }

  public class SelectedItemInput {
    @AuraEnabled
    public Id pricebookEntryId;
    @AuraEnabled
    public Decimal quantity;
    @AuraEnabled
    public Decimal unitPrice;
    @AuraEnabled
    public Date serviceDate;
    @AuraEnabled
    public String lineDescription;
  }

  public class AddProductItemResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id pricebookEntryId;
    @AuraEnabled
    public Id opportunityLineItemId;
    @AuraEnabled
    public String productName;
    @AuraEnabled
    public String productCode;
  }

  @AuraEnabled(cacheable=true)
  public static OpportunityContextResult getContext(Id opportunityId) {
    Opportunity opportunity = loadOpportunity(opportunityId);
    return buildContextResult(opportunity);
  }

  @AuraEnabled(cacheable=true)
  public static ProductSearchResult searchProducts(
    Id opportunityId,
    String searchText,
    Boolean showAllRegions,
    String structureTypeFilter,
    String regionFilter,
    String kitPromotionalFilter,
    Integer pageSize,
    Integer offset
  ) {
    Opportunity opportunity = loadOpportunity(opportunityId);
    OpportunityContextResult context = buildContextResult(opportunity);

    ProductSearchResult response = new ProductSearchResult();
    response.items = new List<ProductSearchItem>();
    Integer safePageSize = sanitizePageSize(pageSize);
    Integer safeOffset = sanitizeOffset(offset);
    response.pageSize = safePageSize;
    response.nextOffset = safeOffset;
    response.hasMore = false;

    if (context.pricebook2Id == null || !context.canAddProducts) {
      return response;
    }

    validatePricebookEntryAndProductReadAccess();

    String searchLike = buildSearchLike(searchText);
    Boolean applyRegionFilter = showAllRegions != true;
    String region = normalizeOptionalString(regionFilter);
    if (String.isBlank(region)) {
      region = context.regiaoInstalacao;
    }
    String normalizedStructureFilter = normalizeOptionalString(
      structureTypeFilter
    );
    String normalizedKitPromotionalFilter = normalizeOptionalString(
      kitPromotionalFilter
    );

    if (applyRegionFilter && String.isBlank(region)) {
      return response;
    }

    Integer queryLimit = safePageSize + 1;
    List<PricebookEntry> entries = queryPricebookEntries(
      context.pricebook2Id,
      region,
      applyRegionFilter,
      searchLike,
      normalizedStructureFilter,
      normalizedKitPromotionalFilter,
      queryLimit,
      safeOffset
    );

    if (entries.size() > safePageSize) {
      response.hasMore = true;
      response.nextOffset = safeOffset + safePageSize;
      entries.remove(entries.size() - 1);
    }

    for (PricebookEntry entry : entries) {
      ProductSearchItem item = new ProductSearchItem();
      item.pricebookEntryId = entry.Id;
      item.product2Id = entry.Product2Id;
      item.name = entry.Product2.Name;
      item.productCode = entry.Product2.ProductCode;
      item.externalId = entry.Product2.ExternalId__c;
      item.description = entry.Product2.Description;
      item.family = entry.Product2.Family;
      item.tipoItem = entry.Product2.TipoItem__c;
      item.unitPrice = entry.UnitPrice;
      response.items.add(item);
    }

    return response;
  }

  @AuraEnabled
  public static List<AddProductItemResult> addProducts(
    Id opportunityId,
    List<SelectedItemInput> selectedItems
  ) {
    Opportunity opportunity = loadOpportunity(opportunityId);
    OpportunityContextResult context = buildContextResult(opportunity);

    if (String.isBlank(context.estadoInstalacao)) {
      throw new AuraHandledException(
        'Preencha o campo Estado Instalação na oportunidade antes de adicionar produtos.'
      );
    }

    if (context.pricebook2Id == null) {
      throw new AuraHandledException(
        'A oportunidade não possui uma lista de preços associada.'
      );
    }

    if (selectedItems == null || selectedItems.isEmpty()) {
      throw new AuraHandledException(
        'Selecione ao menos um produto para adicionar.'
      );
    }

    List<SelectedItemInput> sanitizedItems = new List<SelectedItemInput>();
    for (SelectedItemInput selectedItem : selectedItems) {
      if (selectedItem != null && selectedItem.pricebookEntryId != null) {
        sanitizedItems.add(selectedItem);
      }
    }

    if (sanitizedItems.isEmpty()) {
      throw new AuraHandledException(
        'Selecione ao menos um produto para adicionar.'
      );
    }

    validatePricebookEntryAndProductReadAccess();
    validateOpportunityLineItemCreateAccess();

    Set<Id> pricebookEntryIds = new Set<Id>();
    for (SelectedItemInput selectedItem : sanitizedItems) {
      pricebookEntryIds.add(selectedItem.pricebookEntryId);
    }

    Map<Id, PricebookEntry> pricebookEntryById = new Map<Id, PricebookEntry>();
    if (!pricebookEntryIds.isEmpty()) {
      pricebookEntryById = new Map<Id, PricebookEntry>(
        [
          SELECT Id, UnitPrice, Product2.Name, Product2.ProductCode
          FROM PricebookEntry
          WHERE
            Id IN :pricebookEntryIds
            AND Pricebook2Id = :context.pricebook2Id
            AND IsActive = TRUE
            AND Product2.IsActive = TRUE
        ]
      );
    }

    List<AddProductItemResult> itemResults = new List<AddProductItemResult>();
    List<OpportunityLineItem> itemsToInsert = new List<OpportunityLineItem>();
    List<Integer> resultIndexesToInsert = new List<Integer>();

    for (SelectedItemInput selectedItem : sanitizedItems) {
      AddProductItemResult itemResult = new AddProductItemResult();
      itemResult.success = false;
      itemResult.message = 'Item inválido.';

      itemResult.pricebookEntryId = selectedItem.pricebookEntryId;
      PricebookEntry entry = pricebookEntryById.get(
        selectedItem.pricebookEntryId
      );

      if (entry == null) {
        itemResult.message = 'Produto indisponível para a lista de preços da oportunidade.';
        itemResults.add(itemResult);
        continue;
      }

      itemResult.productName = entry.Product2.Name;
      itemResult.productCode = entry.Product2.ProductCode;

      Decimal quantity = selectedItem.quantity;
      if (quantity == null || quantity <= 0) {
        itemResult.message =
          'Quantidade inválida para o produto ' +
          entry.Product2.Name +
          '.';
        itemResults.add(itemResult);
        continue;
      }

      Decimal unitPrice = selectedItem.unitPrice;
      if (unitPrice == null) {
        unitPrice = entry.UnitPrice;
      }

      if (unitPrice == null || unitPrice <= 0) {
        itemResult.message =
          'Preço de venda inválido para o produto ' +
          entry.Product2.Name +
          '.';
        itemResults.add(itemResult);
        continue;
      }

      OpportunityLineItem opportunityLineItem = new OpportunityLineItem(
        OpportunityId = opportunity.Id,
        PricebookEntryId = entry.Id,
        Quantity = quantity,
        UnitPrice = unitPrice
      );

      if (selectedItem.serviceDate != null) {
        opportunityLineItem.ServiceDate = selectedItem.serviceDate;
      }

      if (String.isNotBlank(selectedItem.lineDescription)) {
        opportunityLineItem.Description = selectedItem.lineDescription.trim();
      }

      itemsToInsert.add(opportunityLineItem);
      itemResults.add(itemResult);
      resultIndexesToInsert.add(itemResults.size() - 1);
    }

    if (!itemsToInsert.isEmpty()) {
      Database.SaveResult[] saveResults = Database.insert(itemsToInsert, false);
      for (Integer index = 0; index < saveResults.size(); index++) {
        Database.SaveResult saveResult = saveResults[index];
        Integer resultIndex = resultIndexesToInsert[index];
        AddProductItemResult itemResult = itemResults[resultIndex];

        if (saveResult.isSuccess()) {
          itemResult.success = true;
          itemResult.opportunityLineItemId = saveResult.getId();
          itemResult.message = 'Produto adicionado com sucesso.';
        } else {
          itemResult.success = false;
          itemResult.message =
            'Falha ao adicionar produto: ' +
            firstErrorMessage(saveResult.getErrors());
        }
      }
    }

    return itemResults;
  }

  private static Opportunity loadOpportunity(Id opportunityId) {
    if (opportunityId == null) {
      throw new AuraHandledException('Informe uma oportunidade válida.');
    }

    validateOpportunityReadAccess();

    List<Opportunity> opportunities = [
      SELECT
        Id,
        Pricebook2Id,
        EstadoInstalacao__c,
        RegiaoInstalacao__c,
        TipoTelhadoEstrutura__c,
        TipoKitPromocional__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    if (opportunities.isEmpty()) {
      throw new AuraHandledException('Oportunidade não encontrada.');
    }

    return opportunities[0];
  }

  private static OpportunityContextResult buildContextResult(
    Opportunity opportunity
  ) {
    OpportunityContextResult context = new OpportunityContextResult();
    context.opportunityId = opportunity.Id;
    context.pricebook2Id = opportunity.Pricebook2Id;
    context.estadoInstalacao = opportunity.EstadoInstalacao__c;
    context.regiaoInstalacao = opportunity.RegiaoInstalacao__c;
    context.tipoTelhadoEstrutura = opportunity.TipoTelhadoEstrutura__c;
    context.tipoKitPromocional = opportunity.TipoKitPromocional__c;
    context.canAddProducts = true;

    if (String.isBlank(opportunity.EstadoInstalacao__c)) {
      context.canAddProducts = false;
      context.blockingMessage = 'Preencha o campo Estado Instalação na oportunidade para habilitar a inclusão de produtos.';
      return context;
    }

    if (String.isBlank(opportunity.RegiaoInstalacao__c)) {
      context.canAddProducts = false;
      context.blockingMessage = 'Não foi possível determinar a região da instalação para o estado informado.';
      return context;
    }

    if (opportunity.Pricebook2Id == null) {
      context.canAddProducts = false;
      context.blockingMessage = 'Associe uma lista de preços à oportunidade antes de incluir produtos.';
      return context;
    }

    return context;
  }

  private static List<PricebookEntry> queryPricebookEntries(
    Id pricebook2Id,
    String region,
    Boolean applyRegionFilter,
    String searchLike,
    String structureTypeFilter,
    String kitPromotionalFilter,
    Integer queryLimit,
    Integer safeOffset
  ) {
    String kitRegionLike = null;
    if (applyRegionFilter && !String.isBlank(region)) {
      kitRegionLike = '% - ' + region + ' - %';
    }

    Boolean hasStructureTypeFilter = !String.isBlank(structureTypeFilter);
    Boolean hasKitPromotionalFilter = !String.isBlank(kitPromotionalFilter);
    Boolean enforceKitOnly = hasStructureTypeFilter || hasKitPromotionalFilter;
    String kitItemType = KIT_ITEM_TYPE;
    String kitNameLike = KIT_NAME_LIKE;

    String structureFamilyLike = null;
    if (hasStructureTypeFilter) {
      structureFamilyLike = structureTypeFilter + ' - %';
    }
    String kitPromotionalLabel = hasKitPromotionalFilter
      ? getKitPromotionalLabel(kitPromotionalFilter)
      : null;
    String kitPromotionalFamilyLike = null;
    if (hasKitPromotionalFilter && !String.isBlank(kitPromotionalLabel)) {
      kitPromotionalFamilyLike = '% - % - ' + kitPromotionalLabel;
    }

    String soql =
      'SELECT Id, UnitPrice, Product2Id, Product2.Name, Product2.ProductCode, Product2.ExternalId__c, ' +
      'Product2.Description, Product2.Family, Product2.TipoItem__c ' +
      'FROM PricebookEntry ' +
      'WHERE Pricebook2Id = :pricebook2Id ' +
      'AND IsActive = true ' +
      'AND Product2.IsActive = true';

    if (applyRegionFilter) {
      soql += ' AND (Product2.Family = :region OR Product2.Family LIKE :kitRegionLike)';
    }

    if (!String.isBlank(searchLike)) {
      soql +=
        ' AND (' +
        'Product2.Name LIKE :searchLike ' +
        'OR Product2.ProductCode LIKE :searchLike ' +
        'OR Product2.ExternalId__c LIKE :searchLike ' +
        'OR Product2.Description LIKE :searchLike' +
        ')';
    }

    if (hasStructureTypeFilter) {
      soql += ' AND Product2.Family LIKE :structureFamilyLike';
    }

    if (hasKitPromotionalFilter) {
      if (String.isBlank(kitPromotionalFamilyLike)) {
        return new List<PricebookEntry>();
      }
      soql += ' AND Product2.Family LIKE :kitPromotionalFamilyLike';
    }

    if (enforceKitOnly) {
      soql += ' AND (Product2.TipoItem__c = :kitItemType OR Product2.Name LIKE :kitNameLike)';
    }

    soql += ' ORDER BY Product2.Name LIMIT :queryLimit OFFSET :safeOffset';

    return Database.query(soql);
  }

  private static Integer sanitizePageSize(Integer pageSize) {
    if (pageSize == null || pageSize <= 0) {
      return DEFAULT_PAGE_SIZE;
    }
    return Math.min(pageSize, MAX_PAGE_SIZE);
  }

  private static Integer sanitizeOffset(Integer offsetValue) {
    if (offsetValue == null || offsetValue < 0) {
      return 0;
    }
    return Math.min(offsetValue, MAX_OFFSET);
  }

  private static String buildSearchLike(String searchText) {
    if (String.isBlank(searchText)) {
      return null;
    }

    String trimmed = searchText.trim();
    if (trimmed == '') {
      return null;
    }

    return '%' + trimmed + '%';
  }

  private static String normalizeOptionalString(String inputValue) {
    if (String.isBlank(inputValue)) {
      return null;
    }
    String trimmedValue = inputValue.trim();
    return trimmedValue == '' ? null : trimmedValue;
  }

  private static String getKitPromotionalLabel(String kitPromotionalValue) {
    if (String.isBlank(kitPromotionalValue)) {
      return null;
    }

    Map<String, String> valueToLabel = new Map<String, String>{
      '1' => 'KITS MONOFÁSICOS',
      '2' => 'KITS TRIFÁSICOS',
      '3' => 'KITS MICRO',
      '4' => 'CAMPANHA WEG - FAST TRACK',
      '5' => 'KITS TRIFÁSICOS PROMO WEG',
      '6' => 'KIT SOLAR + BESS',
      '7' => 'KITS MONOFÁSICOS SEM WEGHOME',
      '8' => 'KITS MICRO SEM WEGHOME'
    };

    String label = valueToLabel.get(kitPromotionalValue);
    return String.isBlank(label) ? null : label;
  }

  private static void validateOpportunityReadAccess() {
    if (!Opportunity.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('Sem permissão para acessar Opportunity.');
    }

    ensureReadableField(Opportunity.Pricebook2Id.getDescribe(), 'Pricebook2Id');
    ensureReadableField(
      Opportunity.EstadoInstalacao__c.getDescribe(),
      'EstadoInstalacao__c'
    );
    ensureReadableField(
      Opportunity.RegiaoInstalacao__c.getDescribe(),
      'RegiaoInstalacao__c'
    );
    ensureReadableField(
      Opportunity.TipoTelhadoEstrutura__c.getDescribe(),
      'TipoTelhadoEstrutura__c'
    );
    ensureReadableField(
      Opportunity.TipoKitPromocional__c.getDescribe(),
      'TipoKitPromocional__c'
    );
  }

  private static void validatePricebookEntryAndProductReadAccess() {
    if (!PricebookEntry.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(
        'Sem permissão para acessar PricebookEntry.'
      );
    }
    if (!Product2.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('Sem permissão para acessar Product2.');
    }

    ensureReadableField(PricebookEntry.Id.getDescribe(), 'PricebookEntry.Id');
    ensureReadableField(
      PricebookEntry.Pricebook2Id.getDescribe(),
      'PricebookEntry.Pricebook2Id'
    );
    ensureReadableField(
      PricebookEntry.Product2Id.getDescribe(),
      'PricebookEntry.Product2Id'
    );
    ensureReadableField(
      PricebookEntry.UnitPrice.getDescribe(),
      'PricebookEntry.UnitPrice'
    );
    ensureReadableField(
      PricebookEntry.IsActive.getDescribe(),
      'PricebookEntry.IsActive'
    );

    ensureReadableField(Product2.Name.getDescribe(), 'Product2.Name');
    ensureReadableField(
      Product2.ProductCode.getDescribe(),
      'Product2.ProductCode'
    );
    ensureReadableField(
      Product2.ExternalId__c.getDescribe(),
      'Product2.ExternalId__c'
    );
    ensureReadableField(
      Product2.Description.getDescribe(),
      'Product2.Description'
    );
    ensureReadableField(Product2.Family.getDescribe(), 'Product2.Family');
    ensureReadableField(
      Product2.TipoItem__c.getDescribe(),
      'Product2.TipoItem__c'
    );
    ensureReadableField(Product2.IsActive.getDescribe(), 'Product2.IsActive');
  }

  private static void validateOpportunityLineItemCreateAccess() {
    if (!OpportunityLineItem.SObjectType.getDescribe().isCreateable()) {
      throw new AuraHandledException(
        'Sem permissão para incluir produtos na oportunidade.'
      );
    }

    ensureCreateableField(
      OpportunityLineItem.OpportunityId.getDescribe(),
      'OpportunityLineItem.OpportunityId'
    );
    ensureCreateableField(
      OpportunityLineItem.PricebookEntryId.getDescribe(),
      'OpportunityLineItem.PricebookEntryId'
    );
    ensureCreateableField(
      OpportunityLineItem.Quantity.getDescribe(),
      'OpportunityLineItem.Quantity'
    );
    ensureCreateableField(
      OpportunityLineItem.UnitPrice.getDescribe(),
      'OpportunityLineItem.UnitPrice'
    );
    ensureCreateableField(
      OpportunityLineItem.ServiceDate.getDescribe(),
      'OpportunityLineItem.ServiceDate'
    );
    ensureCreateableField(
      OpportunityLineItem.Description.getDescribe(),
      'OpportunityLineItem.Description'
    );
  }

  private static void ensureReadableField(
    Schema.DescribeFieldResult fieldDescribe,
    String fieldName
  ) {
    if (fieldDescribe == null || !fieldDescribe.isAccessible()) {
      throw new AuraHandledException(
        'Sem permissão de leitura para ' + fieldName + '.'
      );
    }
  }

  private static void ensureCreateableField(
    Schema.DescribeFieldResult fieldDescribe,
    String fieldName
  ) {
    if (fieldDescribe == null || !fieldDescribe.isCreateable()) {
      throw new AuraHandledException(
        'Sem permissão de escrita para ' + fieldName + '.'
      );
    }
  }

  private static String firstErrorMessage(Database.Error[] errors) {
    if (errors == null || errors.isEmpty()) {
      return 'Erro desconhecido.';
    }

    String message = errors[0].getMessage();
    return String.isBlank(message) ? 'Erro desconhecido.' : message;
  }
}
