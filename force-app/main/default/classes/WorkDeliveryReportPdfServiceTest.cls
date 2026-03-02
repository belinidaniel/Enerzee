@IsTest
private class WorkDeliveryReportPdfServiceTest {
  @IsTest
  static void generatePdfBase64_returnsBase64() {
    Account acc = new Account(Name = 'Conta Teste');
    insert acc;

    Blob body = Blob.valueOf('TESTE');
    ContentVersion cv = new ContentVersion();
    cv.ContentLocation = 'S';
    cv.FirstPublishLocationId = acc.Id;
    cv.Title = 'foto-teste';
    cv.PathOnClient = 'foto-teste.png';
    cv.VersionData = body;
    insert cv;

    cv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ];

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c(
      Name = 'Anexo Teste',
      SObjectId__c = acc.Id,
      ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
      AttachmentDescription__c = 'foto-teste.png',
      DocRequiredName__c = 'TESTE',
      ContentDocumentId__c = String.valueOf(cv.ContentDocumentId)
    );
    insert link;

    Test.startTest();
    String base64 = WorkDeliveryReportPdfService.generatePdfBase64(
      acc.Id,
      TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
    );
    Test.stopTest();

    System.assertNotEquals(null, base64, 'Base64 não deveria ser nulo.');
    System.assert(base64.length() > 0, 'Base64 não deveria ser vazio.');
  }
}
