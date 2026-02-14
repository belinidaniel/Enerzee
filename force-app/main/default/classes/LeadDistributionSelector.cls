/**
 * @description       : Seleciona o consultor correto para um Lead e atualiza o "ultimo lead recebido"
 *                      com lock de linha para evitar concorrencia.
 * @author            :
 * @group             :
 * @last modified on  : 02-13-2026
 * @last modified by  : Codex
**/
public with sharing class LeadDistributionSelector {

    private static final Integer LOCK_BATCH_SIZE = 5;
    private static final Set<String> GRADS_WARM_STATE = new Set<String>{'Advanced Builder', 'Builder'};
    private static final Set<String> GRADS_HOT_STATE = new Set<String>{'Platinum', 'Gold'};
    private static final Set<String> GRADS_PRIOR_STATE = new Set<String>{'Diamond', 'Carbon Diamond'};
    private static final Set<String> GRADS_WARM_NO_STATE = new Set<String>{'Advisor', 'Builder'};
    private static final Set<String> GRADS_HOT_NO_STATE = new Set<String>{'Advanced Builder', 'Gold'};
    private static final Set<String> GRADS_PRIOR_NO_STATE = new Set<String>{'Platinum', 'Diamond', 'Carbon Diamond'};

    private static final Set<String> CONSULTOR_GOLD_PLUS = new Set<String>{'GOLD', 'PLATINUM', 'DIAMOND', 'CARBON DIAMOND'};
    private static final Set<String> CONSULTOR_LEAD_SOURCES = new Set<String>{
        'WEB TO LEAD CONSULTOR',
        'WEB TO LEAD INTEGRADOR',
        'FACEBOOK CONSULTOR EMPREENDA',
        'FACEBOOK CONSULTOR REUNIAO ONLINE',
        'QUERO SER ENERZEE'
    };
    private static final Set<String> B2B_KEYWORDS = new Set<String>{'B2B', 'BESS'};

    private static final Map<String, String> BRAZIL_STATE_MAP = new Map<String, String>{
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

    @InvocableMethod(label = 'Select Consultant For Lead (Locked)' description = 'Seleciona o consultor para o Lead e atualiza o ultimo lead recebido usando lock de linha.')
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

        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Boolean hasDistributionType = leadFields.containsKey('Distributiontype__c');
        Boolean hasDistributionValue = leadFields.containsKey('DistributionValue__c');
        Boolean hasLeadRegion = leadFields.containsKey('LeadRegion__c');
        Boolean hasConsultorRegional = leadFields.containsKey('ConsultorRegional__c');
        Boolean hasEmailConsultor = leadFields.containsKey('EmailConsultor__c');
        Boolean hasMetaCampaignName = leadFields.containsKey('Nome_da_Campanha_Meta__c');

        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            List<String> selectFields = new List<String>{
                'Id',
                'State',
                'City',
                'Rating',
                'LeadSource',
                'RecordTypeId',
                'RecordType.DeveloperName'
            };
            if (hasDistributionType) {
                selectFields.add('Distributiontype__c');
            }
            if (hasDistributionValue) {
                selectFields.add('DistributionValue__c');
            }
            if (hasLeadRegion) {
                selectFields.add('LeadRegion__c');
            }
            if (hasConsultorRegional) {
                selectFields.add('ConsultorRegional__c');
            }
            if (hasEmailConsultor) {
                selectFields.add('EmailConsultor__c');
            }
            if (hasMetaCampaignName) {
                selectFields.add('Nome_da_Campanha_Meta__c');
            }

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
                res.consultantId = selectConsultantForLead(
                    lead,
                    hasDistributionType,
                    hasDistributionValue,
                    hasLeadRegion,
                    hasConsultorRegional,
                    hasEmailConsultor,
                    hasMetaCampaignName
                );
            } catch (Exception ex) {
                res.message = ex.getMessage();
            }

            results.add(res);
        }

        return results;
    }

    // Exposto para uso em Apex sem dependencia de Flow.
    public static Id selectConsultantForLeadRecord(Lead lead) {
        if (lead == null) {
            return null;
        }

        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        return selectConsultantForLead(
            lead,
            leadFields.containsKey('Distributiontype__c'),
            leadFields.containsKey('DistributionValue__c'),
            leadFields.containsKey('LeadRegion__c'),
            leadFields.containsKey('ConsultorRegional__c'),
            leadFields.containsKey('EmailConsultor__c'),
            leadFields.containsKey('Nome_da_Campanha_Meta__c')
        );
    }

    private static Id selectConsultantForLead(
        Lead lead,
        Boolean hasDistributionType,
        Boolean hasDistributionValue,
        Boolean hasLeadRegion,
        Boolean hasConsultorRegional,
        Boolean hasEmailConsultor,
        Boolean hasMetaCampaignName
    ) {
        if (lead == null) {
            return null;
        }

        String distributionType = hasDistributionType ? (String) lead.get('Distributiontype__c') : null;
        String distributionValue = hasDistributionValue ? (String) lead.get('DistributionValue__c') : null;
        String leadRegion = hasLeadRegion ? (String) lead.get('LeadRegion__c') : null;
        Id consultorRegionalId = hasConsultorRegional ? (Id) lead.get('ConsultorRegional__c') : null;
        String emailConsultor = hasEmailConsultor ? (String) lead.get('EmailConsultor__c') : null;

        Id selectedId;

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

        Boolean b2bLead = isB2BLead(lead, hasMetaCampaignName);

        // Quando email especifico e informado no formulario, direciona exclusivamente para ele.
        if (!String.isBlank(emailConsultor)) {
            selectedId = selectEligibleByEmail(splitCsv(emailConsultor), b2bLead, false);
            return selectedId;
        }

        if (b2bLead) {
            selectedId = selectB2BLead(lead);
            if (selectedId != null) {
                return selectedId;
            }
        }

        if (isConsultorLead(lead)) {
            selectedId = selectConsultorLead(lead);
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

    private static Boolean isColdOrWarm(String rating) {
        return rating == 'Cold' || rating == 'Warm';
    }

    private static Boolean isConsultorLead(Lead lead) {
        String recordTypeDeveloperName = getRecordTypeDeveloperName(lead);
        if (recordTypeDeveloperName == 'QualificacaodeConsultores') {
            return true;
        }

        String sourceNormalized = normalizeText(lead.LeadSource);
        if (String.isBlank(sourceNormalized)) {
            return false;
        }

        if (CONSULTOR_LEAD_SOURCES.contains(sourceNormalized)) {
            return true;
        }

        if (sourceNormalized.contains('INTEGRADOR')) {
            return true;
        }

        return sourceNormalized.contains('CONSULTOR');
    }

    private static Boolean isB2BLead(Lead lead, Boolean hasMetaCampaignName) {
        if (lead == null) {
            return false;
        }

        String sourceNormalized = normalizeText(lead.LeadSource);
        if (containsB2BKeyword(sourceNormalized)) {
            return true;
        }

        if (hasMetaCampaignName) {
            String metaCampaignName = (String) lead.get('Nome_da_Campanha_Meta__c');
            return containsB2BKeyword(metaCampaignName);
        }

        return false;
    }

    private static Boolean containsB2BKeyword(String rawValue) {
        String normalized = normalizeText(rawValue);
        if (String.isBlank(normalized)) {
            return false;
        }

        for (String keyword : B2B_KEYWORDS) {
            if (normalized.contains(keyword)) {
                return true;
            }
        }

        return false;
    }

    private static String getRecordTypeDeveloperName(Lead lead) {
        if (lead == null) {
            return null;
        }

        if (lead.RecordType != null && !String.isBlank(lead.RecordType.DeveloperName)) {
            return lead.RecordType.DeveloperName;
        }

        if (lead.RecordTypeId == null) {
            return null;
        }

        Map<Id, Schema.RecordTypeInfo> infosById = Schema.SObjectType.Lead.getRecordTypeInfosById();
        Schema.RecordTypeInfo info = infosById != null ? infosById.get(lead.RecordTypeId) : null;
        return info != null ? info.getDeveloperName() : null;
    }

    private static Id selectConsultorLead(Lead lead) {
        Map<String, Schema.SObjectField> consultorFields = Schema.SObjectType.Consultor__c.fields.getMap();
        String soql =
            'SELECT Id, Municipio__c, Estado__c, EstadoCobranca__c, EstadoEntrega__c, Lb65_Graduacao__c, ' +
            'SpecialRange__c, ConsultantDeadlineRange__c, Lb065_UltimoLeadRecebido__c ' +
            'FROM Consultor__c ' +
            'WHERE Ativo__c = true AND SendLead__c = true AND FreezeConsult__c = false';
        if (consultorFields.containsKey('ReceiveConsultorLead__c')) {
            soql += ' AND ReceiveConsultorLead__c = true';
        }
        soql += ' ORDER BY Lb065_UltimoLeadRecebido__c ASC LIMIT 500';

        List<Consultor__c> candidates = (List<Consultor__c>) Database.query(soql);

        List<Consultor__c> eligible = new List<Consultor__c>();
        for (Consultor__c candidate : candidates) {
            if (isConsultorLeadEligible(candidate, lead.Rating)) {
                eligible.add(candidate);
            }
        }

        return selectByGeoPriority(eligible, lead.City, lead.State);
    }

    private static Boolean isConsultorLeadEligible(Consultor__c candidate, String rating) {
        if (candidate == null) {
            return false;
        }

        Boolean specialRangeException = !String.isBlank(rating) && candidate.SpecialRange__c == rating;
        if (specialRangeException) {
            return true;
        }

        String deadlineRangeNormalized = normalizeText(candidate.ConsultantDeadlineRange__c);
        Boolean faixaVerde = candidate.ConsultantDeadlineRange__c == '3' ||
            deadlineRangeNormalized == '3' ||
            (!String.isBlank(deadlineRangeNormalized) && deadlineRangeNormalized.contains('VERDE'));
        Boolean goldOrHigher = isGoldOrHigher(candidate.Lb65_Graduacao__c);

        return faixaVerde && goldOrHigher;
    }

    private static Boolean isGoldOrHigher(String graduation) {
        String normalized = normalizeText(graduation);
        if (String.isBlank(normalized)) {
            return false;
        }

        return CONSULTOR_GOLD_PLUS.contains(normalized);
    }

    private static Id selectB2BLead(Lead lead) {
        Map<String, Schema.SObjectField> consultorFields = Schema.SObjectType.Consultor__c.fields.getMap();
        String soql =
            'SELECT Id, Municipio__c, Estado__c, EstadoCobranca__c, EstadoEntrega__c, Lb065_UltimoLeadRecebido__c ' +
            'FROM Consultor__c ' +
            'WHERE Ativo__c = true AND SendLead__c = true AND FreezeConsult__c = false';
        if (consultorFields.containsKey('ReceiveB2BLead__c')) {
            soql += ' AND ReceiveB2BLead__c = true';
        }
        soql += ' ORDER BY Lb065_UltimoLeadRecebido__c ASC LIMIT 500';

        List<Consultor__c> candidates = (List<Consultor__c>) Database.query(soql);

        return selectByGeoPriority(candidates, lead.City, lead.State);
    }

    private static Id selectByGeoPriority(List<Consultor__c> candidates, String leadCity, String leadState) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }

        String normalizedLeadCity = normalizeText(leadCity);
        String normalizedLeadState = normalizeState(leadState);

        Integer bestTier = 2;
        for (Consultor__c candidate : candidates) {
            Integer candidateTier = getGeoTier(candidate, normalizedLeadCity, normalizedLeadState);
            if (candidateTier < bestTier) {
                bestTier = candidateTier;
            }
        }

        List<Consultor__c> shortlist = new List<Consultor__c>();
        for (Consultor__c candidate : candidates) {
            if (getGeoTier(candidate, normalizedLeadCity, normalizedLeadState) == bestTier) {
                insertByOldest(shortlist, candidate, LOCK_BATCH_SIZE);
            }
        }

        return lockAndUpdate(shortlist);
    }

    private static Integer getGeoTier(Consultor__c candidate, String normalizedLeadCity, String normalizedLeadState) {
        if (candidate == null) {
            return 2;
        }

        if (String.isBlank(normalizedLeadState)) {
            return 2;
        }

        String candidateState = getConsultorStateCode(candidate);
        if (candidateState != normalizedLeadState) {
            return 2;
        }

        String candidateCity = normalizeText(candidate.Municipio__c);
        if (!String.isBlank(normalizedLeadCity) && !String.isBlank(candidateCity) && candidateCity == normalizedLeadCity) {
            return 0;
        }

        return 1;
    }

    private static String getConsultorStateCode(Consultor__c candidate) {
        if (candidate == null) {
            return null;
        }

        String code = normalizeState(candidate.EstadoCobranca__c);
        if (!String.isBlank(code)) {
            return code;
        }

        code = normalizeState(candidate.EstadoEntrega__c);
        if (!String.isBlank(code)) {
            return code;
        }

        return normalizeState(candidate.Estado__c);
    }

    private static String normalizeState(String rawValue) {
        String normalized = normalizeText(rawValue);
        if (String.isBlank(normalized)) {
            return null;
        }

        if (normalized.length() == 2) {
            return normalized;
        }

        List<String> parts = normalized.split(' ');
        if (!parts.isEmpty()) {
            String maybeCode = parts[parts.size() - 1];
            if (maybeCode != null && maybeCode.length() == 2) {
                return maybeCode;
            }
        }

        if (BRAZIL_STATE_MAP.containsKey(normalized)) {
            return BRAZIL_STATE_MAP.get(normalized);
        }

        return normalized;
    }

    private static String normalizeText(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String normalized = rawValue.trim().toUpperCase();
        normalized = normalized.replace('Á', 'A').replace('À', 'A').replace('Â', 'A').replace('Ã', 'A').replace('Ä', 'A');
        normalized = normalized.replace('É', 'E').replace('È', 'E').replace('Ê', 'E').replace('Ë', 'E');
        normalized = normalized.replace('Í', 'I').replace('Ì', 'I').replace('Î', 'I').replace('Ï', 'I');
        normalized = normalized.replace('Ó', 'O').replace('Ò', 'O').replace('Ô', 'O').replace('Õ', 'O').replace('Ö', 'O');
        normalized = normalized.replace('Ú', 'U').replace('Ù', 'U').replace('Û', 'U').replace('Ü', 'U');
        normalized = normalized.replace('Ç', 'C');
        normalized = normalized.replaceAll('[^A-Z0-9 ]', ' ');
        normalized = normalized.replaceAll(' +', ' ');

        return normalized.trim();
    }

    private static void insertByOldest(List<Consultor__c> target, Consultor__c candidate, Integer maxSize) {
        if (candidate == null || target == null || maxSize == null || maxSize <= 0) {
            return;
        }

        Integer insertIndex = target.size();
        for (Integer i = 0; i < target.size(); i++) {
            if (isOlder(candidate.Lb065_UltimoLeadRecebido__c, target[i].Lb065_UltimoLeadRecebido__c)) {
                insertIndex = i;
                break;
            }
        }

        if (insertIndex >= target.size()) {
            target.add(candidate);
        } else {
            target.add(insertIndex, candidate);
        }
        if (target.size() > maxSize) {
            target.remove(target.size() - 1);
        }
    }

    private static Boolean isOlder(DateTime currentCandidate, DateTime currentSelected) {
        if (currentSelected == null) {
            return false;
        }
        if (currentCandidate == null) {
            return true;
        }

        return currentCandidate < currentSelected;
    }

    private static Id selectByEmail(String distributionValue) {
        List<String> emails = splitCsv(distributionValue);
        if (emails.isEmpty()) {
            return null;
        }

        return selectEligibleByEmail(emails, false, true);
    }

    private static Id selectEligibleByEmail(List<String> emails, Boolean requireB2BEnabled, Boolean fallbackToAnyEligible) {
        if (emails == null || emails.isEmpty()) {
            return null;
        }

        List<Consultor__c> candidates;
        Map<String, Schema.SObjectField> consultorFields = Schema.SObjectType.Consultor__c.fields.getMap();
        if (requireB2BEnabled && consultorFields.containsKey('ReceiveB2BLead__c')) {
            candidates = [
                SELECT Id, Lb065_UltimoLeadRecebido__c
                FROM Consultor__c
                WHERE Email__c IN :emails
                    AND Ativo__c = true
                    AND SendLead__c = true
                    AND FreezeConsult__c = false
                    AND ReceiveB2BLead__c = true
                ORDER BY Lb065_UltimoLeadRecebido__c ASC
                LIMIT :LOCK_BATCH_SIZE
            ];

            if (!candidates.isEmpty() || !fallbackToAnyEligible) {
                return lockAndUpdate(candidates);
            }
        }

        candidates = [
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

        String normalizedLeadState = normalizeState(lead.State);
        if (String.isBlank(normalizedLeadState)) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT
                Id,
                Estado__c,
                EstadoCobranca__c,
                EstadoEntrega__c,
                Lb65_Graduacao__c,
                SpecialRange__c,
                Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE SendLead__c = true
                AND FreezeConsult__c = false
            ORDER BY Lb065_UltimoLeadRecebido__c ASC
            LIMIT 500
        ];

        List<Consultor__c> shortlist = new List<Consultor__c>();
        for (Consultor__c candidate : candidates) {
            if (getConsultorStateCode(candidate) != normalizedLeadState) {
                continue;
            }
            Boolean graduationMatch = GRADS_WARM_STATE.contains(candidate.Lb65_Graduacao__c);
            Boolean specialRangeMatch = candidate.SpecialRange__c == lead.Rating && candidate.SpecialRange__c != null;
            if (graduationMatch || specialRangeMatch) {
                insertByOldest(shortlist, candidate, LOCK_BATCH_SIZE);
            }
        }

        return lockAndUpdate(shortlist);
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

        String normalized = rawValue.replace(';', ',');
        for (String part : normalized.split(',')) {
            String trimmed = part != null ? part.trim() : null;
            if (!String.isBlank(trimmed)) {
                values.add(trimmed);
            }
        }
        return values;
    }
}
