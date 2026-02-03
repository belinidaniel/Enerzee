/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-26-2026
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

    public String getOpportunityChartImageB() {
        return generateOpportunityChartImageB(this.opportunity.Id);
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

    public static String generateOpportunityChartImageB(Id opportunityId) {
        Opportunity opp = [SELECT Id, CreatedDate, ValorTotalProposta__c, EconomiaAnualEstimada__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        Integer startYear = opp.CreatedDate.year();
        Decimal investimento = opp.ValorTotalProposta__c != null ? opp.ValorTotalProposta__c : 0;
        Decimal economia = opp.EconomiaAnualEstimada__c != null ? opp.EconomiaAnualEstimada__c : 0;

        List<String> years = new List<String>();
        List<Decimal> saldoAcumulado = new List<Decimal>();
        List<String> colors = new List<String>();

        Decimal saldo = -investimento;
        for (Integer year = startYear; year <= startYear + 24; year++) {
            saldo += economia;
            years.add(String.valueOf(year));
            saldoAcumulado.add(saldo);

            if (saldo < 0) {
                colors.add('rgb(39, 64, 97)');
            } else {
                colors.add('rgb(168, 206, 140)');
            }
        }

        return generateQuickChartImageUrlB(years, saldoAcumulado, colors, investimento);
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

    public static String generateQuickChartImageUrlB(List<String> years, List<Decimal> saldoData, List<String> colors, Decimal investimento) {
        String baseUrl = 'https://quickchart.io/chart?';

        Map<Integer, String> labelMap = new Map<Integer, String>();

        if (!years.isEmpty() && !saldoData.isEmpty()) {
            Integer startYear = Integer.valueOf(years[0]);
            Integer highlightYear = startYear + 8;
            Integer highlightIndex = years.indexOf(String.valueOf(highlightYear));
            if (highlightIndex >= 0) {
                Decimal highlightValue = saldoData[highlightIndex];
                labelMap.put(highlightIndex, 'R$ ' + formatCurrencyPtBr(highlightValue));
            }

            Integer finalIndex = saldoData.size() - 1;
            Decimal finalValue = saldoData[finalIndex];
            labelMap.put(finalIndex, 'R$ ' + formatCurrencyPtBr(finalValue));

            // Removido label do investimento inicial (primeira barra negativa)
        }

        String labelMapJson = JSON.serialize(labelMap);
        String dataLabelFormatter = 'function(value, context){' +
            'var labels=' + labelMapJson + ';' +
            'return labels[context.dataIndex] ? labels[context.dataIndex] : \"\";' +
        '}';
        String dataLabelAlign = 'function(context){' +
            'var v=context.dataset.data[context.dataIndex];' +
            'return v < 0 ? \"bottom\" : \"top\";' +
        '}';
        String dataLabelAnchor = 'function(context){' +
            'var v=context.dataset.data[context.dataIndex];' +
            'return v < 0 ? \"start\" : \"end\";' +
        '}';

        String tickCallback = 'function(value){' +
            'if(value === 0){return \'R$ -\';}' +
            'var absValue = Math.abs(value);' +
            'var formatted = absValue.toLocaleString(\'pt-BR\', {minimumFractionDigits:2, maximumFractionDigits:2});' +
            'return (value < 0 ? \'-R$ \' : \'R$ \') + formatted;' +
        '}';

        String chartConfig = '{"type":"bar","data":{"labels":' + JSON.serialize(years) +
            ',"datasets":[{"data":' + JSON.serialize(saldoData) +
            ',"backgroundColor":' + JSON.serialize(colors) +
            ',"borderColor":' + JSON.serialize(colors) +
            ',"borderWidth":0}]},' +
            '"options":{' +
            '"plugins":{"datalabels":{"color":"#5b6b7b","font":{"size":7},"formatter":' + dataLabelFormatter + ',"align":' + dataLabelAlign + ',"anchor":' + dataLabelAnchor + ',"clamp":true,"clip":false}},' +
            '"legend":{"display":false},' +
            '"layout":{"padding":{"top":18,"right":28,"left":10,"bottom":0}},' +
            '"scales":{' +
                '"xAxes":[{"ticks":{"fontSize":8,"fontColor":"#2f3f59","maxRotation":0,"minRotation":0,"autoSkip":true,"maxTicksLimit":10,"padding":4},"gridLines":{"display":false}}],' +
                '"yAxes":[{"ticks":{"fontSize":8,"fontColor":"#2f3f59","padding":6,"callback":' + tickCallback + '},' +
                '"gridLines":{"color":"#e3e9f2","zeroLineColor":"#c8d2e3"}}]' +
            '}}}';

        String encodedChartConfig = EncodingUtil.urlEncode(chartConfig, 'UTF-8');
        String chartSize = 'width=370&height=180';
        String chartUrl = baseUrl + chartSize + '&c=' + encodedChartConfig + '&plugins=datalabels';

        return '<img src="' + chartUrl + '" />';
    }

    private static String formatCurrencyPtBr(Decimal value) {
        if (value == null) {
            return '0,00';
        }

        Decimal absValue = value.abs().setScale(2, RoundingMode.HALF_UP);
        Long integerPart = (Long)absValue.setScale(0, RoundingMode.FLOOR);
        Integer cents = Integer.valueOf(((absValue - integerPart) * 100).setScale(0, RoundingMode.HALF_UP));

        String integerString = String.valueOf(integerPart);
        String formattedInteger = '';
        while (integerString.length() > 3) {
            formattedInteger = '.' + integerString.substring(integerString.length() - 3) + formattedInteger;
            integerString = integerString.substring(0, integerString.length() - 3);
        }
        formattedInteger = integerString + formattedInteger;

        String centsString = String.valueOf(cents).leftPad(2, '0');
        String sign = value < 0 ? '-' : '';
        return sign + formattedInteger + ',' + centsString;
    }
}
