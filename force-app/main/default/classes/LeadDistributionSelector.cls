/**
 * @description       : Seleciona o consultor correto para um Lead e atualiza o "ultimo lead recebido"
 *                      com lock de linha para evitar concorrencia.
 * @author            :
 * @group             :
 * @last modified on  : 01-27-2026
 * @last modified by  :
**/
public with sharing class LeadDistributionSelector {

    private static final Integer LOCK_BATCH_SIZE = 5;
    private static final Integer CANDIDATE_QUERY_LIMIT = 200;
    private static final String FIELD_DISTRIBUTION_TYPE = 'Distributiontype__c';
    private static final String FIELD_DISTRIBUTION_VALUE = 'DistributionValue__c';
    private static final String FIELD_LEAD_REGION = 'LeadRegion__c';
    private static final String FIELD_CONSULTOR_REGIONAL = 'ConsultorRegional__c';
    private static final String FIELD_EMAIL_CONSULTOR = 'EmailConsultor__c';
    private static final String FIELD_META_LEAD = 'MetaLead__c';
    private static final String FIELD_CAMPAIGN_META = 'Nome_da_Campanha_Meta__c';
    private static final String FIELD_ADSET_META = 'Nome_do_Conjunto_de_An_ncios_Meta__c';
    private static final String FIELD_AD_META = 'Nome_do_An_ncio_Meta__c';
    private static final Set<String> GRADS_WARM_STATE = new Set<String>{'Advanced Builder', 'Builder'};
    private static final Set<String> GRADS_HOT_STATE = new Set<String>{'Platinum', 'Gold'};
    private static final Set<String> GRADS_PRIOR_STATE = new Set<String>{'Diamond', 'Carbon Diamond'};
    private static final Set<String> GRADS_WARM_NO_STATE = new Set<String>{'Advisor', 'Builder'};
    private static final Set<String> GRADS_HOT_NO_STATE = new Set<String>{'Advanced Builder', 'Gold'};
    private static final Set<String> GRADS_PRIOR_NO_STATE = new Set<String>{'Platinum', 'Diamond', 'Carbon Diamond'};
    private static final Set<String> B2B_KEYWORDS = new Set<String>{'B2B', 'BESS'};
    private static final Id QUALIFICACAO_CONSULTORES_RT = getLeadRecordTypeId('QualificacaodeConsultores');
    private static Map<String, Schema.SObjectField> leadFieldMapCache;

    private static final Map<String, String> STATE_NAME_TO_CODE = new Map<String, String>{
        'ACRE' => 'AC',
        'ALAGOAS' => 'AL',
        'AMAPA' => 'AP',
        'AMAZONAS' => 'AM',
        'BAHIA' => 'BA',
        'CEARA' => 'CE',
        'DISTRITO FEDERAL' => 'DF',
        'ESPIRITO SANTO' => 'ES',
        'GOIAS' => 'GO',
        'MARANHAO' => 'MA',
        'MATO GROSSO' => 'MT',
        'MATO GROSSO DO SUL' => 'MS',
        'MINAS GERAIS' => 'MG',
        'PARA' => 'PA',
        'PARAIBA' => 'PB',
        'PARANA' => 'PR',
        'PERNAMBUCO' => 'PE',
        'PIAUI' => 'PI',
        'RIO DE JANEIRO' => 'RJ',
        'RIO GRANDE DO NORTE' => 'RN',
        'RIO GRANDE DO SUL' => 'RS',
        'RONDONIA' => 'RO',
        'RORAIMA' => 'RR',
        'SANTA CATARINA' => 'SC',
        'SAO PAULO' => 'SP',
        'SERGIPE' => 'SE',
        'TOCANTINS' => 'TO'
    };

    public class Request {
        @InvocableVariable(required = true)
        public Id leadId;
    }

    public class Response {
        @InvocableVariable
        public Id consultantId;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label = 'Select Consultant For Lead (Locked)' description = 'Seleciona o consultor para o Lead e atualiza o último lead recebido usando lock de linha.')
    public static List<Response> selectConsultant(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.leadId != null) {
                leadIds.add(req.leadId);
            }
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
            List<String> selectFields = new List<String>{'Id', 'State', 'City', 'Rating', 'LeadSource', 'RecordTypeId', 'SDRAgent__c'};
            addFieldIfExists(selectFields, leadFieldMap, 'Estado__c');
            addFieldIfExists(selectFields, leadFieldMap, 'Cidade__c');
            addFieldIfExists(selectFields, leadFieldMap, FIELD_DISTRIBUTION_TYPE);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_DISTRIBUTION_VALUE);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_LEAD_REGION);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_CONSULTOR_REGIONAL);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_EMAIL_CONSULTOR);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_META_LEAD);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_CAMPAIGN_META);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_ADSET_META);
            addFieldIfExists(selectFields, leadFieldMap, FIELD_AD_META);

            String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Lead WHERE Id IN :leadIds';
            List<Lead> leads = (List<Lead>) Database.query(soql);
            leadMap = new Map<Id, Lead>(leads);
        }

        for (Request req : requests) {
            Response res = new Response();
            Lead lead = req != null ? leadMap.get(req.leadId) : null;
            if (lead == null) {
                res.message = 'Lead nao encontrado.';
                results.add(res);
                continue;
            }

            try {
                res.consultantId = selectConsultantForLead(lead);
            } catch (Exception ex) {
                res.message = ex.getMessage();
            }

            results.add(res);
        }

        return results;
    }

    public static List<Id> selectConsultantsForLeadRecords(List<Lead> leads) {
        List<Id> selected = new List<Id>();
        if (leads == null || leads.isEmpty()) {
            return selected;
        }
        for (Lead lead : leads) {
            selected.add(selectConsultantForLead(lead));
        }
        return selected;
    }

    public static Boolean isConsultorLeadCandidate(Lead lead) {
        if (lead == null) {
            return false;
        }
        if (QUALIFICACAO_CONSULTORES_RT != null && lead.RecordTypeId == QUALIFICACAO_CONSULTORES_RT) {
            return true;
        }
        String normalizedSource = normalizeText(lead.LeadSource);
        if (normalizedSource.contains('WEB TO LEAD CONSULTOR') || normalizedSource.contains('WEBTOLEAD CONSULTOR')) {
            return true;
        }
        return lead.SDRAgent__c && QUALIFICACAO_CONSULTORES_RT != null && lead.RecordTypeId == QUALIFICACAO_CONSULTORES_RT;
    }

    public static Boolean isB2BLeadCandidate(Lead lead) {
        if (lead == null) {
            return false;
        }
        if (getLeadStringValue(lead, FIELD_DISTRIBUTION_TYPE) == 'B2B') {
            return true;
        }

        String normalizedSource = normalizeText(lead.LeadSource);
        String normalizedCampaign = normalizeText(getLeadStringValue(lead, FIELD_CAMPAIGN_META));
        String normalizedAdset = normalizeText(getLeadStringValue(lead, FIELD_ADSET_META));
        String normalizedAd = normalizeText(getLeadStringValue(lead, FIELD_AD_META));
        String stack = normalizedSource + ' ' + normalizedCampaign + ' ' + normalizedAdset + ' ' + normalizedAd;

        for (String keyword : B2B_KEYWORDS) {
            if (stack.contains(keyword)) {
                return true;
            }
        }
        return false;
    }

    private static Id selectConsultantForLead(Lead lead) {
        if (lead == null) {
            return null;
        }

        Id selectedId;
        String distributionType = getLeadStringValue(lead, FIELD_DISTRIBUTION_TYPE);
        String distributionValue = getLeadStringValue(lead, FIELD_DISTRIBUTION_VALUE);
        String leadRegion = getLeadStringValue(lead, FIELD_LEAD_REGION);
        Id consultorRegionalId = getLeadIdValue(lead, FIELD_CONSULTOR_REGIONAL);

        selectedId = selectByMetaConsultantEmail(lead);
        if (selectedId != null) {
            return selectedId;
        }

        if (isB2BLeadCandidate(lead)) {
            return selectB2BByGeoPriority(lead);
        }

        if (isConsultorLeadCandidate(lead)) {
            return selectConsultorLeadByGeoPriority(lead);
        }

        if (distributionType == 'Email') {
            selectedId = selectByEmail(distributionValue);
            if (selectedId != null) {
                return selectedId;
            }
        } else if (distributionType == 'Graduação') {
            selectedId = selectByGraduation(distributionValue);
            if (selectedId != null) {
                return selectedId;
            }
        }

        if (!String.isBlank(lead.State)) {
            if (isColdOrWarm(lead.Rating)) {
                selectedId = selectByState(lead);
                if (selectedId != null) {
                    return selectedId;
                }
                selectedId = selectWarmFilter(leadRegion, consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                selectedId = selectHotFilter(leadRegion, consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                selectedId = selectPrioritarioFilter(consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                return selectNoState(lead);
            }

            if (lead.Rating == 'Hot') {
                selectedId = selectHotFilter(leadRegion, consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                selectedId = selectPrioritarioFilter(consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                return selectNoState(lead);
            }

            if (lead.Rating == 'Prioritário') {
                selectedId = selectPrioritarioFilter(consultorRegionalId, lead.Rating);
                if (selectedId != null) {
                    return selectedId;
                }
                return selectNoState(lead);
            }
        }

        return selectNoState(lead);
    }

    private static Id selectByMetaConsultantEmail(Lead lead) {
        String consultantEmailRaw = getLeadStringValue(lead, FIELD_EMAIL_CONSULTOR);
        if (lead == null || String.isBlank(consultantEmailRaw) || !isMetaSourceLead(lead)) {
            return null;
        }

        String consultantEmail = consultantEmailRaw != null ? consultantEmailRaw.trim() : null;
        if (String.isBlank(consultantEmail)) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Email__c = :consultantEmail
                AND Ativo__c = true
                AND SendLead__c = true
                AND FreezeConsult__c = false
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectConsultorLeadByGeoPriority(Lead lead) {
        List<Consultor__c> candidates = [
            SELECT
                Id,
                Lb065_UltimoLeadRecebido__c,
                Estado__c,
                Municipio__c,
                Lb65_Graduacao__c,
                ConsultantDeadlineRange__c,
                SpecialRange__c
            FROM Consultor__c
            WHERE Ativo__c = true
                AND SendLead__c = true
                AND FreezeConsult__c = false
                AND ReceiveLeadConsultor__c = true
                AND (SpecialRange__c != null OR ConsultantDeadlineRange__c = '3')
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :CANDIDATE_QUERY_LIMIT
        ];

        List<Consultor__c> eligible = new List<Consultor__c>();
        for (Consultor__c candidate : candidates) {
            if (candidate == null) {
                continue;
            }
            if (!String.isBlank(candidate.SpecialRange__c)) {
                eligible.add(candidate);
                continue;
            }
            if (candidate.ConsultantDeadlineRange__c == '3' && isGoldPlusOrEquivalent(candidate.Lb65_Graduacao__c)) {
                eligible.add(candidate);
            }
        }

        return selectByGeoPriority(lead, eligible);
    }

    private static Id selectB2BByGeoPriority(Lead lead) {
        List<Consultor__c> candidates = [
            SELECT
                Id,
                Lb065_UltimoLeadRecebido__c,
                Estado__c,
                Municipio__c
            FROM Consultor__c
            WHERE Ativo__c = true
                AND SendLead__c = true
                AND FreezeConsult__c = false
                AND ReceiveB2BLead__c = true
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :CANDIDATE_QUERY_LIMIT
        ];

        return selectByGeoPriority(lead, candidates);
    }

    private static Id selectByGeoPriority(Lead lead, List<Consultor__c> candidates) {
        if (lead == null || candidates == null || candidates.isEmpty()) {
            return null;
        }

        String leadCity = normalizeText(getLeadCity(lead));
        String leadState = normalizeStateCode(getLeadState(lead));

        if (!String.isBlank(leadCity) && !String.isBlank(leadState)) {
            List<Consultor__c> sameCityAndState = new List<Consultor__c>();
            for (Consultor__c candidate : candidates) {
                if (candidate == null) {
                    continue;
                }
                if (matchesState(candidate.Estado__c, leadState) && matchesCity(candidate.Municipio__c, leadCity)) {
                    sameCityAndState.add(candidate);
                }
            }
            Id selected = lockAndUpdate(limitCandidates(sameCityAndState));
            if (selected != null) {
                return selected;
            }
        }

        if (!String.isBlank(leadState)) {
            List<Consultor__c> sameState = new List<Consultor__c>();
            for (Consultor__c candidate : candidates) {
                if (candidate == null) {
                    continue;
                }
                if (matchesState(candidate.Estado__c, leadState)) {
                    sameState.add(candidate);
                }
            }
            Id selected = lockAndUpdate(limitCandidates(sameState));
            if (selected != null) {
                return selected;
            }
        }

        return lockAndUpdate(limitCandidates(candidates));
    }

    private static String getLeadCity(Lead lead) {
        if (lead == null) {
            return null;
        }
        if (!String.isBlank(lead.City)) {
            return lead.City;
        }
        return lead.Cidade__c;
    }

    private static String getLeadState(Lead lead) {
        if (lead == null) {
            return null;
        }
        if (!String.isBlank(lead.State)) {
            return lead.State;
        }
        return lead.Estado__c;
    }

    private static Boolean matchesCity(String consultantCity, String leadCityNormalized) {
        if (String.isBlank(consultantCity) || String.isBlank(leadCityNormalized)) {
            return false;
        }
        return normalizeText(consultantCity) == leadCityNormalized;
    }

    private static Boolean matchesState(String consultantState, String leadStateNormalized) {
        if (String.isBlank(consultantState) || String.isBlank(leadStateNormalized)) {
            return false;
        }
        return normalizeStateCode(consultantState) == leadStateNormalized;
    }

    private static List<Consultor__c> limitCandidates(List<Consultor__c> candidates) {
        if (candidates == null || candidates.isEmpty()) {
            return new List<Consultor__c>();
        }
        Integer toIndex = Math.min(candidates.size(), LOCK_BATCH_SIZE);
        List<Consultor__c> limited = new List<Consultor__c>();
        for (Integer idx = 0; idx < toIndex; idx++) {
            limited.add(candidates[idx]);
        }
        return limited;
    }

    private static Boolean isMetaSourceLead(Lead lead) {
        if (lead == null) {
            return false;
        }
        if (getLeadStringValue(lead, FIELD_META_LEAD) == 'Sim') {
            return true;
        }
        return !String.isBlank(getLeadStringValue(lead, FIELD_CAMPAIGN_META))
            || !String.isBlank(getLeadStringValue(lead, FIELD_ADSET_META))
            || !String.isBlank(getLeadStringValue(lead, FIELD_AD_META));
    }

    private static Boolean isGoldPlusOrEquivalent(String graduation) {
        if (String.isBlank(graduation)) {
            return false;
        }
        String normalized = normalizeText(graduation);
        return normalized.contains('GOLD')
            || normalized.contains('OURO')
            || normalized.contains('PLATINUM')
            || normalized.contains('PLATINA')
            || normalized.contains('DIAMOND')
            || normalized.contains('DIAMANTE');
    }

    private static String normalizeStateCode(String stateValue) {
        String normalized = normalizeText(stateValue);
        if (String.isBlank(normalized)) {
            return null;
        }

        if (normalized.length() == 2 && normalized == normalized.replaceAll('[^A-Z]', '')) {
            return normalized;
        }

        List<String> parts = normalized.split(' ');
        for (Integer idx = parts.size() - 1; idx >= 0; idx--) {
            String token = parts[idx];
            if (token.length() == 2 && token == token.replaceAll('[^A-Z]', '')) {
                return token;
            }
        }

        if (STATE_NAME_TO_CODE.containsKey(normalized)) {
            return STATE_NAME_TO_CODE.get(normalized);
        }

        return normalized;
    }

    private static String normalizeText(String rawValue) {
        if (String.isBlank(rawValue)) {
            return '';
        }
        String normalized = rawValue.toUpperCase();
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

    private static Id getLeadRecordTypeId(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }
        Schema.RecordTypeInfo info = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get(developerName);
        return info != null ? info.getRecordTypeId() : null;
    }

    private static Boolean isColdOrWarm(String rating) {
        return rating == 'Cold' || rating == 'Warm';
    }

    private static void addFieldIfExists(List<String> selectFields, Map<String, Schema.SObjectField> fieldMap, String fieldName) {
        if (selectFields == null || fieldMap == null || String.isBlank(fieldName)) {
            return;
        }
        if (fieldMap.containsKey(fieldName)) {
            selectFields.add(fieldName);
        }
    }

    private static String getLeadStringValue(Lead lead, String fieldName) {
        if (lead == null || String.isBlank(fieldName)) {
            return null;
        }
        if (!getLeadFieldMap().containsKey(fieldName)) {
            return null;
        }
        Object rawValue = lead.get(fieldName);
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private static Id getLeadIdValue(Lead lead, String fieldName) {
        String rawValue = getLeadStringValue(lead, fieldName);
        if (String.isBlank(rawValue)) {
            return null;
        }
        return (Id) rawValue;
    }

    private static Map<String, Schema.SObjectField> getLeadFieldMap() {
        if (leadFieldMapCache == null) {
            leadFieldMapCache = Schema.SObjectType.Lead.fields.getMap();
        }
        return leadFieldMapCache;
    }

    private static Id selectByEmail(String distributionValue) {
        List<String> emails = splitCsv(distributionValue);
        if (emails.isEmpty()) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Email__c IN :emails
            AND Ativo__c = true
            AND SendLead__c = true
            AND FreezeConsult__c = false
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectByGraduation(String distributionValue) {
        List<String> graduations = splitCsv(distributionValue);
        if (graduations.isEmpty()) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Lb65_Graduacao__c IN :graduations
            AND Ativo__c = true
            AND SendLead__c = true
            AND FreezeConsult__c = false
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectByState(Lead lead) {
        if (String.isBlank(lead.State)) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Estado__c = :lead.State
            AND Ativo__c = true
            AND SendLead__c = true
            AND FreezeConsult__c = false
            AND (Lb65_Graduacao__c IN :GRADS_WARM_STATE
                OR (SpecialRange__c = :lead.Rating AND SpecialRange__c != null))
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectWarmFilter(String leadRegion, Id consultorRegionalId, String rating) {
        if (String.isBlank(leadRegion)) {
            return null;
        }

        String regionLike = '%' + leadRegion + '%';
        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Lb065_RegiaoConsultorEstado__c LIKE :regionLike
            AND (Lb65_Graduacao__c IN :GRADS_WARM_STATE
                OR (SpecialRange__c = :rating AND SpecialRange__c != null))
            AND Id != :consultorRegionalId
            AND FreezeConsult__c = false
            AND SendLead__c = true
            AND Ativo__c = true
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectHotFilter(String leadRegion, Id consultorRegionalId, String rating) {
        if (String.isBlank(leadRegion)) {
            return null;
        }

        String regionLike = '%' + leadRegion + '%';
        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Lb065_RegiaoConsultorEstado__c LIKE :regionLike
            AND (Lb65_Graduacao__c IN :GRADS_HOT_STATE
                OR (SpecialRange__c = :rating AND SpecialRange__c != null))
            AND Id != :consultorRegionalId
            AND SendLead__c = true
            AND FreezeConsult__c = false
            AND Ativo__c = true
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectPrioritarioFilter(Id consultorRegionalId, String rating) {
        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE (Lb65_Graduacao__c IN :GRADS_PRIOR_STATE
                OR (SpecialRange__c = :rating AND SpecialRange__c != null))
            AND SendLead__c = true
            AND Id != :consultorRegionalId
            AND FreezeConsult__c = false
            AND Ativo__c = true
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id selectNoState(Lead lead) {
        if (lead == null) {
            return null;
        }

        if (lead.Rating == 'Warm') {
            return selectNoStateByGraduation(GRADS_WARM_NO_STATE);
        }

        if (lead.Rating == 'Hot') {
            return selectNoStateByGraduation(GRADS_HOT_NO_STATE);
        }

        if (lead.Rating == 'Prioritário') {
            return selectNoStateByGraduation(GRADS_PRIOR_NO_STATE);
        }

        return null;
    }

    private static Id selectNoStateByGraduation(Set<String> graduations) {
        if (graduations == null || graduations.isEmpty()) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Lb65_Graduacao__c IN :graduations
            AND Ativo__c = true
            AND SendLead__c = true
            AND FreezeConsult__c = false
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT :LOCK_BATCH_SIZE
        ];

        return lockAndUpdate(candidates);
    }

    private static Id lockAndUpdate(List<Consultor__c> candidates) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }

        Set<Id> candidateIds = new Set<Id>();
        for (Consultor__c candidate : candidates) {
            if (candidate != null && candidate.Id != null) {
                candidateIds.add(candidate.Id);
            }
        }
        if (candidateIds.isEmpty()) {
            return null;
        }

        List<Consultor__c> locked = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Id IN :candidateIds
            FOR UPDATE
        ];

        Consultor__c chosen = chooseOldest(locked);
        if (chosen == null) {
            return null;
        }

        chosen.Lb065_UltimoLeadRecebido__c = System.now();
        update chosen;
        return chosen.Id;
    }

    private static Consultor__c chooseOldest(List<Consultor__c> candidates) {
        Consultor__c selected;
        for (Consultor__c candidate : candidates) {
            if (candidate == null) {
                continue;
            }
            if (selected == null) {
                selected = candidate;
                continue;
            }
            DateTime currentDate = candidate.Lb065_UltimoLeadRecebido__c;
            DateTime selectedDate = selected.Lb065_UltimoLeadRecebido__c;
            if (selectedDate == null) {
                continue;
            }
            if (currentDate == null || currentDate < selectedDate) {
                selected = candidate;
            }
        }
        return selected;
    }

    private static List<String> splitCsv(String rawValue) {
        List<String> values = new List<String>();
        if (String.isBlank(rawValue)) {
            return values;
        }
        for (String part : rawValue.split(',')) {
            String trimmed = part != null ? part.trim() : null;
            if (!String.isBlank(trimmed)) {
                values.add(trimmed);
            }
        }
        return values;
    }
}
