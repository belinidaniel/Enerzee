@IsTest
private class HelpDeskCaseDAOTest {
  @IsTest
  static void shouldQueryCaseData() {
    Contact c = new Contact(LastName = 'Contato', Email = 'case@teste.com');
    insert c;

    Case cs = new Case(
      Subject = 'Teste',
      Status = 'New',
      Origin = 'Phone',
      ContactId = c.Id
    );
    insert cs;

    CaseComment comment = new CaseComment(
      ParentId = cs.Id,
      CommentBody = 'Oi',
      IsPublished = true
    );
    insert comment;

    ContentVersion cv = new ContentVersion(
      Title = 'arquivo',
      PathOnClient = 'arquivo.txt',
      VersionData = Blob.valueOf('conteudo'),
      FirstPublishLocationId = cs.Id
    );
    insert cv;

    String ownershipFilter = 'Id = \'' + cs.Id + '\'';
    System.assertEquals(
      1,
      HelpDeskCaseDAO.queryCases(ownershipFilter, false, null).size()
    );
    System.assertEquals(cs.Id, HelpDeskCaseDAO.queryCaseDetail(cs.Id).Id);
    System.assertEquals(1, HelpDeskCaseDAO.queryComments(cs.Id).size());
    System.assertEquals(1, HelpDeskCaseDAO.queryAttachments(cs.Id).size());
  }
}
