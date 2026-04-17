/**
 * @description       : Resolve valores calculados e resumos de simulacoes para tags de proposta
 * @author            : OpenAI Codex
 * @group             :
 * @last modified on  : 04-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalComputedValueService {
  private static final String CALCULATED_PREFIX = 'Calculated.';
  private static final String SIMULATION_PREFIX = 'SimulationSummary.';
  private static final String PAYMENT_TYPE_FINANCING = 'FINANCING';
  private static final String PAYMENT_TYPE_RENTAL = 'RENTAL';
  private static final String PAYMENT_TYPE_CARD = 'CARD';
  private static final Integer RENTAL_TARGET_INSTALLMENTS = 60;

  public static Boolean isComputedPath(String sourcePath) {
    if (String.isBlank(sourcePath)) {
      return false;
    }

    return sourcePath.startsWith(CALCULATED_PREFIX) ||
      sourcePath.startsWith(SIMULATION_PREFIX);
  }

  public static Object resolveValue(
    String sourcePath,
    Map<String, Object> computedValues
  ) {
    if (String.isBlank(sourcePath) || computedValues == null) {
      return null;
    }

    return computedValues.get(sourcePath);
  }

  public static Map<String, Object> build(
    Id opportunityId,
    Opportunity opportunityRecord
  ) {
    Map<String, Object> values = new Map<String, Object>();

    // Resolve simulacoes primeiro para usar o valor do aluguel no calculo percentual
    PaymentSimulation__c rentalOption = addSimulationSummaryValues(
      values,
      opportunityId
    );
    addCalculatedValues(values, opportunityRecord, rentalOption);
    addViabilityCostValues(values, opportunityId);

    return values;
  }

  private static void addViabilityCostValues(
    Map<String, Object> values,
    Id opportunityId
  ) {
    if (opportunityId == null) {
      return;
    }

    List<ViabilityStudy__c> viabilityList = [
      SELECT
        AdequacyCostEnerzee__c,
        AdequacyCostClient__c,
        AcBranchCost__c,
        DcBranchCost__c,
        StandardAdequacyCost__c,
        AdditionalCost__c,
        OtherCosts__c,
        OtherCostsDescription__c,
        CoberturaCost__c,
        StruturalReport__c
      FROM ViabilityStudy__c
      WHERE Opportunity__c = :opportunityId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    if (viabilityList.isEmpty()) {
      values.put(CALCULATED_PREFIX + 'CustosViabilidade', '');
      return;
    }

    ViabilityStudy__c viability = viabilityList[0];

    List<String> enerzeeEntries = buildViabilityCostEntries(
      viability.AdequacyCostEnerzee__c,
      viability
    );
    List<String> clientEntries = buildViabilityCostEntries(
      viability.AdequacyCostClient__c,
      viability
    );

    List<String> allEntries = new List<String>();
    if (!enerzeeEntries.isEmpty()) {
      allEntries.add('Custo Enerzee');
      allEntries.addAll(enerzeeEntries);
    }
    if (!clientEntries.isEmpty()) {
      allEntries.add('Custo Cliente');
      allEntries.addAll(clientEntries);
    }

    values.put(
      CALCULATED_PREFIX + 'CustosViabilidade',
      allEntries.isEmpty() ? '' : String.join(allEntries, '\n')
    );
  }

  private static List<String> buildViabilityCostEntries(
    String multiSelectValues,
    ViabilityStudy__c viability
  ) {
    List<String> entries = new List<String>();
    if (String.isBlank(multiSelectValues)) {
      return entries;
    }
    for (String rawLabel : multiSelectValues.split(';')) {
      String label = rawLabel.trim();
      if (String.isBlank(label)) {
        continue;
      }
      String displayLabel = resolveViabilityCostLabel(label, viability);
      Decimal amount = resolveViabilityCostAmount(label, viability);
      if (amount != null) {
        entries.add(displayLabel + ' (R$ ' + formatDecimalBR(amount, 2) + ')');
      } else {
        entries.add(displayLabel);
      }
    }
    return entries;
  }

  private static String resolveViabilityCostLabel(
    String label,
    ViabilityStudy__c viability
  ) {
    if (String.isBlank(label)) {
      return label;
    }
    String normalized = label.trim().toLowerCase();
    if (
      (normalized == 'outros custos' ||
      normalized == 'outros custo') &&
      viability != null &&
      !String.isBlank(viability.OtherCostsDescription__c)
    ) {
      return viability.OtherCostsDescription__c.trim();
    }
    return label;
  }

  private static Decimal resolveViabilityCostAmount(
    String label,
    ViabilityStudy__c viability
  ) {
    if (viability == null || String.isBlank(label)) {
      return null;
    }
    String normalized = label.trim().toLowerCase();
    Decimal amount;
    if (normalized == 'ramal cc') {
      amount = viability.DcBranchCost__c;
    } else if (normalized == 'ramal ca') {
      amount = viability.AcBranchCost__c;
    } else if (
      normalized == 'adequação padrão' ||
      normalized == 'adequacao padrao'
    ) {
      amount = viability.StandardAdequacyCost__c;
    } else if (normalized == 'cobertura') {
      amount = viability.CoberturaCost__c;
    } else if (normalized == 'laudo estrutural') {
      amount = viability.StruturalReport__c;
    } else if (normalized == 'outros custos' || normalized == 'outros custo') {
      amount = viability.OtherCosts__c;
    } else if (normalized == 'custos adicionais') {
      amount = viability.AdditionalCost__c;
    }
    return (amount != null && amount != 0) ? amount : null;
  }

  private static String formatDecimalBR(Decimal value, Integer scale) {
    Decimal scaled = value.setScale(scale, RoundingMode.HALF_UP);
    Long integerPart = scaled.longValue();
    Decimal fractionalPart = (scaled - integerPart)
      .abs()
      .setScale(scale, RoundingMode.HALF_UP);

    String intStr = String.valueOf(
      integerPart < 0 ? -integerPart : integerPart
    );
    String intFormatted = '';
    Integer remainder = Math.mod(intStr.length(), 3);
    for (Integer i = 0; i < intStr.length(); i++) {
      if (i > 0 && Math.mod(i - remainder, 3) == 0 && i >= remainder) {
        intFormatted += '.';
      }
      intFormatted += intStr.substring(i, i + 1);
    }

    String fracStr = String.valueOf(fractionalPart).replace('0.', '');
    while (fracStr.length() < scale) {
      fracStr += '0';
    }

    String result = intFormatted + ',' + fracStr;
    return integerPart < 0 ? '-' + result : result;
  }

  private static void addCalculatedValues(
    Map<String, Object> values,
    Opportunity opportunityRecord,
    PaymentSimulation__c rentalOption
  ) {
    if (opportunityRecord == null) {
      return;
    }

    Decimal currentEnergyCost = toDecimal(
      opportunityRecord.get('CustoMedioEnergia__c')
    );
    Decimal monthlySavings = toDecimal(
      opportunityRecord.get('EconomiaMensalEstimada__c')
    );
    Decimal monthlyGeneration = toDecimal(
      opportunityRecord.get('GeracaoMensalEstimada__c')
    );
    Decimal monthlyConsumption = toDecimal(
      opportunityRecord.get('ConsumoInformadoB__c')
    );

    // Reducao na conta: EconomiaMensalEstimada / CustoMedioEnergia * 100
    if (
      monthlySavings != null &&
      currentEnergyCost != null &&
      currentEnergyCost != 0
    ) {
      values.put(
        CALCULATED_PREFIX + 'ReducaoNaConta',
        (monthlySavings /
          currentEnergyCost *
          100)
          .setScale(2, RoundingMode.HALF_UP)
      );
    }

    // Autossuficiencia: GeracaoMensalEstimada / ConsumoInformadoB * 100
    if (
      monthlyGeneration != null &&
      monthlyConsumption != null &&
      monthlyConsumption != 0
    ) {
      values.put(
        CALCULATED_PREFIX + 'Autossuficiencia',
        (monthlyGeneration /
          monthlyConsumption *
          100)
          .setScale(2, RoundingMode.HALF_UP)
      );
    }

    // EconomiaPercentual (card Aluguel): (CustoMedioEnergia - ParcelaAluguel) / CustoMedioEnergia * 100
    // Calculado antes do bloco de negatividade (que pode sobrescrever para null)
    Decimal rentalAmountPct = toDecimal(
      values.get(SIMULATION_PREFIX + 'Rental.InstallmentAmount1')
    );
    if (
      rentalAmountPct != null &&
      currentEnergyCost != null &&
      currentEnergyCost != 0
    ) {
      values.put(
        CALCULATED_PREFIX + 'EconomiaPercentual',
        ((currentEnergyCost - rentalAmountPct) /
          currentEnergyCost *
          100)
          .setScale(2, RoundingMode.HALF_UP)
      );
    }

    // EconomiaPercentualFinanciamento (card Financiamento 60x): (CustoMedioEnergia - ParcelaFinanciamento3) / CustoMedioEnergia * 100
    // Se negativo, zera os campos da seção de financiamento
    Decimal financing3Amount = toDecimal(
      values.get(SIMULATION_PREFIX + 'Financing.InstallmentAmount3')
    );
    if (
      financing3Amount != null &&
      currentEnergyCost != null &&
      currentEnergyCost != 0
    ) {
      Decimal financingPct = ((currentEnergyCost - financing3Amount) /
        currentEnergyCost *
        100)
        .setScale(2, RoundingMode.HALF_UP);
      if (financingPct < 0) {
        // Seção de financiamento fica em branco quando porcentagem é negativa
        // parcelaFinanciamento3 nunca é zerada — sempre exibe o número de parcelas
        values.put(CALCULATED_PREFIX + 'EconomiaPercentualFinanciamento', '');
        values.put(CALCULATED_PREFIX + 'FinanciamentoMensal', '');
        values.put(CALCULATED_PREFIX + 'EconomiaMensalTxt', '');
        values.put(CALCULATED_PREFIX + 'EconomiaMensalFinalTxt', '');
      } else {
        values.put(
          CALCULATED_PREFIX + 'EconomiaPercentualFinanciamento',
          financingPct
        );
        values.put(CALCULATED_PREFIX + 'FinanciamentoMensal', monthlySavings);
        // Monta o texto "Economia Mensal Nx" com a quantidade da 3ª opção de financiamento
        Decimal count3 = toDecimal(
          values.get(SIMULATION_PREFIX + 'Financing.InstallmentCount3')
        );
        String countLabel = count3 == null
          ? ''
          : String.valueOf(
              count3.setScale(0, RoundingMode.HALF_UP).intValue()
            ) + 'x';
        values.put(
          CALCULATED_PREFIX + 'EconomiaMensalTxt',
          'Economia Mensal ' + countLabel
        );
      }
    }

    // EconomiaPercentual negativo → zera seção aluguel
    Decimal rentalAmount = toDecimal(
      values.get(SIMULATION_PREFIX + 'Rental.InstallmentAmount1')
    );
    if (
      rentalAmount != null &&
      currentEnergyCost != null &&
      currentEnergyCost != 0
    ) {
      Decimal rentalPct = ((currentEnergyCost - rentalAmount) /
        currentEnergyCost *
        100)
        .setScale(2, RoundingMode.HALF_UP);
      if (rentalPct < 0) {
        // Seção de aluguel fica em branco quando porcentagem é negativa
        values.put(CALCULATED_PREFIX + 'AluguelEconomiaMensal', '');
        values.put(CALCULATED_PREFIX + 'EconomiaMensal', '');
        values.put(CALCULATED_PREFIX + 'EconomiaPercentual', '');
      } else {
        // Propaga o valor de EconomiaMensalEstimada para o path calculado do aluguel
        values.put(CALCULATED_PREFIX + 'AluguelEconomiaMensal', monthlySavings);
      }
    }

    // Parcelas com formato COUNT_X para financiamento (1, 2, 3) e aluguel
    // Sempre populadas — nunca ficam vazias
    for (Integer i = 1; i <= 3; i++) {
      Decimal count = toDecimal(
        values.get(SIMULATION_PREFIX + 'Financing.InstallmentCount' + i)
      );
      values.put(
        CALCULATED_PREFIX + 'parcelaFinanciamento' + i,
        count == null ? 0 : count.setScale(0, RoundingMode.HALF_UP).intValue()
      );
    }
    Decimal rentalCount = toDecimal(
      values.get(SIMULATION_PREFIX + 'Rental.InstallmentCount1')
    );
    values.put(
      CALCULATED_PREFIX + 'AlugelParcelas',
      rentalCount == null
        ? 0
        : rentalCount.setScale(0, RoundingMode.HALF_UP).intValue()
    );
  }

  private static PaymentSimulation__c addSimulationSummaryValues(
    Map<String, Object> values,
    Id opportunityId
  ) {
    if (opportunityId == null) {
      return null;
    }

    List<PaymentSimulation__c> simulations = PaymentSimulationDAO.getByOpportunityIds(
      new Set<Id>{ opportunityId }
    );
    if (simulations.isEmpty()) {
      return null;
    }

    List<PaymentSimulation__c> financingOptions = selectPrimaryGroupByPaymentType(
      simulations,
      PAYMENT_TYPE_FINANCING
    );
    for (
      Integer index = 0; index < financingOptions.size() && index < 3; index++
    ) {
      PaymentSimulation__c simulationRecord = financingOptions[index];
      Integer optionNumber = index + 1;
      values.put(
        SIMULATION_PREFIX + 'Financing.InstallmentAmount' + optionNumber,
        simulationRecord.InstallmentAmount__c
      );
      values.put(
        SIMULATION_PREFIX + 'Financing.InstallmentCount' + optionNumber,
        simulationRecord.InstallmentCount__c
      );
    }

    PaymentSimulation__c rentalDisplayOption = selectRentalDisplayOption(
      selectPrimaryGroupByPaymentType(simulations, PAYMENT_TYPE_RENTAL)
    );
    if (rentalDisplayOption != null) {
      values.put(
        SIMULATION_PREFIX + 'Rental.InstallmentAmount1',
        rentalDisplayOption.InstallmentAmount__c
      );
      values.put(
        SIMULATION_PREFIX + 'Rental.InstallmentCount1',
        rentalDisplayOption.InstallmentCount__c
      );
    }

    List<PaymentSimulation__c> cardOptions = selectPrimaryGroupByPaymentType(
      simulations,
      PAYMENT_TYPE_CARD
    );
    if (!cardOptions.isEmpty()) {
      // Pega a última parcela (maior InstallmentCount) do cartão
      PaymentSimulation__c cardOption = cardOptions[cardOptions.size() - 1];
      values.put(
        SIMULATION_PREFIX + 'Card.InstallmentAmount1',
        cardOption.InstallmentAmount__c
      );
      values.put(
        SIMULATION_PREFIX + 'Card.InstallmentCount1',
        cardOption.InstallmentCount__c
      );
    }

    return rentalDisplayOption;
  }

  private static List<PaymentSimulation__c> selectPrimaryGroupByPaymentType(
    List<PaymentSimulation__c> simulations,
    String paymentType
  ) {
    List<PaymentSimulation__c> matches = new List<PaymentSimulation__c>();
    String primaryLabel;

    for (PaymentSimulation__c simulationRecord : simulations) {
      if (normalize(simulationRecord.PaymentType__c) != paymentType) {
        continue;
      }

      if (String.isBlank(primaryLabel)) {
        primaryLabel = simulationRecord.ProposalLabel__c;
      }

      if (simulationRecord.ProposalLabel__c != primaryLabel) {
        continue;
      }

      matches.add(simulationRecord);
    }

    return matches;
  }

  private static PaymentSimulation__c selectRentalDisplayOption(
    List<PaymentSimulation__c> rentalOptions
  ) {
    if (rentalOptions.isEmpty()) {
      return null;
    }

    PaymentSimulation__c bestMatch = rentalOptions[0];
    for (PaymentSimulation__c optionRecord : rentalOptions) {
      Integer installments = optionRecord.InstallmentCount__c == null
        ? null
        : Integer.valueOf(String.valueOf(optionRecord.InstallmentCount__c));
      Integer bestInstallments = bestMatch.InstallmentCount__c == null
        ? null
        : Integer.valueOf(String.valueOf(bestMatch.InstallmentCount__c));

      if (installments == RENTAL_TARGET_INSTALLMENTS) {
        return optionRecord;
      }

      if (
        installments != null &&
        (bestInstallments == null ||
        installments > bestInstallments)
      ) {
        bestMatch = optionRecord;
      }
    }

    return bestMatch;
  }

  private static Decimal toDecimal(Object value) {
    try {
      if (value instanceof Decimal) {
        return (Decimal) value;
      }
      return Decimal.valueOf(String.valueOf(value));
    } catch (Exception e) {
      return null;
    }
  }

  private static String normalize(String value) {
    return String.isBlank(value) ? null : value.trim().toUpperCase();
  }
}
