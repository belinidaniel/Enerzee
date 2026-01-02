/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-06-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class OpportunityDataController {
    private final Opportunity opportunity;

    // Constructor
    public OpportunityDataController(ApexPages.StandardController controller) {
        this.opportunity = (Opportunity)controller.getRecord();
    }

    public String getOpportunityChartImage() {
        return generateOpportunityChartImage(this.opportunity.Id);
    }

    public static String generateOpportunityChartImage(Id opportunityId) {
        // Fetch opportunity data
        Opportunity opp = [SELECT Id, CreatedDate, ValorTotalProposta__c, EconomiaAnualEstimada__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        Integer startYear = opp.CreatedDate.year();
        Decimal investimento = opp.ValorTotalProposta__c != null ? -opp.ValorTotalProposta__c : 0;
        Decimal economia = opp.EconomiaAnualEstimada__c != null ? opp.EconomiaAnualEstimada__c : 0;

        List<String> years = new List<String>();
        List<Decimal> saldoAcumulado = new List<Decimal>();
        List<String> colors = new List<String>();

        Decimal saldo = investimento;
        for (Integer year = startYear; year <= startYear + 25; year++) {
            years.add(String.valueOf(year));
            saldoAcumulado.add(saldo);

            // Cores: azul para negativo, verde para positivo
            if (saldo < 0) {
                colors.add('rgb(0, 51, 102)'); // azul escuro
            } else {
                colors.add('rgb(153, 204, 102)'); // verde claro
            }

            saldo += economia;
        }

        String chartImageUrl = generateQuickChartImageUrl(years, saldoAcumulado, colors);
        return chartImageUrl;
    }

    @AuraEnabled(cacheable=true)
    public static String generateQuickChartImageUrl(List<String> years, List<Decimal> saldoData, List<String> colors) {
        String baseUrl = 'https://quickchart.io/chart?';

        // Índices dos anos para anotar
        Integer vplYear = 2032;
        Integer vplIndex = years.indexOf(String.valueOf(vplYear));
        Decimal vplValue = vplIndex >= 0 ? saldoData[vplIndex] : 0;

        Integer finalIndex = saldoData.size() - 1;
        Decimal finalValue = saldoData[finalIndex];
        String finalYear = years[finalIndex];

        // Annotations para VPL e valor final
        String annotations = 
            '"annotations":{"annotations":[' +
            '{"type":"label","xScaleID":"x-axis-0","xValue":"' + String.valueOf(vplYear) + '","yValue":' + String.valueOf(vplValue) + ',"backgroundColor":"rgba(0,0,0,0.1)","content":["R$ ' + String.valueOf(vplValue.setScale(2)) + '"],"fontSize":10},' +
            '{"type":"label","xScaleID":"x-axis-0","xValue":"' + finalYear + '","yValue":' + String.valueOf(finalValue) + ',"backgroundColor":"rgba(0,0,0,0.1)","content":["R$ ' + String.valueOf(finalValue.setScale(2)) + '"],"fontSize":10}' +
            ']},';

    String chartConfig = '{"type":"bar","data":{"labels":' + JSON.serialize(years) + 
    ',"datasets":[{"data":' + JSON.serialize(saldoData) + 
    ',"backgroundColor":' + JSON.serialize(colors) + 
    ',"borderColor":' + JSON.serialize(colors) + ',"borderWidth":1}]},' +
    '"options":{' + annotations +
    '"plugins":{"annotation":true},' +
    '"legend":{"display":false},"scales":{"xAxes":[{"ticks":{"fontSize":8}}],"yAxes":[{"ticks":{"beginAtZero":true,"fontSize":8}}]}}}';

        String encodedChartConfig = EncodingUtil.urlEncode(chartConfig, 'UTF-8');

        String chartSize = 'width=350&height=200';

        String chartUrl = baseUrl + chartSize + '&c=' + encodedChartConfig;

        return '<img src="' + chartUrl + '" />';
    }
}