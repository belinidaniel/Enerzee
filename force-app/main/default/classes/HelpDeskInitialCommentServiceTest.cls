@IsTest
private class HelpDeskInitialCommentServiceTest {
  @IsTest
  static void shouldCreateDetailedInitialCommentAndMirrorIt() {
    CaseTriggerHandler.disableTrigger();
    Case caseRecord = new Case(
      Subject = 'Falha no acesso',
      Status = 'Novo',
      Origin = 'Help Desk Salesforce',
      Description = 'Usuário não consegue acessar o sistema.',
      SuppliedEmail = 'solicitante@teste.com',
      SuppliedPhone = '11999990000'
    );
    insert caseRecord;
    CaseTriggerHandler.enabled = true;

    Test.startTest();
    HelpDeskInitialCommentService.createForCase(caseRecord.Id);
    Test.stopTest();

    HelpDeskMessage__c message = [
      SELECT Body__c, AuthorName__c, AuthorType__c, IsPublic__c
      FROM HelpDeskMessage__c
      WHERE Case__c = :caseRecord.Id
      LIMIT 1
    ];
    Assert.areEqual('Salesforce Help Desk', message.AuthorName__c);
    Assert.areEqual('Agente', message.AuthorType__c);
    Assert.isTrue(message.IsPublic__c);
    Assert.isTrue(message.Body__c.contains('RESUMO INICIAL DO CHAMADO'));
    Assert.isTrue(message.Body__c.contains('Falha no acesso'));
    Assert.isTrue(message.Body__c.contains('solicitante@teste.com'));

    CaseComment mirroredComment = [
      SELECT CommentBody
      FROM CaseComment
      WHERE ParentId = :caseRecord.Id
      LIMIT 1
    ];
    Assert.areEqual(message.Body__c, mirroredComment.CommentBody);
  }
}
