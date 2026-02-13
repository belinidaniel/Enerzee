/**
 * @description       : Centraliza regras de Approval Process da Opportunity
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-12-2026
 * @last modified by  : Daniel Belini
 **/
public without sharing class ApprovalProcessService {

    @TestVisible private static final String DISCOUNT_STATUS_PENDING = 'Pendente';
    @TestVisible private static final String DISCOUNT_STATUS_APPROVED = 'Aprovado';
    @TestVisible private static final String RECALL_ACTION_REMOVED = 'Removed';
    @TestVisible private static final String DEFAULT_RECALL_COMMENT =
        'Approval cancelado automaticamente por readequacao: StatusAprovacaoDesconto__c alterado de Pendente para em branco.';

    // Controle por transacao para evitar multiplas enfileiracoes da mesma oportunidade
    @TestVisible private static Set<Id> queuedProposalOpps = new Set<Id>();

    public interface ApprovalGateway {
        List<ProcessInstanceWorkitem> findPendingWorkitems(Set<Id> targetObjectIds);
        Approval.ProcessResult recall(Approval.ProcessWorkitemRequest request);
    }

    private class DefaultApprovalGateway implements ApprovalGateway {
        public List<ProcessInstanceWorkitem> findPendingWorkitems(Set<Id> targetObjectIds) {
            return [
                SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :targetObjectIds
                AND ProcessInstance.Status = 'Pending'
            ];
        }

        public Approval.ProcessResult recall(Approval.ProcessWorkitemRequest request) {
            return Approval.process(request);
        }
    }

    @TestVisible
    private static ApprovalGateway gateway = new DefaultApprovalGateway();

    @TestVisible
    static void setGateway(ApprovalGateway customGateway) {
        gateway = (customGateway == null) ? new DefaultApprovalGateway() : customGateway;
    }

    @TestVisible
    static void resetGateway() {
        gateway = new DefaultApprovalGateway();
    }

    /**
     * Aplica desconto proposto e inicia Approval Process quando o status muda para Pendente.
     */
    public static void applyDiscountAndInitiateApproval(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        if (newMap == null || oldMap == null || newMap.isEmpty()) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        List<Approval.ProcessSubmitRequest> approvalRequests = new List<Approval.ProcessSubmitRequest>();

        Set<Id> oppIdsWithActiveApproval = new Set<Id>();
        for (ProcessInstance pi : [
            SELECT TargetObjectId
            FROM ProcessInstance
            WHERE TargetObjectId IN :newMap.keySet()
            AND Status = 'Pending'
        ]) {
            oppIdsWithActiveApproval.add(pi.TargetObjectId);
        }

        for (Opportunity opp : newMap.values()) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) {
                continue;
            }

            if (opp.StatusAprovacaoDesconto__c != oldOpp.StatusAprovacaoDesconto__c
                && opp.StatusAprovacaoDesconto__c == DISCOUNT_STATUS_PENDING) {

                Opportunity updateOpp = new Opportunity(Id = opp.Id);

                Decimal totalProposalValue = opp.ValorTotalProposta__c != null ? opp.ValorTotalProposta__c : opp.ValorTotalProdutos__c;
                Decimal discountPercentage = 0;
                if (totalProposalValue != null && totalProposalValue != 0) {
                    discountPercentage = (opp.DescontoUFV__c / totalProposalValue) * 100;
                }

                Decimal totalValue =
                    (opp.BDI__c != null ? opp.BDI__c : 0) +
                    (opp.Rede3750__c != null ? opp.Rede3750__c : 0) +
                    (opp.Pontos__c != null ? opp.Pontos__c : 0) +
                    (opp.Direct__c != null ? opp.Direct__c : 0);

                Decimal bdiPercentage = 0;
                Decimal redePercentage = 0;
                if (totalValue > 0) {
                    bdiPercentage = (opp.BDI__c / totalValue);
                    redePercentage = 1 - bdiPercentage;
                }

                Decimal bdiDiscount = opp.DescontoUFV__c * bdiPercentage;
                Decimal redeDiscount = opp.DescontoUFV__c * redePercentage;

                updateOpp.ValorPropostoBDI__c = opp.BDI__c - bdiDiscount;

                Decimal redeTotal = opp.Rede__c != null ? opp.Rede__c :
                    (opp.Rede3750__c != null ? opp.Rede3750__c : 0) +
                    (opp.Pontos__c != null ? opp.Pontos__c : 0) +
                    (opp.Direct__c != null ? opp.Direct__c : 0);

                if (redeTotal != null && redeTotal > 0 && opp.Rede3750__c != null && opp.Rede3750__c > 0) {
                    updateOpp.ValorPropostoRede3750__c = opp.Rede3750__c - (redeDiscount * (opp.Rede3750__c / redeTotal));
                }
                if (redeTotal != null && redeTotal > 0 && opp.Pontos__c != null && opp.Pontos__c > 0) {
                    updateOpp.ValorPropostoPontos__c = opp.Pontos__c - (redeDiscount * (opp.Pontos__c / redeTotal));
                }
                if (redeTotal != null && redeTotal > 0 && opp.Direct__c != null && opp.Direct__c > 0) {
                    updateOpp.ValorPropostoDirect__c = opp.Direct__c - (redeDiscount * (opp.Direct__c / redeTotal));
                }

                updateOpp.BDIOriginal__c = opp.BDI__c;
                updateOpp.DirectOriginal__c = opp.Direct__c;
                updateOpp.PontosOriginal__c = opp.Pontos__c;
                updateOpp.TotalRedeOriginal__c =
                    (opp.Rede3750__c != null ? opp.Rede3750__c : 0) +
                    (opp.Pontos__c != null ? opp.Pontos__c : 0) +
                    (opp.Direct__c != null ? opp.Direct__c : 0);
                updateOpp.RedeOriginal3750__c = opp.Rede3750__c;
                updateOpp.ValorTotalPropostaOriginal__c = opp.ValorTotalProposta__c;

                oppsToUpdate.add(updateOpp);

                if (oppIdsWithActiveApproval.contains(opp.Id)) {
                    continue;
                }

                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setComments('Submissão automática para aprovação de desconto.');
                req.setObjectId(opp.Id);
                req.setSubmitterId(UserInfo.getUserId());
                req.setProcessDefinitionNameOrId('Processo_de_Aprova_o_de_Desconto');
                approvalRequests.add(req);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            try {
                update oppsToUpdate;
            } finally {
                OpportunityTriggerHandler.enableTrigger();
            }
        }

        if (!approvalRequests.isEmpty() && !Test.isRunningTest()) {
            OpportunityTriggerHandler.disableTrigger();
            try {
                Approval.process(approvalRequests);
            } finally {
                OpportunityTriggerHandler.enableTrigger();
            }
        }
    }

    /**
     * Aplica desconto definitivo quando o Approval de desconto for aprovado.
     */
    public static void applyApprovedDiscounts(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        if (newMap == null || oldMap == null || newMap.isEmpty()) {
            return;
        }

        List<Opportunity> approvedOpportunities = new List<Opportunity>();
        List<Id> approvedIds = new List<Id>();

        for (Opportunity opp : newMap.values()) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) {
                continue;
            }

            if (opp.StatusAprovacaoDesconto__c == DISCOUNT_STATUS_APPROVED
                && opp.StatusAprovacaoDesconto__c != oldOpp.StatusAprovacaoDesconto__c) {

                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);

                oppToUpdate.ValorAnteriorBDI__c = opp.BDI__c;
                oppToUpdate.ValorAnteriorRede3750__c = opp.Rede3750__c;
                oppToUpdate.ValorAnteriorPontos__c = opp.Pontos__c;
                oppToUpdate.ValorAnteriorDirect__c = opp.Direct__c;

                oppToUpdate.BDI__c = opp.ValorPropostoBDI__c;
                oppToUpdate.Rede3750__c = opp.ValorPropostoRede3750__c;
                oppToUpdate.Pontos__c = opp.ValorPropostoPontos__c;
                oppToUpdate.Direct__c = opp.ValorPropostoDirect__c;

                oppToUpdate.PropostaAlterada__c = true;
                oppToUpdate.PropostaGerada__c = false;
                oppToUpdate.ReadequacaoSolicitada__c = true;

                approvedOpportunities.add(oppToUpdate);
                approvedIds.add(opp.Id);
            }
        }

        if (!approvedOpportunities.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            try {
                update approvedOpportunities;
            } finally {
                OpportunityTriggerHandler.enableTrigger();
            }

            for (Id oppId : approvedIds) {
                enqueueProposalSavePdfJobIfAbsent(oppId, true, true);
            }
        }
    }

    public static void updateApproveComment(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap) {
        if (newRecords == null || newRecords.isEmpty() || oldRecordsMap == null) {
            return;
        }

        for (Opportunity opportunity : newRecords) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);
            if (oldOpportunity == null) {
                continue;
            }

            if (OpportunityUtils.hasDiscountApprovalStatusChangedToApprovedOrRejected(opportunity, oldOpportunity)) {
                opportunity.ObservacaoAprovacao__c = OpportunityUtils.getApproveComment(opportunity);
            }
        }
    }

    public static void sendApprovalUpdate(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap) {
        if (newRecordList == null || newRecordList.isEmpty() || oldRecordsMap == null) {
            return;
        }

        for (Opportunity opportunity : newRecordList) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);
            if (oldOpportunity == null) {
                continue;
            }

            if (opportunity.StatusAprovacaoDesconto__c != oldOpportunity.StatusAprovacaoDesconto__c) {
                IntegracaoNivelloAprovacaoDesconto.enviarStatusAprovacaoDesconto(new Set<Id>{opportunity.Id});
            }
        }
    }

    // Compatibilidade com chamadas legadas
    public static void sendAprovalUpdate(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap) {
        sendApprovalUpdate(newRecordList, oldRecordsMap);
    }

    /**
     * Regra de negocio:
     * se StatusAprovacaoDesconto__c mudar de 'Pendente' para vazio,
     * qualquer approval pendente da oportunidade deve ser cancelado automaticamente.
     */
    public static void recallPendingDiscountApprovals(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        Set<Id> targetObjectIds = collectDiscountResetIds(newMap, oldMap);
        if (targetObjectIds.isEmpty()) {
            return;
        }
        System.debug('ApprovalProcessService.recallPendingDiscountApprovals - targetObjectIds: ' + targetObjectIds);
        System.debug('ApprovalProcessService.recallPendingDiscountApprovals - DEFAULT_RECALL_COMMENT: ' + DEFAULT_RECALL_COMMENT);

        recallPendingApprovals(targetObjectIds, DEFAULT_RECALL_COMMENT);
    }

    /**
     * Metodo generico para permitir reutilizacao por outros objetos/triggers.
     */
    public static void recallPendingApprovals(Set<Id> targetObjectIds, String recallComment) {
        if (targetObjectIds == null || targetObjectIds.isEmpty()) {
            return;
        }

        List<ProcessInstanceWorkitem> pendingWorkitems = gateway.findPendingWorkitems(targetObjectIds);
        if (pendingWorkitems.isEmpty()) {
            return;
        }

        Map<Id, ProcessInstanceWorkitem> firstWorkitemByProcessInstanceId = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem workitem : pendingWorkitems) {
            if (workitem.ProcessInstanceId == null || firstWorkitemByProcessInstanceId.containsKey(workitem.ProcessInstanceId)) {
                continue;
            }
            firstWorkitemByProcessInstanceId.put(workitem.ProcessInstanceId, workitem);
        }

        String finalComment = String.isBlank(recallComment) ? DEFAULT_RECALL_COMMENT : recallComment;
        for (ProcessInstanceWorkitem workitem : firstWorkitemByProcessInstanceId.values()) {
            Approval.ProcessWorkitemRequest request = new Approval.ProcessWorkitemRequest();
            request.setWorkitemId(workitem.Id);
            request.setAction(RECALL_ACTION_REMOVED);
            request.setComments(finalComment);

            try {
                gateway.recall(request);
            } catch (Exception ex) {
                System.debug(
                    LoggingLevel.ERROR,
                    'ApprovalProcessService.recallPendingApprovals failed for workitem ' + workitem.Id + ': ' + ex.getMessage()
                );
            }
        }
    }

    @TestVisible
    static Set<Id> collectDiscountResetIds(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        Set<Id> targetObjectIds = new Set<Id>();

        System.debug(
            LoggingLevel.INFO,
            'ApprovalProcessService.collectDiscountResetIds - start. newMapSize=' +
            (newMap == null ? 0 : newMap.size()) +
            ', oldMapSize=' +
            (oldMap == null ? 0 : oldMap.size())
        );

        if (newMap == null || oldMap == null) {
            System.debug(
                LoggingLevel.WARN,
                'ApprovalProcessService.collectDiscountResetIds - abortado: newMap ou oldMap nulo.'
            );
            return targetObjectIds;
        }

        for (Opportunity newOpportunity : newMap.values()) {
            Opportunity oldOpportunity = oldMap.get(newOpportunity.Id);
            if (oldOpportunity == null) {
                System.debug(
                    LoggingLevel.WARN,
                    'ApprovalProcessService.collectDiscountResetIds - oldOpportunity nao encontrada para Id=' + newOpportunity.Id
                );
                continue;
            }

            String oldStatus = oldOpportunity.StatusAprovacaoDesconto__c;
            String newStatus = newOpportunity.StatusAprovacaoDesconto__c;
            Boolean isNewStatusBlank = String.isBlank(newStatus);
            Boolean changedFromPendingToBlank =
                oldStatus == DISCOUNT_STATUS_PENDING && isNewStatusBlank;
            Boolean alreadyBlankStatus = String.isBlank(oldStatus) && isNewStatusBlank;

            System.debug(
                LoggingLevel.INFO,
                'ApprovalProcessService.collectDiscountResetIds - oppId=' + newOpportunity.Id +
                ', oldStatus=' + oldStatus +
                ', newStatus=' + newStatus +
                ', changedFromPendingToBlank=' + changedFromPendingToBlank +
                ', alreadyBlankStatus=' + alreadyBlankStatus
            );

            if (changedFromPendingToBlank || alreadyBlankStatus) {
                targetObjectIds.add(newOpportunity.Id);
                System.debug(
                    LoggingLevel.INFO,
                    'ApprovalProcessService.collectDiscountResetIds - oppId adicionado=' + newOpportunity.Id
                );
            }
        }

        System.debug(
            LoggingLevel.INFO,
            'ApprovalProcessService.collectDiscountResetIds - end. matchedCount=' +
            targetObjectIds.size() +
            ', matchedIds=' + targetObjectIds
        );
        return targetObjectIds;
    }

    public static Boolean enqueueProposalSavePdfJobIfAbsent(Id opportunityId, Boolean firstFlag, Boolean secondFlag) {
        if (opportunityId == null) {
            return false;
        }

        if (queuedProposalOpps.contains(opportunityId)) {
            System.debug('SavePdfJob - ja enfileirado para opp ' + opportunityId);
            return false;
        }

        queuedProposalOpps.add(opportunityId);
        System.enqueueJob(new PDFControllerExtension.SavePdfJob(opportunityId, firstFlag, secondFlag));
        return true;
    }
}
