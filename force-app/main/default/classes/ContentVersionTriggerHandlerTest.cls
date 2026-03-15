/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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
