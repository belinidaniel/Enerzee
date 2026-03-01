public with sharing class FaturamentoBO {

    // Atribuir cliente ao campo correspondente no Faturamento, ao receber ID externo da Conta via integração
    public static void assignClientToIntegratedBilling(List<Faturamento__c> newRecords){
        Set<String> externalAccountIds = new Set<String>();
        Map<String, Id> externalAccountIdToAccountId = new Map<String, Id>();

        for(Faturamento__c billing : newRecords){
            externalAccountIds.add(billing.IdExternoCliente__c);
        }

        for(Account account : [
            SELECT  Id, IdVirtualOffice__c
            FROM    Account
            WHERE   IdVirtualOffice__c IN :externalAccountIds
        ]){
            externalAccountIdToAccountId.put(account.IdVirtualOffice__c, account.Id);
        }

        for(Faturamento__c billing : newRecords){
            billing.Cliente__c = externalAccountIdToAccountId.get(billing.IdExternoCliente__c);
        }
    }

    // Atribuir oportunidade ao campo correspondente no Faturamento, ao receber ID externo da Oportunidade via integração
    public static void assignOpportunityToIntegratedBilling(List<Faturamento__c> newRecords){
        Set<String> externalOpportunityIds = new Set<String>();
        Map<String, Id> externalOpportunityIdToOpportunityId = new Map<String, Id>();

        for(Faturamento__c billing : newRecords){
            externalOpportunityIds.add(billing.IdExternoOportunidade__c);
        }

        for(Opportunity opportunity : [
            SELECT  Id, IdVirtualOffice__c
            FROM    Opportunity
            WHERE   IdVirtualOffice__c IN :externalOpportunityIds
        ]){
            externalOpportunityIdToOpportunityId.put(opportunity.IdVirtualOffice__c, opportunity.Id);
        }

        for(Faturamento__c billing : newRecords){
            billing.Oportunidade__c = externalOpportunityIdToOpportunityId.get(billing.IdExternoOportunidade__c);
        }
    }
}