/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-14-2025
 * @last modified by	 : Daniel Belini
 **/
public class ProposalPendingStatusQueueable implements Queueable, Database.AllowsCallouts {
  private Id pendingId;
  private String status;
  private String descriptionRejected;

  public ProposalPendingStatusQueueable(
    Id pendingId,
    String status,
    String descriptionRejected
  ) {
    this.pendingId = pendingId;
    this.status = status;
    this.descriptionRejected = descriptionRejected;
  }

  public void execute(QueueableContext context) {
    if (pendingId == null || String.isBlank(status)) {
      return;
    }

    ProposalPending__c pending = [
      SELECT Id, Status__c, Opportunity__r.IdVirtualOffice__c, Opportunity__c
      FROM ProposalPending__c
      WHERE Id = :pendingId
      LIMIT 1
    ];

    if (String.isBlank(pending.Opportunity__r.IdVirtualOffice__c)) {
      return;
    }

    try {
      EzeeConnectProposalPendingService.PendingUpdateRequest payload = new EzeeConnectProposalPendingService.PendingUpdateRequest();
      payload.PendingId = pending.Id;
      ProposalPendingController.PendingStatus statusEnum = ProposalPendingController.parseStatus(
        status
      );
      payload.Status = ProposalPendingController.getStatusCode(statusEnum);
      if (statusEnum == ProposalPendingController.PendingStatus.Recusado) {
        payload.DescriptionRejected = String.isNotBlank(descriptionRejected)
          ? descriptionRejected
          : '';
      } else if (!String.isBlank(descriptionRejected)) {
        payload.DescriptionRejected = descriptionRejected;
      }

      EzeeConnectProposalPendingService.updatePendingInApp(payload);
    } catch (Exception e) {
      Utils.createLog(
        'ProposalPendingStatusQueueable',
        'execute ' + pending.Id,
        e
      );
    }
  }
}
