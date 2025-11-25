public with sharing class OpportunityLogViewerController {
    private static final Integer DEFAULT_LIMIT = 100;
    private static final Integer MAX_LIMIT = 500;

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        Profile profileInfo = [
            SELECT PermissionsModifyAllData, PermissionsViewAllData
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        return profileInfo.PermissionsModifyAllData || profileInfo.PermissionsViewAllData;
    }

    @AuraEnabled(cacheable=true)
    public static List<Log__c> getLogsByOpportunity(Id opportunityId, Integer recordLimit) {
        enforceAdminAccess();

        if (opportunityId == null) {
            return new List<Log__c>();
        }

        Integer limitSize = normalizeLimit(recordLimit);

        List<Log__c> logs = [
            SELECT Id, Name, CreatedDate, StatusCode__c, Status__c, Class__c, Method__c,
                   HTTPMethod__c, RequestURI__c
            FROM Log__c
            WHERE RelatedId__c = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT :limitSize
        ];

        return (List<Log__c>) Security.stripInaccessible(
            AccessType.READABLE,
            logs
        ).getRecords();
    }

    @AuraEnabled(cacheable=true)
    public static Log__c getLogDetail(Id logId) {
        enforceAdminAccess();

        if (logId == null) {
            throw new AuraHandledException('Log Id e obrigatorio.');
        }

        List<Log__c> logs = [
            SELECT Id, Name, CreatedDate, StatusCode__c, Status__c, Class__c, Method__c,
                   HTTPMethod__c, RequestURI__c, Message__c, RequestBody__c,
                   ResponseBody__c, StackTraceString__c, LineNumber__c, Type__c
            FROM Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        if (logs.isEmpty()) {
            return null;
        }

        return (Log__c) Security.stripInaccessible(
            AccessType.READABLE,
            logs
        ).getRecords().get(0);
    }

    private static Integer normalizeLimit(Integer limitSize) {
        if (limitSize == null || limitSize <= 0) {
            return DEFAULT_LIMIT;
        }

        return Math.min(limitSize, MAX_LIMIT);
    }

    private static void enforceAdminAccess() {
        if (!isCurrentUserAdmin()) {
            throw new AuraHandledException('Apenas administradores podem visualizar estes logs.');
        }
    }
}