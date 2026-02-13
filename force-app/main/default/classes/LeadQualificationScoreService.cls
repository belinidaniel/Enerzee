/**
 * @description       : Calcula score do lead com base em metadata (fallback para regra legada quando nao parametrizado).
 * @author            :
 * @group             :
 * @last modified on  : 02-13-2026
 * @last modified by  :
**/
public with sharing class LeadQualificationScoreService {
    private static final String TARGET_VERSION = '2026';
    private static final String CATEGORY_LEAD_VALUE = 'LeadValue';
    private static final String CATEGORY_LEAD_SOURCE = 'LeadSource';
    private static final String CATEGORY_LEAD_PRODUCT = 'LeadProduct';

    @TestVisible
    private static Boolean disableMetadataForTest = false;
    @TestVisible
    private static ScoreCatalog cachedCatalog;

    public class Request {
        @InvocableVariable(required = true)
        public Id leadId;
    }

    private class RuleRow {
        String category;
        String matchType;
        String matchValue;
        Decimal points;
        Integer priority;
    }

    private class ThresholdRow {
        Decimal minScore;
        Decimal maxScore;
        String rating;
        Integer priority;
    }

    private class ScoreCatalog {
        Map<String, List<RuleRow>> rulesByCategory = new Map<String, List<RuleRow>>();
        List<ThresholdRow> thresholds = new List<ThresholdRow>();
        Boolean usingMetadata = false;
    }

    private class ScoreResult {
        Decimal total;
        String rating;
    }

    @InvocableMethod(label = 'Calculate Lead Qualification Score' description = 'Calcula score e classificação do lead com regras metadata-driven.')
    public static void calculateScore(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Request requestItem : requests) {
            if (requestItem != null && requestItem.leadId != null) {
                leadIds.add(requestItem.leadId);
            }
        }
        if (leadIds.isEmpty()) {
            return;
        }

        List<Lead> leads = [
            SELECT Id, LeadSource, CustoEnergiaMes__c, Lb065_ProdutoInteresse__c, Lb065_PontuacaoOrigem__c, Rating
            FROM Lead
            WHERE Id IN :leadIds
        ];

        ScoreCatalog catalog = getCatalog();
        List<Lead> updates = new List<Lead>();

        for (Lead lead : leads) {
            ScoreResult result = scoreLead(lead, catalog);
            if (result == null) {
                continue;
            }

            Boolean shouldUpdate = lead.Lb065_PontuacaoOrigem__c != result.total || lead.Rating != result.rating;
            if (!shouldUpdate) {
                continue;
            }

            updates.add(new Lead(
                Id = lead.Id,
                Lb065_PontuacaoOrigem__c = result.total,
                Rating = result.rating
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static ScoreResult scoreLead(Lead lead, ScoreCatalog catalog) {
        if (lead == null || catalog == null) {
            return null;
        }

        Decimal valuePoints = findPoints(CATEGORY_LEAD_VALUE, lead.CustoEnergiaMes__c, catalog.rulesByCategory);
        Decimal sourcePoints = findPoints(CATEGORY_LEAD_SOURCE, lead.LeadSource, catalog.rulesByCategory);
        Decimal productPoints = findPoints(CATEGORY_LEAD_PRODUCT, lead.Lb065_ProdutoInteresse__c, catalog.rulesByCategory);

        Decimal totalScore = valuePoints + sourcePoints + productPoints;
        String rating = resolveRating(totalScore, catalog.thresholds);

        ScoreResult result = new ScoreResult();
        result.total = totalScore;
        result.rating = rating;
        return result;
    }

    private static Decimal findPoints(String category, String candidateValue, Map<String, List<RuleRow>> rulesByCategory) {
        List<RuleRow> rules = rulesByCategory.get(category);
        if (rules == null || rules.isEmpty() || String.isBlank(candidateValue)) {
            return 0;
        }

        String normalizedCandidate = normalize(candidateValue);
        for (RuleRow rule : rules) {
            if (rule == null || String.isBlank(rule.matchValue)) {
                continue;
            }

            String normalizedRule = normalize(rule.matchValue);
            if (String.isBlank(normalizedRule)) {
                continue;
            }

            if (rule.matchType == 'Contains' && normalizedCandidate.contains(normalizedRule)) {
                return rule.points != null ? rule.points : 0;
            }
            if ((rule.matchType == null || rule.matchType == 'Equals') && normalizedCandidate == normalizedRule) {
                return rule.points != null ? rule.points : 0;
            }
        }

        return 0;
    }

    private static String resolveRating(Decimal totalScore, List<ThresholdRow> thresholds) {
        if (thresholds == null || thresholds.isEmpty()) {
            return null;
        }
        for (ThresholdRow threshold : thresholds) {
            if (threshold == null || threshold.minScore == null) {
                continue;
            }

            Boolean matchesMin = totalScore >= threshold.minScore;
            Boolean matchesMax = threshold.maxScore == null || totalScore <= threshold.maxScore;
            if (matchesMin && matchesMax) {
                return threshold.rating;
            }
        }
        return null;
    }

    private static ScoreCatalog getCatalog() {
        if (cachedCatalog != null) {
            return cachedCatalog;
        }

        if (!disableMetadataForTest) {
            ScoreCatalog metadataCatalog = loadMetadataCatalog();
            if (metadataCatalog != null && metadataCatalog.usingMetadata) {
                cachedCatalog = metadataCatalog;
                return cachedCatalog;
            }
        }

        cachedCatalog = buildFallbackCatalog();
        return cachedCatalog;
    }

    private static ScoreCatalog loadMetadataCatalog() {
        ScoreCatalog catalog = new ScoreCatalog();

        List<Lead_Score_Rule__mdt> rules = [
            SELECT Category__c, MatchType__c, MatchValue__c, Points__c, Priority__c
            FROM Lead_Score_Rule__mdt
            WHERE Active__c = true
                AND Version__c = :TARGET_VERSION
            ORDER BY Category__c ASC, Priority__c ASC
        ];

        List<Lead_Score_Threshold__mdt> thresholds = [
            SELECT MinScore__c, MaxScore__c, Rating__c, Priority__c
            FROM Lead_Score_Threshold__mdt
            WHERE Active__c = true
                AND Version__c = :TARGET_VERSION
            ORDER BY Priority__c ASC
        ];

        if (rules.isEmpty() || thresholds.isEmpty()) {
            return catalog;
        }

        for (Lead_Score_Rule__mdt row : rules) {
            RuleRow rule = new RuleRow();
            rule.category = row.Category__c;
            rule.matchType = row.MatchType__c;
            rule.matchValue = row.MatchValue__c;
            rule.points = row.Points__c;
            rule.priority = row.Priority__c != null ? Integer.valueOf(row.Priority__c) : 0;

            if (!catalog.rulesByCategory.containsKey(rule.category)) {
                catalog.rulesByCategory.put(rule.category, new List<RuleRow>());
            }
            catalog.rulesByCategory.get(rule.category).add(rule);
        }

        for (Lead_Score_Threshold__mdt row : thresholds) {
            ThresholdRow threshold = new ThresholdRow();
            threshold.minScore = row.MinScore__c;
            threshold.maxScore = row.MaxScore__c;
            threshold.rating = row.Rating__c;
            threshold.priority = row.Priority__c != null ? Integer.valueOf(row.Priority__c) : 0;
            catalog.thresholds.add(threshold);
        }

        catalog.usingMetadata = true;
        return catalog;
    }

    private static ScoreCatalog buildFallbackCatalog() {
        ScoreCatalog catalog = new ScoreCatalog();

        addRule(catalog, CATEGORY_LEAD_VALUE, 'Equals', 'até R$ 300', 2, 1);
        addRule(catalog, CATEGORY_LEAD_VALUE, 'Equals', 'até R$ 300 a R$ 500', 5, 2);
        addRule(catalog, CATEGORY_LEAD_VALUE, 'Equals', 'de R$ 500 a R$ 1.000', 10, 3);
        addRule(catalog, CATEGORY_LEAD_VALUE, 'Equals', 'mais de R$ 1.000', 15, 4);
        addRule(catalog, CATEGORY_LEAD_VALUE, 'Equals', 'acima de R$ 5.000', 20, 5);

        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Customer Event', 10, 1);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Employee Referral', 10, 2);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Partner', 10, 3);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Webinar', 10, 4);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Trade Show', 10, 5);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Website', 10, 6);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'WhatsApp via botão no site / link direto', 10, 7);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Facebook Consultor - Empreenda', 6, 8);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Facebook Consultor - Reunião Online', 6, 9);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Facebook Super Black - Consumidor Final', 6, 10);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Advertisement', 6, 11);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Google AdWords', 6, 12);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Anúncio patrocinado com preenchimento completo', 6, 13);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Quero Ser Enerzee', 3, 14);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Nivello', 3, 15);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Purchased List', 3, 16);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Web-To-Lead Integrador', 3, 17);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Web-To-Lead Cliente', 3, 18);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Acesso direto ao site ou via busca orgânica', 3, 19);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Other', 1, 20);
        addRule(catalog, CATEGORY_LEAD_SOURCE, 'Equals', 'Base antiga sem nova ação', 1, 21);

        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Ezee Connect', 10, 1);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Ezee Livre', 10, 2);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Ezee Solar', 10, 3);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Solar', 10, 4);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Baterias', 10, 5);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Carregador veicular', 10, 6);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Interesse genérico em energia solar', 5, 7);
        addRule(catalog, CATEGORY_LEAD_PRODUCT, 'Equals', 'Não indicou ou não soube informar', 2, 8);

        addThreshold(catalog, 0, 25, 'Cold', 1);
        addThreshold(catalog, 26, 40, 'Warm', 2);
        addThreshold(catalog, 41, 55, 'Hot', 3);
        addThreshold(catalog, 56, null, 'Prioritário', 4);

        return catalog;
    }

    private static void addRule(ScoreCatalog catalog, String category, String matchType, String matchValue, Decimal points, Integer priority) {
        if (catalog == null) {
            return;
        }

        RuleRow rule = new RuleRow();
        rule.category = category;
        rule.matchType = matchType;
        rule.matchValue = matchValue;
        rule.points = points;
        rule.priority = priority;

        if (!catalog.rulesByCategory.containsKey(category)) {
            catalog.rulesByCategory.put(category, new List<RuleRow>());
        }
        catalog.rulesByCategory.get(category).add(rule);
    }

    private static void addThreshold(ScoreCatalog catalog, Decimal minScore, Decimal maxScore, String rating, Integer priority) {
        if (catalog == null) {
            return;
        }

        ThresholdRow threshold = new ThresholdRow();
        threshold.minScore = minScore;
        threshold.maxScore = maxScore;
        threshold.rating = rating;
        threshold.priority = priority;
        catalog.thresholds.add(threshold);
    }

    private static String normalize(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.toUpperCase();
        normalized = normalized
            .replace('Á', 'A').replace('À', 'A').replace('Â', 'A').replace('Ã', 'A')
            .replace('É', 'E').replace('Ê', 'E')
            .replace('Í', 'I')
            .replace('Ó', 'O').replace('Ô', 'O').replace('Õ', 'O')
            .replace('Ú', 'U')
            .replace('Ç', 'C')
            .replace('-', ' ')
            .replace('_', ' ');
        return normalized.replaceAll('\\s+', ' ').trim();
    }
}
