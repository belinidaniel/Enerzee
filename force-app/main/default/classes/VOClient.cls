public with sharing class VOClient {
    private static final Integer DEFAULT_TIMEOUT_MS = 120000;
    private static Map<String, Integrador__mdt> endpointByDeveloperName = new Map<String, Integrador__mdt>();

    public class CalloutResult {
        public String endpointDeveloperName;
        public HttpRequest request;
        public HttpResponse response;
    }

    public static CalloutResult sendJson(String endpointDeveloperName, String payload) {
        Integrador__mdt endpointMetadata = getEndpointMetadata(endpointDeveloperName);
        HttpRequest request = buildRequest(endpointMetadata, payload);
        HttpResponse response = Utils.callIntegrationVO(request);

        CalloutResult result = new CalloutResult();
        result.endpointDeveloperName = endpointDeveloperName;
        result.request = request;
        result.response = response;
        return result;
    }

    public static Integrador__mdt getEndpointMetadata(String endpointDeveloperName) {
        if (String.isBlank(endpointDeveloperName)) {
            throw new VOClientException('DeveloperName do endpoint VO não informado.');
        }

        if (!endpointByDeveloperName.containsKey(endpointDeveloperName)) {
            List<Integrador__mdt> metadataList = [
                SELECT DeveloperName, URL__c, Method__c, ContentType__c
                FROM Integrador__mdt
                WHERE DeveloperName = :endpointDeveloperName
                LIMIT 1
            ];

            endpointByDeveloperName.put(
                endpointDeveloperName,
                metadataList.isEmpty() ? null : metadataList[0]
            );
        }

        Integrador__mdt endpointMetadata = endpointByDeveloperName.get(endpointDeveloperName);

        if (endpointMetadata == null || String.isBlank(endpointMetadata.URL__c)) {
            throw new VOClientException('Endpoint VO não encontrado para DeveloperName: ' + endpointDeveloperName);
        }

        return endpointMetadata;
    }

    public static Map<String, Object> parseBodyAsMap(String responseBody) {
        if (String.isBlank(responseBody)) {
            return new Map<String, Object>();
        }

        try {
            Object rawBody = JSON.deserializeUntyped(responseBody);
            if (rawBody instanceof Map<String, Object>) {
                return (Map<String, Object>) rawBody;
            }
        } catch (Exception ex) {
            return new Map<String, Object>();
        }

        return new Map<String, Object>();
    }

    public static String extractStringValue(Map<String, Object> bodyAsMap, List<String> possibleKeys) {
        if (bodyAsMap == null || bodyAsMap.isEmpty() || possibleKeys == null || possibleKeys.isEmpty()) {
            return null;
        }

        for (String key : possibleKeys) {
            if (!bodyAsMap.containsKey(key)) {
                continue;
            }

            Object rawValue = bodyAsMap.get(key);
            if (rawValue == null) {
                continue;
            }

            String value = String.valueOf(rawValue);
            if (String.isNotBlank(value) && value.toLowerCase() != 'null') {
                return value;
            }
        }

        return null;
    }

    private static HttpRequest buildRequest(Integrador__mdt endpointMetadata, String payload) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpointMetadata.URL__c);
        request.setMethod(String.isBlank(endpointMetadata.Method__c) ? 'POST' : endpointMetadata.Method__c);
        request.setHeader('Content-Type', String.isBlank(endpointMetadata.ContentType__c) ? 'application/json' : endpointMetadata.ContentType__c);
        request.setTimeout(DEFAULT_TIMEOUT_MS);
        request.setBody(payload);
        return request;
    }

    public class VOClientException extends Exception {}
}
