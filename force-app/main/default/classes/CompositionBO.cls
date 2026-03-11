/**
 * @description    : Business Object for Composition__c — handles upsert from REST integration
 * @author         : Daniel Belini
 * @group          :
 * @last modified on  : 03-11-2026
 * @last modified by  : Daniel Belini
 **/
public with sharing class CompositionBO {

	/**
	 * Upserts Composition__c records from the OpportunityEntry REST payload.
	 * Uses ExternalId__c as the upsert key.
	 *
	 * @param singleOpportunities     List of SingleOpportunity DTOs from the payload
	 * @param externalIdToOpportunity Map of Opportunity.IdVirtualOffice__c -> inserted Opportunity
	 * @return Map of CompositionExternalId -> Composition__c.Id
	 */
	public static Map<String, Id> upsertFromRest(
		List<OpportunityRecordsTO.SingleOpportunity> singleOpportunities,
		Map<String, Opportunity> externalIdToOpportunity
	) {
		Map<String, Id> compositionExternalIdToId = new Map<String, Id>();

		if (singleOpportunities == null || singleOpportunities.isEmpty()) {
			return compositionExternalIdToId;
		}

		List<Composition__c> toUpsert = new List<Composition__c>();

		for (OpportunityRecordsTO.SingleOpportunity singleOpportunity : singleOpportunities) {
			if (singleOpportunity.Compositions == null || singleOpportunity.Compositions.isEmpty()) {
				continue;
			}

			Opportunity opportunity = externalIdToOpportunity.get(singleOpportunity.Id);
			if (opportunity == null || opportunity.Id == null) {
				continue;
			}

			for (OpportunityRecordsTO.Composition comp : singleOpportunity.Compositions) {
				if (String.isBlank(comp.ExternalId)) {
					continue;
				}

				Composition__c record = new Composition__c(
					ExternalId__c = comp.ExternalId,
					Name = comp.Name,
					Opportunity__c = opportunity.Id,
					ByIntegration__c = true
				);

				if (comp.Bdi != null) {
					record.Bdi__c = comp.Bdi;
				}
				if (comp.Direct != null) {
					record.Direct__c = comp.Direct;
				}
				if (comp.Rede != null) {
					record.Network3750__c = comp.Rede;
				}
				if (comp.Pontos != null) {
					record.Points__c = comp.Pontos;
				}
				if (comp.Installation != null) {
					record.Installation__c = comp.Installation;
				}
				if (comp.AdditionalFixedCost != null) {
					record.AdditionalFixedCost__c = comp.AdditionalFixedCost;
				}
				if (comp.Coupling != null) {
					record.Coupling__c = comp.Coupling;
				}
				if (comp.FinancialCostWeg != null) {
					record.FinancialCostWeg__c = comp.FinancialCostWeg;
				}
				if (comp.TotalProductValue != null) {
					record.TotalProductValue__c = comp.TotalProductValue;
				}

				toUpsert.add(record);
			}
		}

		if (toUpsert.isEmpty()) {
			return compositionExternalIdToId;
		}

		List<Database.UpsertResult> results = Database.upsert(
			toUpsert,
			Composition__c.ExternalId__c,
			false
		);

		for (Integer i = 0; i < results.size(); i++) {
			if (results.get(i).isSuccess()) {
				compositionExternalIdToId.put(
					toUpsert.get(i).ExternalId__c,
					results.get(i).getId()
				);
			} else {
				System.debug(
					LoggingLevel.ERROR,
					'CompositionBO.upsertFromRest - falha: ExternalId=' +
					toUpsert.get(i).ExternalId__c + ' erros=' + results.get(i).getErrors()
				);
			}
		}

		return compositionExternalIdToId;
	}
}
