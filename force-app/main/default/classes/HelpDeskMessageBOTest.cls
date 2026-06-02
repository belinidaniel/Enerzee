/**
 * @description       : Testes da ponte HelpDeskMessage__c -> CaseComment (e ausência de loop).
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class HelpDeskMessageBOTest {
  private static Case buildCase() {
    CaseTriggerHandler.disableTrigger();
    Case c = new Case(Subject = 'Ponte msg', Status = 'Novo', Origin = 'Phone');
    insert c;
    CaseTriggerHandler.enabled = true;
    return c;
  }

  @isTest
  static void mirrorsPortalMessageToCaseComment() {
    Case c = buildCase();

    Test.startTest();
    insert new HelpDeskMessage__c(
      Case__c = c.Id,
      Body__c = 'Mensagem do cliente no portal',
      AuthorType__c = 'Cliente',
      IsPublic__c = true
    );
    Test.stopTest();

    List<CaseComment> comments = [
      SELECT CommentBody, IsPublished
      FROM CaseComment
      WHERE ParentId = :c.Id
    ];
    Assert.areEqual(1, comments.size(), 'Deve criar 1 CaseComment para o Jira');
    Assert.areEqual('Mensagem do cliente no portal', comments[0].CommentBody);
  }

  @isTest
  static void doesNotMirrorMessageThatCameFromBridge() {
    Case c = buildCase();

    Test.startTest();
    // Mensagem com ExternalSource preenchido = veio de um CaseComment (ponte oposta).
    insert new HelpDeskMessage__c(
      Case__c = c.Id,
      Body__c = 'Veio do Jira',
      AuthorType__c = 'Agente',
      IsPublic__c = true,
      ExternalSource__c = '00aAA0000000001'
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM CaseComment WHERE ParentId = :c.Id],
      'Mensagem da ponte não deve gerar CaseComment (anti-loop)'
    );
  }

  @isTest
  static void coversHandlerLifecycleAndToggle() {
    Case c = buildCase();
    HelpDeskMessage__c m = new HelpDeskMessage__c(
      Case__c = c.Id,
      Body__c = 'lifecycle',
      AuthorType__c = 'Cliente',
      IsPublic__c = true,
      ExternalSource__c = 'x'
    );
    insert m;
    // Exercita os demais eventos do handler (update/delete) — métodos no-op.
    update m;
    delete m;
    HelpDeskMessageTriggerHandler.disableTrigger();
    Assert.isFalse(
      HelpDeskMessageTriggerHandler.isTriggerEnabled(),
      'Deve desabilitar'
    );
    HelpDeskMessageTriggerHandler.enabled = true;
    Assert.isTrue(
      HelpDeskMessageTriggerHandler.isTriggerEnabled(),
      'Deve reabilitar'
    );

    // Cobre os métodos no-op do handler (o trigger só escuta after insert).
    HelpDeskMessageTriggerHandler h = new HelpDeskMessageTriggerHandler();
    h.beforeInsert();
    h.beforeUpdate();
    h.afterUpdate();
    h.beforeDelete();
    h.afterDelete();
  }

  @isTest
  static void noInfiniteLoopOnNativePortalMessage() {
    Case c = buildCase();

    Test.startTest();
    // Mensagem nativa -> cria 1 CaseComment -> que NÃO deve recriar outra mensagem.
    insert new HelpDeskMessage__c(
      Case__c = c.Id,
      Body__c = 'Nativa do portal',
      AuthorType__c = 'Cliente',
      IsPublic__c = true
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM CaseComment WHERE ParentId = :c.Id],
      'Exatamente 1 CaseComment'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM HelpDeskMessage__c WHERE Case__c = :c.Id],
      'Continua só a mensagem original (sem duplicar via loop)'
    );
  }
}
