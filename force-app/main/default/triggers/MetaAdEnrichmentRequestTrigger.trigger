/**
 * @description Dispara o enriquecimento Meta Ads fora do contexto do Site Guest.
 */
trigger MetaAdEnrichmentRequestTrigger on Meta_Ad_Enrichment_Request__e(
  after insert
) {
  for (Meta_Ad_Enrichment_Request__e requestEvent : Trigger.New) {
    Id leadId = null;
    if (!String.isBlank(requestEvent.Lead_ID__c)) {
      leadId = (Id) requestEvent.Lead_ID__c;
    }

    System.enqueueJob(
      new MetaAdEnrichmentQueueable(
        requestEvent.Meta_Ad_ID__c,
        leadId,
        requestEvent.CTWA_CLID__c
      )
    );
  }
}
