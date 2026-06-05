/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class HelpDeskCaseServiceTest {
  @IsTest
  static void shouldHandleCasesFlow() {
    Account acc = new Account(Name = 'Enerzee Support');
    insert acc;

    Contact c = new Contact(
      LastName = 'Contato',
      Email = 'helpdesk@teste.com',
      AccountId = acc.Id
    );
    insert c;

    Case cs = new Case(
      Subject = 'Ajuda',
      Status = 'New',
      Origin = 'Phone',
      ContactId = c.Id,
      AccountId = acc.Id
    );
    insert cs;

    HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
    ctx.userId = UserInfo.getUserId();
    ctx.contactId = c.Id;
    ctx.email = c.Email;

    List<Case> cases = HelpDeskCaseService.getCases('open', null, c.Id, ctx);
    System.assertEquals(1, cases.size());

    Case detail = HelpDeskCaseService.getCaseDetail(cs.Id, c.Id, ctx);
    System.assertEquals(cs.Id, detail.Id);

    CaseComment comment = HelpDeskCaseService.addComment(
      cs.Id,
      'Teste',
      c.Id,
      ctx
    );
    System.assertEquals(cs.Id, comment.ParentId);

    List<CaseComment> comments = HelpDeskCaseService.getCaseComments(
      cs.Id,
      c.Id,
      ctx
    );
    System.assertEquals(1, comments.size());

    HelpDeskFilePayload payload = new HelpDeskFilePayload();
    payload.fileName = 'arquivo.txt';
    payload.base64Data = EncodingUtil.base64Encode(Blob.valueOf('conteudo'));

    HelpDeskCaseService.uploadFiles(
      cs.Id,
      new List<HelpDeskFilePayload>{ payload },
      c.Id,
      ctx
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :cs.Id]
    );

    HelpDeskCaseService.uploadFilesBypassLicense(
      cs.Id,
      new List<HelpDeskFilePayload>{ payload },
      c.Id,
      ctx
    );
    System.assertEquals(
      2,
      [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :cs.Id]
    );

    HelpDeskCaseService.DefaultEntitiesDTO defaults = HelpDeskCaseService.getDefaultEntities(
      c.Id
    );
    System.assertEquals(acc.Id, defaults.accountId);
    System.assertEquals(c.Id, defaults.contactId);
    System.assertEquals(c.Email, defaults.contactEmail);

    List<HelpDeskCaseService.CaseCategoryOptionDTO> categoryOptions = HelpDeskCaseService.getCaseCategoryOptions();
    System.assertNotEquals(null, categoryOptions);

    if (
      Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .containsKey('Help_Desk_Salesforce')
    ) {
      Id newCaseId = HelpDeskCaseService.createCase(
        'Novo caso',
        'Desc',
        null,
        'Salesforce',
        'Acesso',
        'Login',
        'Medium',
        c.Email,
        '1199',
        c.Id,
        acc.Id
      );
      System.assertNotEquals(null, newCaseId);
      if (
        Schema.SObjectType.Case.fields.getMap()
          .containsKey('HelpDesk_Sistema__c')
      ) {
        Case createdCase = [
          SELECT HelpDesk_Sistema__c, HelpDesk_Tipo__c, HelpDesk_Subtipo__c
          FROM Case
          WHERE Id = :newCaseId
          LIMIT 1
        ];
        Object systemValue = createdCase.get('HelpDesk_Sistema__c');
        if (systemValue != null) {
          System.assertEquals('Salesforce', (String) systemValue);
        }
        Object typeValue = createdCase.get('HelpDesk_Tipo__c');
        if (typeValue != null) {
          System.assertEquals('Acesso', (String) typeValue);
        }
        Object subtypeValue = createdCase.get('HelpDesk_Subtipo__c');
        if (subtypeValue != null) {
          System.assertEquals('Login', (String) subtypeValue);
        }
      }
    }
  }

  @IsTest
  static void shouldAddAndListMessages() {
    Account acc = new Account(Name = 'Enerzee Mensagens');
    insert acc;

    Contact c = new Contact(
      LastName = 'Contato Mensagens',
      Email = 'mensagens@teste.com',
      AccountId = acc.Id
    );
    insert c;

    Case cs = new Case(
      Subject = 'Caso com mensagens',
      Status = 'New',
      Origin = 'Phone',
      ContactId = c.Id,
      AccountId = acc.Id
    );
    insert cs;

    HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
    ctx.userId = UserInfo.getUserId();
    ctx.contactId = c.Id;
    ctx.email = c.Email;
    ctx.name = 'Agente Teste';

    Id publicMessageId = HelpDeskCaseService.addMessage(
      cs.Id,
      'Mensagem pública',
      null,
      'Cliente',
      true,
      c.Id,
      ctx
    );
    System.assertNotEquals(null, publicMessageId);

    Id privateMessageId = HelpDeskCaseService.addMessage(
      cs.Id,
      'Mensagem interna',
      null,
      'Agente',
      false,
      c.Id,
      ctx
    );
    System.assertNotEquals(null, privateMessageId);

    List<HelpDeskMessage__c> publicMessages = HelpDeskCaseService.getMessages(
      cs.Id,
      c.Id,
      ctx,
      false
    );
    System.assertEquals(1, publicMessages.size());

    List<HelpDeskMessage__c> allMessages = HelpDeskCaseService.getMessages(
      cs.Id,
      c.Id,
      ctx,
      true
    );
    System.assertEquals(2, allMessages.size());

    List<AttachmentLink__c> links = HelpDeskCaseService.getCaseAttachmentLinks(
      cs.Id,
      c.Id,
      ctx,
      true
    );
    System.assertNotEquals(null, links);
  }

  @IsTest
  static void shouldRejectAttachmentForMessageFromAnotherCase() {
    Account acc = new Account(Name = 'Enerzee Mensagem Cruzada');
    insert acc;

    Contact c = new Contact(
      LastName = 'Contato Mensagem Cruzada',
      Email = 'mensagem.cruzada@teste.com',
      AccountId = acc.Id
    );
    insert c;

    List<Case> cases = new List<Case>{
      new Case(
        Subject = 'Caso autorizado',
        Status = 'New',
        Origin = 'Phone',
        ContactId = c.Id,
        AccountId = acc.Id
      ),
      new Case(
        Subject = 'Caso de outra mensagem',
        Status = 'New',
        Origin = 'Phone',
        ContactId = c.Id,
        AccountId = acc.Id
      )
    };
    insert cases;

    HelpDeskMessage__c message = new HelpDeskMessage__c(
      Case__c = cases[1].Id,
      Body__c = 'Mensagem de outro caso',
      AuthorType__c = 'Cliente',
      IsPublic__c = true
    );
    insert message;

    HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
    ctx.userId = UserInfo.getUserId();
    ctx.contactId = c.Id;
    ctx.email = c.Email;

    Boolean rejected = false;
    try {
      HelpDeskCaseService.uploadMessageFileExternal(
        cases[0].Id,
        message.Id,
        'arquivo.txt',
        EncodingUtil.base64Encode(Blob.valueOf('conteudo')),
        c.Id,
        ctx
      );
    } catch (AuraHandledException expected) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'Deve rejeitar mensagem vinculada a outro caso');
  }

  @IsTest
  static void shouldUseContactApproverLabelsWhenCaseSnapshotIsMasked() {
    User approver = [
      SELECT Id, Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];

    Account acc = new Account(Name = 'Enerzee Aprovadores');
    insert acc;

    Contact c = new Contact(
      LastName = 'Contato Aprovadores',
      Email = 'aprovadores@teste.com',
      AccountId = acc.Id,
      Supervisor__c = approver.Id,
      Gerente__c = approver.Id
    );
    insert c;

    Case cs = new Case(
      Subject = 'Caso com snapshot mascarado',
      Status = 'New',
      Origin = 'Phone',
      ContactId = c.Id,
      AccountId = acc.Id,
      Supervisor__c = approver.Id,
      Gerente__c = approver.Id,
      SupervisorNome__c = 'Usuário123',
      GerenteNome__c = 'Usuário456',
      StatusAprovacao__c = 'Em Aprovação'
    );
    insert cs;

    HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
    ctx.userId = UserInfo.getUserId();
    ctx.contactId = c.Id;
    ctx.email = c.Email;

    HelpDeskCaseService.ApprovalStatusDTO dto = HelpDeskCaseService.getApprovalStatus(
      cs.Id,
      c.Id,
      ctx
    );

    System.assertEquals(approver.Name, dto.supervisorName);
    System.assertEquals(approver.Name, dto.gerenteName);
  }

  private class ExternalArchiveMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"data":"https://files.example.com/msg.png"}');
      return res;
    }
  }

  @IsTest
  static void shouldUploadMessageFileAndReturnAttachmentLinks() {
    Account acc = new Account(Name = 'Enerzee Anexos');
    insert acc;
    Contact c = new Contact(
      LastName = 'Contato Anexo',
      Email = 'anexo@teste.com',
      AccountId = acc.Id
    );
    insert c;
    Case cs = new Case(
      Subject = 'Caso anexo',
      Status = 'New',
      Origin = 'Phone',
      ContactId = c.Id,
      AccountId = acc.Id
    );
    insert cs;

    HelpDeskCaseService.UserContext ctx = new HelpDeskCaseService.UserContext();
    ctx.userId = UserInfo.getUserId();
    ctx.contactId = c.Id;
    ctx.email = c.Email;

    Id messageId = HelpDeskCaseService.addMessage(
      cs.Id,
      'Comentário com anexo',
      'Cliente',
      'Cliente',
      true,
      c.Id,
      ctx
    );

    Test.setMock(HttpCalloutMock.class, new ExternalArchiveMock());

    Test.startTest();
    Id linkId = HelpDeskCaseService.uploadMessageFileExternal(
      cs.Id,
      messageId,
      'foto.png',
      EncodingUtil.base64Encode(Blob.valueOf('imagem')),
      c.Id,
      ctx
    );
    Test.stopTest();

    System.assertNotEquals(null, linkId);
    AttachmentLink__c link = [
      SELECT SObjectId__c, SObjectType__c, AttachmentURL__c
      FROM AttachmentLink__c
      WHERE Id = :linkId
    ];
    System.assertEquals(String.valueOf(messageId), link.SObjectId__c);
    System.assertEquals('HelpDeskMessage__c', link.SObjectType__c);

    List<AttachmentLink__c> links = HelpDeskCaseService.getCaseAttachmentLinks(
      cs.Id,
      c.Id,
      ctx,
      false
    );
    System.assertEquals(1, links.size());
  }
}
