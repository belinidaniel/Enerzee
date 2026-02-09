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
    public List<Section> sections { get; private set; }
    public Map<String, Integer> templateBySection { get; private set; }

    public class Section {
        public String title { get; set; }
        public List<String> images { get; set; }
        public Integer imageCount { get; set; }
        public Integer templateType { get; set; }
        public String image1 { get; set; }
        public String image2 { get; set; }
        public String image3 { get; set; }
    }

    public Boolean getHasSections() {
        return sections != null && !sections.isEmpty();
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
        introSubtitle = (sections != null && !sections.isEmpty()) ? sections[0].title : activityName;
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
        sections = new List<Section>();
        templateBySection = new Map<String, Integer>();
        if (sobjectId == null || String.isBlank(activityName)) {
            return;
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT ContentDocumentId__c, DocRequiredName__c, AttachmentDescription__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
            AND ActivityName__c = :activityName
            ORDER BY CreatedDate ASC
        ];

        Map<String, List<OpportunityAttachmentLink__c>> grouped = new Map<String, List<OpportunityAttachmentLink__c>>();
        Set<Id> docIds = new Set<Id>();

        for (OpportunityAttachmentLink__c link : links) {
            if (String.isBlank(link.ContentDocumentId__c)) {
                continue;
            }
            Id docId;
            try {
                docId = (Id) link.ContentDocumentId__c;
            } catch (Exception ex) {
                continue;
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
            docIds.add(docId);
        }

        if (grouped.isEmpty() || docIds.isEmpty()) {
            return;
        }

        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ]) {
            latestByDoc.put(cv.ContentDocumentId, cv);
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<String> orderedNames = loadRequiredOrder(activityName);
        Set<String> used = new Set<String>();

        for (String name : orderedNames) {
            if (!grouped.containsKey(name)) {
                continue;
            }
            Section section = buildSection(name, grouped.get(name), latestByDoc, baseUrl);
            if (section != null) {
                sections.add(section);
                templateBySection.put(section.title, section.templateType);
                used.add(name);
            }
        }

        List<String> remaining = new List<String>();
        for (String key : grouped.keySet()) {
            if (!used.contains(key)) {
                remaining.add(key);
            }
        }
        remaining.sort();
        for (String key : remaining) {
            Section section = buildSection(key, grouped.get(key), latestByDoc, baseUrl);
            if (section != null) {
                sections.add(section);
                templateBySection.put(section.title, section.templateType);
            }
        }
    }

    private Section buildSection(
        String title,
        List<OpportunityAttachmentLink__c> links,
        Map<Id, ContentVersion> latestByDoc,
        String baseUrl
    ) {
        List<String> images = new List<String>();
        if (links != null) {
            for (OpportunityAttachmentLink__c link : links) {
                if (images.size() >= 3) {
                    break;
                }
                if (String.isBlank(link.ContentDocumentId__c)) {
                    continue;
                }
                Id docId;
                try {
                    docId = (Id) link.ContentDocumentId__c;
                } catch (Exception ex) {
                    continue;
                }
                ContentVersion cv = latestByDoc.get(docId);
                if (cv == null) {
                    continue;
                }
                images.add(baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id);
            }
        }

        if (images.isEmpty()) {
            return null;
        }

        Section section = new Section();
        section.title = title;
        section.images = images;
        section.imageCount = images.size();
        section.templateType = section.imageCount;
        section.image1 = images.size() > 0 ? images[0] : null;
        section.image2 = images.size() > 1 ? images[1] : null;
        section.image3 = images.size() > 2 ? images[2] : null;
        return section;
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
