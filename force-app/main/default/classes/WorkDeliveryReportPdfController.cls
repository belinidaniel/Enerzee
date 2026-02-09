/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-05-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class WorkDeliveryReportPdfController {
    public List<String> pageUrls { get; private set; }
    private static final String AZURE_NAMED_CREDENTIAL = 'AzureBlobNC';
    private static final String LOG_CLASS = 'WorkDeliveryReportPdfController';

    public WorkDeliveryReportPdfController() {
        pageUrls = new List<String>();

        String pagesParam = ApexPages.currentPage().getParameters().get('pages');
        if (String.isNotBlank(pagesParam)) {
            List<Object> raw = (List<Object>) JSON.deserializeUntyped(pagesParam);
            for (Object entry : raw) {
                if (entry == null) {
                    continue;
                }
                Map<String, Object> item = (Map<String, Object>) entry;
                String rawUrl = (String) item.get('url');
                if (String.isNotBlank(rawUrl)) {
                    String resolved = resolveImageUrl(rawUrl);
                    if (String.isNotBlank(resolved)) {
                        pageUrls.add(resolved);
                    } else {
                        System.debug(LOG_CLASS + ' -> URL externa não resolvida: ' + rawUrl);
                    }
                    continue;
                }
                String versionId = (String) item.get('versionId');
                String contentDocumentId = (String) item.get('contentDocumentId');
                if (String.isBlank(versionId) || String.isBlank(contentDocumentId)) {
                    continue;
                }
                String renditionUrl = buildRenditionUrl(versionId, contentDocumentId);
                if (String.isNotBlank(renditionUrl)) {
                    pageUrls.add(renditionUrl);
                }
            }
            return;
        }

        String installationId = ApexPages.currentPage().getParameters().get('installationId');
        if (String.isBlank(installationId)) {
            installationId = ApexPages.currentPage().getParameters().get('id');
        }
        if (String.isBlank(installationId)) {
            return;
        }

        buildPagesFromInstallation(installationId);
    }

    private static String buildRenditionUrl(String versionId, String contentDocumentId) {
        return '/sfc/servlet.shepherd/version/download/' + versionId;
    }

    private void buildPagesFromInstallation(String installationId) {
        ProposalCover__c cover = [
            SELECT Id, Name
            FROM ProposalCover__c
            WHERE Name = 'Relatorio de entrega de obra'
            LIMIT 1
        ];

        Map<String, ContentDocumentLink> coverLinks = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cover.Id
        ]) {
            if (link.ContentDocument == null || String.isBlank(link.ContentDocument.Title)) {
                continue;
            }
            coverLinks.put(link.ContentDocument.Title.trim().toLowerCase(), link);
        }

        ContentDocumentLink coverDoc = findByTitle(coverLinks, new List<String>{'capa'});
        ContentDocumentLink backDoc = findByTitle(coverLinks, new List<String>{'contra capa', 'contracapa', 'contra_capa'});

        if (coverDoc != null && coverDoc.ContentDocument != null) {
            pageUrls.add(buildRenditionUrl(
                coverDoc.ContentDocument.LatestPublishedVersionId,
                coverDoc.ContentDocumentId
            ));
        }

        for (OpportunityAttachmentLink__c link : [
            SELECT Id, AttachmentURL__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :installationId
                AND ActivityName__c = 'RELATÓRIO FINAL DE OBRA'
            ORDER BY CreatedDate ASC
        ]) {
            if (String.isNotBlank(link.AttachmentURL__c)) {
                String resolved = resolveImageUrl(link.AttachmentURL__c);
                if (String.isNotBlank(resolved)) {
                    pageUrls.add(resolved);
                } else {
                    System.debug(LOG_CLASS + ' -> URL externa não resolvida: ' + link.AttachmentURL__c);
                }
            }
        }

        if (backDoc != null && backDoc.ContentDocument != null) {
            pageUrls.add(buildRenditionUrl(
                backDoc.ContentDocument.LatestPublishedVersionId,
                backDoc.ContentDocumentId
            ));
        }
    }

    private static ContentDocumentLink findByTitle(
        Map<String, ContentDocumentLink> linksByTitle,
        List<String> titles
    ) {
        if (linksByTitle == null || titles == null) {
            return null;
        }
        for (String title : titles) {
            if (title == null) {
                continue;
            }
            ContentDocumentLink match = linksByTitle.get(title.trim().toLowerCase());
            if (match != null) {
                return match;
            }
        }
        return null;
    }

    private static String resolveImageUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        // internal SF content URL
        if (url.startsWith('/sfc/')) {
            return url;
        }
        // external image: embed as base64 for PDF renderer
        if (!isImageUrl(url)) {
            return null;
        }
        return downloadExternalImageDataUrl(url);
    }

    private static String downloadExternalImageDataUrl(String externalUrl) {
        String endpoint = buildAzureEndpoint(externalUrl);
        if (String.isBlank(endpoint)) {
            System.debug(LOG_CLASS + ' -> endpoint inválido para URL: ' + externalUrl);
            return null;
        }
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setTimeout(120000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            System.debug(LOG_CLASS + ' -> CalloutException: ' + e.getMessage());
            return null;
        }

        if (res == null || res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(LOG_CLASS + ' -> Resposta inválida: ' +
                (res != null ? res.getStatusCode() + ' ' + res.getStatus() : 'sem resposta'));
            return null;
        }

        Blob fileBody = res.getBodyAsBlob();
        if (fileBody == null || fileBody.size() == 0) {
            System.debug(LOG_CLASS + ' -> body vazio.');
            return null;
        }

        String contentType = res.getHeader('Content-Type');
        if (String.isBlank(contentType)) {
            contentType = guessContentTypeFromUrl(externalUrl);
        }
        if (String.isBlank(contentType) || !contentType.toLowerCase().startsWith('image/')) {
            System.debug(LOG_CLASS + ' -> Conteúdo não é imagem. Content-Type=' + contentType);
            return null;
        }

        String base64Data = EncodingUtil.base64Encode(fileBody);
        return 'data:' + contentType + ';base64,' + base64Data;
    }

    private static String buildAzureEndpoint(String attachmentUrl) {
        if (String.isBlank(attachmentUrl)) {
            return null;
        }
        String normalized = attachmentUrl.trim();
        Integer schemeIndex = normalized.indexOf('://');
        Integer pathIndex = schemeIndex > -1 ? normalized.indexOf('/', schemeIndex + 3) : normalized.indexOf('/');
        String path = pathIndex > -1 ? normalized.substring(pathIndex) : '';
        if (String.isBlank(path)) {
            return null;
        }
        return 'callout:' + AZURE_NAMED_CREDENTIAL + path;
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

    private static String guessContentTypeFromUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        String cleaned = url.toLowerCase();
        Integer queryIndex = cleaned.indexOf('?');
        if (queryIndex > -1) {
            cleaned = cleaned.substring(0, queryIndex);
        }
        if (cleaned.endsWith('.png')) return 'image/png';
        if (cleaned.endsWith('.jpg') || cleaned.endsWith('.jpeg')) return 'image/jpeg';
        if (cleaned.endsWith('.gif')) return 'image/gif';
        if (cleaned.endsWith('.bmp')) return 'image/bmp';
        if (cleaned.endsWith('.webp')) return 'image/webp';
        return null;
    }

}
