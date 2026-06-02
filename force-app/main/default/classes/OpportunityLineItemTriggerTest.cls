/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class OpportunityLineItemTriggerTest {
  @TestSetup
  static void makeData() {
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(Pricebook2Id = Test.getStandardPricebookId()),
      true
    );
    ProductTriggerHandler.disableTrigger();
    Product2 product = (Product2) TestFactory.createSObject(
      new Product2(
        ExternalId__c = 'oli-prod-' + String.valueOf(DateTime.now().getTime())
      ),
      true
    );
    ProductTriggerHandler.enableTrigger();
    insert new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product.Id,
      UnitPrice = 10,
      IsActive = true
    );
  }

  @isTest
  static void forceKitUpdateOnItemInsertUpdateTest() {
    Opportunity opportunity = [
      SELECT Id
      FROM Opportunity
      LIMIT 1
    ];

    Product2 product = [
      SELECT Id
      FROM Product2
      LIMIT 1
    ];

    Test.startTest();

    OpportunityLineItem item = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = opportunity.Id,
        Product2Id = product.Id
      ),
      true
    );

    item = [
      SELECT Id, Quantity, UnitPrice
      FROM OpportunityLineItem
      WHERE Id = :item.Id
    ];
    item.Quantity = item.Quantity + 1;
    update item;

    delete item;

    Test.stopTest();
  }

  @isTest
  static void triggerEnabledFlagTest() {
    OpportunityLineItemTriggerHandler.enableTrigger();
    Assert.isTrue(OpportunityLineItemTriggerHandler.isTriggerEnabled());

    OpportunityLineItemTriggerHandler.disableTrigger();
    Assert.isFalse(OpportunityLineItemTriggerHandler.isTriggerEnabled());

    OpportunityLineItemTriggerHandler.enableTrigger();
    Assert.isTrue(OpportunityLineItemTriggerHandler.isTriggerEnabled());
  }

  @isTest
  static void forceKitUpdateOnItemInsertUpdate2Test() {
    Opportunity opportunity = [
      SELECT Id
      FROM Opportunity
      LIMIT 1
    ];

    Product2 product = [
      SELECT Id
      FROM Product2
      LIMIT 1
    ];

    Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opportunity.Id),
      true
    );

    OpportunityLineItem item = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = opportunity.Id,
        Product2Id = product.Id,
        Kit_Instalacao__c = kit.Id
      ),
      true
    );

    OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate2(
      new List<OpportunityLineItem>{ item }
    );
  }
}
