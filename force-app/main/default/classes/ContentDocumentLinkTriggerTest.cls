@IsTest
private class ContentDocumentLinkTriggerTest {
  @IsTest
  static void shouldCreateAndDeleteProjectLinks() {
    Account acc = new Account(Name = 'Conta');
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'VO-CDL'
    );
    insert opp;

    Task t = new Task(
      Subject = 'Task',
      Status = 'Not Started',
      Priority = 'Normal',
      WhatId = opp.Id
    );
    insert t;

    ContentVersion cv = new ContentVersion(
      Title = 'Documento',
      PathOnClient = 'doc.pdf',
      VersionData = Blob.valueOf('conteudo'),
      FirstPublishLocationId = t.Id
    );
    insert cv;

    ContentVersion insertedCv = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
    ];

    List<ContentDocumentLink> links = [
      SELECT Id, LinkedEntityId
      FROM ContentDocumentLink
      WHERE ContentDocumentId = :insertedCv.ContentDocumentId
    ];

    Boolean hasTask = false;
    Boolean hasWhat = false;
    Id taskLinkId;
    for (ContentDocumentLink link : links) {
      if (link.LinkedEntityId == t.Id) {
        hasTask = true;
        taskLinkId = link.Id;
      }
      if (link.LinkedEntityId == opp.Id) {
        hasWhat = true;
      }
    }
    System.assert(hasTask, 'Link para Task deve existir');
    System.assert(hasWhat, 'Link para WhatId deve existir');

    delete new ContentDocumentLink(Id = taskLinkId);

    Integer remaining = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE
        ContentDocumentId = :insertedCv.ContentDocumentId
        AND LinkedEntityId = :opp.Id
    ];
    System.assertEquals(0, remaining, 'Link para WhatId deve ser removido');
  }
}
