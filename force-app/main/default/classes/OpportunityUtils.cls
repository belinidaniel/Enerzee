/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-10-2025
 * @last modified by  : Daniel Belini
**/
public class OpportunityUtils {

    //  Status
    //public static String STATUS_PROSPECCAO                          = 'Prospecção';
    //public static String STATUS_BACKLOG                             = 'Backlog';
    //public static String STATUS_SOLICITACAO_DE_PROPOSTA             = 'Solicitação de Proposta';
    //public static String STATUS_AGUARDANDO_APROVACAO                = 'Aguardando Aprovação';
    //public static String STATUS_PROPOSTA_ENVIADA_AGUARDANDO_ACEITE  = 'Proposta enviada / Aguardando Aceite';
    //public static String STATUS_AGENDAMENTO_DA_VISITA_TECNICA       = 'Agendamento da Visita Técnica';
    //public static String STATUS_AGUARDANDO_DADOS_DA_VISITA          = 'Aguardando dados da visita';
    //public static String STATUS_METODO_DE_PAGAMENTO                 = 'Método de pagamento';
    //public static String STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO    = 'Validação do método de pagamento';
    //public static String STATUS_GERACAO_DE_CONTRATO                 = 'Geração de contrato';
    //public static String STATUS_CONTRATO_ENVIADO                    = 'Contrato enviado';
    //public static String STATUS_CONTRATO_FIRMADO_ASSINADO           = 'Contrato firmado / Assinado';
    //public static String STATUS_AGUARDANDO_PAGAMENTO                = 'Aguardando Pagamento';
    //public static String STATUS_MINUTA_GERADA                       = 'Minuta Gerada';
    //public static String STATUS_AGUARDANDO_INFORMACAO               = 'Aguardando Informação';
    //public static String STATUS_AGUARDANDO_ASSINATURA				  = 'Aguardando Assinatura';
    //public static String STATUS_ASSINATURA_CONTRATO_PARCEIRO        = 'Assinatura de Contrato com o Parceiro';

    public static String STATUS_ELABORACAO_DE_PROPOSTA          = 'Elaboração de proposta';
    public static String STATUS_SIMULACAO_DE_PROPOSTA           = 'Simulação de Proposta';
    public static String STATUS_PROPOSTA_GERADA                 = 'Proposta Gerada';
    public static String STATUS_PROPOSTA_ENVIADA                = 'Proposta enviada';
    public static String STATUS_APRESENTACAO_COMERCIAL          = 'Apresentação Comercial';
    public static String STATUS_NEGOCIACAO                      = 'Negociação';
    public static String STATUS_CONFIRMACAO_PAGAMENTO_SINAL     = 'Confirmação de pagamento sinal';
    public static String STATUS_ANALISE_CREDITO                 = 'Análise de Crédito';
    public static String STATUS_INFORMACOES_ADICIONAIS          = 'Informações adicionais';
    public static String STATUS_ANALISE_DE_VIABILIDADE          = 'Viabilidade Técnica';
    public static String STATUS_READEQUACAO_DE_PROPOSTA         = 'Readequação de Proposta';
    public static String STATUS_AGUARDANDO_ACEITE               = 'Aguardando aceite';
    public static String STATUS_CONTRATO                        = 'Contrato';
    public static String STATUS_VIABILIDADE_TECNICA             = 'Viabilidade Tecnica';
    public static String STATUS_VALIDACAO                       = 'Validação';
    public static String STATUS_PARECER_DE_ACESSO               = 'Parecer de acesso';
    public static String STATUS_EQUIPAMENTO                     = 'Equipamento';
    public static String STATUS_INSTALACAO                      = 'Instalação';
    public static String STATUS_CONFIRMACAO_PAGAMENTO           = 'Confirmação de pagamento';
    public static String STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO  = 'Confirmação de pagamento contrato';
    public static String STATUS_FINALIZADO                      = 'Finalizado';
    public static String STATUS_GANHO_FECHADO                   = 'Ganho fechado';
    public static String STATUS_FECHADO_PERDIDO                 = 'Fechado Perdido';

