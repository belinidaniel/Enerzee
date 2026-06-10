/**
 * @description       : Persiste e coordena o estado da geração assíncrona de propostas.
 * @author            : OpenAI Codex
 * @last modified on  : 06-10-2026
 * @test              : ProposalGenerationWorkflowTest, ProposalEngineSupportTest
 **/
public without sharing class ProposalGenerationStateService {
  public static final String PENDING = 'Pending';
  public static final String PROCESSING = 'Processing';
  public static final String SUCCEEDED = 'Succeeded';
  public static final String FAILED = 'Failed';

  public static Boolean requestGeneration(Id opportunityId) {
    if (opportunityId == null) {
      return false;
    }

    Opportunity opportunityRecord = [
      SELECT ProposalGenerationStatus__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (isActive(opportunityRecord.ProposalGenerationStatus__c)) {
      return false;
    }

    updateStatus(opportunityId, PENDING);
    return true;
  }

  public static Boolean canProcess(Id opportunityId) {
    if (opportunityId == null) {
      return false;
    }

    Opportunity opportunityRecord = [
      SELECT ProposalGenerationStatus__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    return opportunityRecord.ProposalGenerationStatus__c != SUCCEEDED;
  }

  public static void markProcessing(Id opportunityId) {
    updateStatus(opportunityId, PROCESSING);
  }

  public static void markSucceeded(Id opportunityId) {
    updateStatus(opportunityId, SUCCEEDED);
  }

  public static void markFailed(Id opportunityId) {
    updateStatus(opportunityId, FAILED);
  }

  // Reabre o ciclo de geração de uma proposta já concluída (ex.: troca de simulação),
  // limpando o status para que requestGeneration/canProcess permitam reprocessar.
  public static void reset(Id opportunityId) {
    updateStatus(opportunityId, null);
  }

  public static Boolean isActive(String status) {
    return status == PENDING || status == PROCESSING;
  }

  private static void updateStatus(Id opportunityId, String status) {
    if (opportunityId == null) {
      return;
    }

    Opportunity opportunityUpdate = new Opportunity(
      Id = opportunityId,
      ProposalGenerationStatus__c = status
    );

    Boolean triggerWasEnabled = OpportunityTriggerHandler.isTriggerEnabled();
    if (triggerWasEnabled) {
      OpportunityTriggerHandler.disableTrigger();
    }
    try {
      update opportunityUpdate;
    } finally {
      if (triggerWasEnabled) {
        OpportunityTriggerHandler.enableTrigger();
      }
    }
  }

  private static Boolean hasAnyStoredProposal(Id opportunityId) {
    Map<Id, ProposalFileService.ProposalAvailability> availabilityByOpportunityId = ProposalFileService.getProposalAvailability(
      new Set<Id>{ opportunityId }
    );
    ProposalFileService.ProposalAvailability availability = availabilityByOpportunityId.get(
      opportunityId
    );
    return availability != null && availability.hasStoredProposal;
  }
}
