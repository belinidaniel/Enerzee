/**
 * @description       : Controller LWC para exibição das simulações de pagamento agrupadas por ProposalLabel
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-07-2026
 * @last modified by  : Daniel Belini
 * @test              : PaymentSimulationCardControllerTest
 **/
public with sharing class PaymentSimulationCardController {
  @AuraEnabled(cacheable=true)
  public static List<ProposalCardWrapper> getSimulationCards(Id opportunityId) {
    if (opportunityId == null) {
      return new List<ProposalCardWrapper>();
    }

    List<Opportunity> opps = [
      SELECT SelectedSimulation__c
      FROM Opportunity
      WHERE Id = :opportunityId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    String selectedSimulationId = opps.isEmpty()
      ? null
      : opps[0].SelectedSimulation__c;

    List<PaymentSimulation__c> simulations = PaymentSimulationDAO.getByOpportunityIds(
      new Set<Id>{ opportunityId }
    );

    Map<String, ProposalCardWrapper> cardsByLabel = new Map<String, ProposalCardWrapper>();
    List<String> labelOrder = new List<String>();

    for (PaymentSimulation__c sim : simulations) {
      String label = sim.ProposalLabel__c;
      if (String.isBlank(label)) {
        continue;
      }

      if (!cardsByLabel.containsKey(label)) {
        ProposalCardWrapper card = new ProposalCardWrapper();
        card.proposalLabel = label;
        card.paymentType = sim.PaymentType__c;
        card.hasSelected = false;
        card.selectedSimulationId = selectedSimulationId;
        card.options = new List<SimulationOptionWrapper>();
        cardsByLabel.put(label, card);
        labelOrder.add(label);
      }

      Boolean isAppSelected =
        String.isNotBlank(selectedSimulationId) &&
        sim.Id == (Id) selectedSimulationId;

      SimulationOptionWrapper option = new SimulationOptionWrapper();
      option.id = sim.Id;
      option.name = sim.Name;
      option.installmentCount = sim.InstallmentCount__c == null
        ? null
        : Integer.valueOf(String.valueOf(sim.InstallmentCount__c));
      option.installmentAmount = sim.InstallmentAmount__c;
      option.interestRate = sim.InterestRate__c;
      option.selected = isAppSelected;

      ProposalCardWrapper card = cardsByLabel.get(label);
      card.options.add(option);

      if (isAppSelected) {
        card.hasSelected = true;
      }
    }

    List<ProposalCardWrapper> cards = new List<ProposalCardWrapper>();
    for (String label : labelOrder) {
      cards.add(cardsByLabel.get(label));
    }
    return cards;
  }

  public class ProposalCardWrapper {
    @AuraEnabled
    public String proposalLabel;
    @AuraEnabled
    public String paymentType;
    @AuraEnabled
    public Boolean hasSelected;
    @AuraEnabled
    public String selectedSimulationId;
    @AuraEnabled
    public List<SimulationOptionWrapper> options;
  }

  public class SimulationOptionWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer installmentCount;
    @AuraEnabled
    public Decimal installmentAmount;
    @AuraEnabled
    public Decimal interestRate;
    @AuraEnabled
    public Boolean selected;
  }
}
