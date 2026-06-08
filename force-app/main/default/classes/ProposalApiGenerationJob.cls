/**
 * @description       : Queueable que gera proposta via API PPTX e avança o estágio da Opportunity. Usado como substituto do PDFControllerExtension.SavePdfJob para capas com IntegrationKey__c.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-26-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalApiGenerationJob implements Queueable, Database.AllowsCallouts {
  private Id opportunityId;
  private Id coverId;
  private Boolean autoIntegrate;
  private Boolean forceNewFile;

  public ProposalApiGenerationJob(
    Id opportunityId,
    Id coverId,
    Boolean autoIntegrate
  ) {
    this(opportunityId, coverId, autoIntegrate, false);
  }

  public ProposalApiGenerationJob(
    Id opportunityId,
    Id coverId,
    Boolean autoIntegrate,
    Boolean forceNewFile
  ) {
    this.opportunityId = opportunityId;
    this.coverId = coverId;
    this.autoIntegrate = autoIntegrate;
    this.forceNewFile = forceNewFile;
  }

  public void execute(QueueableContext ctx) {
    if (!ProposalGenerationStateService.canProcess(opportunityId)) {
      return;
    }

    try {
      ProposalGenerationService.ProposalResult result = ProposalGenerationService.generateProposal(
        opportunityId,
        coverId,
        forceNewFile
      );
      ensureProposalWasStored(opportunityId, result.contentVersionId);
      Boolean stageChanged = advanceStage(opportunityId);

      // Quando advanceStage muda o StageName, o trigger da Opportunity já dispara o
      // envio da fase. Quando NÃO muda (opp já estava na fase-alvo), enviamos aqui —
      // do contrário o payload sairia sem OptionsFinanciamentos. Neste ponto as
      // simulações já existem, então as opções de financiamento vão preenchidas.
      if (!stageChanged) {
        PaymentSimulationProposalStatusService.enqueueOpportunityStatusSync(
          new Set<Id>{ opportunityId }
        );
      }

      // gerandoProposta(oppId, cvId) é @future(callout=true): apenas enfileira aqui e
      // executa o callout em transação separada, sem conflito com o DML acima.
      if (autoIntegrate == true) {
        IntegracaoNivelloProposta.gerandoProposta(
          opportunityId,
          result.contentVersionId
        );
      }
      ProposalGenerationStateService.markSucceeded(opportunityId);
    } catch (Exception e) {
      ProposalGenerationStateService.markFailed(opportunityId);
      Utils.createLog(
        'ProposalApiGenerationJob',
        'execute',
        e,
        String.valueOf(opportunityId)
      );
    }
  }

  private static void ensureProposalWasStored(
    Id opportunityId,
    Id contentVersionId
  ) {
    if (contentVersionId == null) {
      throw new ProposalGenerationService.ProposalGenerationException(
        'A geração terminou sem retornar o arquivo da proposta.'
      );
    }

    if (
      !ProposalFileService.isStoredProposal(opportunityId, contentVersionId)
    ) {
      throw new ProposalGenerationService.ProposalGenerationException(
        'O arquivo retornado não está vinculado à oportunidade.'
      );
    }
  }

  public static void advanceStage(Id opportunityId) {
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
      return false;
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
    Boolean stageChanged = stageToSet != null && opp.StageName != stageToSet;
    if (stageChanged) {
      oppUpdate.StageName = stageToSet;
    }
    update oppUpdate;
    return stageChanged;
  }
}
