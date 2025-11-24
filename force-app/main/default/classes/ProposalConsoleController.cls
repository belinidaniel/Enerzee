/**
 * @description       : Apex controller that powers the LWC responsible for managing proposal generation.
 * @author            : Daniel Belini
**/
public with sharing class ProposalConsoleController {
    public class ProposalTemplateDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String templateName;
    }

    public class ProposalFileDTO {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String downloadUrl;
        @AuraEnabled public String fileType;
    }

    public class ProposalDataDTO {
        @AuraEnabled public List<ProposalTemplateDTO> templates;
        @AuraEnabled public Id defaultTemplateId;
        @AuraEnabled public List<ProposalFileDTO> proposalFiles;
        @AuraEnabled public List<ProposalFileDTO> otherFiles;
        @AuraEnabled public Boolean hasViability;
    }

    public class ProposalActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id contentVersionId;
    }

    private static Boolean hasViabilityRecords(Id opportunityId){
        return [
            SELECT Id
            FROM ViabilityStudy__c
            WHERE Opportunity__c = :opportunityId
            LIMIT 1
        ].size() > 0;
    }

    @AuraEnabled(cacheable=true)
    public static ProposalDataDTO loadProposalData(Id opportunityId) {
        validateOpportunityId(opportunityId);

        Opportunity opp = [
            SELECT Id,
                   Numeroproposta__c,
                   GrupoTarifario__c,
                   RecordTypeId,
                   Parceiro__r.CapaProposta__c,
                   Parceiro__r.CapaPromocional__c,
                   ViabilityStudyFinished__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Set<Id> coverIds = new Set<Id>();
        if (opp.Parceiro__r != null) {
            if (opp.Parceiro__r.CapaProposta__c != null) {
                coverIds.add(opp.Parceiro__r.CapaProposta__c);
            }
            if (opp.Parceiro__r.CapaPromocional__c != null) {
                coverIds.add(opp.Parceiro__r.CapaPromocional__c);
            }
        }

        List<ProposalTemplateDTO> templates = new List<ProposalTemplateDTO>();
        if (!coverIds.isEmpty()) {
            for (ProposalCover__c cover : [
                SELECT Id, Name, Template__c
                FROM ProposalCover__c
                WHERE Id IN :coverIds AND IsActive__c = true
                ORDER BY Name
            ]) {
                ProposalTemplateDTO dto = new ProposalTemplateDTO();
                dto.id = cover.Id;
                dto.label = cover.Name;
                dto.templateName = cover.Template__c;
                templates.add(dto);
            }
        }

        List<OpportunityAttachmentLink__c> attachments = [
            SELECT Id,
                   Name,
                   AttachmentDescription__c,
                   AttachmentURL__c,
                   CreatedDate,
                   Type__c
            FROM OpportunityAttachmentLink__c
            WHERE OpportunityId__c = :opportunityId
            ORDER BY CreatedDate DESC
        ];

        List<ProposalFileDTO> proposalFiles = new List<ProposalFileDTO>();
        List<ProposalFileDTO> otherFiles = new List<ProposalFileDTO>();

        for (OpportunityAttachmentLink__c link : attachments) {
            ProposalFileDTO dto = new ProposalFileDTO();
            dto.recordId = link.Id;
            dto.title = String.isNotBlank(link.AttachmentDescription__c) ? link.AttachmentDescription__c : link.Name;
            dto.description = link.AttachmentDescription__c;
            dto.createdDate = link.CreatedDate;
            dto.downloadUrl = link.AttachmentURL__c;
            dto.fileType = link.Type__c;

            if ('Proposal'.equalsIgnoreCase(link.Type__c)) {
                proposalFiles.add(dto);
            } else {
                otherFiles.add(dto);
            }
        }

        ProposalDataDTO result = new ProposalDataDTO();
        result.templates = templates;
        result.proposalFiles = proposalFiles;
        result.otherFiles = otherFiles;
        result.hasViability = hasViabilityRecords(opportunityId);
        if (opp.Parceiro__r != null) {
            result.defaultTemplateId = opp.Parceiro__r.CapaProposta__c;
        }
        if (result.defaultTemplateId == null && !templates.isEmpty()) {
            result.defaultTemplateId = templates[0].id;
        }
        return result;
    }

    @AuraEnabled
    public static ProposalActionResult sendProposal(Id opportunityId, Id coverId) {
        validateOpportunityId(opportunityId);
        if (coverId == null) {
            throw new AuraHandledException('Selecione um modelo de proposta.');
        }

        Opportunity opp = [
            SELECT Id,
                   Account.Name,
                   Numeroproposta__c,
                   GrupoTarifario__c,
                   StageName,
                   RecordTypeId,
                   RecordType.DeveloperName,
                   PropostaAlterada__c,
                   Parceiro__r.Name,
                   ViabilityStudyFinished__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        ProposalCover__c cover = [
            SELECT Id, Template__c
            FROM ProposalCover__c
            WHERE Id = :coverId AND IsActive__c = true
            LIMIT 1
        ];

        if (cover == null || String.isBlank(cover.Template__c)) {
            throw new AuraHandledException('Modelo de proposta inválido.');
        }

        Blob pdfContent = PDFControllerExtension.generatePdfContent(
            opp.Id,
            cover.Id,
            cover.Template__c,
            true
        );

        if (pdfContent == null) {
            throw new AuraHandledException('Não foi possível gerar o PDF da proposta.');
        }

        String filePrefix = buildFilePrefix(opp);
        Id contentVersionId = PDFControllerExtension.savePdfFile(
            opp.Id,
            filePrefix,
            cover.Template__c,
            pdfContent,
            opp.PropostaAlterada__c
        );
        if (contentVersionId == null) {
            throw new AuraHandledException('Não foi possível salvar o arquivo da proposta.');
        }

        IntegracaoNivelloProposta.ProposalIntegrationResult integrationResult =
            applyPostGenerationUpdates(opp, true, contentVersionId);

        ProposalActionResult result = new ProposalActionResult();
        result.success = integrationResult == null || integrationResult.success == null || integrationResult.success;
        result.contentVersionId = contentVersionId;
        result.message = String.isNotBlank(integrationResult != null ? integrationResult.message : null)
            ? integrationResult.message
            : 'Proposta enviada para o aplicativo.';
        return result;
    }

    private static String buildFilePrefix(Opportunity opp) {
        String accountName = (opp.Account != null && !String.isBlank(opp.Account.Name))
            ? opp.Account.Name
            : opp.Name;
        String numero = String.isBlank(opp.Numeroproposta__c) ? '' : opp.Numeroproposta__c + ' ';
        String nomeRegistro = (numero + accountName).trim();
        String parceiro = (opp.Parceiro__r != null) ? opp.Parceiro__r.Name : null;
        String baseLabel = opp.ViabilityStudyFinished__c ? 'Readequacao' : 'Proposta';

        if (opp.GrupoTarifario__c == 'Grupo A' || parceiro == 'Enerzee - Grupo A') {
            return baseLabel + ' A ' + nomeRegistro;
        } else if (opp.GrupoTarifario__c == 'Grupo B' || parceiro == 'Enerzee - Grupo B') {
            return baseLabel + ' B ' + nomeRegistro;
        }

        return baseLabel + ' ' + nomeRegistro;
    }

    private static IntegracaoNivelloProposta.ProposalIntegrationResult applyPostGenerationUpdates(Opportunity sourceOpp, Boolean waitForIntegration, Id contentVersionId) {
        OpportunityBO.skipAsyncProposalGeneration = true;

        Opportunity oppUpdate = new Opportunity(Id = sourceOpp.Id);
        oppUpdate.PropostaGerada__c = true;

        if (OpportunityUtils.isStatusAwaitingAcceptance(sourceOpp)) {
            oppUpdate.StageName = OpportunityUtils.STATUS_CONTRATO;
        } else if (
            OpportunityUtils.isStatusProposalElaboration(sourceOpp) ||
            OpportunityUtils.isStatusProposalSimulation(sourceOpp)
        ) {
            if (OpportunityUtils.isRecordTypeSolar(sourceOpp)) {
                oppUpdate.StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA;
            } else if (OpportunityUtils.isRecordTypeEzeeSolarB(sourceOpp)) {
                oppUpdate.StageName = OpportunityUtils.STATUS_ANALISE_CREDITO;
            } else {
                oppUpdate.StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
            }
        }

        if (sourceOpp.PropostaAlterada__c) {
            oppUpdate.PropostaAlterada__c = false;
        }

        try {
            update oppUpdate;
        } catch (Exception e) {
            Utils.createLog('ProposalConsoleController', 'applyPostGenerationUpdates.update', e);
            throw new AuraHandledException('Não foi possível atualizar a oportunidade após gerar a proposta.');
        }

        IntegracaoNivelloProposta.ProposalIntegrationResult integrationResult;
        try {
            if(waitForIntegration == true){
                integrationResult = contentVersionId != null
                    ? IntegracaoNivelloProposta.gerandoPropostaSincrona(sourceOpp.Id)
                    : IntegracaoNivelloProposta.gerandoPropostaSincrona(sourceOpp.Id);
            } else {
                IntegracaoNivelloProposta.gerandoProposta(sourceOpp.Id);
            }
        } catch (Exception integrationEx) {
            Utils.createLog('ProposalConsoleController', 'IntegracaoNivelloProposta', integrationEx);
            integrationResult = new IntegracaoNivelloProposta.ProposalIntegrationResult();
            integrationResult.success = false;
            integrationResult.message = 'Proposta salva, mas falha ao enviar para o aplicativo.';
        } finally {
            OpportunityBO.skipAsyncProposalGeneration = false;
        }

        if (sourceOpp.PropostaAlterada__c) {
            try {
                ProposalService.updateOpportunityPhase(new Set<Id>{ sourceOpp.Id });
            } catch (Exception proposalEx) {
                Utils.createLog('ProposalConsoleController', 'ProposalService.updateOpportunityPhase', proposalEx);
            }
        }

        return integrationResult;
    }

    private static void validateOpportunityId(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('O registro da oportunidade é obrigatório.');
        }
    }
}
