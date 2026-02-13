public with sharing class VOLogService {
    public static final String TYPE_ACCOUNT_SYNC = 'ACCOUNT_SYNC';
    public static final String TYPE_OPP_SYNC = 'OPP_SYNC';

    private static final Integer URI_LIMIT = 255;
    private static final Integer SHORT_TEXT_LIMIT = 255;
    private static final Integer LONG_MESSAGE_LIMIT = 100000;
    private static final Integer REQUEST_BODY_LIMIT = 131072;
    private static final Integer RESPONSE_BODY_LIMIT = 100000;

    private static final Set<String> SENSITIVE_KEYWORDS = new Set<String>{
        'password', 'senha', 'token', 'authorization', 'cpf', 'cnpj', 'documento', 'email', 'login'
    };

    private static final Map<String, Schema.SObjectField> LOG_FIELDS = Log__c.SObjectType.getDescribe().fields.getMap();

    public static String newCorrelationId(String prefix, Id recordId) {
        String safePrefix = String.isBlank(prefix) ? 'VO' : prefix.trim().toUpperCase();
        String safeRecordId = recordId == null ? 'NOID' : String.valueOf(recordId).left(8);
        return safePrefix + '-' + DateTime.now().formatGmt('yyyyMMddHHmmssSSS') + '-' + safeRecordId + '-' + String.valueOf(Math.abs(Crypto.getRandomLong())).left(6);
    }

    public static void addNoEndpointLog(
        List<Log__c> logs,
        String className,
        String operation,
        String integrationType,
        Id recordId,
        String origin,
        String correlationId,
        String normalizedError,
        Boolean isError
    ) {
        if (logs == null) {
            return;
        }

        Log__c log = baseLog(className, operation, integrationType, recordId, origin, correlationId, isError);
        log.Message__c = truncate(normalizedError, LONG_MESSAGE_LIMIT);
        logs.add(log);
    }

    public static void addResponseLog(
        List<Log__c> logs,
        String className,
        String operation,
        String integrationType,
        Id recordId,
        String origin,
        String correlationId,
        HttpRequest request,
        String maskedRequestPayload,
        HttpResponse response,
        String normalizedError,
        Boolean isError
    ) {
        if (logs == null) {
            return;
        }

        Log__c log = baseLog(className, operation, integrationType, recordId, origin, correlationId, isError);

        if (request != null) {
            log.HTTPMethod__c = truncate(request.getMethod(), SHORT_TEXT_LIMIT);
            log.RequestURI__c = truncate(request.getEndpoint(), URI_LIMIT);
        }

        log.RequestBody__c = truncate(maskedRequestPayload, REQUEST_BODY_LIMIT);

        if (response != null) {
            log.StatusCode__c = response.getStatusCode();
            log.Status__c = truncate(response.getStatus(), RESPONSE_BODY_LIMIT);
            log.ResponseBody__c = truncate(response.getBody(), RESPONSE_BODY_LIMIT);
        }

        log.Message__c = truncate(normalizedError, LONG_MESSAGE_LIMIT);
        logs.add(log);
    }

    public static void addExceptionLog(
        List<Log__c> logs,
        String className,
        String operation,
        String integrationType,
        Id recordId,
        String origin,
        String correlationId,
        HttpRequest request,
        String maskedRequestPayload,
        Exception ex
    ) {
        if (logs == null) {
            return;
        }

        Log__c log = baseLog(className, operation, integrationType, recordId, origin, correlationId, true);

        if (request != null) {
            log.HTTPMethod__c = truncate(request.getMethod(), SHORT_TEXT_LIMIT);
            log.RequestURI__c = truncate(request.getEndpoint(), URI_LIMIT);
        }

        log.RequestBody__c = truncate(maskedRequestPayload, REQUEST_BODY_LIMIT);

        if (ex != null) {
            log.Message__c = truncate(normalizeException(ex), LONG_MESSAGE_LIMIT);
            log.Type__c = truncate(ex.getTypeName(), SHORT_TEXT_LIMIT);
            log.LineNumber__c = truncate(String.valueOf(ex.getLineNumber()), SHORT_TEXT_LIMIT);
            log.StackTraceString__c = truncate(ex.getStackTraceString(), LONG_MESSAGE_LIMIT);
        }

        logs.add(log);
    }

    public static void addDmlResultErrors(
        List<Log__c> logs,
        String className,
        String operation,
        String integrationType,
        List<SObject> records,
        Database.SaveResult[] saveResults,
        String origin,
        Map<Id, String> correlationByRecordId
    ) {
        if (logs == null || records == null || saveResults == null) {
            return;
        }

        Integer upperBound = Math.min(records.size(), saveResults.size());

        for (Integer index = 0; index < upperBound; index++) {
            if (saveResults[index].isSuccess()) {
                continue;
            }

            Id recordId = (Id) records[index].get('Id');
            String correlationId = correlationByRecordId != null ? correlationByRecordId.get(recordId) : null;

            List<String> messages = new List<String>();
            for (Database.Error errorItem : saveResults[index].getErrors()) {
                messages.add(errorItem.getStatusCode() + ': ' + errorItem.getMessage());
            }

            addNoEndpointLog(
                logs,
                className,
                operation,
                integrationType,
                recordId,
                origin,
                correlationId,
                'DML_ERROR: ' + String.join(messages, ' | '),
                true
            );
        }
    }

    public static void flush(List<Log__c> logs) {
        if (logs == null || logs.isEmpty()) {
            return;
        }

        try {
            insert logs;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'VOLogService.flush failed: ' + ex.getMessage());
        }
    }

    public static String maskPayload(String payload) {
        if (String.isBlank(payload)) {
            return payload;
        }

        try {
            Object deserialized = JSON.deserializeUntyped(payload);
            Object masked = maskObject(null, deserialized);
            return JSON.serialize(masked);
        } catch (Exception ex) {
            return payload;
        }
    }

    public static String normalizeHttpError(HttpResponse response, Boolean hasBusinessError, String businessErrorMessage) {
        if (response == null) {
            return 'HTTP_ERROR: sem resposta do endpoint.';
        }

        Integer statusCode = response.getStatusCode();

        if (statusCode < 200 || statusCode > 299) {
            return 'HTTP_ERROR ' + statusCode + ': ' + response.getStatus();
        }

        if (hasBusinessError) {
            return String.isBlank(businessErrorMessage)
                ? 'VO_BUSINESS_ERROR: erro de negócio retornado pelo endpoint.'
                : 'VO_BUSINESS_ERROR: ' + businessErrorMessage;
        }

        return null;
    }

    public static String normalizeException(Exception ex) {
        if (ex == null) {
            return 'EXCEPTION: desconhecida';
        }

        return 'EXCEPTION ' + ex.getTypeName() + ': ' + ex.getMessage();
    }

    private static Log__c baseLog(
        String className,
        String operation,
        String integrationType,
        Id recordId,
        String origin,
        String correlationId,
        Boolean isError
    ) {
        Log__c log = new Log__c();

        log.Name = truncate((String.isBlank(integrationType) ? 'VO' : integrationType) + ' ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss'), 80);
        log.Class__c = truncate(className, SHORT_TEXT_LIMIT);
        log.Method__c = truncate(operation, SHORT_TEXT_LIMIT);
        log.RelatedId__c = recordId == null ? null : truncate(String.valueOf(recordId), SHORT_TEXT_LIMIT);
        log.Type__c = truncate(integrationType, SHORT_TEXT_LIMIT);

        putIfFieldExists(log, 'CorrelationId__c', truncate(correlationId, SHORT_TEXT_LIMIT));
        putIfFieldExists(log, 'Operation__c', truncate(operation, SHORT_TEXT_LIMIT));
        putIfFieldExists(log, 'CallOrigin__c', truncate(origin, SHORT_TEXT_LIMIT));
        putIfFieldExists(log, 'IntegrationType__c', truncate(integrationType, SHORT_TEXT_LIMIT));
        putIfFieldExists(log, 'Erro_Enviado__c', isError == true);

        return log;
    }

    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || !LOG_FIELDS.containsKey(fieldApiName)) {
            return;
        }

        record.put(fieldApiName, value);
    }

    private static Object maskObject(String parentKey, Object value) {
        if (value == null) {
            return null;
        }

        if (value instanceof Map<String, Object>) {
            Map<String, Object> originalMap = (Map<String, Object>) value;
            Map<String, Object> maskedMap = new Map<String, Object>();

            for (String key : originalMap.keySet()) {
                maskedMap.put(key, maskObject(key, originalMap.get(key)));
            }

            return maskedMap;
        }

        if (value instanceof List<Object>) {
            List<Object> originalList = (List<Object>) value;
            List<Object> maskedList = new List<Object>();

            for (Object item : originalList) {
                maskedList.add(maskObject(parentKey, item));
            }

            return maskedList;
        }

        if (value instanceof String) {
            return maskScalarValue(parentKey, (String) value);
        }

        return value;
    }

    private static String maskScalarValue(String key, String value) {
        if (String.isBlank(value)) {
            return value;
        }

        String safeKey = String.isBlank(key) ? '' : key.toLowerCase();

        if (!isSensitiveKey(safeKey)) {
            return value;
        }

        if (safeKey.contains('email')) {
            return maskEmail(value);
        }

        if (safeKey.contains('cpf') || safeKey.contains('cnpj') || safeKey.contains('document')) {
            return maskDocument(value);
        }

        return '***';
    }

    private static Boolean isSensitiveKey(String key) {
        if (String.isBlank(key)) {
            return false;
        }

        for (String keyword : SENSITIVE_KEYWORDS) {
            if (key.contains(keyword)) {
                return true;
            }
        }

        return false;
    }

    private static String maskEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return '***';
        }

        List<String> parts = email.split('@');
        String localPart = parts[0];
        String domainPart = parts.size() > 1 ? parts[1] : '';

        if (localPart.length() <= 2) {
            return '**@' + domainPart;
        }

        return localPart.left(2) + '***@' + domainPart;
    }

    private static String maskDocument(String documentValue) {
        if (String.isBlank(documentValue)) {
            return '***';
        }

        String numbers = documentValue.replaceAll('[^0-9]', '');

        if (numbers.length() <= 4) {
            return '***';
        }

        return '***' + numbers.right(4);
    }

    private static String truncate(String value, Integer limitSize) {
        if (value == null || limitSize == null || limitSize <= 0) {
            return value;
        }

        return value.length() > limitSize ? value.substring(0, limitSize) : value;
    }
}
