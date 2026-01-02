public class ProposalPendingSendQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> pendingIds;

    public ProposalPendingSendQueueable(List<Id> idsToProcess) {
        this.pendingIds = new Set<Id>(idsToProcess);
    }

    public void execute(QueueableContext context) {
        if(pendingIds == null || pendingIds.isEmpty()){
            return;
        }

        List<ProposalPending__c> pendings = [
            SELECT  Id,
                    Description__c,
                    DocumentTypeId__c,
                    Status__c,
                    Opportunity__r.IdVirtualOffice__c
            FROM    ProposalPending__c
            WHERE   Id IN :pendingIds
        ];

        List<EzeeConnectProposalPendingService.PendingRequest> batchPayload = new List<EzeeConnectProposalPendingService.PendingRequest>();
        List<String> errorMessages = new List<String>();

        for(ProposalPending__c pending : pendings){
            if(String.isBlank(pending.Opportunity__r.IdVirtualOffice__c)){
                continue;
            }

            try{
                EzeeConnectProposalPendingService.PendingRequest payload = new EzeeConnectProposalPendingService.PendingRequest();
                payload.ProposalId  = pending.Opportunity__r.IdVirtualOffice__c;
                payload.Description = pending.Description__c;
                payload.DocumentType= pending.DocumentTypeId__c != null ? Integer.valueOf(pending.DocumentTypeId__c.intValue()) : null;
                payload.Status      = EzeeConnectProposalPendingService.getStatusCode(pending.Status__c);
                payload.PendingId   = pending.Id;

                batchPayload.add(payload);
            } catch (Exception e){
                errorMessages.add('Map payload error for ' + pending.Id + ': ' + e.getMessage());
            }
        }

        if(batchPayload.isEmpty()){
            return;
        }

        try{
            EzeeConnectProposalPendingService.sendPendingBatchToApp(batchPayload);
        } catch (Exception batchError){
            errorMessages.add('Batch send failed: ' + batchError.getMessage());
            for(EzeeConnectProposalPendingService.PendingRequest payload : batchPayload){
                try{
                    EzeeConnectProposalPendingService.sendPendingToApp(payload);
                } catch (Exception e){
                    errorMessages.add('Fallback send failed for ' + payload.PendingId + ': ' + e.getMessage());
                }
            }
        }

        if(!errorMessages.isEmpty()){
            System.debug(LoggingLevel.ERROR, 'ProposalPendingSendQueueable errors: ' + String.join(errorMessages, ' | '));
        }
    }
}