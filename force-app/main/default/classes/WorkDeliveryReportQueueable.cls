public with sharing class WorkDeliveryReportQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> installationIds;

    public WorkDeliveryReportQueueable(List<Id> installationIds) {
        this.installationIds = installationIds != null ? new List<Id>(installationIds) : new List<Id>();
    }

    public void execute(QueueableContext context) {
        if (installationIds == null || installationIds.isEmpty()) {
            return;
        }

        Id currentId = installationIds.remove(0);
        WorkDeliveryReportService.generateAndAttach(currentId);

        if (!installationIds.isEmpty()) {
            System.enqueueJob(new WorkDeliveryReportQueueable(installationIds));
        }
    }
}
