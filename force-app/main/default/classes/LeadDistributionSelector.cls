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
    private static final Set<String> GRADS_WARM_STATE = new Set<String>{'Advanced Builder', 'Builder'};
    private static final Set<String> GRADS_HOT_STATE = new Set<String>{'Platinum', 'Gold'};
    private static final Set<String> GRADS_PRIOR_STATE = new Set<String>{'Diamond', 'Carbon Diamond'};
    private static final Set<String> GRADS_WARM_NO_STATE = new Set<String>{'Advisor', 'Builder'};
    private static final Set<String> GRADS_HOT_NO_STATE = new Set<String>{'Advanced Builder', 'Gold'};
    private static final Set<String> GRADS_PRIOR_NO_STATE = new Set<String>{'Platinum', 'Diamond', 'Carbon Diamond'};

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

        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Boolean hasDistributionType = leadFields.containsKey('Distributiontype__c');
        Boolean hasDistributionValue = leadFields.containsKey('DistributionValue__c');
        Boolean hasLeadRegion = leadFields.containsKey('LeadRegion__c');
        Boolean hasConsultorRegional = leadFields.containsKey('ConsultorRegional__c');

        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            List<String> selectFields = new List<String>{'Id', 'State', 'Rating'};
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
                    hasConsultorRegional
                );
            } catch (Exception ex) {
                res.message = ex.getMessage();
            }

            results.add(res);
        }

        return results;
    }

    private static Id selectConsultantForLead(
        Lead lead,
        Boolean hasDistributionType,
        Boolean hasDistributionValue,
        Boolean hasLeadRegion,
        Boolean hasConsultorRegional
    ) {
        if (lead == null) {
            return null;
        }

        String distributionType = hasDistributionType ? (String)lead.get('Distributiontype__c') : null;
        String distributionValue = hasDistributionValue ? (String)lead.get('DistributionValue__c') : null;
        String leadRegion = hasLeadRegion ? (String)lead.get('LeadRegion__c') : null;
        Id consultorRegionalId = hasConsultorRegional ? (Id)lead.get('ConsultorRegional__c') : null;

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

    private static Id selectByEmail(String distributionValue) {
        List<String> emails = splitCsv(distributionValue);
        if (emails.isEmpty()) {
            return null;
        }

        List<Consultor__c> candidates = [
            SELECT Id, Lb065_UltimoLeadRecebido__c
            FROM Consultor__c
            WHERE Email__c IN :emails
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