    public static String SUB_STATUS_EM_AGENDAMENTO              = 'Em Agendamento';
    public static String SUB_STATUS_AGENDADO                    = 'Agendado';   
    public static String SUB_STATUS_AGUARDANDO_PAGAMENTO        = 'Aguardando Pagamento';
    public static String SUB_STATUS_PAGO                        = 'Pago';
    public static String SUB_STATUS_AGENDAMENTO_VISITA          = 'Agendamento de Visita';
    public static String SUB_STATUS_ESTUDO_VIABILIDADE          = 'Estudo de Viabilidade';
    public static String SUB_STATUS_AGUARDANDO_DOCUMENTOS       = 'Aguardando Documentos';
    public static String SUB_STATUS_GERACAO_CONTRATO            = 'Geração do Contrato';
    public static String SUB_STATUS_CONTRATO_ENVIADO            = 'Contrato Enviado';
    public static String SUB_STATUS_CONTRATO_ASSINADO           = 'Contrato Assinado';
    public static String SUB_STATUS_EM_ANDAMENTO                = 'Em Andamento';
    public static String SUB_STATUS_PENDENCIA                   = 'Pendência';
    public static String SUB_STATUS_ANALISE_CREDITO             = 'Análise';
    public static String SUB_STATUS_FAST_TRACK                  = 'Fast Track';
    public static String SUB_STATUS_EM_ANALISE                  = 'Em Análise';
    public static String SUB_STATUS_APROVADO                    = 'Aprovado';
    public static String SUB_STATUS_REPROVADO                   = 'Reprovado';
    public static String SUB_STATUS_ENTREGA_DE_MATERIAIS        = 'Entrega de materiais';
    public static String SUB_STATUS_EM_INSTALACAO               = 'Em instalação';
    public static String SUB_STATUS_VALIDANDO_BONIFICACAO       = 'Validando Bonificação';
    public static String SUB_STATUS_GANHO                       = 'Ganho';   
    public static String SUB_STATUS_PERDIDO                     = 'Perdido';   

    public static String SUB_TYPE_CONTRATO_MICRO                = 'Contrato Micro';
    public static String SUB_TYPE_CONTRATO_MINI                 = 'Contrato Mini';

    //  Validação de Tipo de Registro
    public static boolean isRecordTypeSolar(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId();
    }

    public static boolean isRecordTypeProdutos(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Produtos').getRecordTypeId();
    }

    public static boolean isRecordTypeServicos(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Servicos').getRecordTypeId();
    }

    public static boolean isRecordTypeServicosEPC(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('ServicosEPC').getRecordTypeId();
    }

    public static boolean isRecordTypeEzeeSolarA(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarA').getRecordTypeId();
    }

    public static boolean isRecordTypeEzeeSolarB(Opportunity opportunity){
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarB').getRecordTypeId();
    }

    public static Boolean isRecordTypeEzeeSolar(Opportunity opportunity) {
        Id EzeeSolarA = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarA').getRecordTypeId();
        Id EzeeSolarB = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarB').getRecordTypeId();
    
        return opportunity.RecordTypeId == EzeeSolarA || opportunity.RecordTypeId == EzeeSolarB;
    }

    public static boolean isRecordTypeEzeeConnect(Opportunity opportunity) {
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect').getRecordTypeId();
    }

    public static boolean isRecordTypeEzeeLivre(Opportunity opportunity) {
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeLivre').getRecordTypeId();
    }

    public static boolean isRecordTypeOtherOpportunities(Opportunity opportunity) {
        return opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('OutrasOportunidades').getRecordTypeId();
    }

    public static String resolveStageForProjectCompletion(Opportunity opportunity) {
        if (opportunity == null) {
            return STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO;
        }
        if (isRecordTypeEzeeSolarA(opportunity)) {
            return STATUS_EQUIPAMENTO;
        }
        return STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO;
    }

    //public static boolean isStatusProspecting(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_PROSPECCAO);
    //}

    //public static boolean isStatusAwaitingApproval(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_APROVACAO);
    //}

    //public static boolean isStatusProposalSentAwaitingAccepting(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_PROPOSTA_ENVIADA_AGUARDANDO_ACEITE);
    //}

    //public static boolean isStatusTechnicalVisitScheduling(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGENDAMENTO_DA_VISITA_TECNICA);
    //}

    //public static boolean isStatusAwaitingVisitData(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_DADOS_DA_VISITA);
    //}

    //public static boolean isStatusPaymentWay(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_METODO_DE_PAGAMENTO);
    //}

    //public static boolean isStatusPaymentWayValidation(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO);
    //}

    //public static boolean isStatusContractGenerating(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_GERACAO_DE_CONTRATO);
    //}
    
