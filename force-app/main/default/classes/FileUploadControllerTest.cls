/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 08-19-2025
 * @last modified by	 : Daniel Belini
 **/
@isTest
private class FileUploadControllerTest {
  @isTest
  static void testUploadFile() {
    // Create a test account record
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // Test data
    String recordId = acc.Id;
    String fileName = 'testFile';
    String base64Data = 'VGVzdCBjb250ZW50'; // "Test content" in base64

    // Test method
    Test.startTest();
    String contentDocumentId = FileUploadController.uploadFile(
      recordId,
      fileName,
      base64Data
    );
    Test.stopTest();

    // Assertions

    // Verify ContentVersion
    ContentVersion cv = [
      SELECT Id, Title, PathOnClient
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      LIMIT 1
    ];

    // Verify ContentDocumentLink
    ContentDocumentLink cdl = [
      SELECT Id
      FROM ContentDocumentLink
      WHERE
        ContentDocumentId = :contentDocumentId
        AND LinkedEntityId = :recordId
      LIMIT 1
    ];
  }

  @isTest
  static void testUploadFileWithPdfExtension() {
    // Create a test account record
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // Test data
    String recordId = acc.Id;
    String fileName = 'testFile.pdf';
    String base64Data = 'VGVzdCBjb250ZW50'; // "Test content" in base64

    // Test method
    Test.startTest();
    String contentDocumentId = FileUploadController.uploadFile(
      recordId,
      fileName,
      base64Data
    );
    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      contentDocumentId,
      'ContentDocumentId should not be null'
    );

    // Verify ContentVersion
    ContentVersion cv = [
      SELECT Id, Title, PathOnClient
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      LIMIT 1
    ];
  }

  @isTest
  static void testDeleteFile() {
    // Create a test account record and upload a file
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    String contentDocumentId = FileUploadController.uploadFile(
      acc.Id,
      'testFile',
      'VGVzdCBjb250ZW50'
    );

    // Test method
    Test.startTest();
    FileUploadController.deleteFile(contentDocumentId);
    Test.stopTest();

    // Assertions
    List<ContentDocument> docs = [
      SELECT Id
      FROM ContentDocument
      WHERE Id = :contentDocumentId
    ];
    System.assertEquals(0, docs.size(), 'ContentDocument should be deleted');
  }

  @isTest
  static void testUploadFileMissingParameters() {
    Test.startTest();
    try {
      FileUploadController.uploadFile(null, 'test', 'test');
    } catch (AuraHandledException e) {
    }

    try {
      Account acc = new Account(Name = 'Test Account');
      insert acc;
      FileUploadController.uploadFile(acc.Id, null, 'test');
    } catch (AuraHandledException e) {
    }
    Test.stopTest();
  }
}
