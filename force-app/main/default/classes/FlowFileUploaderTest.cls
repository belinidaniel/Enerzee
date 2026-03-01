/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 09-18-2025
 * @last modified by	 : Daniel Belini
 **/
@isTest
public with sharing class FlowFileUploaderTest {
  @isTest
  static void testUploadFiles() {
    // Create a parent record to link the file to
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // Prepare Base64 content (a simple text file)
    String fileContent = 'This is a test file';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

    // Prepare the input for the invocable method
    FlowFileUploader.FileInput input = new FlowFileUploader.FileInput();
    input.fileName = 'TestFile.txt';
    input.base64Data = base64Data;
    input.parentRecordId = acc.Id;

    Test.startTest();
    List<FlowFileUploader.FileOutput> results = FlowFileUploader.uploadFiles(
      new List<FlowFileUploader.FileInput>{ input }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one result');
    System.assertNotEquals(
      null,
      results[0].contentDocumentId,
      'ContentDocumentId should not be null'
    );

    // Verify the file was linked to the Account
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :acc.Id
    ];
    System.assertEquals(
      1,
      links.size(),
      'A ContentDocumentLink should be created'
    );
    System.assertEquals(
      acc.Id,
      links[0].LinkedEntityId,
      'The file should be linked to the Account'
    );
  }
}
