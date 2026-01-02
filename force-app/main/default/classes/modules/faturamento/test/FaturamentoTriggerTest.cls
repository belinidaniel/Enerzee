@isTest
public class FaturamentoTriggerTest {
    @TestSetup
    static void makeData(){
        Account customer = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
    }

    @isTest
    static void assignClientToIntegratedBillingTest(){
        Account customer = [
            SELECT  Id, IdVirtualOffice__c
            FROM    Account
            WHERE   RecordTypeID = :Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaFisica').getRecordTypeId()
            LIMIT   1
        ];

        Faturamento__c billing = (Faturamento__c) TestFactory.createSObject(new Faturamento__c(
            IdExternoCliente__c = customer.IdVirtualOffice__c
        ), true);

        billing = [
            SELECT  Cliente__c
            FROM    Faturamento__c 
            LIMIT   1
        ];
        System.assertEquals(customer.Id, billing.Cliente__c);
    }

    @isTest
    static void assignOpportunityToIntegratedBillingTest(){
        Opportunity opportunity = [
            SELECT  Id, IdVirtualOffice__c
            FROM    Opportunity
            LIMIT   1
        ];

        Faturamento__c billing = (Faturamento__c) TestFactory.createSObject(new Faturamento__c(
            IdExternoOportunidade__c = opportunity.IdVirtualOffice__c
        ), true);

        billing = [
            SELECT  Oportunidade__c
            FROM    Faturamento__c 
            LIMIT   1
        ];
        System.assertEquals(opportunity.Id, billing.Oportunidade__c);
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Faturamento__c billing = (Faturamento__c) TestFactory.createSObject(new Faturamento__c(), true);
        
        billing.Name = 'Teste 2';
        update billing;

        delete billing;

        FaturamentoTriggerHandler.disableTrigger();
        System.assert(!FaturamentoTriggerHandler.isTriggerEnabled());
        
        FaturamentoTriggerHandler.enableTrigger();
        System.assert(FaturamentoTriggerHandler.isTriggerEnabled());
    }
}