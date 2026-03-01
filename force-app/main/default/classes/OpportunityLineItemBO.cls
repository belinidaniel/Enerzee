/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 08-21-2025
 * @last modified by	 : Daniel Belini
 **/
public without sharing class OpportunityLineItemBO {
  public static void forceKitUpdateOnItemInsertUpdate(
    List<OpportunityLineItem> newRecordsList
  ) {
    System.debug('forceKitUpdateOnItemInsertUpdate');
    if (newRecordsList == null || newRecordsList.isEmpty()) {
      return;
    }
    List<Kit_Instalacao__c> kitsToUpdate = [
      SELECT Id, ValorKit__c, Nome_da_Oportunidade__c
      FROM Kit_Instalacao__c
      WHERE
        Id IN :Collection.of(newRecordsList)
          .pluckNotNullStrings(OpportunityLineItem.Kit_Instalacao__c)
    ];
    Set<Id> kits = new Set<Id>();
    for (Kit_Instalacao__c kit : kitsToUpdate) {
      kits.add(kit.Id);
    }
    KitInstalacaoBO.calculateValueKit(kitsToUpdate);
    syncOpportunityTechnicalQuantitiesByKitSelection(newRecordsList);
    KitInstalacaoBO.SendKitUpdate(kits);
  }

  public static void forceKitUpdateOnItemInsertUpdate2(
    List<OpportunityLineItem> newRecordsList
  ) {
    Set<Id> kitIds = new Set<Id>();
    Decimal valor;
    List<Kit_Instalacao__c> kitInstalacao = new List<Kit_Instalacao__c>();

    for (OpportunityLineItem item : newRecordsList) {
      valor = 0;
      valor = item.TotalPrice;
      Kit_Instalacao__c kit = new Kit_Instalacao__c();
      kit.Id = item.Kit_Instalacao__c;

      if (kit.ValorKit__c != null) {
        kit.ValorKit__c = kit.ValorKit__c + valor;
      } else {
        kit.ValorKit__c = valor;
      }

      kitInstalacao.add(kit);

      kitIds.add(item.Kit_Instalacao__c);
    }

    List<Kit_Instalacao__c> kitsToUpdate = [
      SELECT Id
      FROM Kit_Instalacao__c
      WHERE Id IN :kitIds
    ];

    update kitInstalacao;
  }

  public static void GenerateOppLineItemKit(
    List<OpportunityLineItem> newRecordsList
  ) {
    //adiciona as opp line itens aos kits referentes a opp
    Set<Id> oppId = new Set<Id>();
    Map<Id, Id> mapKit = new Map<Id, Id>();
    List<OpportunityLineItem> opplineitemToUpd = new List<OpportunityLineItem>();

    for (OpportunityLineItem opline : newRecordsList) {
      oppId.add(opline.OpportunityId);
    }

    for (Kit_Instalacao__c kit : [
      SELECT Id, ValorKit__c, Nome_da_Oportunidade__c
      FROM Kit_Instalacao__c
      WHERE Nome_da_Oportunidade__c IN :oppId
    ]) {
      mapKit.put(kit.Nome_da_Oportunidade__c, kit.Id);
    }
    if (mapKit.isEmpty()) {
      Id singleOppId = oppId.isEmpty() ? null : oppId.iterator().next();
      Kit_Instalacao__c newKit = new Kit_Instalacao__c(
        Nome_da_Oportunidade__c = singleOppId
      );
      insert newKit;
      mapKit.put(singleOppId, newKit.Id);
    }
    for (OpportunityLineItem opline : newRecordsList) {
      opline.Kit_Instalacao__c = mapKit.get(opline.OpportunityId);
    }
  }

  public static Boolean shouldAllowOperation(
    OpportunityLineItem opportunityLineItem,
    Opportunity opportunity
  ) {
    // Obtém a oportunidade associada ao OpportunityLineItem
    //Opportunity opportunity = [SELECT StageName, RecordType.Name FROM Opportunity WHERE Id = :opportunityLineItem.OpportunityId];

    if (
      (opportunity.StageName == 'Método de pagamento' ||
      opportunity.StageName == 'Validação do método de pagamento' ||
      opportunity.StageName == 'Geração de contrato' ||
      opportunity.StageName == 'Contrato enviado' ||
      opportunity.StageName == 'Contrato firmado / Assinado' ||
      opportunity.StageName == 'Encerrado') &&
      opportunity.RecordType.Name == 'Contrato Micro'
    ) {
      return false; // Bloqueie a inserção, atualização e exclusão
    }

    return true; // Não há bloqueio
  }

  @TestVisible
  private static void syncOpportunityTechnicalQuantitiesByKitSelection(
    List<OpportunityLineItem> changedItems
  ) {
    if (changedItems == null || changedItems.isEmpty()) {
      return;
    }

    Set<Id> opportunityIds = new Set<Id>();
    for (OpportunityLineItem item : changedItems) {
      if (item != null && item.OpportunityId != null) {
        opportunityIds.add(item.OpportunityId);
      }
    }

    if (opportunityIds.isEmpty()) {
      return;
    }

    Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>(
      [
        SELECT
          Id,
          NumeroModulos__c,
          NumeroInversores__c,
          GeracaoAnualEstimada__c,
          GeracaoMensalEstimada__c,
          GeracaoMedioMensal__c,
          PotenciaPicoSistema__c,
          PotenciaNominalWp__c
        FROM Opportunity
        WHERE Id IN :opportunityIds
      ]
    );

    Map<Id, Decimal> kitQuantityByOpportunityId = new Map<Id, Decimal>();
    for (OpportunityLineItem item : [
      SELECT OpportunityId, Quantity, Product2.Name, Product2.Family
      FROM OpportunityLineItem
      WHERE OpportunityId IN :opportunityIds
    ]) {
      if (!isKitProductLine(item)) {
        continue;
      }

      Decimal quantity = item.Quantity != null ? item.Quantity : 0;
      Decimal current = kitQuantityByOpportunityId.containsKey(
          item.OpportunityId
        )
        ? kitQuantityByOpportunityId.get(item.OpportunityId)
        : 0;
      kitQuantityByOpportunityId.put(item.OpportunityId, current + quantity);
    }

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (Id opportunityId : kitQuantityByOpportunityId.keySet()) {
      Opportunity source = opportunityById.get(opportunityId);
      Decimal selectedKitQuantity = kitQuantityByOpportunityId.get(
        opportunityId
      );
      if (
        source == null ||
        selectedKitQuantity == null ||
        selectedKitQuantity <= 0
      ) {
        continue;
      }

      Integer targetInverters = Integer.valueOf(
        selectedKitQuantity.setScale(0, System.RoundingMode.HALF_UP)
      );
      if (targetInverters <= 0) {
        continue;
      }

      Decimal targetModules = calculateTargetModuleQuantity(
        source,
        selectedKitQuantity
      );
      Opportunity updateOpp = new Opportunity(Id = opportunityId);
      Boolean hasChanges = false;

      if (
        source.NumeroInversores__c == null ||
        source.NumeroInversores__c.intValue() != targetInverters
      ) {
        updateOpp.NumeroInversores__c = targetInverters;
        hasChanges = true;
      }

      Decimal generationMultiplier = null;
      if (
        source.NumeroInversores__c != null &&
        source.NumeroInversores__c > 0 &&
        source.NumeroInversores__c.intValue() != targetInverters
      ) {
        generationMultiplier =
          Decimal.valueOf(targetInverters) / source.NumeroInversores__c;
      }

      if (targetModules != null) {
        Decimal roundedModules = targetModules.setScale(
          0,
          System.RoundingMode.HALF_UP
        );
        if (
          source.NumeroModulos__c == null ||
          source.NumeroModulos__c != roundedModules
        ) {
          updateOpp.NumeroModulos__c = roundedModules;
          hasChanges = true;
        }
      }

      if (generationMultiplier != null && generationMultiplier > 0) {
        if (source.GeracaoAnualEstimada__c != null) {
          updateOpp.GeracaoAnualEstimada__c = (source.GeracaoAnualEstimada__c *
            generationMultiplier)
            .setScale(2, System.RoundingMode.HALF_UP);
          hasChanges = true;
        }
        if (source.GeracaoMensalEstimada__c != null) {
          updateOpp.GeracaoMensalEstimada__c = (source.GeracaoMensalEstimada__c *
            generationMultiplier)
            .setScale(2, System.RoundingMode.HALF_UP);
          hasChanges = true;
        }
        if (source.GeracaoMedioMensal__c != null) {
          updateOpp.GeracaoMedioMensal__c = (source.GeracaoMedioMensal__c *
            generationMultiplier)
            .setScale(2, System.RoundingMode.HALF_UP);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        opportunitiesToUpdate.add(updateOpp);
      }
    }

    if (!opportunitiesToUpdate.isEmpty()) {
      OpportunityTriggerHandler.disableTrigger();
      try {
        update opportunitiesToUpdate;
      } finally {
        OpportunityTriggerHandler.enableTrigger();
      }
    }
  }

  private static Decimal calculateTargetModuleQuantity(
    Opportunity opp,
    Decimal selectedKitQuantity
  ) {
    if (
      opp == null ||
      selectedKitQuantity == null ||
      selectedKitQuantity <= 0
    ) {
      return null;
    }

    if (
      opp.NumeroModulos__c != null &&
      opp.NumeroModulos__c > 0 &&
      opp.NumeroInversores__c != null &&
      opp.NumeroInversores__c > 0
    ) {
      Decimal modulesPerKit = opp.NumeroModulos__c / opp.NumeroInversores__c;
      if (modulesPerKit > 0) {
        return modulesPerKit * selectedKitQuantity;
      }
    }

    if (
      opp.PotenciaPicoSistema__c != null &&
      opp.PotenciaPicoSistema__c > 0 &&
      opp.PotenciaNominalWp__c != null &&
      opp.PotenciaNominalWp__c > 0
    ) {
      Decimal modulesPerKitByPower =
        (opp.PotenciaPicoSistema__c * 1000) / opp.PotenciaNominalWp__c;
      if (modulesPerKitByPower > 0) {
        return modulesPerKitByPower * selectedKitQuantity;
      }
    }

    if (opp.NumeroModulos__c != null && opp.NumeroModulos__c > 0) {
      return opp.NumeroModulos__c * selectedKitQuantity;
    }

    return null;
  }

  private static Boolean isKitProductLine(OpportunityLineItem item) {
    if (item == null || item.Product2 == null) {
      return false;
    }

    String productName = item.Product2.Name != null
      ? item.Product2.Name.toLowerCase()
      : '';
    String productFamily = item.Product2.Family != null
      ? item.Product2.Family.toLowerCase()
      : '';

    return productName.contains('kit gerador fotovoltaico') ||
      productName.startsWith('kit ') ||
      productFamily == 'sistfotovoltaicos';
  }
}
