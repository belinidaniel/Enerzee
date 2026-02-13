public with sharing class VOOpportunitySyncQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> opportunityIds;
    private final String origin;
    private final Boolean forceSync;
    private final Map<Id, String> correlationByRecordId;

    public VOOpportunitySyncQueueable(
        Set<Id> opportunityIds,
        String origin,
        Boolean forceSync,
        Map<Id, String> correlationByRecordId
    ) {
        this.opportunityIds = opportunityIds == null ? new Set<Id>() : opportunityIds;
        this.origin = origin;
        this.forceSync = forceSync == true;
        this.correlationByRecordId = correlationByRecordId;
    }

    public void execute(QueueableContext context) {
        VOIntegrationService.syncOpportunities(opportunityIds, origin, forceSync, correlationByRecordId);
    }
}
