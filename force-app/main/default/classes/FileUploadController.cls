/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 08-22-2025
 * @last modified by  : Daniel Belini
**/
public without sharing class FileUploadController {
    
    @AuraEnabled
    public static String uploadFile(String recordId, String fileName, String base64Data) {
        if (String.isEmpty(recordId) || String.isEmpty(fileName) || String.isEmpty(base64Data)) {
            throw new AuraHandledException('Missing parameters.');
        }
        try {
            ContentVersion contentVersion = new ContentVersion();
            
            String name = fileName.endsWith('.pdf') ? fileName : fileName + '.pdf';

            contentVersion.Title = name;
            contentVersion.PathOnClient = '/' + name;
            contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            insert contentVersion;

            ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = cv.ContentDocumentId;
            contentDocumentLink.LinkedEntityId = recordId;
            contentDocumentLink.ShareType = 'V';
            contentDocumentLink.Visibility = 'AllUsers';
            if (!Test.isRunningTest()) {
                IntegracaoNivelloProposta.gerandoProposta(recordId);
            }
            insert contentDocumentLink;


            return cv.ContentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteFile(String fileId) {
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :fileId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
}