/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-27-2026
 * @last modified by  : Daniel Belini
 **/
@isTest
public class OpportunityLineItemTriggerTest {
  @TestSetup
  static void makeData() {
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(Pricebook2Id = Test.getStandardPricebookId()),
      true
    );
    Product2 product = (Product2) TestFactory.createSObject(
      new Product2(),
      true
    );
  }

  @isTest
  static void forceKitUpdateOnItemInsertUpdateTest() {
    Test.startTest();

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

    OpportunityLineItem item = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = opportunity.Id,
        Product2Id = product.Id
      ),
      true
    );

    Test.stopTest();
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
