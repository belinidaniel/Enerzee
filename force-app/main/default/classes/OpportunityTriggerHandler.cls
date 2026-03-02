/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 12-22-2025
 * @last modified by	 : Daniel Belini
 **/
public class OpportunityTriggerHandler extends TriggerHandler {
  public OpportunityTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static boolean enabled = true;
  public static boolean isTriggerEnabled() {
    return enabled;
  }

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
    OpportunityBO.assignDefaultOwner((List<Opportunity>) Trigger.new);
    OpportunityBO.calculateDataToProposalGraphic25Years(
      (List<Opportunity>) Trigger.new
    );
  }

  public override void afterInsert() {
    OpportunityBO.assignOpportunitySellerToAccount(
      (List<Opportunity>) Trigger.new,
      new Map<Id, Opportunity>()
    );
    OpportunityBO.sendEmailToOwnerNivello((List<Opportunity>) Trigger.new);
    OpportunityBO.createMessagingUser(
      (List<Opportunity>) Trigger.new,
      new Map<Id, Opportunity>()
    );
    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      (List<Opportunity>) Trigger.new,
      new Map<Id, Opportunity>()
    );
  }

  public override void beforeUpdate() {
    OpportunityBO.validateViabilityTexts(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.resetReadjustmentFieldsOnStatusChanging(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.calculateDataToProposalGraphic25Years(
      (List<Opportunity>) Trigger.new
    );
    OpportunityBO.setContractSendingDate(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.changeOpportunityStageOnViabilityChanging(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.revertStageForNivelloAPIUser(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.updateOwnerOnFirstModification(
      (List<Opportunity>) Trigger.new
    );
    OpportunityBO.controlsSubstatus(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.assignOwnerByPartner((List<Opportunity>) Trigger.new);
    ApprovalProcessService.updateApproveComment(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
  }

  public override void afterUpdate() {
    OpportunityBO.assignOpportunitySellerToAccount(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createReadjustmentTask(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.validateSellBuyOrderAndContractRequiredFields(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createSellBuyOrder(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.sendContractDataSAP(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    ApprovalProcessService.applyDiscountAndInitiateApproval(
      (Map<Id, Opportunity>) Trigger.newMap,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.updateOpportunityPhaseOnStageChange(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createProjectRecords(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createRequiredFieldsReminderTasks(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.sendContractToExternalSystem(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.updateKitsOnPotenciaChange(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    ApprovalProcessService.applyApprovedDiscounts(
      (Map<Id, Opportunity>) Trigger.newMap,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.scheduleTechnicalVisit(
      (Map<Id, Opportunity>) Trigger.newMap,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.updateFinancingProcessSimulationInExternalSystem(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.updateOpportunityTotalValueIfNeeded(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.processUpdatedOpportunitiesForSimulation(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.checksAndClosesTaskFollowUpCall(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.checkAndSendToRevo(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.sendCustomerRecordToSAP(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createMessagingUser(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.createCaseCustomerJourney(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.sendClienteRecordToVirtualOffice(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.addPlanToUserInVirtualOffice(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    ApprovalProcessService.sendApprovalUpdate(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    ApprovalProcessService.recallPendingDiscountApprovals(
      (Map<Id, Opportunity>) Trigger.newMap,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.handleOpportunityLeadConversion(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.closeActivitiesAndFlowsForClosedLost(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityBO.generateProposalAsync(
      (Map<Id, Opportunity>) Trigger.newMap,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      (List<Opportunity>) Trigger.new,
      (Map<Id, Opportunity>) Trigger.oldMap
    );
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
