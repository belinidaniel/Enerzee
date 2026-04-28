/**
 * @description       : Centraliza queries da funcionalidade de simulação de pagamento
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : OpenAI Codex
 * @test              : OpportunityTriggerTest, PaymentSimulationBOTest, PaymentSimulationCardControllerTest,
 *                       ProposalEngineSupportTest, ProposalServicePaymentSimulationTest
 **/
public without sharing class PaymentSimulationDAO {
  public static List<PaymentSimulation__c> getByOpportunityIds(
    Set<Id> opportunityIds
  ) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return new List<PaymentSimulation__c>();
    }

    return [
      SELECT
        Id,
        Name,
        Opportunity__c,
        PaymentType__c,
        InstallmentAmount__c,
        InstallmentCount__c,
        InterestRate__c,
        Selected__c,
        FinancingRate__c,
        FinancingRate__r.AnticipationRate__c,
        ProposalLabel__c
      FROM PaymentSimulation__c
      WHERE Opportunity__c IN :opportunityIds
      ORDER BY
        Opportunity__c,
        ProposalLabel__c ASC,
        InstallmentCount__c ASC,
        InterestRate__c ASC,
        Name ASC
    ];
  }

  private static List<FinancingRate__c> cachedActiveFinancingRates;

  public static List<FinancingRate__c> getActiveFinancingRates() {
    if (cachedActiveFinancingRates == null) {
      cachedActiveFinancingRates = [
        SELECT
          Id,
          Name,
          ProposalLabel__c,
          PaymentType__c,
          Installments1__c,
          Installments2__c,
          Installments3__c,
          Installments4__c,
          InstallmentRate1__c,
          InstallmentRate2__c,
          InstallmentRate3__c,
          InstallmentRate4__c,
          AnticipationRate__c
        FROM FinancingRate__c
        WHERE Active__c = TRUE
        ORDER BY Name ASC
      ];
    }
    return cachedActiveFinancingRates;
  }

  public static Map<Id, Account> getAccountsByIds(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty()) {
      return new Map<Id, Account>();
    }

    return new Map<Id, Account>(
      [
        SELECT Id, CNPJ__c
        FROM Account
        WHERE Id IN :accountIds
      ]
    );
  }

  public static Map<Id, Opportunity> getOpportunitiesByIds(
    Set<Id> opportunityIds
  ) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return new Map<Id, Opportunity>();
    }

    return new Map<Id, Opportunity>(
      [
        SELECT Id, SelectedSimulation__c, FinancingProcessDetails__c
        FROM Opportunity
        WHERE Id IN :opportunityIds
      ]
    );
  }
}
