public with sharing class WorkDeliveryReportPdfController {
    private static final List<String> COVER_NAMES = new List<String>{
        'Relatorio de entrega de obra',
        'Relatório de entrega de obra'
    };

    public Id sobjectId { get; private set; }
    public String activityName { get; private set; }
    public String documentTitle { get; private set; }
    public String coverUrl { get; private set; }
    public String contraCoverUrl { get; private set; }
    public String introSubtitle { get; private set; }
    public List<SectionPage> pages { get; private set; }
    private String firstActivityTitle;

    public class SectionPage {
        public String activityTitle { get; set; }
        public String displayTitle { get; set; }
        public List<String> images { get; set; }
        public Integer imageCount { get; set; }
        public Integer templateType { get; set; }
        public Integer pageIndex { get; set; }
        public Integer pageCount { get; set; }
        public String image1 { get; set; }
        public String image2 { get; set; }
        public String image3 { get; set; }
    }

    public Boolean getHasSections() {
        return pages != null && !pages.isEmpty();
    }

    public Boolean getHasCover() {
        return String.isNotBlank(coverUrl);
    }

    public Boolean getHasContraCover() {
        return String.isNotBlank(contraCoverUrl);
    }

    public WorkDeliveryReportPdfController() {
        ApexPages.PageReference pageRef = ApexPages.currentPage();
        sobjectId = (Id) pageRef.getParameters().get('sobjectId');
        activityName = pageRef.getParameters().get('activityName');
        documentTitle = buildDocumentTitle();
        loadCoverImages();
        loadSections();
        introSubtitle = String.isNotBlank(firstActivityTitle) ? firstActivityTitle : activityName;
    }

    private String buildDocumentTitle() {
        if (String.isNotBlank(activityName)) {
            return 'Relatorio - ' + activityName;
        }
        return 'Relatorio Final de Obra';
    }

    private void loadCoverImages() {
        coverUrl = null;
        contraCoverUrl = null;

        List<ProposalCover__c> covers = [
            SELECT Id, Name
            FROM ProposalCover__c
            WHERE Name IN :COVER_NAMES
            LIMIT 1
        ];
        if (covers.isEmpty()) {
            return;
        }

        Id coverId = covers[0].Id;
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :coverId
            ORDER BY ContentDocument.CreatedDate ASC
        ];

        List<Id> orderedDocIds = new List<Id>();
        for (ContentDocumentLink link : links) {
            if (link.ContentDocumentId == null) {
                continue;
            }
            if (!orderedDocIds.contains(link.ContentDocumentId)) {
                orderedDocIds.add(link.ContentDocumentId);
            }
            if (orderedDocIds.size() >= 4) {
                break;
            }
        }
        if (orderedDocIds.isEmpty()) {
            return;
        }

        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :orderedDocIds
        ]) {
            latestByDoc.put(cv.ContentDocumentId, cv);
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        Id coverDocId;
        Id contraDocId;

        for (Id docId : orderedDocIds) {
            ContentVersion cv = latestByDoc.get(docId);
            if (cv == null || String.isBlank(cv.Title)) {
                continue;
            }
            String title = cv.Title.toLowerCase();
            if (contraDocId == null && title.contains('contra')) {
                contraDocId = docId;
                continue;
            }
            if (coverDocId == null && title.contains('capa')) {
                coverDocId = docId;
            }
        }

        List<Id> remaining = new List<Id>();
        for (Id docId : orderedDocIds) {
            if (docId != coverDocId && docId != contraDocId) {
                remaining.add(docId);
            }
        }
        if (coverDocId == null && !remaining.isEmpty()) {
            coverDocId = remaining.remove(0);
        }
        if (contraDocId == null && !remaining.isEmpty()) {
            contraDocId = remaining.remove(0);
        }

        if (coverDocId != null) {
            ContentVersion cv = latestByDoc.get(coverDocId);
            if (cv != null) {
                coverUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id;
            }
        }
        if (contraDocId != null) {
            ContentVersion cv = latestByDoc.get(contraDocId);
            if (cv != null) {
                contraCoverUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id;
            }
        }
    }

    private void loadSections() {
        pages = new List<SectionPage>();
        if (sobjectId == null || String.isBlank(activityName)) {
            return;
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT ContentDocumentId__c, AttachmentURL__c, DocRequiredName__c, AttachmentDescription__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
            AND ActivityName__c = :activityName
            ORDER BY CreatedDate ASC
        ];

        Map<String, List<OpportunityAttachmentLink__c>> grouped = new Map<String, List<OpportunityAttachmentLink__c>>();
        Set<Id> docIds = new Set<Id>();

        for (OpportunityAttachmentLink__c link : links) {
            if (String.isBlank(link.ContentDocumentId__c) && String.isBlank(link.AttachmentURL__c)) {
                continue;
            }
            Id docId;
            try {
                docId = String.isNotBlank(link.ContentDocumentId__c) ? (Id) link.ContentDocumentId__c : null;
            } catch (Exception ex) {
                docId = null;
            }

            String key = String.isNotBlank(link.DocRequiredName__c)
                ? link.DocRequiredName__c
                : link.AttachmentDescription__c;
            if (String.isBlank(key)) {
                key = 'Outros';
            }

            if (!grouped.containsKey(key)) {
                grouped.put(key, new List<OpportunityAttachmentLink__c>());
            }
            grouped.get(key).add(link);
            if (docId != null) {
                docIds.add(docId);
            }
        }

        if (grouped.isEmpty()) {
            return;
        }

        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE IsLatest = true AND ContentDocumentId IN :docIds
            ]) {
                latestByDoc.put(cv.ContentDocumentId, cv);
            }
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<String> orderedNames = loadRequiredOrder(activityName);
        Set<String> used = new Set<String>();

        for (String name : orderedNames) {
            if (!grouped.containsKey(name)) {
                continue;
            }
            List<String> images = buildImageList(grouped.get(name), latestByDoc, baseUrl);
            addPagesForActivity(name, images);
            used.add(name);
        }

        List<String> remaining = new List<String>();
        for (String key : grouped.keySet()) {
            if (!used.contains(key)) {
                remaining.add(key);
            }
        }
        remaining.sort();
        for (String key : remaining) {
            List<String> images = buildImageList(grouped.get(key), latestByDoc, baseUrl);
            addPagesForActivity(key, images);
        }
    }

    private List<String> buildImageList(
        List<OpportunityAttachmentLink__c> links,
        Map<Id, ContentVersion> latestByDoc,
        String baseUrl
    ) {
        List<String> images = new List<String>();
        if (links != null) {
            for (OpportunityAttachmentLink__c link : links) {
                String url = null;
                if (String.isNotBlank(link.ContentDocumentId__c)) {
                    Id docId;
                    try {
                        docId = (Id) link.ContentDocumentId__c;
                    } catch (Exception ex) {
                        docId = null;
                    }
                    if (docId != null) {
                        ContentVersion cv = latestByDoc.get(docId);
                        if (cv != null) {
                            url = baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id;
                        }
                    }
                }
                if (url == null && String.isNotBlank(link.AttachmentURL__c)) {
                    String raw = link.AttachmentURL__c.trim();
                    if (raw.startsWith('http')) {
                        url = raw;
                    } else if (raw.startsWith('/')) {
                        url = baseUrl + raw;
                    } else {
                        url = baseUrl + '/' + raw;
                    }
                }
                if (url != null) {
                    images.add(url);
                }
            }
        }
        return images;
    }

    private void addPagesForActivity(String title, List<String> images) {
        if (images == null || images.isEmpty()) {
            return;
        }
        if (String.isBlank(firstActivityTitle)) {
            firstActivityTitle = title;
        }
        Integer total = (Integer) Math.ceil(images.size() / 3.0);
        Integer pageIndex = 0;
        for (Integer i = 0; i < images.size(); i += 3) {
            pageIndex++;
            Integer endIndex = Math.min(i + 3, images.size());
            List<String> slice = new List<String>();
            for (Integer j = i; j < endIndex; j++) {
                slice.add(images[j]);
            }
            SectionPage page = new SectionPage();
            page.activityTitle = title;
            page.pageIndex = pageIndex;
            page.pageCount = total;
            page.displayTitle = total > 1 ? title + ' (' + pageIndex + '/' + total + ')' : title;
            page.images = slice;
            page.imageCount = slice.size();
            page.templateType = page.imageCount;
            page.image1 = slice.size() > 0 ? slice[0] : null;
            page.image2 = slice.size() > 1 ? slice[1] : null;
            page.image3 = slice.size() > 2 ? slice[2] : null;
            pages.add(page);
        }
    }

    private List<String> loadRequiredOrder(String subject) {
        List<String> ordered = new List<String>();
        if (String.isBlank(subject)) {
            return ordered;
        }

        Set<String> seen = new Set<String>();
        for (ActivityRequiredDocument__mdt rec : [
            SELECT RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :subject
        ]) {
            if (String.isBlank(rec.RequiredFiles__c)) {
                continue;
            }
            for (String name : rec.RequiredFiles__c.split(';')) {
                String trimmed = name != null ? name.trim() : null;
                if (String.isBlank(trimmed) || seen.contains(trimmed)) {
                    continue;
                }
                ordered.add(trimmed);
                seen.add(trimmed);
            }
        }
        return ordered;
    }
}
