public with sharing class VOAccountSyncQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> accountIds;
    private final String origin;
    private final Boolean forceSync;
    private final Map<Id, String> correlationByRecordId;

    public VOAccountSyncQueueable(
        Set<Id> accountIds,
        String origin,
        Boolean forceSync,
        Map<Id, String> correlationByRecordId
    ) {
        this.accountIds = accountIds == null ? new Set<Id>() : accountIds;
        this.origin = origin;
        this.forceSync = forceSync == true;
        this.correlationByRecordId = correlationByRecordId;
    }

    public void execute(QueueableContext context) {
        VOIntegrationService.syncAccounts(accountIds, origin, forceSync, correlationByRecordId);
    }
}
