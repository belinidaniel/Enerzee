/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 08-19-2025
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

  @isTest
  static void shouldScaleModulesAndInvertersByKitQuantity() {
    Account accountRecord = (Account) TestFactory.createSObject(
      new Account(),
      true
    );
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountRecord.Id,
        Pricebook2Id = Test.getStandardPricebookId(),
        NumeroModulos__c = 20,
        NumeroInversores__c = 1,
        GeracaoAnualEstimada__c = 144240,
        GeracaoMensalEstimada__c = 12020,
        GeracaoMedioMensal__c = 12020,
        PotenciaPicoSistema__c = 10,
        PotenciaNominalWp__c = 500
      ),
      true
    );

    Product2 kitProduct = (Product2) TestFactory.createSObject(
      new Product2(
        Name = 'KIT Gerador Fotovoltaico 101,15 kWp',
        Family = 'SistFotovoltaicos'
      ),
      true
    );

    Test.startTest();
    OpportunityLineItem kitLine = (OpportunityLineItem) TestFactory.createSObject(
      new OpportunityLineItem(
        OpportunityId = opportunity.Id,
        Product2Id = kitProduct.Id,
        Quantity = 2
      ),
      true
    );
    Test.stopTest();

    Opportunity updatedOpportunity = [
      SELECT
        NumeroModulos__c,
        NumeroInversores__c,
        GeracaoAnualEstimada__c,
        GeracaoMensalEstimada__c,
        GeracaoMedioMensal__c
      FROM Opportunity
      WHERE Id = :opportunity.Id
    ];

    System.assertEquals(
      2,
      updatedOpportunity.NumeroInversores__c.intValue(),
      'Quantidade de inversores deve seguir a quantidade de kits.'
    );
    System.assertEquals(
      40,
      updatedOpportunity.NumeroModulos__c.intValue(),
      'Quantidade de módulos deve ser proporcional à quantidade de kits.'
    );
    System.assertEquals(
      288480,
      updatedOpportunity.GeracaoAnualEstimada__c,
      'Geração anual deve escalar pela quantidade de kits.'
    );
    System.assertEquals(
      24040,
      updatedOpportunity.GeracaoMensalEstimada__c,
      'Geração mensal estimada deve escalar pela quantidade de kits.'
    );
    System.assertEquals(
      24040,
      updatedOpportunity.GeracaoMedioMensal__c,
      'Geração média mensal deve escalar pela quantidade de kits.'
    );
    System.assertNotEquals(null, kitLine.Id);
  }
}
