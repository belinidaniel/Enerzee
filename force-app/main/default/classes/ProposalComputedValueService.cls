/**
 * @description       : Resolve valores calculados e resumos de simulacoes para tags de proposta
 * @author            : OpenAI Codex
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : OpenAI Codex
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalComputedValueService {
  private static final String CALCULATED_PREFIX = 'Calculated.';
  private static final String SIMULATION_PREFIX = 'SimulationSummary.';
  private static final String PAYMENT_TYPE_FINANCING = 'FINANCING';
  private static final String PAYMENT_TYPE_RENTAL = 'RENTAL';
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

    return values;
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

    // % diferenca entre custo mensal atual e pagamento facilitado do aluguel (parcela 60x)
    // Formula: (CustoMedioEnergia - PagamentoFacilitado) / CustoMedioEnergia * 100
    if (
      rentalOption != null &&
      rentalOption.InstallmentAmount__c != null &&
      currentEnergyCost != null &&
      currentEnergyCost != 0
    ) {
      values.put(
        CALCULATED_PREFIX + 'EconomiaPercentual',
        ((currentEnergyCost - rentalOption.InstallmentAmount__c) /
          currentEnergyCost *
          100)
          .setScale(2, RoundingMode.HALF_UP)
      );
    }
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
