/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 10-06-2025
 * @last modified by	 : Daniel Belini
 **/
public with sharing class OpportunityDataController {
  private final Opportunity opportunity;
  private static final Integer CASH_FLOW_YEARS = 25;

  // Constructor
  public OpportunityDataController(ApexPages.StandardController controller) {
    this.opportunity = (Opportunity) controller.getRecord();
  }

  public String getOpportunityChartImage() {
    return generateOpportunityChartImage(this.opportunity.Id);
  }

  public static String generateOpportunityChartImage(Id opportunityId) {
    Opportunity opp = [
      SELECT
        Id,
        CreatedDate,
        ValorTotalProposta__c,
        EconomiaAnualEstimada__c,
        EconomiaAcumulada__c,
        PaybackAnos__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    Integer startYear = opp.CreatedDate.year();
    Decimal economiaAnual = opp.EconomiaAnualEstimada__c != null
      ? opp.EconomiaAnualEstimada__c
      : 0;
    Decimal investimento = resolveInvestment(opp, economiaAnual);
    Decimal economiaAcumulada = opp.EconomiaAcumulada__c != null
      ? opp.EconomiaAcumulada__c
      : 0;

    if (economiaAnual <= 0 && economiaAcumulada != 0) {
      economiaAnual = (economiaAcumulada + investimento) / CASH_FLOW_YEARS;
    } else if (economiaAcumulada != 0) {
      Decimal economiaAnualAjustada =
        (economiaAcumulada + investimento) / CASH_FLOW_YEARS;
      if (economiaAnualAjustada > 0) {
        economiaAnual = economiaAnualAjustada;
      }
    }

    List<String> years = new List<String>();
    List<Decimal> saldoAcumulado = new List<Decimal>();
    List<String> colors = new List<String>();

    for (Integer offset = 0; offset <= CASH_FLOW_YEARS; offset++) {
      Integer year = startYear + offset;
      Decimal saldo = (-investimento) + (economiaAnual * offset);
      years.add(String.valueOf(year));
      saldoAcumulado.add(saldo);
      if (saldo < 0) {
        colors.add('rgb(0, 51, 102)');
      } else {
        colors.add('rgb(153, 204, 102)');
      }
    }

    String chartImageUrl = generateQuickChartImageUrl(
      years,
      saldoAcumulado,
      colors
    );
    return chartImageUrl;
  }

  @TestVisible
  private static Decimal resolveInvestment(
    Opportunity opp,
    Decimal economiaAnual
  ) {
    if (
      opp != null &&
      opp.PaybackAnos__c != null &&
      opp.PaybackAnos__c > 0 &&
      economiaAnual > 0
    ) {
      return opp.PaybackAnos__c * economiaAnual;
    }
    return (opp != null &&
      opp.ValorTotalProposta__c != null &&
      opp.ValorTotalProposta__c > 0)
      ? opp.ValorTotalProposta__c
      : 0;
  }

  @AuraEnabled(cacheable=true)
  public static String generateQuickChartImageUrl(
    List<String> years,
    List<Decimal> saldoData,
    List<String> colors
  ) {
    String baseUrl = 'https://quickchart.io/chart?';

    Integer paybackIndex = 0;
    for (Integer i = 0; i < saldoData.size(); i++) {
      if (saldoData[i] >= 0) {
        paybackIndex = i;
        break;
      }
    }
    String paybackYear = years[paybackIndex];
    Decimal paybackValue = saldoData[paybackIndex];

    Integer finalIndex = saldoData.size() - 1;
    Decimal finalValue = saldoData[finalIndex];
    String finalYear = years[finalIndex];

    String annotations =
      '"annotations":{"annotations":[' +
      '{"type":"label","xScaleID":"x-axis-0","xValue":"' +
      paybackYear +
      '","yValue":' +
      String.valueOf(paybackValue) +
      ',"backgroundColor":"rgba(0,0,0,0.1)","content":["Payback: R$ ' +
      String.valueOf(paybackValue.setScale(2)) +
      '"],"fontSize":10},' +
      '{"type":"label","xScaleID":"x-axis-0","xValue":"' +
      finalYear +
      '","yValue":' +
      String.valueOf(finalValue) +
      ',"backgroundColor":"rgba(0,0,0,0.1)","content":["R$ ' +
      String.valueOf(finalValue.setScale(2)) +
      '"],"fontSize":10}' +
      ']},';

    String chartConfig =
      '{"type":"bar","data":{"labels":' +
      JSON.serialize(years) +
      ',"datasets":[{"data":' +
      JSON.serialize(saldoData) +
      ',"backgroundColor":' +
      JSON.serialize(colors) +
      ',"borderColor":' +
      JSON.serialize(colors) +
      ',"borderWidth":1}]},' +
      '"options":{' +
      annotations +
      '"plugins":{"annotation":true},' +
      '"legend":{"display":false},"scales":{"xAxes":[{"ticks":{"fontSize":8}}],"yAxes":[{"ticks":{"beginAtZero":true,"fontSize":8}}]}}}';

    String encodedChartConfig = EncodingUtil.urlEncode(chartConfig, 'UTF-8');

    String chartSize = 'width=350&height=200';

    String chartUrl = baseUrl + chartSize + '&c=' + encodedChartConfig;

    return '<img src="' + chartUrl + '" />';
  }
}
