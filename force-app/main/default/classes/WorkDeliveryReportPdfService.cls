public with sharing class WorkDeliveryReportPdfService {
    @AuraEnabled
    public static String generatePdfBase64(Id sobjectId, String activitySubject) {
        if (sobjectId == null) {
            throw new AuraHandledException('Registro não informado.');
        }
        String normalizedSubject = String.isNotBlank(activitySubject) ? activitySubject.trim() : null;
        if (String.isBlank(normalizedSubject)) {
            throw new AuraHandledException('Atividade não informada.');
        }

        List<OpportunityAttachmentLink__c> links = [
            SELECT AttachmentDescription__c, DocRequiredName__c, ContentDocumentId__c, CreatedDate
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(sobjectId)
            AND ActivityName__c = :normalizedSubject
            ORDER BY CreatedDate ASC
        ];

        Set<Id> contentDocIds = new Set<Id>();
        for (OpportunityAttachmentLink__c link : links) {
            if (String.isBlank(link.ContentDocumentId__c)) {
                continue;
            }
            try {
                contentDocIds.add((Id) link.ContentDocumentId__c);
            } catch (Exception ex) {
                // ignora ids inválidos
            }
        }

        if (contentDocIds.isEmpty()) {
            throw new AuraHandledException('Nenhum arquivo salvo no Salesforce para este relatório.');
        }

        Map<Id, ContentVersion> versionsByDocId = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, VersionData, FileType, FileExtension, Title, PathOnClient
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :contentDocIds
        ]) {
            versionsByDocId.put(cv.ContentDocumentId, cv);
        }

        List<AttachmentInfo> items = new List<AttachmentInfo>();
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
            ContentVersion cv = versionsByDocId.get(docId);
            if (cv == null) {
                continue;
            }
            String downloadUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
            AttachmentInfo info = new AttachmentInfo();
            info.caption = String.isNotBlank(link.DocRequiredName__c)
                ? link.DocRequiredName__c
                : link.AttachmentDescription__c;
            info.dataUri = downloadUrl;
            items.add(info);
        }

        if (items.isEmpty()) {
            throw new AuraHandledException('Nenhum arquivo disponível para gerar o PDF.');
        }

        String html = buildHtml(items, normalizedSubject, false);
        logHtmlDebug('primary', html, items);
        Blob pdfBlob;
        try {
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('PDF');
            } else {
                pdfBlob = Blob.toPdf(html);
            }
        } catch (Exception ex) {
            String fallbackHtml = buildHtml(items, normalizedSubject, true);
            logHtmlDebug('fallback', fallbackHtml, items);
            try {
                pdfBlob = Blob.toPdf(fallbackHtml);
            } catch (Exception innerEx) {
                throw new AuraHandledException('Falha ao gerar o PDF.');
            }
        }

        return EncodingUtil.base64Encode(pdfBlob);
    }

    private class AttachmentInfo {
        public String dataUri;
        public String caption;
    }

    private static String buildHtml(List<AttachmentInfo> items, String activityName, Boolean minimal) {
        List<String> parts = new List<String>();
        parts.add('<html xmlns="http://www.w3.org/1999/xhtml">');
        parts.add('<head>');
        parts.add('<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />');
        if (!minimal) {
            parts.add('<style>');
            parts.add('@page { size: A4 portrait; margin: 18mm; }');
            parts.add('body { margin: 0; padding: 0; font-family: Arial, sans-serif; color: #1f2937; }');
            parts.add('.page { width: 100%; page-break-after: always; }');
            parts.add('.cover { text-align: center; padding-top: 80mm; }');
            parts.add('.cover-title { font-size: 26px; font-weight: bold; letter-spacing: 0.5px; }');
            parts.add('.cover-subtitle { margin-top: 12px; font-size: 14px; color: #6b7280; }');
            parts.add('.cover-meta { margin-top: 24px; font-size: 12px; color: #94a3b8; }');
            parts.add('.image-wrap { text-align: center; }');
            parts.add('.image-wrap img { width: 100%; height: auto; }');
            parts.add('.caption { margin-top: 6mm; font-size: 12px; color: #4b5563; }');
            parts.add('</style>');
        }
        parts.add('</head>');
        parts.add('<body>');

        if (!minimal) {
            String safeActivity = escapeHtmlText(cleanText(activityName));
            String generatedAt = escapeHtmlText(cleanText(DateTime.now().format('dd/MM/yyyy HH:mm')));
            parts.add('<div class="page cover">');
            parts.add('<div class="cover-title">Relatório Fotográfico</div>');
            if (!String.isBlank(safeActivity)) {
                parts.add('<div class="cover-subtitle">');
                parts.add(safeActivity);
                parts.add('</div>');
            }
            parts.add('<div class="cover-meta">Gerado em ');
            parts.add(generatedAt);
            parts.add('</div>');
            parts.add('</div>');
        }

        for (AttachmentInfo item : items) {
            String safeUrl = escapeHtmlAttribute(normalizeUrl(item.dataUri));
            if (String.isBlank(safeUrl)) {
                continue;
            }
            if (minimal) {
                parts.add('<div style="page-break-after:always;">');
                parts.add('<img style="width:100%;height:auto;" src="');
            } else {
                parts.add('<div class="page">');
                parts.add('<div class="image-wrap">');
                parts.add('<img src="');
            }
            parts.add(safeUrl);
            parts.add('" />');
            if (!minimal) {
                parts.add('</div>');
                String safeCaption = escapeHtmlText(cleanText(item.caption));
                if (!String.isBlank(safeCaption)) {
                    parts.add('<div class="caption">');
                    parts.add(safeCaption);
                    parts.add('</div>');
                }
            }
            parts.add('</div>');
        }

        parts.add('</body>');
        parts.add('</html>');
        return String.join(parts, '');
    }

    private static String buildDataUri(ContentVersion cv) {
        String contentType = inferContentType(cv);
        if (String.isBlank(contentType)) {
            return null;
        }
        String base64 = EncodingUtil.base64Encode(cv.VersionData);
        return 'data:' + contentType + ';base64,' + base64;
    }

    private static String inferContentType(ContentVersion cv) {
        String fileType = cv.FileType != null ? cv.FileType.toLowerCase() : null;
        if (fileType == 'png') {
            return 'image/png';
        }
        if (fileType == 'jpg' || fileType == 'jpeg') {
            return 'image/jpeg';
        }
        if (fileType == 'gif') {
            return 'image/gif';
        }

        String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : null;
        if (ext == 'png') {
            return 'image/png';
        }
        if (ext == 'jpg' || ext == 'jpeg') {
            return 'image/jpeg';
        }
        if (ext == 'gif') {
            return 'image/gif';
        }

        String path = cv.PathOnClient != null ? cv.PathOnClient.toLowerCase() : null;
        if (path != null) {
            if (path.endsWith('.png')) {
                return 'image/png';
            }
            if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
                return 'image/jpeg';
            }
            if (path.endsWith('.gif')) {
                return 'image/gif';
            }
        }
        return null;
    }

    private static String normalizeUrl(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String cleaned = cleanUrl(input);
        if (String.isBlank(cleaned)) {
            return null;
        }
        if (cleaned.startsWith('data:')) {
            return cleaned;
        }
        if (cleaned.startsWith('/sfc/servlet.shepherd/')) {
            return cleaned;
        }
        return null;
    }

    private static String cleanUrl(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String cleaned = input.trim();
        cleaned = cleaned.replace('\r', '');
        cleaned = cleaned.replace('\n', '');
        cleaned = cleaned.replace('\t', '');
        return cleaned;
    }

    private static String escapeHtmlAttribute(String input) {
        if (input == null) {
            return null;
        }
        String escaped = input.replace('&', '&amp;');
        escaped = escaped.replace('"', '&quot;');
        escaped = escaped.replace('<', '&lt;');
        escaped = escaped.replace('>', '&gt;');
        escaped = escaped.replace('\'', '&#39;');
        return escaped;
    }

    private static String escapeHtmlText(String input) {
        if (input == null) {
            return null;
        }
        String escaped = input.replace('&', '&amp;');
        escaped = escaped.replace('<', '&lt;');
        escaped = escaped.replace('>', '&gt;');
        return escaped;
    }

    private static String cleanText(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String cleaned = input.trim();
        cleaned = cleaned.replaceAll('[\u0000-\u001F\u007F]', '');
        return cleaned;
    }

    private static void logHtmlDebug(String label, String html, List<AttachmentInfo> items) {
        if (Test.isRunningTest()) {
            return;
        }
        Integer length = html != null ? html.length() : 0;
        Integer previewSize = Math.min(length, 2000);
        String preview = html != null ? html.substring(0, previewSize) : null;
        System.debug(LoggingLevel.ERROR, 'PDF HTML [' + label + '] length=' + length);
        System.debug(LoggingLevel.ERROR, 'PDF HTML [' + label + '] preview=' + preview);
        if (items != null && !items.isEmpty()) {
            List<String> urls = new List<String>();
            for (AttachmentInfo item : items) {
                if (item == null) {
                    continue;
                }
                if (String.isNotBlank(item.dataUri)) {
                    urls.add(item.dataUri.substring(0, Math.min(item.dataUri.length(), 80)) + '...');
                }
            }
            System.debug(LoggingLevel.ERROR, 'PDF HTML [' + label + '] dataUriSample=' + JSON.serialize(urls));
        }
    }
}