    //public static boolean isStatusContractSent(Opportunity opportunity){
    //    System.debug(opportunity);
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_CONTRATO_ENVIADO);
    //}

    //public static boolean isStatusContractFirmedSigned(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_CONTRATO_FIRMADO_ASSINADO);
    //}

    //public static boolean isWaitingPaiment(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_PAGAMENTO);
    //}

    //public static boolean isStatusDraftGenerated(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_MINUTA_GERADA);
    //}

    //public static boolean isWaitingInformation(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_INFORMACAO);
    //}
    
    //public static boolean isWaitingSignature(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_ASSINATURA);
    //}

    //public static boolean isStatusAssinatura(Opportunity opportunity){
    //    return opportunity.StageName.equalsIgnoreCase(STATUS_ASSINATURA_CONTRATO_PARCEIRO);
    //}

    public static boolean isStatusChanging(Opportunity newOpportunity, Opportunity oldOpportunity){
        return oldOpportunity.StageName != newOpportunity.StageName;
    }

    public static boolean isStatusProposalElaboration(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_ELABORACAO_DE_PROPOSTA);
    }

    public static boolean isStatusProposalSimulation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_SIMULACAO_DE_PROPOSTA);
    }
    
    public static boolean isStatusProposalSent(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_PROPOSTA_ENVIADA);
    }

    public static boolean isStatusProposalGenerated(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_PROPOSTA_GERADA);
    }

    public static boolean isStatusCommercialPresentation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_APRESENTACAO_COMERCIAL);
    }

    public static boolean isStatusNegotiation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_NEGOCIACAO);
    }

    public static boolean isStatusPaymentConfirmationSinal(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_CONFIRMACAO_PAGAMENTO_SINAL);
    }

    public static boolean isStatusCreditAnalysis(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_ANALISE_CREDITO);
    }

    public static boolean isStatusViabilityAnalysis(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_ANALISE_DE_VIABILIDADE) || opportunity.StageName.equalsIgnoreCase(STATUS_VIABILIDADE_TECNICA);
    }

    public static boolean isStatusProposalReadjustment(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_READEQUACAO_DE_PROPOSTA);
    }

    public static boolean isStatusAwaitingAcceptance(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_AGUARDANDO_ACEITE);
    }

    public static boolean isStatusAdditionalInformation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_INFORMACOES_ADICIONAIS);
    }

    public static boolean isStatusContract(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_CONTRATO);
    }

    public static boolean isStatusValidation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_VALIDACAO);
    }

    public static boolean isStatusAccessOpinion(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_PARECER_DE_ACESSO);
    }

    public static boolean isStatusEquipment(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_EQUIPAMENTO);
    }

    public static boolean isStatusInstallation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_INSTALACAO);
    }

    public static boolean isStatusPaymentConfirmation(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_CONFIRMACAO_PAGAMENTO);
    }

    public static boolean isStatusPaymentConfirmationContract(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO);
    }

    public static boolean isStatusCompleted(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_FINALIZADO);
    } 
    
    public static boolean isStatusClosedWon(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_GANHO_FECHADO);
    }

    public static boolean isStatusClosedLost(Opportunity opportunity){
        return opportunity.StageName.equalsIgnoreCase(STATUS_FECHADO_PERDIDO);
    }

    public static boolean isSubStatusContractGenerating(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_GERACAO_CONTRATO);
    }

    public static boolean isSubStatusContractSent(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_CONTRATO_ENVIADO);
    }

    public static boolean isSubStatusContractFirmedSigned(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_CONTRATO_ASSINADO);
    }

    public static boolean isSubStatusInProgress(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_EM_ANDAMENTO);
    }

    public static boolean isSubStatusPending(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_PENDENCIA);
    }

    public static boolean isSubStatusValidatingBonus(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_VALIDANDO_BONIFICACAO);
    }

    public static boolean isSubStatusAwaitingPayment(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_AGUARDANDO_PAGAMENTO);
    }

    public static boolean isSubStatusTechnicalVisitScheduling(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_AGENDAMENTO_VISITA);
    }

    public static boolean isSubStatusAwaitingVisitData(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_ESTUDO_VIABILIDADE);
    }

    public static boolean isSubStatusFastTrack(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_FAST_TRACK);
    }

    public static boolean isSubStatusUnderReview(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_EM_ANALISE);
    }

    public static boolean isSubStatusApproved(Opportunity opportunity){
        return opportunity.Status__c != null && opportunity.Status__c.equalsIgnoreCase(SUB_STATUS_APROVADO);
    }

    public static boolean isSubStatusPaid(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_STATUS_PAGO);
    }

    public static boolean isSubStatusOnSchedule(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_STATUS_EM_AGENDAMENTO);
    }

    public static boolean isSubStatusScheduled(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_STATUS_AGENDADO);
    }

    public static boolean isSubStatusWon(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_STATUS_GANHO);
    }

    public static boolean isSubStatusLost(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_STATUS_PERDIDO);
    }

    public static boolean isSubTypeMicroContract(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_TYPE_CONTRATO_MICRO);
    }

    public static boolean isSubTypeMiniContract(Opportunity opportunity){
        return opportunity.SubTipo__c != null && opportunity.SubTipo__c.equalsIgnoreCase(SUB_TYPE_CONTRATO_MINI);
    }

    /*

    public static boolean isChangingToProposalSentAwaitingAccepting(Opportunity newOpportunity, Opportunity oldOpportunity){
        return isStatusProposalElaboration(oldOpportunity) && isStatusProposalSentAwaitingAccepting(newOpportunity);
    }

    public static boolean isChangingToTechnicalVisitScheduling(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusTechnicalVisitScheduling(oldOpportunity) && isStatusTechnicalVisitScheduling(newOpportunity);
    }

    public static boolean isChangingToPaymentWay(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusPaymentWay(oldOpportunity) && isStatusPaymentWay(newOpportunity);
    }

    public static boolean isChangingToContractFirmedSigned(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusContractFirmedSigned(oldOpportunity) && isStatusContractFirmedSigned(newOpportunity);
    }
    
    public static boolean isChangingToTechnicalProposalReadjustment(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusProposalElaboration(oldOpportunity) && isStatusProposalElaboration(newOpportunity) && newOpportunity.PropostaGerada__c;
    }
    */

    public static boolean hasContractBeenGenerated(Opportunity opportunity, Opportunity oldOpportunity){
        return  opportunity.ContratoGerado__c && !oldOpportunity.ContratoGerado__c;
    }

    public static boolean hasContractBeenApproved(Opportunity opportunity, Opportunity oldOpportunity){
        return  opportunity.Contrato_aprovado__c && !oldOpportunity.Contrato_aprovado__c;
    }

    public static boolean isContractApproved(Opportunity opportunity){
        return  opportunity.Contrato_aprovado__c;
    }

    public static boolean isWithSolarProduct(Opportunity opportunity){
        return  opportunity.ProdutoSolar__c;
    }
    
    public static boolean isViabilityStatusChanging(Opportunity opportunity, Opportunity oldOpportunity){
        return  oldOpportunity.StatusViabilidade__c != opportunity.StatusViabilidade__c;
    }

    public static boolean isOpportunityViable(Opportunity opportunity){
        return  opportunity.StatusViabilidade__c != null && opportunity.StatusViabilidade__c.equalsIgnoreCase('Viável');
    }

    public static boolean isOpportunityNotViable(Opportunity opportunity){
        return  opportunity.StatusViabilidade__c != null && opportunity.StatusViabilidade__c.equalsIgnoreCase('Inviável');
    }

    public static boolean isOpportunityPartiallyViable(Opportunity opportunity){
        return  opportunity.StatusViabilidade__c != null && opportunity.StatusViabilidade__c.equalsIgnoreCase('Parcialmente Viável');
    }

    public static boolean hasProposalBeenGenerated(Opportunity opportunity, Opportunity oldOpportunity){
        return  opportunity.PropostaGerada__c && !oldOpportunity.PropostaGerada__c;
    }

    public static boolean isProposalApproved(Opportunity opportunity){
        return  opportunity.Proposta_aprovada__c;
    }

    public static boolean isChangingToProposalElaboration(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusProposalElaboration(oldOpportunity) && isStatusProposalElaboration(newOpportunity);
    }

    public static boolean isChangingToViabilityAnalysis(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusViabilityAnalysis(oldOpportunity) && isStatusViabilityAnalysis(newOpportunity);
    }

    public static boolean isViabilityStepChanging(Opportunity opportunity, Opportunity oldOpportunity){
        return opportunity.EtapaViabilidade__c != oldOpportunity.EtapaViabilidade__c;
    }
    
    public static boolean isViabilityDeadlineBeingAssigned(Opportunity opportunity, Opportunity oldOpportunity){
        return  oldOpportunity.PrazoAprovacaoViabilidade__c == null && opportunity.PrazoAprovacaoViabilidade__c != null;
    }

    public static boolean isOpportunityBeingRequiredReadjustment(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !oldOpportunity.ReadequacaoSolicitada__c && newOpportunity.ReadequacaoSolicitada__c;
    }

    public static boolean isViabilityStatusBeingAssigned(Opportunity opportunity, Opportunity oldOpportunity){
        return  isViabilityStatusChanging(opportunity, oldOpportunity) && opportunity.StatusViabilidade__c != null;
    }

    public static boolean isViabilityAnalysisOver(Opportunity opportunity, Opportunity oldOpportunity){
        return  isViabilityStepChanging(opportunity, oldOpportunity) && opportunity.EtapaViabilidade__c.equalsIgnoreCase('Estudo');
    }

    public static boolean isChangingContractGenerating(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isSubStatusContractGenerating(oldOpportunity) && isSubStatusContractGenerating(newOpportunity);
    }

    public static boolean isChangingToClosedWon(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusClosedWon(oldOpportunity) && isStatusClosedWon(newOpportunity);
    }

    public static boolean isChangingToClosedLost(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusClosedLost(oldOpportunity) && isStatusClosedLost(newOpportunity);
    }

    public static boolean isChangingToAccessOpinion(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusAccessOpinion(oldOpportunity) && isStatusAccessOpinion(newOpportunity);
    }

    public static boolean isChangingToCompleted(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusCompleted(oldOpportunity) && isStatusCompleted(newOpportunity);
    }

    public static boolean isChangingToValidation(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusValidation(oldOpportunity) && isStatusValidation(newOpportunity);
    }

    public static boolean isChangingToContract(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusContract(oldOpportunity) && isStatusContract(newOpportunity);
    }

    public static boolean isChangingToAwaitingAcceptance(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusAwaitingAcceptance(oldOpportunity) && isStatusAwaitingAcceptance(newOpportunity);
    }

    public static boolean isChangingToPaymentConfirmationSinal(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusPaymentConfirmationSinal(oldOpportunity) && isStatusPaymentConfirmationSinal(newOpportunity);
    }

    public static boolean isChangingToCommercialPresentation(Opportunity newOpportunity, Opportunity oldOpportunity){
        return !isStatusCommercialPresentation(oldOpportunity) && isStatusCommercialPresentation(newOpportunity);
    }

    public static boolean hasProposal(Opportunity opportunity){
        List<ContentVersion> cv = [SELECT Id from ContentVersion where FirstPublishLocationId  =: opportunity.Id];
        if(!cv.isEmpty()){
            return true;
        }
        return false; 
    }

    public static boolean hasProposalReadjustment(Opportunity opportunity){
        List<ContentVersion> cv = [SELECT Id from ContentVersion where FirstPublishLocationId  =: opportunity.Id And (Title like '%READEQUACAO%' OR Title like '%READEQUAÇÃO%')];
        if(!cv.isEmpty()){
            return true;
        }
        return false; 
    }

    public static Boolean hasDiscountApprovalStatusChangedToApprovedOrRejected(Opportunity opportunity, Opportunity oldOpportunity) {
        if (oldOpportunity != null) {
            String oldStatus = oldOpportunity.StatusAprovacaoDesconto__c;
            String newStatus = opportunity.StatusAprovacaoDesconto__c;
            
            Boolean statusChangedToApproved = !'Aprovado'.equals(oldStatus) && 'Aprovado'.equals(newStatus);
            Boolean statusChangedToRejected = !'Rejeitado'.equals(oldStatus) && 'Rejeitado'.equals(newStatus);

            return statusChangedToApproved || statusChangedToRejected;
        }
        return false;
    }

    public static Boolean isFinancingSimulation(Opportunity Opportunity, Opportunity oldOpportunity){
        return  opportunity.Financiamento_solicitado__c && !oldOpportunity.Financiamento_solicitado__c;
    }

    public static Boolean isEzeeSolarGrupoBInCreditAnalysis(Opportunity opp, Opportunity oldOpp) {
        
        if(opp.RecordTypeId != Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarB').getRecordTypeId()) return false;  

        if (opp.GrupoTarifario__c != 'Grupo B' || opp.StageName != 'Análise de Crédito') return false;

        return !String.isBlank(opp.ReferenceIdRevo__c) && opp.StageName != oldOpp.StageName;
    }

    public static String getApproveComment(Opportunity opportunity) {
        return [SELECT Id, Comments FROM ProcessInstanceStep 
        WHERE ProcessInstance.TargetObjectId = :opportunity.Id 
        AND StepStatus IN ('Approved', 'Rejected')
        Order By CreatedDate Desc Limit 1].Comments;
    }
}