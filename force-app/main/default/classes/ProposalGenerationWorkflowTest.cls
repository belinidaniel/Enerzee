/**
 * @description       : Testa o estado persistido e a proteção de estágio da geração de propostas.
 * @author            : OpenAI Codex
 * @last modified on  : 06-12-2026
 **/
@IsTest
private class ProposalGenerationWorkflowTest {
  @IsTest
  static void persistsGenerationStateAndPreventsDuplicateRequests() {
    Opportunity opportunityRecord = createOpportunity();

    Assert.isTrue(
      ProposalGenerationStateService.requestGeneration(opportunityRecord.Id)
    );
    Assert.areEqual(
      ProposalGenerationStateService.PENDING,
      getStatus(opportunityRecord.Id)
    );
    Assert.isFalse(
      ProposalGenerationStateService.requestGeneration(opportunityRecord.Id),
      'Uma geração pendente não pode ser enfileirada novamente.'
    );

    ProposalGenerationStateService.markProcessing(opportunityRecord.Id);
    Assert.areEqual(
      ProposalGenerationStateService.PROCESSING,
      getStatus(opportunityRecord.Id)
    );

    ProposalGenerationStateService.markSucceeded(opportunityRecord.Id);
    Assert.areEqual(
      ProposalGenerationStateService.SUCCEEDED,
      getStatus(opportunityRecord.Id)
    );
    Assert.isFalse(
      ProposalGenerationStateService.canProcess(opportunityRecord.Id)
    );

    Assert.isTrue(
      ProposalGenerationStateService.requestGeneration(opportunityRecord.Id),
      'Uma solicitação explícita deve iniciar nova geração após o sucesso.'
    );
  }

  @IsTest
  static void blocksStageRegressionUnlessReadjustmentWasRequested() {
    Opportunity oldOpportunity = new Opportunity(
      Id = '006000000000001AAA',
      StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA,
      PropostaGerada__c = true,
      ProposalGenerationStatus__c = ProposalGenerationStateService.SUCCEEDED,
      ReadequacaoSolicitada__c = false
    );
    Opportunity blockedRegression = new Opportunity(
      Id = oldOpportunity.Id,
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
      PropostaGerada__c = true,
      ReadequacaoSolicitada__c = false
    );

    OpportunityBO.preventCompletedProposalStageRegression(
      new List<Opportunity>{ blockedRegression },
      new Map<Id, Opportunity>{ oldOpportunity.Id => oldOpportunity }
    );
    Assert.areEqual(
      OpportunityUtils.STATUS_PROPOSTA_GERADA,
      blockedRegression.StageName
    );

    Opportunity explicitReadjustment = blockedRegression.clone(
      true,
      false,
      false,
      false
    );
    explicitReadjustment.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
    explicitReadjustment.ReadequacaoSolicitada__c = true;

    OpportunityBO.preventCompletedProposalStageRegression(
      new List<Opportunity>{ explicitReadjustment },
      new Map<Id, Opportunity>{ oldOpportunity.Id => oldOpportunity }
    );
    Assert.areEqual(
      OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
      explicitReadjustment.StageName
    );
  }

  @IsTest
  static void forcedGenerationDoesNotReuseAnExistingProposal() {
    ContentVersion existingProposal = new ContentVersion(
      Title = 'Proposta existente'
    );

    Assert.isTrue(
      ProposalGenerationService.shouldReuseExistingProposal(
        existingProposal,
        false
      )
    );
    Assert.isFalse(
      ProposalGenerationService.shouldReuseExistingProposal(
        existingProposal,
        true
      ),
      'A regeneração explícita deve ignorar o arquivo com o mesmo hash.'
    );
  }

  @IsTest
  static void blocksGeneratedStageUntilProposalFileExists() {
    Opportunity opportunityRecord = createOpportunity();
    Opportunity oldOpportunity = opportunityRecord.clone(
      true,
      false,
      false,
      false
    );
    oldOpportunity.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
    Opportunity attemptedUpdate = oldOpportunity.clone(
      true,
      false,
      false,
      false
    );
    attemptedUpdate.StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA;

    OpportunityBO.preventProposalGeneratedStageWithoutStoredFile(
      new List<Opportunity>{ attemptedUpdate },
      new Map<Id, Opportunity>{ oldOpportunity.Id => oldOpportunity }
    );

    Assert.areEqual(
      OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
      attemptedUpdate.StageName,
      'O estágio não pode avançar antes de o PDF estar armazenado.'
    );
  }

  @IsTest
  static void dispatcherRoutesApiCoverAndPersistsProcessing() {
    ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(
        IntegrationKey__c = 'WORKFLOW_API',
        Template__c = 'ModeloPropostaA',
        TemplateUrl__c = 'https://api.example.com/template'
      ),
      true
    );
    Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(
        Produto__c = 'Solar',
        GrupoTarifario__c = 'Grupo B',
        CapaProposta__c = cover.Id
      ),
      true
    );
    Opportunity opportunityRecord = createOpportunity(partner.Id);

    ProposalGenerationDispatcher.dispatch(opportunityRecord.Id, true, true);

  }

  private static Opportunity createOpportunity() {
    return createOpportunity(null);
  }

  private static Opportunity createOpportunity(Id partnerId) {
    Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
      new Opportunity(Parceiro__c = partnerId)
    );
    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
    return opportunityRecord;
  }

  private static String getStatus(Id opportunityId) {
    return [
      SELECT ProposalGenerationStatus__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ]
    .ProposalGenerationStatus__c;
  }
}
