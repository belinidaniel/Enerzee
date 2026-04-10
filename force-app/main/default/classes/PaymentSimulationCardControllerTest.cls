/**
 * @description       : Testes para PaymentSimulationCardController
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-06-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public class PaymentSimulationCardControllerTest {
  @IsTest
  static void getSimulationCardsReturnsGroupedCardsForOpportunity() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    FinancingRate__c fr1 = createFinancingRate(
      'Opção 1',
      'Financing',
      true,
      25,
      0.02,
      38,
      0.03,
      60,
      0.04,
      null,
      null
    );
    FinancingRate__c fr2 = createFinancingRate(
      'Solar Aluguel',
      'Rental',
      true,
      12,
      0.01,
      24,
      0.02,
      null,
      null,
      null,
      null
    );
    insertSimulations(opp.Id, fr1);
    insertSimulations(opp.Id, fr2);

    Test.startTest();
    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      cards.size(),
      'Deve retornar 2 cards (1 por ProposalLabel)'
    );

    PaymentSimulationCardController.ProposalCardWrapper firstCard = cards[0];
    Assert.areEqual(
      'Opção 1',
      firstCard.proposalLabel,
      'ProposalLabel do primeiro card deve ser Opção 1'
    );
    Assert.areEqual(
      'Financing',
      firstCard.paymentType,
      'PaymentType do primeiro card deve ser Financing'
    );
    Assert.areEqual(
      3,
      firstCard.options.size(),
      'Opção 1 tem 3 combinações de parcelas'
    );
    Assert.areEqual(
      false,
      firstCard.hasSelected,
      'Nenhuma opção deve estar selecionada'
    );

    PaymentSimulationCardController.ProposalCardWrapper secondCard = cards[1];
    Assert.areEqual(
      'Solar Aluguel',
      secondCard.proposalLabel,
      'ProposalLabel do segundo card deve ser Solar Aluguel'
    );
    Assert.areEqual(
      'Rental',
      secondCard.paymentType,
      'PaymentType do segundo card deve ser Rental'
    );
    Assert.areEqual(
      2,
      secondCard.options.size(),
      'Solar Aluguel tem 2 combinações de parcelas'
    );
  }

  @IsTest
  static void getSimulationCardsReturnsEmptyListForOpportunityWithNoSimulations() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);

    Test.startTest();
    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      cards.size(),
      'Sem simulações deve retornar lista vazia'
    );
  }

  @IsTest
  static void getSimulationCardsReturnsEmptyForNullOpportunityId() {
    Test.startTest();
    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      null
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      cards.size(),
      'Null opportunityId deve retornar lista vazia'
    );
  }

  @IsTest
  static void getSimulationCardsReflectsSelectedState() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    FinancingRate__c fr = createFinancingRate(
      'Opção 1',
      'Financing',
      true,
      25,
      0.02,
      38,
      0.03,
      null,
      null,
      null,
      null
    );
    List<PaymentSimulation__c> sims = insertSimulations(opp.Id, fr);

    PaymentSimulationTriggerHandler.isRunning = true;
    try {
      sims[0].Selected__c = true;
      update sims[0];
    } finally {
      PaymentSimulationTriggerHandler.isRunning = false;
    }

    Test.startTest();
    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(1, cards.size(), 'Deve retornar 1 card');
    Assert.areEqual(
      true,
      cards[0].hasSelected,
      'Card deve refletir que há opção selecionada'
    );

    Boolean foundSelected = false;
    for (
      PaymentSimulationCardController.SimulationOptionWrapper opt : cards[0]
        .options
    ) {
      if (opt.selected) {
        foundSelected = true;
        Assert.areEqual(
          sims[0].Id,
          opt.id,
          'Id da opção selecionada deve corresponder ao registro atualizado'
        );
      }
    }
    Assert.areEqual(
      true,
      foundSelected,
      'Deve encontrar ao menos uma opção selected'
    );
  }

  @IsTest
  static void getSimulationCardsReturnsCorrectInstallmentData() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    FinancingRate__c fr = createFinancingRate(
      'Opção 2',
      'Financing',
      true,
      10,
      0.02,
      null,
      null,
      null,
      null,
      null,
      null
    );
    insertSimulations(opp.Id, fr);

    Test.startTest();
    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(1, cards.size());
    PaymentSimulationCardController.SimulationOptionWrapper opt = cards[0]
      .options[0];
    Assert.areEqual(10, opt.installmentCount, 'installmentCount deve ser 10');
    Assert.areEqual(0.02, opt.interestRate, 'interestRate deve ser 0.02');
    Assert.isNotNull(
      opt.installmentAmount,
      'installmentAmount não deve ser nulo'
    );
    Assert.isNotNull(opt.name, 'name não deve ser nulo');
  }

  @IsTest
  static void createManualSimulationCreatesSelectedSimulationForReadjustment() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    setOpportunityStage(opp.Id, 'Readequação de Proposta');

    FinancingRate__c fr = createFinancingRate(
      'Opção 1',
      'Financing',
      true,
      25,
      0.02,
      38,
      0.03,
      null,
      null,
      null,
      null
    );
    List<PaymentSimulation__c> sims = insertSimulations(opp.Id, fr);
    setSelectedSimulation(opp.Id, sims[0].Id);

    Test.startTest();
    PaymentSimulationCardController.ManualSimulationResult result = PaymentSimulationCardController.createManualSimulation(
      opp.Id,
      sims[0].Id,
      72,
      1492.28
    );
    Test.stopTest();

    List<PaymentSimulation__c> updatedSimulations = [
      SELECT
        Id,
        Name,
        ProposalLabel__c,
        PaymentType__c,
        InstallmentCount__c,
        InstallmentAmount__c,
        InterestRate__c,
        Selected__c
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opp.Id
      ORDER BY CreatedDate ASC, Name ASC
    ];
    Opportunity updatedOpportunity = getOpportunity(opp.Id);

    Assert.areEqual(
      true,
      result.createdNewSimulation,
      'Ao informar novos valores, deve criar uma nova simulação.'
    );
    Assert.areEqual(
      3,
      updatedSimulations.size(),
      'Deve ter criado uma nova linha.'
    );
    Assert.areEqual(
      result.simulationId,
      updatedOpportunity.SelectedSimulation__c,
      'A oportunidade deve apontar para a simulação criada.'
    );

    PaymentSimulation__c createdSimulation;
    Integer selectedCount = 0;
    for (PaymentSimulation__c simulationRecord : updatedSimulations) {
      if (simulationRecord.Selected__c == true) {
        selectedCount++;
      }
      if (simulationRecord.Id == result.simulationId) {
        createdSimulation = simulationRecord;
      }
    }

    Assert.areEqual(
      1,
      selectedCount,
      'Deve existir apenas uma simulação selecionada.'
    );
    Assert.isNotNull(
      createdSimulation,
      'A simulação retornada pela ação deve existir na base.'
    );
    Assert.areEqual('Simulação ajustada', createdSimulation.ProposalLabel__c);
    Assert.areEqual('Financing', createdSimulation.PaymentType__c);
    Assert.areEqual(72, createdSimulation.InstallmentCount__c);
    Assert.areEqual(1492.28, createdSimulation.InstallmentAmount__c);
    Assert.areEqual(0.02, createdSimulation.InterestRate__c);
    Assert.areEqual(true, createdSimulation.Selected__c);

    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    PaymentSimulationCardController.ProposalCardWrapper manualCard;
    for (PaymentSimulationCardController.ProposalCardWrapper card : cards) {
      if (card.proposalLabel == 'Simulação ajustada') {
        manualCard = card;
        break;
      }
    }

    Assert.isNotNull(
      manualCard,
      'A simulação manual deve aparecer em um card separado.'
    );
    Assert.areEqual(true, manualCard.isManual);
    Assert.areEqual('Financing', manualCard.paymentType);
    Assert.areEqual(1, manualCard.options.size());
    Assert.areEqual(result.simulationId, manualCard.options[0].id);
  }

  @IsTest
  static void createManualSimulationReusesBaseSimulationWhenValuesMatch() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    setOpportunityStage(opp.Id, 'Readequação de Proposta');

    FinancingRate__c fr = createFinancingRate(
      'Solar Aluguel',
      'Rental',
      true,
      12,
      0.01,
      24,
      0.02,
      null,
      null,
      null,
      null
    );
    List<PaymentSimulation__c> sims = insertSimulations(opp.Id, fr);

    Test.startTest();
    PaymentSimulationCardController.ManualSimulationResult result = PaymentSimulationCardController.createManualSimulation(
      opp.Id,
      sims[0].Id,
      12,
      1000
    );
    Test.stopTest();

    Integer simulationCount = [
      SELECT COUNT()
      FROM PaymentSimulation__c
      WHERE Opportunity__c = :opp.Id
    ];
    Opportunity updatedOpportunity = getOpportunity(opp.Id);
    PaymentSimulation__c selectedSimulation = [
      SELECT Id, Selected__c
      FROM PaymentSimulation__c
      WHERE Id = :sims[0].Id
      LIMIT 1
    ];

    Assert.areEqual(
      false,
      result.createdNewSimulation,
      'Sem alteração de valores, deve reaproveitar a simulação base.'
    );
    Assert.areEqual(2, simulationCount, 'Não deve criar um novo registro.');
    Assert.areEqual(
      sims[0].Id,
      result.simulationId,
      'Deve retornar a simulação base.'
    );
    Assert.areEqual(
      sims[0].Id,
      updatedOpportunity.SelectedSimulation__c,
      'A oportunidade deve manter a simulação base selecionada.'
    );
    Assert.areEqual(
      true,
      selectedSimulation.Selected__c,
      'A simulação base deve ficar marcada como selecionada.'
    );
  }

  @IsTest
  static void createManualSimulationCreatesOneCardPerManualSimulation() {
    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    setOpportunityStage(opp.Id, 'Readequação de Proposta');

    FinancingRate__c fr = createFinancingRate(
      'Opção 1',
      'Financing',
      true,
      25,
      0.02,
      38,
      0.03,
      null,
      null,
      null,
      null
    );
    List<PaymentSimulation__c> sims = insertSimulations(opp.Id, fr);
    setSelectedSimulation(opp.Id, sims[0].Id);

    Test.startTest();
    PaymentSimulationCardController.ManualSimulationResult firstResult = PaymentSimulationCardController.createManualSimulation(
      opp.Id,
      sims[0].Id,
      72,
      1492.28
    );
    PaymentSimulationCardController.ManualSimulationResult secondResult = PaymentSimulationCardController.createManualSimulation(
      opp.Id,
      firstResult.simulationId,
      84,
      1325.45
    );
    Test.stopTest();

    List<PaymentSimulationCardController.ProposalCardWrapper> cards = PaymentSimulationCardController.getSimulationCards(
      opp.Id
    );
    Integer manualCardCount = 0;
    Integer selectedManualCardCount = 0;
    for (PaymentSimulationCardController.ProposalCardWrapper card : cards) {
      if (card.proposalLabel != 'Simulação ajustada') {
        continue;
      }

      manualCardCount++;
      Assert.areEqual(
        1,
        card.options.size(),
        'Cada simulação manual deve aparecer em seu próprio card.'
      );
      if (card.hasSelected) {
        selectedManualCardCount++;
        Assert.areEqual(
          secondResult.simulationId,
          card.options[0].id,
          'O card manual selecionado deve apontar para a última simulação criada.'
        );
      }
    }

    Assert.areEqual(
      2,
      manualCardCount,
      'Duas simulações manuais devem resultar em dois cards distintos.'
    );
    Assert.areEqual(
      1,
      selectedManualCardCount,
      'Apenas o card da última simulação manual deve ficar selecionado.'
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────

  private static Account createAccount() {
    Account acc = (Account) TestFactory.createSObject(
      new Account(),
      'TestFactoryDefaults.LegalPersonAccount'
    );
    acc.IdVirtualOffice__c = TestFactory.nextUniqueValue('ACCVO');
    acc.CNPJ__c = '12.345.678/0001-90';
    insert acc;
    return acc;
  }

  private static Opportunity createOpportunity(Id accountId) {
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = accountId,
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('Solar')
          .getRecordTypeId(),
        GrupoTarifario__c = 'Grupo B',
        Amount = 100000
      )
    );
    opp.IdVirtualOffice__c = TestFactory.nextUniqueValue('OPPVO');
    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opp;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
    return opp;
  }

  private static Opportunity getOpportunity(Id opportunityId) {
    return [
      SELECT Id, StageName, SelectedSimulation__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
  }

  private static void setOpportunityStage(Id opportunityId, String stageName) {
    OpportunityTriggerHandler.disableTrigger();
    try {
      update new Opportunity(Id = opportunityId, StageName = stageName);
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
  }

  private static void setSelectedSimulation(Id opportunityId, Id simulationId) {
    OpportunityTriggerHandler.disableTrigger();
    try {
      update new Opportunity(
        Id = opportunityId,
        SelectedSimulation__c = simulationId
      );
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
  }

  private static FinancingRate__c createFinancingRate(
    String name,
    String paymentType,
    Boolean active,
    Integer i1,
    Decimal r1,
    Integer i2,
    Decimal r2,
    Integer i3,
    Decimal r3,
    Integer i4,
    Decimal r4
  ) {
    FinancingRate__c fr = new FinancingRate__c(
      Name = name,
      ProposalLabel__c = name,
      PaymentType__c = paymentType,
      Active__c = active,
      Installments1__c = i1,
      InstallmentRate1__c = r1,
      Installments2__c = i2,
      InstallmentRate2__c = r2,
      Installments3__c = i3,
      InstallmentRate3__c = r3,
      Installments4__c = i4,
      InstallmentRate4__c = r4
    );
    insert fr;
    return fr;
  }

  private static List<PaymentSimulation__c> insertSimulations(
    Id oppId,
    FinancingRate__c fr
  ) {
    List<Integer> counts = new List<Integer>{
      fr.Installments1__c == null
        ? null
        : Integer.valueOf(String.valueOf(fr.Installments1__c)),
      fr.Installments2__c == null
        ? null
        : Integer.valueOf(String.valueOf(fr.Installments2__c)),
      fr.Installments3__c == null
        ? null
        : Integer.valueOf(String.valueOf(fr.Installments3__c)),
      fr.Installments4__c == null
        ? null
        : Integer.valueOf(String.valueOf(fr.Installments4__c))
    };
    List<Decimal> rates = new List<Decimal>{
      fr.InstallmentRate1__c,
      fr.InstallmentRate2__c,
      fr.InstallmentRate3__c,
      fr.InstallmentRate4__c
    };

    List<PaymentSimulation__c> sims = new List<PaymentSimulation__c>();
    for (Integer i = 0; i < 4; i++) {
      if (counts[i] == null || rates[i] == null) {
        continue;
      }
      sims.add(
        new PaymentSimulation__c(
          Opportunity__c = oppId,
          FinancingRate__c = fr.Id,
          PaymentType__c = fr.PaymentType__c,
          ProposalLabel__c = fr.ProposalLabel__c,
          InstallmentCount__c = counts[i],
          InterestRate__c = rates[i],
          InstallmentAmount__c = 1000,
          Selected__c = false
        )
      );
    }

    PaymentSimulationTriggerHandler.isRunning = true;
    try {
      insert sims;
    } finally {
      PaymentSimulationTriggerHandler.isRunning = false;
    }
    return sims;
  }
}
