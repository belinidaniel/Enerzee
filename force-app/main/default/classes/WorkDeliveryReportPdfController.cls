public with sharing class WorkDeliveryReportPdfController {
    public List<String> pageUrls { get; private set; }

    public WorkDeliveryReportPdfController() {
        pageUrls = new List<String>();

        String pagesParam = ApexPages.currentPage().getParameters().get('pages');
        if (String.isBlank(pagesParam)) {
            return;
        }

        List<Object> raw = (List<Object>) JSON.deserializeUntyped(pagesParam);
        for (Object entry : raw) {
            if (entry == null) {
                continue;
            }
            Map<String, Object> item = (Map<String, Object>) entry;
            String rawUrl = (String) item.get('url');
            if (String.isNotBlank(rawUrl)) {
                pageUrls.add(rawUrl);
                continue;
            }
            String versionId = (String) item.get('versionId');
            String contentDocumentId = (String) item.get('contentDocumentId');
            if (String.isBlank(versionId) || String.isBlank(contentDocumentId)) {
                continue;
            }
            pageUrls.add(buildRenditionUrl(versionId, contentDocumentId));
        }
    }

    private static String buildRenditionUrl(String versionId, String contentDocumentId) {
        return '/sfc/servlet.shepherd/version/renditionDownload' +
            '?rendition=THUMB1200BY900' +
            '&versionId=' + versionId +
            '&operationContext=CHATTER' +
            '&contentId=' + contentDocumentId +
            '&page=0';
    }
}
