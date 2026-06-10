/**
 * @description       : Testes da ponte CaseComment -> HelpDeskMessage__c.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class CaseCommentBOTest {
  private static Case buildCase() {
    CaseTriggerHandler.disableTrigger();
    Case c = new Case(
      Subject = 'Ponte coment',
      Status = 'Novo',
      Origin = 'Phone'
    );
    insert c;
    CaseTriggerHandler.enabled = true;
    return c;
  }

  @isTest
  static void mirrorsCaseCommentToHelpDeskMessage() {
    Case c = buildCase();

    Test.startTest();
    CaseComment cc = new CaseComment(
      ParentId = c.Id,
      CommentBody = 'Comentário vindo do Jira',
      IsPublished = true
    );
    insert cc;
    Test.stopTest();

    List<HelpDeskMessage__c> msgs = [
      SELECT Body__c, ExternalSource__c, AuthorType__c, IsPublic__c, Case__c
      FROM HelpDeskMessage__c
      WHERE Case__c = :c.Id
    ];
    Assert.areEqual(1, msgs.size(), 'Deve espelhar 1 mensagem no portal');
    Assert.areEqual('Comentário vindo do Jira', msgs[0].Body__c);
    Assert.areEqual(
      String.valueOf(cc.Id),
      msgs[0].ExternalSource__c,
      'Marca a origem'
    );
    Assert.areEqual('Agente', msgs[0].AuthorType__c);
    Assert.isTrue(msgs[0].IsPublic__c, 'IsPublished true -> IsPublic true');
  }

  @isTest
  static void doesNotDuplicateWhenMirroredTwice() {
    Case c = buildCase();
    insert new CaseComment(
      ParentId = c.Id,
      CommentBody = 'Idempotente',
      IsPublished = true
    );

    // Re-executa a ponte manualmente sobre o mesmo comentário (simula reprocesso).
    CaseComment existing = [
      SELECT Id, ParentId, CommentBody, IsPublished
      FROM CaseComment
      WHERE ParentId = :c.Id
      LIMIT 1
    ];
    Test.startTest();
    CaseCommentBO.mirrorToHelpDeskMessages(new List<CaseComment>{ existing });
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM HelpDeskMessage__c WHERE Case__c = :c.Id],
      'Não deve duplicar a mensagem já espelhada'
    );
  }

  @isTest
  static void coversHandlerLifecycleAndToggle() {
    Case c = buildCase();
    CaseComment cc = new CaseComment(
      ParentId = c.Id,
      CommentBody = 'lifecycle',
      IsPublished = true
    );
    insert cc;
    // Exercita os demais eventos do handler (update/delete) — métodos no-op.
    update cc;
    delete cc;
    // Toggle de habilitação.
    CaseCommentTriggerHandler.disableTrigger();
    Assert.isFalse(
      CaseCommentTriggerHandler.isTriggerEnabled(),
      'Deve desabilitar'
    );
    CaseCommentTriggerHandler.enabled = true;
    Assert.isTrue(
      CaseCommentTriggerHandler.isTriggerEnabled(),
      'Deve reabilitar'
    );

    // Cobre os métodos no-op do handler (o trigger só escuta after insert).
    CaseCommentTriggerHandler h = new CaseCommentTriggerHandler();
    h.beforeInsert();
    h.beforeUpdate();
    h.afterUpdate();
    h.beforeDelete();
    h.afterDelete();
  }

  @isTest
  static void respectsSuppressionFlag() {
    Case c = buildCase();
    CaseCommentBO.suppressMirrorToMessage = true;

    Test.startTest();
    insert new CaseComment(
      ParentId = c.Id,
      CommentBody = 'Não deve espelhar',
      IsPublished = true
    );
    Test.stopTest();

    CaseCommentBO.suppressMirrorToMessage = false;
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM HelpDeskMessage__c WHERE Case__c = :c.Id],
      'Com flag de supressão, não espelha'
    );
  }
}
