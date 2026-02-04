@isTest
public class KitInstalacaoTriggerTest {
    @TestSetup
    static void makeData(){
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            Pricebook2Id = Test.getStandardPricebookId()
        ), true);
        Product2 product = (Product2) TestFactory.createSObject(new Product2(), true);
        OpportunityLineItem item = (OpportunityLineItem) TestFactory.createSObject(new OpportunityLineItem(
            OpportunityId = opportunity.Id,
            Product2Id    = product.Id
        ), true);
    }
    
    @isTest
    static void sendKitRecordsToSAPTest(){
        Test.startTest();

        Opportunity opportunity = [
            SELECT  Id
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);

        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;

        update kit;
        
        Test.stopTest();
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Opportunity opportunity = [
            SELECT  Id
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);

        delete kit;

        KitInstalacaoTriggerHandler.disableTrigger();
        System.assert(!KitInstalacaoTriggerHandler.isTriggerEnabled());
        
        KitInstalacaoTriggerHandler.enableTrigger();
        System.assert(KitInstalacaoTriggerHandler.isTriggerEnabled());
    }
}