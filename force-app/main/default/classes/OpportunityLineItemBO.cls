/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : OpportunityLineItemTriggerTest
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
