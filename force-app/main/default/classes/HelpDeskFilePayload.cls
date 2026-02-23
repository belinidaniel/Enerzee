public with sharing class HelpDeskFilePayload {
    @AuraEnabled public String fileName;
    @AuraEnabled public String contentType;
    @AuraEnabled public String base64Data;
    @AuraEnabled public String humanSize;
    @AuraEnabled public String name;
}