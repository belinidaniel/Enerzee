public with sharing class HelpDeskFilePayload {
    @AuraEnabled public String fileName { get; set; }
    @AuraEnabled public String contentType { get; set; }
    @AuraEnabled public String base64Data { get; set; }
    @AuraEnabled public String humanSize { get; set; }
    @AuraEnabled public String name { get; set; }
}
