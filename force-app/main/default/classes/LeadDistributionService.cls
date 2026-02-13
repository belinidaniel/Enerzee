/**
 * @description       : Orquestra regras de distribuicao de lead e consistencia da integracao.
 * @author            :
 * @group             :
 * @last modified on  : 02-13-2026
 * @last modified by  :
**/
public with sharing class LeadDistributionService {
    private static final String STATUS_NOVO = 'Novo';
    private static final String STATUS_DISTRIBUIDO = 'Distribuído';
    private static final String SUB_STATUS_LEAD_INCOMPLETO = 'Lead incompleto';
    private static final String PRODUCT_EZEE_SOLAR = 'Ezee Solar';
    private static final String PRODUCT_NEUTRO = 'Não indicou ou não soube informar';
    private static final String FIELD_NOT_FINISH_MESSAGING = 'NotFinishMessaging__c';
    private static final String FIELD_DISTRIBUTION_TYPE = 'Distributiontype__c';
    private static final String FIELD_DISTRIBUTION_VALUE = 'DistributionValue__c';

    private static Map<String, Schema.SObjectField> leadFieldMapCache;

    public static void applyAutomaticDistribution(List<Lead> newRecords, Map<Id, Lead> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<Lead> leadsToDistribute = new List<Lead>();
        for (Lead lead : newRecords) {
            Lead oldLead = oldMap != null ? oldMap.get(lead.Id) : null;
            if (shouldAutoDistribute(lead, oldLead)) {
                leadsToDistribute.add(lead);
            }
        }

        if (leadsToDistribute.isEmpty()) {
            return;
        }

        List<Id> selectedConsultantIds = LeadDistributionSelector.selectConsultantsForLeadRecords(leadsToDistribute);
        Integer total = Math.min(leadsToDistribute.size(), selectedConsultantIds.size());

        for (Integer idx = 0; idx < total; idx++) {
            Id consultantId = selectedConsultantIds[idx];
            if (consultantId == null) {
                continue;
            }

            Lead lead = leadsToDistribute[idx];
            lead.ConsultorRegional__c = consultantId;
            lead.Status = STATUS_DISTRIBUIDO;
            lead.Lb065_LeadVencido__c = false;
            lead.Lab065_IntegracaoDistribuicaoLead__c = false;
        }
    }

    public static void handleIntegrationFlagConsistency(List<Lead> newRecords, Map<Id, Lead> oldMap) {
        if (newRecords == null || newRecords.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        for (Lead lead : newRecords) {
            Lead oldLead = oldMap.get(lead.Id);
            if (oldLead == null) {
                continue;
            }

            Boolean consultantChanged = lead.ConsultorRegional__c != oldLead.ConsultorRegional__c;
            Boolean becameDistributed = lead.Status != oldLead.Status && lead.Status == STATUS_DISTRIBUIDO;

            if ((consultantChanged && lead.ConsultorRegional__c != null) || (becameDistributed && lead.ConsultorRegional__c != null)) {
                lead.Lab065_IntegracaoDistribuicaoLead__c = false;
            }
        }
    }

    public static void normalizeSdrLeadClassification(List<Lead> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        for (Lead lead : newRecords) {
            if (lead == null || !lead.SDRAgent__c) {
                continue;
            }

            Boolean isIncomplete = getLeadBooleanValue(lead, FIELD_NOT_FINISH_MESSAGING)
                || lead.Sub_Status__c == SUB_STATUS_LEAD_INCOMPLETO;
            if (!isIncomplete) {
                continue;
            }

            setLeadBooleanValue(lead, FIELD_NOT_FINISH_MESSAGING, true);
            lead.Sub_Status__c = SUB_STATUS_LEAD_INCOMPLETO;

            if (String.isBlank(lead.Lb065_ProdutoInteresse__c) || lead.Lb065_ProdutoInteresse__c == PRODUCT_EZEE_SOLAR) {
                lead.Lb065_ProdutoInteresse__c = PRODUCT_NEUTRO;
            }
        }
    }

    private static Boolean shouldAutoDistribute(Lead lead, Lead oldLead) {
        if (lead == null) {
            return false;
        }

        Boolean isTargetLead = LeadDistributionSelector.isConsultorLeadCandidate(lead)
            || LeadDistributionSelector.isB2BLeadCandidate(lead);

        if (!isTargetLead) {
            return false;
        }
        if (lead.ConsultorRegional__c != null) {
            return false;
        }
        if (!isStatusEligibleForDistribution(lead.Status)) {
            return false;
        }
        if (oldLead == null) {
            return true;
        }
        if (oldLead.ConsultorRegional__c != null) {
            return false;
        }
        return hasDistributionRelevantChange(lead, oldLead);
    }

    private static Boolean isStatusEligibleForDistribution(String status) {
        return String.isBlank(status) || status == STATUS_NOVO;
    }

    private static Boolean hasDistributionRelevantChange(Lead lead, Lead oldLead) {
        if (oldLead == null) {
            return true;
        }
        return lead.Status != oldLead.Status
            || lead.Lb065_LeadVencido__c != oldLead.Lb065_LeadVencido__c
            || lead.RecordTypeId != oldLead.RecordTypeId
            || lead.LeadSource != oldLead.LeadSource
            || lead.EmailConsultor__c != oldLead.EmailConsultor__c
            || lead.Nome_da_Campanha_Meta__c != oldLead.Nome_da_Campanha_Meta__c
            || lead.Nome_do_Conjunto_de_An_ncios_Meta__c != oldLead.Nome_do_Conjunto_de_An_ncios_Meta__c
            || lead.Nome_do_An_ncio_Meta__c != oldLead.Nome_do_An_ncio_Meta__c
            || getLeadStringValue(lead, FIELD_DISTRIBUTION_TYPE) != getLeadStringValue(oldLead, FIELD_DISTRIBUTION_TYPE)
            || getLeadStringValue(lead, FIELD_DISTRIBUTION_VALUE) != getLeadStringValue(oldLead, FIELD_DISTRIBUTION_VALUE);
    }

    private static Map<String, Schema.SObjectField> getLeadFieldMap() {
        if (leadFieldMapCache == null) {
            leadFieldMapCache = Schema.SObjectType.Lead.fields.getMap();
        }
        return leadFieldMapCache;
    }

    private static Boolean hasLeadField(String fieldName) {
        return !String.isBlank(fieldName) && getLeadFieldMap().containsKey(fieldName);
    }

    private static String getLeadStringValue(Lead lead, String fieldName) {
        if (lead == null || !hasLeadField(fieldName)) {
            return null;
        }
        Object value = lead.get(fieldName);
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean getLeadBooleanValue(Lead lead, String fieldName) {
        if (lead == null || !hasLeadField(fieldName)) {
            return false;
        }
        Object value = lead.get(fieldName);
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return String.valueOf(value).equalsIgnoreCase('true');
    }

    private static void setLeadBooleanValue(Lead lead, String fieldName, Boolean value) {
        if (lead == null || !hasLeadField(fieldName)) {
            return;
        }
        lead.put(fieldName, value);
    }
}
