/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-10-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class WorkDeliveryReportPdfController {
    private static final Integer IMAGES_PER_PAGE = 2;
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
    public List<SectionPage> sections { get; private set; }
    private String firstActivityTitle;
    public String clientName { get; private set; }
    public String endereco { get; private set; }
    public String integradorName { get; private set; }
    public String prazoContratual { get; private set; }
    public String periodoObra { get; private set; }
    public String gestorName { get; private set; }
    public String statusInstalacao { get; private set; }

    public class SectionPage {
        public String activityTitle { get; set; }
        public String displayTitle { get; set; }
        public String title { get; set; }
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

    // Backward compatibility for old Visualforce markup
    public List<SectionPage> getSections() {
        return pages;
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
        loadCoverDetails();
        loadCoverImages();
        loadSections();
        introSubtitle = String.isNotBlank(firstActivityTitle) ? firstActivityTitle : activityName;
    }

    private void loadCoverDetails() {
        clientName = null;
        endereco = '-';
        integradorName = null;
        prazoContratual = null;
        periodoObra = null;
        gestorName = null;
        statusInstalacao = null;

        if (sobjectId == null) {
            return;
        }

        try {
            Instalacao__c inst = [
                SELECT Id,
                    Status__c,
                    GestorObra__r.Name,
                    Integrador__r.Name,
                    PrazoExecucaoServico__c,
                    ContagemPrazoContrato__c,
                    InstallDate__c,
                    DataConclusao__c,
                    DataPrevisaoConclusao__c,
                    ClienteConta__r.Name,
                    ClienteConta__r.Logradouro__c,
                    ClienteConta__r.NumeroRua__c,
                    ClienteConta__r.Complemento__c,
                    ClienteConta__r.Bairro__c,
                    ClienteConta__r.MunicipioInstalacao__c,
                    ClienteConta__r.EstadoInstalacao__c,
                    ClienteConta__r.CEP__c,
                    ClienteConta__r.ShippingStreet,
                    ClienteConta__r.ShippingCity,
                    ClienteConta__r.ShippingState,
                    ClienteConta__r.ShippingPostalCode,
                    ClienteConta__r.ShippingCountry
                FROM Instalacao__c
                WHERE Id = :sobjectId
                LIMIT 1
            ];

            if (inst.ClienteConta__r != null) {
                clientName = inst.ClienteConta__r.Name;
                endereco = buildEndereco(inst.ClienteConta__r);
            }
            integradorName = inst.Integrador__r != null ? inst.Integrador__r.Name : null;
            gestorName = inst.GestorObra__r != null ? inst.GestorObra__r.Name : null;
            statusInstalacao = inst.Status__c;
            prazoContratual = buildPrazo(inst);
            periodoObra = buildPeriodo(inst.InstallDate__c, inst.DataConclusao__c, inst.DataPrevisaoConclusao__c);
        } catch (Exception ex) {
            // nao bloquear a geracao do PDF
        }
    }

    private String buildEndereco(Account acc) {
        if (acc == null) {
            return '-';
        }
        String custom = buildEnderecoCustom(acc);
        if (String.isNotBlank(custom)) {
            return custom;
        }
        String shipping = buildEnderecoShipping(acc);
        if (String.isNotBlank(shipping)) {
            return shipping;
        }
        return '-';
    }

    private String buildEnderecoCustom(Account acc) {
        if (acc == null) {
            return null;
        }
        List<String> parts = new List<String>();
        String streetLine = null;
        if (String.isNotBlank(acc.Logradouro__c) && String.isNotBlank(acc.NumeroRua__c)) {
            streetLine = acc.Logradouro__c + ', ' + acc.NumeroRua__c;
        } else if (String.isNotBlank(acc.Logradouro__c)) {
            streetLine = acc.Logradouro__c;
        } else if (String.isNotBlank(acc.NumeroRua__c)) {
            streetLine = acc.NumeroRua__c;
        }
        if (String.isNotBlank(streetLine)) {
            parts.add(streetLine);
        }
        if (String.isNotBlank(acc.MunicipioInstalacao__c)) {
            parts.add(acc.MunicipioInstalacao__c);
        }
        return String.join(parts, ', ');
    }

    private String buildEnderecoShipping(Account acc) {
        if (acc == null) {
            return null;
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(acc.ShippingStreet)) {
            parts.add(normalizeLine(acc.ShippingStreet));
        }
        if (String.isNotBlank(acc.ShippingCity)) {
            parts.add(acc.ShippingCity);
        }
        return String.join(parts, ', ');
    }

    private String buildCityState(String city, String state) {
        String cityState = null;
        if (String.isNotBlank(city) || String.isNotBlank(state)) {
            String safeCity = String.isNotBlank(city) ? city : '';
            String safeState = String.isNotBlank(state) ? state : '';
            if (String.isNotBlank(safeCity) && String.isNotBlank(safeState)) {
                cityState = safeCity + ' - ' + safeState;
            } else if (String.isNotBlank(safeCity)) {
                cityState = safeCity;
            } else if (String.isNotBlank(safeState)) {
                cityState = safeState;
            }
        }
        return cityState;
    }

    private String normalizeLine(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.replace('\r', ' ').replace('\n', ' ').trim();
        return normalized;
    }

    private String buildPrazo(Instalacao__c inst) {
        if (inst == null) {
            return null;
        }
        Decimal value = inst.ContagemPrazoContrato__c;
        if (value == null) {
            value = inst.PrazoExecucaoServico__c;
        }
        if (value == null) {
            return null;
        }
        return String.valueOf(value.setScale(0)) + ' dias';
    }

    private String buildPeriodo(Datetime inicio, Date fim, Date previsaoFim) {
        String inicioFmt = formatDateTime(inicio);
        String fimFmt = formatDate(fim);
        if (String.isBlank(fimFmt)) {
            fimFmt = formatDate(previsaoFim);
        }
        if (String.isBlank(inicioFmt) && String.isBlank(fimFmt)) {
            return null;
        }
        if (String.isBlank(fimFmt)) {
            return inicioFmt;
        }
        if (String.isBlank(inicioFmt)) {
            return fimFmt;
        }
        return inicioFmt + ' - ' + fimFmt;
    }

    private String formatDate(Date value) {
        if (value == null) {
            return null;
        }
        Datetime dt = Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0));
        return dt.format('dd/MM/yyyy');
    }

    private String formatDateTime(Datetime value) {
        if (value == null) {
            return null;
        }
        return value.format('dd/MM/yyyy');
    }

    private String buildDocumentTitle() {
        if (String.isNotBlank(activityName)) {
            return 'Relatorio - ' + activityName;
        }
        return 'Relatorio de Execucao de Obra';
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
        sections = pages;
        if (sobjectId == null || String.isBlank(activityName)) {
            return;
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT ContentDocumentId__c, AttachmentURL__c, InternalAttachmentURL__c,
                DocRequiredName__c, AttachmentDescription__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
            AND ActivityName__c = :activityName
            ORDER BY CreatedDate ASC
        ];

        Map<String, List<OpportunityAttachmentLink__c>> grouped = new Map<String, List<OpportunityAttachmentLink__c>>();
        Set<Id> docIds = new Set<Id>();

        for (OpportunityAttachmentLink__c link : links) {
            if (String.isBlank(link.ContentDocumentId__c)
                && String.isBlank(link.AttachmentURL__c)
                && String.isBlank(link.InternalAttachmentURL__c)) {
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
                if (String.isNotBlank(link.InternalAttachmentURL__c)) {
                    url = normalizeUrl(link.InternalAttachmentURL__c, baseUrl);
                }
                if (url == null && String.isNotBlank(link.ContentDocumentId__c)) {
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
                    url = normalizeUrl(link.AttachmentURL__c, baseUrl);
                }
                if (url != null) {
                    images.add(url);
                }
            }
        }
        return images;
    }

    private String normalizeUrl(String rawValue, String baseUrl) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String raw = rawValue.trim();
        if (raw.startsWith('http')) {
            return raw;
        }
        if (raw.startsWith('/')) {
            return baseUrl + raw;
        }
        return baseUrl + '/' + raw;
    }

    private void addPagesForActivity(String title, List<String> images) {
        if (images == null || images.isEmpty()) {
            return;
        }
        if (String.isBlank(firstActivityTitle)) {
            firstActivityTitle = title;
        }
        Integer total = (Integer) Math.ceil(images.size() / (Decimal) IMAGES_PER_PAGE);
        Integer pageIndex = 0;
        for (Integer i = 0; i < images.size(); i += IMAGES_PER_PAGE) {
            pageIndex++;
            Integer endIndex = Math.min(i + IMAGES_PER_PAGE, images.size());
            List<String> slice = new List<String>();
            for (Integer j = i; j < endIndex; j++) {
                slice.add(images[j]);
            }
            SectionPage page = new SectionPage();
            page.activityTitle = title;
            page.pageIndex = pageIndex;
            page.pageCount = total;
            page.displayTitle = total > 1 ? title + ' (' + pageIndex + '/' + total + ')' : title;
            page.title = page.displayTitle;
            page.images = slice;
            page.imageCount = slice.size();
            page.templateType = page.imageCount;
            page.image1 = slice.size() > 0 ? slice[0] : null;
            page.image2 = slice.size() > 1 ? slice[1] : null;
            page.image3 = null;
            pages.add(page);
        }
    }

    private List<String> loadRequiredOrder(String subject) {
        List<String> ordered = new List<String>();
        if (String.isBlank(subject)) {
            return ordered;
        }

        List<String> subjects = TaskUtils.isRelatorioExecucaoDeObraSubject(subject)
            ? TaskUtils.getRelatorioExecucaoDeObraSubjects()
            : new List<String>{subject};

        Map<String, ActivityRequiredDocument__mdt> bySubject = new Map<String, ActivityRequiredDocument__mdt>();
        for (ActivityRequiredDocument__mdt rec : [
            SELECT ActivitySubject__c, RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c IN :subjects
        ]) {
            bySubject.put(rec.ActivitySubject__c, rec);
        }

        Set<String> seen = new Set<String>();
        for (String subjectName : subjects) {
            ActivityRequiredDocument__mdt rec = bySubject.get(subjectName);
            if (rec == null) {
                continue;
            }
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
