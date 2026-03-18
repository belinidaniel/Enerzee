/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPTest
 **/
public with sharing class IntegracaoSAPKit implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPKit(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Kit_Instalacao__c> kitList = [
      SELECT Id, Name, SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
      FROM Kit_Instalacao__c
      WHERE Id IN :recordIds
    ];

    Map<Id, List<OpportunityLineItem>> kitIdToLineList = new Map<Id, List<OpportunityLineItem>>();
    for (OpportunityLineItem line : [
      SELECT Id, ProductCode, Kit_Instalacao__c, Quantity, UnitPrice
      FROM OpportunityLineItem
      WHERE Kit_Instalacao__c IN :recordIds
    ]) {
      if (!kitIdToLineList.containsKey(line.Kit_Instalacao__c)) {
        kitIdToLineList.put(
          line.Kit_Instalacao__c,
          new List<OpportunityLineItem>()
        );
      }
      kitIdToLineList.get(line.Kit_Instalacao__c).add(line);
    }

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'KitSAP'
    );

    for (Kit_Instalacao__c kit : kitList) {
      KitRequest corpoRequisicao = new KitRequest();
      corpoRequisicao.TreeCode = kit.Name;
      corpoRequisicao.TreeType = 'iProductionTree';
      corpoRequisicao.Quantity = 1;
      corpoRequisicao.PriceList = null;
      corpoRequisicao.Warehouse = null;
      corpoRequisicao.PlanAvgProdSize = null;
      corpoRequisicao.ProductTreeLines = new List<ProductTreeLine>{};

      List<OpportunityLineItem> lines = kitIdToLineList.get(kit.Id);
      if (lines != null) {
        Integer lineIndex = 1;
        for (OpportunityLineItem line : lines) {
          ProductTreeLine productTreeLine = new ProductTreeLine();
          productTreeLine.ItemCode = line.ProductCode;
          productTreeLine.Quantity = line.Quantity;
          productTreeLine.Warehouse = null;
          productTreeLine.Price = line.UnitPrice;
          productTreeLine.CurrencySAP = 'R$';
          productTreeLine.ParentItem = corpoRequisicao.TreeCode;
          productTreeLine.PriceList = null;
          productTreeLine.AdditionalQuantity = null;
          productTreeLine.ChildNum = lineIndex;
          corpoRequisicao.ProductTreeLines.add(productTreeLine);
          lineIndex++;
        }
      }

      try {
        HttpResponse response = SAPIntegrationService.post(
          JSON.serialize(corpoRequisicao).replace('CurrencySAP', 'Currency'),
          sapConfig,
          null
        );
        Utils.createLog('IntegracaoSAPKit', 'sendKit ' + kit.Id, response);

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));
          kit.SucessoIntegracaoSAP__c = SAPIntegrationService.isSuccess(
            statusCode
          );
          kit.StatusBodyIntegracaoSAP__c =
            statusCode +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog('IntegracaoSAPKit', 'sendKit ' + kit.Id, e);
        kit.SucessoIntegracaoSAP__c = false;
        kit.StatusBodyIntegracaoSAP__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    KitInstalacaoTriggerHandler.disableTrigger();
    try {
      update kitList;
    } finally {
      KitInstalacaoTriggerHandler.enableTrigger();
    }
  }

  public class KitRequest {
    public String TreeCode;
    public String TreeType;
    public Double Quantity;
    public Integer PriceList;
    public String Warehouse;
    public Double PlanAvgProdSize;
    public ProductTreeLine[] ProductTreeLines;
  }

  public class ProductTreeLine {
    public String ItemCode;
    public Double Quantity;
    public String Warehouse;
    public Double Price;
    public String CurrencySAP; // serializado como "Currency" via replace()
    public String ParentItem;
    public Integer PriceList;
    public Double AdditionalQuantity;
    public Integer ChildNum;
  }
}
