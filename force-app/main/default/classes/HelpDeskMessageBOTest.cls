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
      SELECT Id, CommentBody, IsPublished
      FROM CaseComment
      WHERE ParentId = :c.Id
    ];
    Assert.areEqual(1, comments.size(), 'Deve criar 1 CaseComment para o Jira');
    Assert.areEqual('Mensagem do cliente no portal', comments[0].CommentBody);

    // A mensagem deve guardar o Id do CaseComment espelhado (para append de URLs).
    HelpDeskMessage__c stored = [
      SELECT CaseCommentId__c
      FROM HelpDeskMessage__c
      WHERE Case__c = :c.Id
      LIMIT 1
    ];
    Assert.areEqual(
      String.valueOf(comments[0].Id),
      stored.CaseCommentId__c,
      'CaseCommentId__c deve apontar para o CaseComment espelhado'
    );
  }

  @isTest
  static void appendsAttachmentUrlsToMirroredComment() {
    Case c = buildCase();

    HelpDeskMessage__c msg = new HelpDeskMessage__c(
      Case__c = c.Id,
      Body__c = 'Mensagem com anexo',
      AuthorType__c = 'Cliente',
      IsPublic__c = true
    );
    insert msg;

    Id commentId = (Id) [
      SELECT CaseCommentId__c
      FROM HelpDeskMessage__c
      WHERE Id = :msg.Id
      LIMIT 1
    ]
    .CaseCommentId__c;

    // Anexos vinculados à mensagem (fonte da verdade para a seção "Anexos:").
    insert new List<AttachmentLink__c>{
      new AttachmentLink__c(
        SObjectType__c = 'HelpDeskMessage__c',
        SObjectId__c = String.valueOf(msg.Id),
        FileName__c = 'foto-erro.png',
        AttachmentURL__c = 'https://arquivos.exemplo/abc123'
      ),
      new AttachmentLink__c(
        SObjectType__c = 'HelpDeskMessage__c',
        SObjectId__c = String.valueOf(msg.Id),
        FileName__c = 'layout.png',
        AttachmentURL__c = 'https://arquivos.exemplo/def456'
      ),
      new AttachmentLink__c(
        SObjectType__c = 'HelpDeskMessage__c',
        SObjectId__c = String.valueOf(msg.Id),
        FileName__c = 'sem-url.png',
        AttachmentURL__c = null
      )
    };

    Test.startTest();
    HelpDeskMessageBO.appendAttachmentUrlsToComment(msg.Id, null, null);
    Test.stopTest();

    CaseComment updated = [
      SELECT CommentBody
      FROM CaseComment
      WHERE Id = :commentId
      LIMIT 1
    ];
    Assert.isTrue(
      updated.CommentBody.contains('Anexos:'),
      'Deve conter o cabeçalho "Anexos:"'
    );
    Assert.isTrue(
      updated.CommentBody.contains(
        '1- foto-erro.png: https://arquivos.exemplo/abc123'
      ),
      'Deve numerar o primeiro anexo'
    );
    Assert.isTrue(
      updated.CommentBody.contains(
        '2- layout.png: https://arquivos.exemplo/def456'
      ),
      'Deve numerar o segundo anexo'
    );
    Assert.isFalse(
      updated.CommentBody.contains('sem-url.png'),
      'Anexo sem URL deve ser ignorado'
    );
    // Texto original da mensagem deve ser preservado acima da seção.
    Assert.isTrue(
      updated.CommentBody.startsWith('Mensagem com anexo'),
      'O texto original do comentário deve ser preservado'
    );

    HelpDeskMessageBO.syncMirroredCommentAttachments(msg.Id);
    CaseComment synchronizedAgain = [
      SELECT CommentBody
      FROM CaseComment
      WHERE Id = :commentId
      LIMIT 1
    ];
    Assert.areEqual(
      updated.CommentBody,
      synchronizedAgain.CommentBody,
      'Sincronizações sucessivas não devem duplicar a seção de anexos'
    );
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