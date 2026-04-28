// Recalcula InstallmentAmount__c das simulações de Cartão de Crédito
// usando Tabela Price com CET (antecipação sobre o principal)
// PMT = PV_cet * i / (1 - (1+i)^-n)
// PV_cet = principal * (1 + antecipação%)
// principal = ValorTotalProposta__c ?? Amount (mesma lógica do PaymentSimulationBO.getSimulationAmount)

List<PaymentSimulation__c> cardSimulations = [
  SELECT
    Id,
    InstallmentCount__c,
    InstallmentAmount__c,
    InterestRate__c,
    FinancingRate__c,
    FinancingRate__r.AnticipationRate__c,
    Opportunity__r.ValorTotalProposta__c,
    Opportunity__r.Amount
  FROM PaymentSimulation__c
  WHERE PaymentType__c = 'Card'
    AND FinancingRate__c != null
    AND InstallmentCount__c != null
    AND InterestRate__c != null
];

System.debug('Total simulações Card encontradas: ' + cardSimulations.size());

List<PaymentSimulation__c> toUpdate = new List<PaymentSimulation__c>();

for (PaymentSimulation__c sim : cardSimulations) {
  // Mesma lógica do PaymentSimulationBO.getSimulationAmount
  Decimal principal = sim.Opportunity__r.ValorTotalProposta__c != null &&
    sim.Opportunity__r.ValorTotalProposta__c > 0
    ? sim.Opportunity__r.ValorTotalProposta__c
    : sim.Opportunity__r.Amount;

  if (principal == null || principal <= 0) {
    System.debug('Pulando sim ' + sim.Id + ' — principal nulo ou zero');
    continue;
  }

  Decimal interestRate = sim.InterestRate__c;
  Integer n = Integer.valueOf(sim.InstallmentCount__c);
  Decimal anticipationRate = sim.FinancingRate__r.AnticipationRate__c;

  // Normaliza taxa: se < 0.1 assume decimal (0.0216 → 2.16%), converte para %
  Decimal pct = interestRate.abs() >= 0.1
    ? interestRate
    : interestRate * 100;

  // Antecipação sobre o principal (CET)
  Decimal anticipationPct = anticipationRate == null ? 0
    : (anticipationRate.abs() >= 0.1 ? anticipationRate : anticipationRate * 100);
  Decimal pv = principal + (principal * anticipationPct / 100);

  // Tabela Price: PMT = PV * i / (1 - (1+i)^-n)
  Decimal newAmount;
  if (n <= 1 || pct == 0) {
    newAmount = (pv / n).setScale(2, RoundingMode.HALF_UP);
  } else {
    Decimal i = pct / 100;
    Decimal factor = 1 - Math.pow(1 + i.doubleValue(), -n);
    newAmount = (pv * i / factor).setScale(2, RoundingMode.HALF_UP);
  }

  if (newAmount != null && newAmount != sim.InstallmentAmount__c) {
    System.debug(
      'Sim ' + sim.Id +
      ' | n=' + n +
      ' | taxa=' + pct + '%' +
      ' | antecip=' + anticipationPct + '%' +
      ' | principal=' + principal +
      ' | PV_cet=' + pv +
      ' | antes=' + sim.InstallmentAmount__c +
      ' | depois=' + newAmount
    );
    toUpdate.add(new PaymentSimulation__c(
      Id = sim.Id,
      InstallmentAmount__c = newAmount
    ));
  }
}

System.debug('Simulações a atualizar: ' + toUpdate.size());

if (!toUpdate.isEmpty()) {
  update toUpdate;
  System.debug('Update concluído com sucesso.');
} else {
  System.debug('Nenhuma simulação precisou de atualização.');
}
