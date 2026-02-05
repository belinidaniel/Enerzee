/**
 * Configuração rápida:
 * - ProposalCover__c com Name = 'Relatorio de entrega de obra' e IsActive__c = true.
 * - Anexe dois arquivos (Files) no ProposalCover__c com títulos "Capa" e "Contra capa".
 * - ActivityRequiredDocument__mdt com ActivitySubject__c = 'RELATÓRIO FINAL DE OBRA' e RequiredFiles__c
 *   na ordem desejada das páginas.
 * - Apenas imagens (JPG/PNG/etc.) são suportadas por enquanto; PDFs serão ignorados.
 * - Imagens externas são usadas diretamente por URL (sem callout).
 */
public with sharing class WorkDeliveryReportService {
    public static final String STATUS_OBRA_CONCLUIDA = 'Obra concluída';
    public static final String TASK_SUBJECT = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA;
    public static final String TEMPLATE_NAME = 'Relatorio de entrega de obra';
    public static final String COVER_TITLE = 'Capa';
    public static final String BACK_COVER_TITLE = 'Contra capa';
    public static final String AZURE_NAMED_CREDENTIAL = 'AzureBlobNC';

    @TestVisible
    private static List<String> requiredDocsOverride;

    private static Set<Id> enqueuedInstalacoes = new Set<Id>();

    public static void enqueueForInstallations(
        List<Instalacao__c> newRecords,
        Map<Id, Instalacao__c> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Set<Id> installationIds = new Set<Id>();
        for (Instalacao__c inst : newRecords) {
            Instalacao__c oldInst = oldMap != null ? oldMap.get(inst.Id) : null;
            if (!isStatusChangedToCompleted(inst, oldInst)) {
                continue;
            }
            if (inst.WorkDeliveryReportGenerated__c == true || inst.WorkDeliveryReportContentDocumentId__c != null) {
                continue;
            }
            if (enqueuedInstalacoes.contains(inst.Id)) {
                continue;
            }
            installationIds.add(inst.Id);
            enqueuedInstalacoes.add(inst.Id);
        }

        if (!installationIds.isEmpty()) {
            System.enqueueJob(new WorkDeliveryReportQueueable(new List<Id>(installationIds)));
        }
    }

    @TestVisible
    static Boolean isStatusChangedToCompleted(Instalacao__c inst, Instalacao__c oldInst) {
        if (inst == null || String.isBlank(inst.Status__c)) {
            return false;
        }
        if (oldInst != null && equalsIgnoreCase(inst.Status__c, oldInst.Status__c)) {
            return false;
        }
        return equalsIgnoreCase(inst.Status__c, STATUS_OBRA_CONCLUIDA);
    }

    public static void generateAndAttach(Id installationId) {
        if (installationId == null) {
            return;
        }
        Instalacao__c inst;
        try {
            inst = [
                SELECT Id, Status__c, WorkDeliveryReportGenerated__c, WorkDeliveryReportContentDocumentId__c,
                       WorkDeliveryReportLastError__c,
                       Oportunidade__c, Oportunidade__r.Numeroproposta__c, Oportunidade__r.Name
                FROM Instalacao__c
                WHERE Id = :installationId
                LIMIT 1
            ];
        } catch (Exception e) {
            logError(installationId, 'Instalação não encontrada.', e);
            return;
        }

        if (inst.WorkDeliveryReportGenerated__c == true || inst.WorkDeliveryReportContentDocumentId__c != null) {
            return;
        }
        if (!equalsIgnoreCase(inst.Status__c, STATUS_OBRA_CONCLUIDA)) {
            return;
        }

        Task finalReportTask = null;
        List<Task> taskList = [
            SELECT Id, Subject
            FROM Task
            WHERE WhatId = :installationId
                AND Subject = :TASK_SUBJECT
                AND IsDeleted = false
            LIMIT 1
        ];
        if (!taskList.isEmpty()) {
            finalReportTask = taskList[0];
        }
        if (finalReportTask == null) {
            logAndUpdateInstallation(inst, 'Tarefa "' + TASK_SUBJECT + '" não encontrada para a instalação.');
            return;
        }

        List<String> requiredDocs = loadRequiredDocuments();
        if (requiredDocs.isEmpty()) {
            logAndUpdateInstallation(inst, 'Nenhum documento obrigatório configurado para "' + TASK_SUBJECT + '".');
            return;
        }

        ProposalCover__c template = loadActiveTemplate();
        if (template == null) {
            logAndUpdateInstallation(inst, 'Template "' + TEMPLATE_NAME + '" não encontrado ou inativo.');
            return;
        }

        CoverPair covers = loadCoverVersions(template.Id);
        if (covers == null || covers.coverVersion == null || covers.backCoverVersion == null) {
            logAndUpdateInstallation(inst, 'Capa e/ou contracapa não encontradas nos arquivos do template "' + TEMPLATE_NAME + '".');
            return;
        }

        List<OpportunityAttachmentLink__c> externalLinks = [
            SELECT Id, AttachmentURL__c, AttachmentDescription__c, DocRequiredName__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(installationId)
                AND ActivityName__c = :TASK_SUBJECT
            ORDER BY CreatedDate DESC
        ];
        Map<String, OpportunityAttachmentLink__c> externalByNorm = mapExternalLinks(externalLinks);

        Set<Id> linkedEntityIds = new Set<Id>{ installationId };
        if (finalReportTask != null) {
            linkedEntityIds.add(finalReportTask.Id);
        }
        List<ContentDocumentLink> internalLinks = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ];
        Map<String, ContentDocumentLink> internalByNorm = mapInternalLinks(internalLinks);

        List<DocumentSource> sources = new List<DocumentSource>();
        List<String> missingDocs = new List<String>();

        for (String docName : requiredDocs) {
            String normalized = normalizeName(docName);
            OpportunityAttachmentLink__c external = externalByNorm.get(normalized);
            if (external != null) {
                sources.add(buildExternalSource(external, docName));
                continue;
            }

            ContentDocumentLink internal = internalByNorm.get(normalized);
            if (internal != null
                && internal.ContentDocument != null
                && internal.ContentDocument.LatestPublishedVersionId != null) {
                sources.add(buildInternalSource(
                    internal.ContentDocumentId,
                    internal.ContentDocument.LatestPublishedVersionId
                ));
                continue;
            }

            missingDocs.add(docName);
        }

        if (!missingDocs.isEmpty()) {
            logAndUpdateInstallation(
                inst,
                'Ainda faltam anexar os documentos obrigatórios: ' + String.join(missingDocs, ', ')
            );
            return;
        }

        List<PageItem> pages = new List<PageItem>();
        PageItem coverPage = buildPageItemFromVersion(covers.coverVersion);
        if (coverPage != null) {
            pages.add(coverPage);
        }

        for (DocumentSource source : sources) {
            if (source == null) {
                continue;
            }
            if (source.isExternal()) {
                if (!isImageUrl(source.externalUrl)) {
                    logAndUpdateInstallation(
                        inst,
                        'Documento não é imagem (somente imagens são suportadas): ' + source.displayName + '.'
                    );
                    return;
                }
                PageItem externalPage = buildPageItemFromUrl(source.externalUrl);
                if (externalPage != null) {
                    pages.add(externalPage);
                }
            } else {
                pages.add(new PageItem(source.versionId, source.contentDocumentId));
            }
        }

        PageItem backPage = buildPageItemFromVersion(covers.backCoverVersion);
        if (backPage != null) {
            pages.add(backPage);
        }

        String fileName = buildReportFileName(inst);
        Blob pdfContent;
        if (Test.isRunningTest()) {
            pdfContent = Blob.valueOf('TEST_PDF');
        } else {
            PageReference pageRef = Page.WorkDeliveryReportPdf;
            pageRef.getParameters().put('pages', JSON.serialize(pages));
            pdfContent = pageRef.getContentAsPDF();
        }

        if (pdfContent == null || pdfContent.size() == 0) {
            logAndUpdateInstallation(inst, 'Falha ao gerar o PDF final.');
            return;
        }

        ContentVersion reportVersion = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = pdfContent
        );
        insert reportVersion;

        ContentVersion storedReport = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :reportVersion.Id
            LIMIT 1
        ];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = storedReport.ContentDocumentId,
            LinkedEntityId = installationId,
            Visibility = 'AllUsers',
            ShareType = 'V'
        );
        insert link;

        // update new Instalacao__c(
        //     Id = installationId,
        //     WorkDeliveryReportGenerated__c = true,
        //     WorkDeliveryReportContentDocumentId__c = String.valueOf(storedReport.ContentDocumentId),
        //     WorkDeliveryReportLastError__c = null
        // );
    }

    private static List<String> loadRequiredDocuments() {
        if (requiredDocsOverride != null) {
            return new List<String>(requiredDocsOverride);
        }

        List<String> docs = new List<String>();
        for (ActivityRequiredDocument__mdt cfg : [
            SELECT RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :TASK_SUBJECT
        ]) {
            if (String.isBlank(cfg.RequiredFiles__c)) {
                continue;
            }
            for (String name : cfg.RequiredFiles__c.split(';')) {
                if (String.isBlank(name)) {
                    continue;
                }
                docs.add(name.trim());
            }
        }
        return docs;
    }

    private static ProposalCover__c loadActiveTemplate() {
        List<ProposalCover__c> templates = [
            SELECT Id, Name, Template__c, IsActive__c
            FROM ProposalCover__c
            WHERE Name = :TEMPLATE_NAME
                AND IsActive__c = true
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    private static CoverPair loadCoverVersions(Id proposalCoverId) {
        if (proposalCoverId == null) {
            return null;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :proposalCoverId
        ];

        String coverKey = normalizeName(COVER_TITLE);
        Set<String> backKeys = new Set<String>{
            normalizeName(BACK_COVER_TITLE),
            normalizeName('Contracapa'),
            normalizeName('Contra_capa')
        };

        Id coverVersionId;
        Id backVersionId;

        for (ContentDocumentLink link : links) {
            if (link.ContentDocument == null) {
                continue;
            }
            String titleKey = normalizeName(link.ContentDocument.Title);
            if (titleKey == coverKey && coverVersionId == null) {
                coverVersionId = link.ContentDocument.LatestPublishedVersionId;
            } else if (backKeys.contains(titleKey) && backVersionId == null) {
                backVersionId = link.ContentDocument.LatestPublishedVersionId;
            }
        }

        if (coverVersionId == null || backVersionId == null) {
            return null;
        }

        Map<Id, ContentVersion> versionsById = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new Set<Id>{ coverVersionId, backVersionId }
        ]);

        CoverPair pair = new CoverPair();
        pair.coverVersion = versionsById.get(coverVersionId);
        pair.backCoverVersion = versionsById.get(backVersionId);
        return pair;
    }

    private static Map<String, OpportunityAttachmentLink__c> mapExternalLinks(List<OpportunityAttachmentLink__c> links) {
        Map<String, OpportunityAttachmentLink__c> result = new Map<String, OpportunityAttachmentLink__c>();
        if (links == null) {
            return result;
        }
        for (OpportunityAttachmentLink__c link : links) {
            String sourceName = String.isNotBlank(link.DocRequiredName__c)
                ? link.DocRequiredName__c
                : link.AttachmentDescription__c;
            String norm = normalizeName(sourceName);
            if (String.isBlank(norm) || result.containsKey(norm)) {
                continue;
            }
            result.put(norm, link);
        }
        return result;
    }

    private static Map<String, ContentDocumentLink> mapInternalLinks(List<ContentDocumentLink> links) {
        Map<String, ContentDocumentLink> result = new Map<String, ContentDocumentLink>();
        if (links == null) {
            return result;
        }
        for (ContentDocumentLink link : links) {
            String title = link.ContentDocument != null ? link.ContentDocument.Title : null;
            String norm = normalizeName(title);
            if (String.isBlank(norm) || result.containsKey(norm)) {
                continue;
            }
            result.put(norm, link);
        }
        return result;
    }

    private static String buildReportFileName(Instalacao__c inst) {
        String proposalNumber = inst.Oportunidade__r != null ? inst.Oportunidade__r.Numeroproposta__c : null;
        String oppName = inst.Oportunidade__r != null ? inst.Oportunidade__r.Name : null;
        String name = 'Relatório de Entrega de Obra - ' +
            (String.isBlank(proposalNumber) ? 'Sem Proposta' : proposalNumber) +
            ' - ' +
            (String.isBlank(oppName) ? 'Sem Oportunidade' : oppName) +
            '.pdf';
        return truncateString(name, 255);
    }

    private static String truncateString(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }

    @TestVisible
    private static String normalizeName(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.toLowerCase();
        normalized = normalized
            .replaceAll('[áàãâä]', 'a')
            .replaceAll('[éèêë]', 'e')
            .replaceAll('[íìîï]', 'i')
            .replaceAll('[óòõôö]', 'o')
            .replaceAll('[úùûü]', 'u')
            .replaceAll('[ç]', 'c');
        normalized = normalized.replaceAll('[^a-z0-9]+', '_');
        normalized = normalized.replaceAll('^_+|_+$', '');
        return normalized;
    }

    private static Boolean equalsIgnoreCase(String first, String second) {
        if (first == null || second == null) {
            return false;
        }
        return first.trim().toLowerCase() == second.trim().toLowerCase();
    }

    private static void logAndUpdateInstallation(Instalacao__c inst, String message) {
        if (inst == null) {
            return;
        }

        if (String.isNotBlank(message)) {
            update new Instalacao__c(
                Id = inst.Id,
                WorkDeliveryReportLastError__c = message
            );
        }

        Utils.LogDTO dto = new Utils.LogDTO();
        dto.className = 'WorkDeliveryReportService';
        dto.methodName = 'generateAndAttach';
        dto.message = message;
        dto.relatedId = String.valueOf(inst.Id);
        Utils.createLog(dto);
    }

    private static void logError(Id installationId, String message, Exception ex) {
        Utils.LogDTO dto = new Utils.LogDTO();
        dto.className = 'WorkDeliveryReportService';
        dto.methodName = 'generateAndAttach';
        dto.message = message;
        dto.relatedId = String.valueOf(installationId);
        if (ex != null) {
            dto.typeName = ex.getTypeName();
            dto.lineNumber = String.valueOf(ex.getLineNumber());
            dto.stackTraceString = ex.getStackTraceString();
        }
        Utils.createLog(dto);
    }

    public class PageItem {
        public String versionId;
        public String contentDocumentId;
        public String url;

        public PageItem(String versionId, String contentDocumentId) {
            this.versionId = versionId;
            this.contentDocumentId = contentDocumentId;
        }
    }

    private class DocumentSource {
        public OpportunityAttachmentLink__c externalLink;
        public String displayName;
        public String contentDocumentId;
        public String versionId;
        public String externalUrl;

        public DocumentSource(
            OpportunityAttachmentLink__c link,
            String displayName,
            String contentDocumentId,
            String versionId
        ) {
            this.externalLink = link;
            this.displayName = displayName;
            this.contentDocumentId = contentDocumentId;
            this.versionId = versionId;
            this.externalUrl = link != null ? link.AttachmentURL__c : null;
        }

        public Boolean isExternal() {
            return externalLink != null;
        }
    }

    private static PageItem buildPageItemFromVersion(ContentVersion version) {
        return version == null ? null : new PageItem(version.Id, version.ContentDocumentId);
    }

    private static PageItem buildPageItemFromUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        PageItem item = new PageItem(null, null);
        item.url = url;
        return item;
    }

    private static DocumentSource buildExternalSource(OpportunityAttachmentLink__c link, String displayName) {
        return new DocumentSource(link, displayName, null, null);
    }

    private static DocumentSource buildInternalSource(Id contentDocumentId, Id versionId) {
        return new DocumentSource(null, null, (String)contentDocumentId, (String)versionId);
    }

    private static Boolean isImageUrl(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String cleaned = value;
        Integer queryIndex = cleaned.indexOf('?');
        if (queryIndex > -1) {
            cleaned = cleaned.substring(0, queryIndex);
        }
        cleaned = cleaned.toLowerCase();
        return cleaned.endsWith('.png')
            || cleaned.endsWith('.jpg')
            || cleaned.endsWith('.jpeg')
            || cleaned.endsWith('.gif')
            || cleaned.endsWith('.bmp')
            || cleaned.endsWith('.webp');
    }

    private class CoverPair {
        public ContentVersion coverVersion;
        public ContentVersion backCoverVersion;
    }
}
