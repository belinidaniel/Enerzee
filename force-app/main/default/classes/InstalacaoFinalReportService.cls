public with sharing class InstalacaoFinalReportService {
    private static final Integer MAX_PER_RUN = 5;

    public static void enqueueIfNeeded(List<Instalacao__c> newList, Map<Id, Instalacao__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> idsToProcess = new Set<Id>();
        for (Instalacao__c inst : newList) {
            Instalacao__c oldInst = oldMap != null ? oldMap.get(inst.Id) : null;
            if (oldInst == null) {
                continue;
            }
            if (inst.Status__c == oldInst.Status__c) {
                continue;
            }
            if (isObraConcluida(inst.Status__c)) {
                idsToProcess.add(inst.Id);
            }
        }

        if (!idsToProcess.isEmpty()) {
            System.enqueueJob(new FinalReportJob(new List<Id>(idsToProcess)));
        }
    }

    private static Boolean isObraConcluida(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        String value = status.trim();
        if (value.equalsIgnoreCase(ProjetoUtils.STATUS_OBRA_CONCLUIDA)) {
            return true;
        }
        return value.equalsIgnoreCase('Obra Concluida');
    }

    public class FinalReportJob implements Queueable, Database.AllowsCallouts {
        private List<Id> instalacaoIds;

        public FinalReportJob(List<Id> instalacaoIds) {
            this.instalacaoIds = instalacaoIds != null ? new List<Id>(instalacaoIds) : new List<Id>();
        }

        public void execute(QueueableContext context) {
            if (instalacaoIds == null || instalacaoIds.isEmpty()) {
                return;
            }

            Integer sliceSize = Math.min(instalacaoIds.size(), MAX_PER_RUN);
            List<Id> current = new List<Id>();
            List<Id> remaining = new List<Id>();
            for (Integer i = 0; i < instalacaoIds.size(); i++) {
                if (i < sliceSize) {
                    current.add(instalacaoIds[i]);
                } else {
                    remaining.add(instalacaoIds[i]);
                }
            }

            processInstallations(current);

            if (!remaining.isEmpty()) {
                System.enqueueJob(new FinalReportJob(remaining));
            }
        }
    }

    @TestVisible
    private static void processInstallations(List<Id> instalacaoIds) {
        if (instalacaoIds == null || instalacaoIds.isEmpty()) {
            return;
        }

        Map<Id, Instalacao__c> instById = new Map<Id, Instalacao__c>([
            SELECT Id, Name
            FROM Instalacao__c
            WHERE Id IN :instalacaoIds
        ]);

        Set<String> instIdStrings = new Set<String>();
        for (Id instId : instalacaoIds) {
            instIdStrings.add(String.valueOf(instId));
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT Id, SObjectId__c, ContentDocumentId__c, InternalAttachmentURL__c, AttachmentURL__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c IN :instIdStrings
            AND ActivityName__c = :TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
        ];

        Map<Id, List<OpportunityAttachmentLink__c>> linksByInst = new Map<Id, List<OpportunityAttachmentLink__c>>();
        Map<Id, Set<Id>> docIdsByInst = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> versionIdsByInst = new Map<Id, Set<Id>>();

        for (OpportunityAttachmentLink__c link : links) {
            Id instId = parseId(link.SObjectId__c);
            if (instId == null) {
                continue;
            }
            if (!linksByInst.containsKey(instId)) {
                linksByInst.put(instId, new List<OpportunityAttachmentLink__c>());
            }
            linksByInst.get(instId).add(link);

            Id docId = parseId(link.ContentDocumentId__c);
            if (docId != null) {
                if (!docIdsByInst.containsKey(instId)) {
                    docIdsByInst.put(instId, new Set<Id>());
                }
                docIdsByInst.get(instId).add(docId);
            }

            Id idFromInternal = parseIdFromUrl(link.InternalAttachmentURL__c);
            storeDocOrVersion(instId, idFromInternal, docIdsByInst, versionIdsByInst);

            Id idFromAttachment = parseIdFromUrl(link.AttachmentURL__c);
            storeDocOrVersion(instId, idFromAttachment, docIdsByInst, versionIdsByInst);
        }

        List<ContentVersion> pdfVersions = new List<ContentVersion>();
        Set<Id> successInstIds = new Set<Id>();

        for (Id instId : instalacaoIds) {
            List<OpportunityAttachmentLink__c> instLinks = linksByInst.get(instId);
            if (instLinks == null || instLinks.isEmpty()) {
                continue;
            }

            Blob pdfBlob = generatePdf(instId);
            if (pdfBlob == null) {
                continue;
            }

            String baseName = 'Relatorio Final de Obra';
            String timestamp = Datetime.now().format('yyyyMMdd-HHmm');
            Instalacao__c inst = instById.get(instId);
            String title = baseName + ' - ' + timestamp;
            if (inst != null && String.isNotBlank(inst.Name)) {
                title = baseName + ' - ' + inst.Name + ' - ' + timestamp;
            }

            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.FirstPublishLocationId = instId;
            cv.VersionData = pdfBlob;
            cv.Title = title;
            cv.PathOnClient = baseName.replace(' ', '-') + '-' + timestamp + '.pdf';
            cv.IsMajorVersion = true;
            pdfVersions.add(cv);
            successInstIds.add(instId);
        }

        if (!pdfVersions.isEmpty()) {
            insert pdfVersions;
        }

        if (successInstIds.isEmpty()) {
            return;
        }

        Set<Id> docIdsToDelete = new Set<Id>();
        for (Id instId : successInstIds) {
            Set<Id> idsForInst = docIdsByInst.get(instId);
            if (idsForInst != null) {
                docIdsToDelete.addAll(idsForInst);
            }
        }

        Set<Id> versionIdsToResolve = new Set<Id>();
        for (Id instId : successInstIds) {
            Set<Id> versionsForInst = versionIdsByInst.get(instId);
            if (versionsForInst != null) {
                versionIdsToResolve.addAll(versionsForInst);
            }
        }
        if (!versionIdsToResolve.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :versionIdsToResolve
            ]) {
                if (cv.ContentDocumentId != null) {
                    docIdsToDelete.add(cv.ContentDocumentId);
                }
            }
        }

        if (!docIdsToDelete.isEmpty()) {
            try {
                List<ContentDocument> docsToDelete = [
                    SELECT Id
                    FROM ContentDocument
                    WHERE Id IN :docIdsToDelete
                ];
                if (!docsToDelete.isEmpty()) {
                    delete docsToDelete;
                }
            } catch (Exception ex) {
                Utils.createLog('InstalacaoFinalReportService', 'deleteContentDocuments', ex);
                try {
                    List<ContentDocumentLink> linksToDelete = [
                        SELECT Id
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId IN :successInstIds
                        AND ContentDocumentId IN :docIdsToDelete
                    ];
                    if (!linksToDelete.isEmpty()) {
                        delete linksToDelete;
                    }
                } catch (Exception innerEx) {
                    Utils.createLog('InstalacaoFinalReportService', 'deleteContentDocumentLinks', innerEx);
                }
            }
        }

        List<OpportunityAttachmentLink__c> linksToUpdate = new List<OpportunityAttachmentLink__c>();
        for (OpportunityAttachmentLink__c link : links) {
            Id instId = parseId(link.SObjectId__c);
            if (instId == null || !successInstIds.contains(instId)) {
                continue;
            }
            if (String.isNotBlank(link.ContentDocumentId__c) || String.isNotBlank(link.InternalAttachmentURL__c)) {
                OpportunityAttachmentLink__c toUpdate = new OpportunityAttachmentLink__c(
                    Id = link.Id
                );
                toUpdate.ContentDocumentId__c = null;
                toUpdate.InternalAttachmentURL__c = null;
                linksToUpdate.add(toUpdate);
            }
        }
        if (!linksToUpdate.isEmpty()) {
            update linksToUpdate;
        }
    }

    private static Blob generatePdf(Id instalacaoId) {
        if (Test.isRunningTest()) {
            return Blob.valueOf('PDF');
        }

        PageReference pdfPage = Page.WorkDeliveryReportPdf;
        pdfPage.getParameters().put('sobjectId', String.valueOf(instalacaoId));
        pdfPage.getParameters().put('activityName', TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA);

        try {
            return pdfPage.getContent();
        } catch (Exception ex) {
            Utils.createLog('InstalacaoFinalReportService', 'generatePdf', ex, String.valueOf(instalacaoId));
            return null;
        }
    }

    private static Id parseId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Id parseIdFromUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        String cleaned = url.trim();
        Integer queryIndex = cleaned.indexOf('?');
        if (queryIndex > -1) {
            cleaned = cleaned.substring(0, queryIndex);
        }
        Integer lastSlash = cleaned.lastIndexOf('/');
        if (lastSlash > -1 && lastSlash < cleaned.length() - 1) {
            cleaned = cleaned.substring(lastSlash + 1);
        }
        return parseId(cleaned);
    }

    private static void storeDocOrVersion(
        Id instId,
        Id parsedId,
        Map<Id, Set<Id>> docIdsByInst,
        Map<Id, Set<Id>> versionIdsByInst
    ) {
        if (parsedId == null || instId == null) {
            return;
        }
        String prefix = String.valueOf(parsedId).substring(0, 3);
        if (prefix == '068') {
            if (!versionIdsByInst.containsKey(instId)) {
                versionIdsByInst.put(instId, new Set<Id>());
            }
            versionIdsByInst.get(instId).add(parsedId);
            return;
        }
        if (prefix == '069') {
            if (!docIdsByInst.containsKey(instId)) {
                docIdsByInst.put(instId, new Set<Id>());
            }
            docIdsByInst.get(instId).add(parsedId);
        }
    }
}
