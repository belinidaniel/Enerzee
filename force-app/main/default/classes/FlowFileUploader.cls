/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 09-18-2025
 * @last modified by	 : Daniel Belini
 **/
public with sharing class FlowFileUploader {
  public class FileInput {
    @InvocableVariable(required=true)
    public String fileName;

    @InvocableVariable(required=true)
    public String base64Data;

    @InvocableVariable(required=true)
    public Id parentRecordId;
  }

  public class FileOutput {
    @InvocableVariable
    public Id contentDocumentId;
  }

  @InvocableMethod(
    label='Upload File'
    description='Uploads a file and relates it to a record'
  )
  public static List<FileOutput> uploadFiles(List<FileInput> inputs) {
    List<FileOutput> results = new List<FileOutput>();

    for (FileInput input : inputs) {
      // Create ContentVersion (file)
      ContentVersion cv = new ContentVersion(
        Title = input.fileName,
        PathOnClient = input.fileName,
        VersionData = EncodingUtil.base64Decode(input.base64Data)
      );
      insert cv;

      // Query for ContentDocumentId created
      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];

      // Link file to parent record
      ContentDocumentLink cdl = new ContentDocumentLink(
        ContentDocumentId = cv.ContentDocumentId,
        LinkedEntityId = input.parentRecordId,
        ShareType = 'V', // Viewer permission
        Visibility = 'AllUsers'
      );
      insert cdl;

      FileOutput out = new FileOutput();
      out.contentDocumentId = cv.ContentDocumentId;
      results.add(out);
    }

    return results;
  }
}
