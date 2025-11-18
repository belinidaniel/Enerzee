/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-14-2025
 * @last modified by  : Daniel Belini
**/
public class ProposalPendingStatusQueueable implements Queueable, Database.AllowsCallouts {
    private Id pendingId;
    private String status;

    public ProposalPendingStatusQueueable(Id pendingId, String status){
        this.pendingId = pendingId;
        this.status = status;
    }

    public void execute(QueueableContext context) {
        if(pendingId == null || String.isBlank(status)){
            return;
        }

        ProposalPending__c pending = [
            SELECT  Id,
                    Status__c,
                    Opportunity__r.IdVirtualOffice__c,
                    Opportunity__c
            FROM    ProposalPending__c
            WHERE   Id = :pendingId
            LIMIT   1
        ];

        if(String.isBlank(pending.Opportunity__r.IdVirtualOffice__c)){
            return;
        }

        try{
            EzeeConnectProposalPendingService.PendingUpdateRequest payload = new EzeeConnectProposalPendingService.PendingUpdateRequest();
            payload.PendingId = pending.Id;
            payload.Status    = EzeeConnectProposalPendingService.getStatusCode(status);

            EzeeConnectProposalPendingService.updatePendingInApp(payload);

        } catch (Exception e){
            Utils.createLog('ProposalPendingStatusQueueable', 'execute ' + pending.Id, e);
        }
    }
}