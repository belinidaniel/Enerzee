/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityUtilsTest {
  @IsTest
  static void shouldEvaluateRecordTypeHelpers() {
    Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();

    if (recordTypes.containsKey('Solar')) {
      System.assert(
        OpportunityUtils.isRecordTypeSolar(
          new Opportunity(
            RecordTypeId = recordTypes.get('Solar').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('Produtos')) {
      System.assert(
        OpportunityUtils.isRecordTypeProdutos(
          new Opportunity(
            RecordTypeId = recordTypes.get('Produtos').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('Servicos')) {
      System.assert(
        OpportunityUtils.isRecordTypeServicos(
          new Opportunity(
            RecordTypeId = recordTypes.get('Servicos').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('ServicosEPC')) {
      System.assert(
        OpportunityUtils.isRecordTypeServicosEPC(
          new Opportunity(
            RecordTypeId = recordTypes.get('ServicosEPC').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('EzeeSolarA')) {
      Opportunity solarA = new Opportunity(
        RecordTypeId = recordTypes.get('EzeeSolarA').getRecordTypeId()
      );
      System.assert(OpportunityUtils.isRecordTypeEzeeSolarA(solarA));
      System.assert(OpportunityUtils.isRecordTypeEzeeSolar(solarA));
      System.assertEquals(
        OpportunityUtils.STATUS_EQUIPAMENTO,
        OpportunityUtils.resolveStageForProjectCompletion(solarA)
      );
    }
    if (recordTypes.containsKey('EzeeSolarB')) {
      Opportunity solarB = new Opportunity(
        RecordTypeId = recordTypes.get('EzeeSolarB').getRecordTypeId()
      );
      System.assert(OpportunityUtils.isRecordTypeEzeeSolarB(solarB));
      System.assert(OpportunityUtils.isRecordTypeEzeeSolar(solarB));
    }
    if (recordTypes.containsKey('EzeeConnect')) {
      System.assert(
        OpportunityUtils.isRecordTypeEzeeConnect(
          new Opportunity(
            RecordTypeId = recordTypes.get('EzeeConnect').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('EzeeLivre')) {
      System.assert(
        OpportunityUtils.isRecordTypeEzeeLivre(
          new Opportunity(
            RecordTypeId = recordTypes.get('EzeeLivre').getRecordTypeId()
          )
        )
      );
    }
    if (recordTypes.containsKey('OutrasOportunidades')) {
      System.assert(
        OpportunityUtils.isRecordTypeOtherOpportunities(
          new Opportunity(
            RecordTypeId = recordTypes.get('OutrasOportunidades')
              .getRecordTypeId()
          )
        )
      );
    }

    System.assertEquals(
      OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO,
      OpportunityUtils.resolveStageForProjectCompletion(null)
    );
  }

  @IsTest
  static void shouldEvaluateStatusAndTransitionHelpers() {
    Opportunity oldOpp = new Opportunity(
      StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA,
      Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE,
      SubTipo__c = OpportunityUtils.SUB_STATUS_PENDENCIA,
      ContratoGerado__c = false,
      Contrato_aprovado__c = false,
      ProdutoSolar__c = false,
      StatusViabilidade__c = 'Viável',
      PropostaGerada__c = false,
      Proposta_aprovada__c = false,
      EtapaViabilidade__c = 'Aguardando',
      ReadequacaoSolicitada__c = false,
      Financiamento_solicitado__c = false,
      StatusAprovacaoDesconto__c = 'Em análise'
    );

    Opportunity newOpp = new Opportunity(
      StageName = OpportunityUtils.STATUS_APRESENTACAO_COMERCIAL,
      Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO,
      SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO,
      ContratoGerado__c = true,
      Contrato_aprovado__c = true,
      ProdutoSolar__c = true,
      StatusViabilidade__c = 'Parcialmente Viável',
      PropostaGerada__c = true,
      Proposta_aprovada__c = true,
      EtapaViabilidade__c = 'Estudo',
      ReadequacaoSolicitada__c = true,
      PrazoAprovacaoViabilidade__c = Date.today().addDays(2),
      Financiamento_solicitado__c = true,
      StatusAprovacaoDesconto__c = 'Aprovado'
    );

    System.assert(OpportunityUtils.isStatusChanging(newOpp, oldOpp));
    System.assert(OpportunityUtils.isStatusCommercialPresentation(newOpp));

    Opportunity proposalOpp = new Opportunity(
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA
    );
    System.assert(OpportunityUtils.isStatusProposalElaboration(proposalOpp));
    System.assert(
      OpportunityUtils.isChangingToProposalElaboration(proposalOpp, oldOpp)
    );

    Opportunity simulationOpp = new Opportunity(
      StageName = OpportunityUtils.STATUS_SIMULACAO_DE_PROPOSTA
    );
    System.assert(OpportunityUtils.isStatusProposalSimulation(simulationOpp));

    Opportunity sentOpp = new Opportunity(
      StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA
    );
    System.assert(OpportunityUtils.isStatusProposalSent(sentOpp));

    System.assert(
      OpportunityUtils.isStatusProposalGenerated(
        new Opportunity(StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA)
      )
    );
    System.assert(
      OpportunityUtils.isStatusNegotiation(
        new Opportunity(StageName = OpportunityUtils.STATUS_NEGOCIACAO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusPaymentConfirmationSinal(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusCreditAnalysis(
        new Opportunity(StageName = OpportunityUtils.STATUS_ANALISE_CREDITO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusViabilityAnalysis(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusViabilityAnalysis(
        new Opportunity(StageName = OpportunityUtils.STATUS_VIABILIDADE_TECNICA)
      )
    );
    System.assert(
      OpportunityUtils.isStatusProposalReadjustment(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusAwaitingAcceptance(
        new Opportunity(StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE)
      )
    );
    System.assert(
      OpportunityUtils.isStatusAdditionalInformation(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_INFORMACOES_ADICIONAIS
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusContract(
        new Opportunity(StageName = OpportunityUtils.STATUS_CONTRATO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusValidation(
        new Opportunity(StageName = OpportunityUtils.STATUS_VALIDACAO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusAccessOpinion(
        new Opportunity(StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusEquipment(
        new Opportunity(StageName = OpportunityUtils.STATUS_EQUIPAMENTO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusInstallation(
        new Opportunity(StageName = OpportunityUtils.STATUS_INSTALACAO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusPaymentConfirmation(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusPaymentConfirmationContract(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO
        )
      )
    );
    System.assert(
      OpportunityUtils.isStatusCompleted(
        new Opportunity(StageName = OpportunityUtils.STATUS_FINALIZADO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusClosedWon(
        new Opportunity(StageName = OpportunityUtils.STATUS_GANHO_FECHADO)
      )
    );
    System.assert(
      OpportunityUtils.isStatusClosedLost(
        new Opportunity(StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO)
      )
    );

    System.assert(
      OpportunityUtils.isSubStatusContractGenerating(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusContractSent(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ENVIADO
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusContractFirmedSigned(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ASSINADO
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusInProgress(
        new Opportunity(Status__c = OpportunityUtils.SUB_STATUS_EM_ANDAMENTO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusPending(
        new Opportunity(Status__c = OpportunityUtils.SUB_STATUS_PENDENCIA)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusValidatingBonus(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_VALIDANDO_BONIFICACAO
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusAwaitingPayment(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusTechnicalVisitScheduling(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusAwaitingVisitData(
        new Opportunity(
          Status__c = OpportunityUtils.SUB_STATUS_ESTUDO_VIABILIDADE
        )
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusFastTrack(
        new Opportunity(Status__c = OpportunityUtils.SUB_STATUS_FAST_TRACK)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusUnderReview(
        new Opportunity(Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusApproved(
        new Opportunity(Status__c = OpportunityUtils.SUB_STATUS_APROVADO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusPaid(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_STATUS_PAGO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusOnSchedule(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_STATUS_EM_AGENDAMENTO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusScheduled(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_STATUS_AGENDADO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusWon(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_STATUS_GANHO)
      )
    );
    System.assert(
      OpportunityUtils.isSubStatusLost(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_STATUS_PERDIDO)
      )
    );
    System.assert(OpportunityUtils.isSubTypeMicroContract(newOpp));
    System.assert(
      OpportunityUtils.isSubTypeMiniContract(
        new Opportunity(SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MINI)
      )
    );

    System.assert(OpportunityUtils.hasContractBeenGenerated(newOpp, oldOpp));
    System.assert(OpportunityUtils.hasContractBeenApproved(newOpp, oldOpp));
    System.assert(OpportunityUtils.isContractApproved(newOpp));
    System.assert(OpportunityUtils.isWithSolarProduct(newOpp));
    System.assert(OpportunityUtils.isViabilityStatusChanging(newOpp, oldOpp));
    System.assert(
      OpportunityUtils.isOpportunityViable(
        new Opportunity(StatusViabilidade__c = 'Viável')
      )
    );
    System.assert(
      OpportunityUtils.isOpportunityNotViable(
        new Opportunity(StatusViabilidade__c = 'Inviável')
      )
    );
    System.assert(OpportunityUtils.isOpportunityPartiallyViable(newOpp));
    System.assert(OpportunityUtils.hasProposalBeenGenerated(newOpp, oldOpp));
    System.assert(OpportunityUtils.isProposalApproved(newOpp));
    System.assert(
      OpportunityUtils.isChangingToViabilityAnalysis(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
        ),
        oldOpp
      )
    );
    System.assert(OpportunityUtils.isViabilityStepChanging(newOpp, oldOpp));
    System.assert(
      OpportunityUtils.isViabilityDeadlineBeingAssigned(newOpp, oldOpp)
    );
    System.assert(
      OpportunityUtils.isOpportunityBeingRequiredReadjustment(newOpp, oldOpp)
    );
    System.assert(
      OpportunityUtils.isViabilityStatusBeingAssigned(newOpp, oldOpp)
    );
    System.assert(OpportunityUtils.isViabilityAnalysisOver(newOpp, oldOpp));
    System.assert(
      OpportunityUtils.isChangingContractGenerating(newOpp, oldOpp)
    );
    System.assert(
      OpportunityUtils.isChangingToClosedWon(
        new Opportunity(StageName = OpportunityUtils.STATUS_GANHO_FECHADO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToClosedLost(
        new Opportunity(StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToAccessOpinion(
        new Opportunity(StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToCompleted(
        new Opportunity(StageName = OpportunityUtils.STATUS_FINALIZADO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToValidation(
        new Opportunity(StageName = OpportunityUtils.STATUS_VALIDACAO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToContract(
        new Opportunity(StageName = OpportunityUtils.STATUS_CONTRATO),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToAwaitingAcceptance(
        new Opportunity(StageName = OpportunityUtils.STATUS_AGUARDANDO_ACEITE),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToPaymentConfirmationSinal(
        new Opportunity(
          StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL
        ),
        oldOpp
      )
    );
    System.assert(
      OpportunityUtils.isChangingToCommercialPresentation(newOpp, oldOpp)
    );
    System.assert(
      OpportunityUtils.hasDiscountApprovalStatusChangedToApprovedOrRejected(
        newOpp,
        oldOpp
      )
    );
    System.assert(OpportunityUtils.isFinancingSimulation(newOpp, oldOpp));

    Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
    if (recordTypes.containsKey('EzeeSolarB')) {
      Opportunity oldCredit = new Opportunity(
        RecordTypeId = recordTypes.get('EzeeSolarB').getRecordTypeId(),
        StageName = OpportunityUtils.STATUS_NEGOCIACAO
      );
      Opportunity newCredit = new Opportunity(
        RecordTypeId = recordTypes.get('EzeeSolarB').getRecordTypeId(),
        GrupoTarifario__c = 'Grupo B',
        StageName = OpportunityUtils.STATUS_ANALISE_CREDITO,
        ReferenceIdRevo__c = 'revo-123'
      );
      System.assert(
        OpportunityUtils.isEzeeSolarGrupoBInCreditAnalysis(newCredit, oldCredit)
      );
    }
  }

  @IsTest
  static void shouldDetectProposalFilesByTitle() {
    Account accountRecord = new Account(Name = 'Opportunity Utils');
    AccountTriggerHandler.disableTrigger();
    try {
      insert accountRecord;
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opp Utils',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = '00000000-0000-0000-0000-000000000010'
    );

    OpportunityTriggerHandler.disableTrigger();
    AccountTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      AccountTriggerHandler.enableTrigger();
      OpportunityTriggerHandler.enableTrigger();
    }

    insert new ContentVersion(
      Title = 'PROPOSTA BASE',
      PathOnClient = 'proposal.pdf',
      VersionData = Blob.valueOf('proposal'),
      FirstPublishLocationId = opportunityRecord.Id
    );
    insert new ContentVersion(
      Title = 'PROPOSTA READEQUACAO',
      PathOnClient = 'readequacao.pdf',
      VersionData = Blob.valueOf('readjustment'),
      FirstPublishLocationId = opportunityRecord.Id
    );

    System.assert(OpportunityUtils.hasProposal(opportunityRecord));
    System.assert(OpportunityUtils.hasProposalReadjustment(opportunityRecord));
  }
}
