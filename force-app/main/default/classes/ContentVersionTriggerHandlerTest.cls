@IsTest
private class ContentVersionTriggerHandlerTest {
  @IsTest
  static void shouldFillIsProposal() {
    ContentVersion cv = new ContentVersion(
      Title = 'Proposta Teste',
      PathOnClient = 'proposta.pdf',
      VersionData = Blob.valueOf('teste')
    );
    insert cv;

    ContentVersion inserted = [
      SELECT Id, IsProposal__c
      FROM ContentVersion
      WHERE Id = :cv.Id
    ];
    System.assertEquals(true, inserted.IsProposal__c);
  }
}
