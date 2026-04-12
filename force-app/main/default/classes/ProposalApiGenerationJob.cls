/**
 * @description       : Queueable que gera proposta via API PPTX e avança o estágio da Opportunity. Usado como substituto do PDFControllerExtension.SavePdfJob para capas com IntegrationKey__c.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalApiGenerationJob implements Queueable, Database.AllowsCallouts {
  private Id opportunityId;
  private Id coverId;
  private Boolean autoIntegrate;

  public ProposalApiGenerationJob(
    Id opportunityId,
    Id coverId,
    Boolean autoIntegrate
  ) {
    this.opportunityId = opportunityId;
    this.coverId = coverId;
    this.autoIntegrate = autoIntegrate;
  }

  public void execute(QueueableContext ctx) {
    try {
      ProposalGenerationService.ProposalResult result = ProposalGenerationService.generateProposal(
        opportunityId,
        coverId
      );

      if (result == null || result.success != true) {
        Utils.createLog(
          'ProposalApiGenerationJob',
          'execute',
          new AuraHandledException(
            'Geracao de proposta via API falhou sem excecao.'
          )
        );
        return;
      }

      advanceStage(opportunityId);

      if (autoIntegrate == true) {
        try {
          if (result.contentVersionId != null) {
            IntegracaoNivelloProposta.gerandoProposta(
              opportunityId,
              result.contentVersionId
            );
          } else {
            IntegracaoNivelloProposta.gerandoProposta(opportunityId);
          }
        } catch (Exception eInteg) {
          Utils.createLog(
            'ProposalApiGenerationJob',
            'execute.integration',
            eInteg
          );
        }
      }
    } catch (Exception e) {
      Utils.createLog('ProposalApiGenerationJob', 'execute', e);
    }
  }

  private static void advanceStage(Id opportunityId) {
    List<Opportunity> opps = [
      SELECT
        Id,
        StageName,
        RecordTypeId,
        RecordType.DeveloperName,
        PropostaGerada__c,
        ReadequacaoSolicitada__c,
        ViabilityStudyFinished__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (opps.isEmpty()) {
      return;
    }
    Opportunity opp = opps[0];

    String stageToSet;
    if (OpportunityUtils.isStatusAwaitingAcceptance(opp)) {
      stageToSet = OpportunityUtils.STATUS_CONTRATO;
    } else if (
      OpportunityUtils.isStatusProposalElaboration(opp) ||
      OpportunityUtils.isStatusProposalSimulation(opp)
    ) {
      if (OpportunityUtils.isRecordTypeSolar(opp)) {
        stageToSet = OpportunityUtils.STATUS_PROPOSTA_GERADA;
      } else if (OpportunityUtils.isRecordTypeEzeeSolarB(opp)) {
        stageToSet = OpportunityUtils.STATUS_ANALISE_CREDITO;
      } else {
        stageToSet = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
      }
    }

    Opportunity oppUpdate = new Opportunity(
      Id = opportunityId,
      PropostaGerada__c = true
    );
    if (stageToSet != null && opp.StageName != stageToSet) {
      oppUpdate.StageName = stageToSet;
    }
    update oppUpdate;
  }
}
