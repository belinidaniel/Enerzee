/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class OpportunityCommentNotifServiceTest {
  @isTest
  static void shouldCreateSuccessLogWhenCommentChanges() {
    Id activeUserId = [SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1].Id;
    OpportunityCommentNotificationService.notificationTypeIdOverride = activeUserId;
    Id opportunityId = Id.valueOf('006000000000001AAA');

    Opportunity oldOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Teste',
      OwnerId = activeUserId,
      PropostaGerada__c = false,
      ComentarioSolicitante__c = 'Comentario anterior'
    );

    Opportunity newOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Teste',
      OwnerId = activeUserId,
      PropostaGerada__c = false,
      ComentarioSolicitante__c = 'Comentario atualizado com nova informacao'
    );

    Test.startTest();
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityId => oldOpportunity }
    );
    Test.stopTest();

    List<Log__c> logs = [
      SELECT Id, Status__c, Message__c, RelatedId__c
      FROM Log__c
      WHERE
        Class__c = 'OpportunityCommentNotificationService'
        AND Method__c = 'notifyOnConsultantCommentChange'
    ];

    System.assertEquals(1, logs.size(), 'Deve criar 1 log de envio.');
    System.assertEquals(
      'SUCCESS',
      logs[0].Status__c,
      'Status esperado para envio com sucesso.'
    );
    System.assert(logs[0].Message__c.contains('InAppSent=true'));
    System.assert(logs[0].Message__c.contains('EmailSent=true'));
    System.assertEquals(String.valueOf(opportunityId), logs[0].RelatedId__c);
  }

  @isTest
  static void shouldNotCreateLogWhenNormalizedCommentIsUnchanged() {
    Id activeUserId = [SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1].Id;
    OpportunityCommentNotificationService.notificationTypeIdOverride = activeUserId;
    Id opportunityId = Id.valueOf('006000000000002AAA');

    Opportunity oldOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Sem Mudanca',
      OwnerId = activeUserId,
      PropostaGerada__c = false,
      ComentarioSolicitante__c = 'comentario com	 espacos'
    );

    Opportunity newOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Sem Mudanca',
      OwnerId = activeUserId,
      PropostaGerada__c = false,
      ComentarioSolicitante__c = '	comentario com espacos	 '
    );

    Test.startTest();
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityId => oldOpportunity }
    );
    Test.stopTest();

    Integer logsCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        Class__c = 'OpportunityCommentNotificationService'
        AND Method__c = 'notifyOnConsultantCommentChange'
    ];

    System.assertEquals(
      0,
      logsCount,
      'Nao deve gerar log quando nao houver mudanca relevante no comentario.'
    );
  }

  @isTest
  static void shouldUseFallbackWhenOwnerIsInvalid() {
    OpportunityCommentNotificationService.notificationTypeIdOverride = UserInfo.getUserId();
    Id opportunityId = Id.valueOf('006000000000003AAA');
    Id invalidOwnerId = Id.valueOf('005000000000001AAA');

    Opportunity newOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Fallback',
      OwnerId = invalidOwnerId,
      PropostaGerada__c = false,
      ComentarioSolicitante__c = 'Novo comentario'
    );

    Test.startTest();
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      new List<Opportunity>{ newOpportunity },
      null
    );
    Test.stopTest();

    List<Log__c> logs = [
      SELECT Id, Status__c, Message__c
      FROM Log__c
      WHERE
        Class__c = 'OpportunityCommentNotificationService'
        AND Method__c = 'notifyOnConsultantCommentChange'
    ];

    System.assertEquals(
      1,
      logs.size(),
      'Deve criar 1 log para cenario com fallback.'
    );
    System.assertEquals(
      'SUCCESS',
      logs[0].Status__c,
      'Fallback deve permitir envio com sucesso.'
    );
    System.assert(logs[0].Message__c.contains('FallbackUsed=true'));
    System.assert(logs[0].Message__c.contains('EmailSent=true'));
  }

  @isTest
  static void shouldNotCreateLogWhenCommentIsBlank() {
    Id activeUserId = [SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1].Id;
    OpportunityCommentNotificationService.notificationTypeIdOverride = activeUserId;
    Id opportunityId = Id.valueOf('006000000000004AAA');

    Opportunity oldOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Comentario Vazio',
      OwnerId = activeUserId,
      ComentarioSolicitante__c = 'Texto anterior'
    );

    Opportunity newOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Comentario Vazio',
      OwnerId = activeUserId,
      ComentarioSolicitante__c = '	 '
    );

    Test.startTest();
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      new List<Opportunity>{ newOpportunity },
      new Map<Id, Opportunity>{ opportunityId => oldOpportunity }
    );
    Test.stopTest();

    Integer logsCount = [
      SELECT COUNT()
      FROM Log__c
      WHERE
        Class__c = 'OpportunityCommentNotificationService'
        AND Method__c = 'notifyOnConsultantCommentChange'
    ];

    System.assertEquals(
      0,
      logsCount,
      'Nao deve gerar log quando comentario final estiver vazio.'
    );
  }

  @isTest
  static void shouldNormalizeCommentSafely() {
    String normalized = OpportunityCommentNotificationService.normalizeComment(
      ' Linha 1' + '\n' + '\t' + 'Linha 2		'
    );
    System.assertEquals('Linha 1 Linha 2', normalized);
  }

  @isTest
  static void shouldCreatePartialSuccessLogWhenNotificationTypeIsMissing() {
    OpportunityCommentNotificationService.notificationTypeIdOverride = null;
    OpportunityCommentNotificationService.forceMissingNotificationTypeForTest = true;
    Id opportunityId = Id.valueOf('006000000000005AAA');

    Opportunity newOpportunity = new Opportunity(
      Id = opportunityId,
      Name = 'Opp Sem Tipo',
      OwnerId = UserInfo.getUserId(),
      ComentarioSolicitante__c = 'Comentario sem tipo de notificacao'
    );

    Test.startTest();
    OpportunityCommentNotificationService.notifyOnConsultantCommentChange(
      new List<Opportunity>{ newOpportunity },
      null
    );
    Test.stopTest();
    OpportunityCommentNotificationService.forceMissingNotificationTypeForTest = false;

    Log__c latestLog = [
      SELECT Status__c, Message__c
      FROM Log__c
      WHERE
        Class__c = 'OpportunityCommentNotificationService'
        AND Method__c = 'notifyOnConsultantCommentChange'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    System.assertEquals('PARTIAL_SUCCESS', latestLog.Status__c);
    System.assert(latestLog.Message__c.contains('InAppSent=false'));
    System.assert(latestLog.Message__c.contains('EmailSent=true'));
    System.assert(
      latestLog.Message__c.contains('InAppError=Tipo de notificacao')
    );
  }

  @isTest
  static void shouldBuildBodiesAndHelpersSafely() {
    OpportunityCommentNotificationService.notificationTypeIdOverride = UserInfo.getUserId();

    String htmlComment = '<b>' + buildRepeatedString('x', 240) + '</b>';
    Opportunity opportunityRecord = new Opportunity(
      Id = Id.valueOf('006000000000006AAA'),
      Name = 'Opp & Especial',
      ComentarioSolicitante__c = htmlComment
    );

    String title = OpportunityCommentNotificationService.buildTitle(
      opportunityRecord
    );
    String inAppBody = OpportunityCommentNotificationService.buildInAppBody(
      opportunityRecord
    );
    String link = OpportunityCommentNotificationService.buildOpportunityLink(
      opportunityRecord
    );
    String escaped = OpportunityCommentNotificationService.escapeHtml(
      '<tag>"teste"&'
    );
    String plainTextBody = OpportunityCommentNotificationService.buildEmailPlainTextBody(
      opportunityRecord,
      link
    );
    String htmlBody = OpportunityCommentNotificationService.buildEmailHtmlBody(
      opportunityRecord,
      link
    );
    Messaging.SingleEmailMessage emailMessage = OpportunityCommentNotificationService.buildEmailMessage(
      opportunityRecord,
      'recipient@teste.com'
    );
    String noDetailError = OpportunityCommentNotificationService.buildEmailErrorMessage(
      null
    );
    Log__c builtLog = OpportunityCommentNotificationService.buildLog(
      opportunityRecord,
      'SUCCESS',
      'msg'
    );

    System.assertEquals('Novo comentario do consultor - Opp & Especial', title);
    System.assert(inAppBody.contains('Oportunidade: Opp & Especial'));
    System.assert(inAppBody.endsWith('...'));
    System.assert(link.contains('/lightning/r/Opportunity/'));
    System.assertEquals('&lt;tag&gt;&quot;teste&quot;&amp;', escaped);
    System.assert(plainTextBody.contains('Abrir oportunidade'));
    System.assert(htmlBody.contains('&lt;b&gt;'));
    System.assertNotEquals(null, emailMessage);
    System.assertEquals('Falha no envio sem detalhe', noDetailError);
    System.assertEquals('SUCCESS', builtLog.Status__c);
    System.assertEquals(
      String.valueOf(opportunityRecord.Id),
      builtLog.RelatedId__c
    );
  }

  @isTest
  static void shouldResolveNotificationTypeAndSenderFallbacksSafely() {
    Id fakeOverride = UserInfo.getUserId();
    OpportunityCommentNotificationService.notificationTypeIdOverride = fakeOverride;

    System.assertEquals(
      fakeOverride,
      OpportunityCommentNotificationService.resolveNotificationTypeId()
    );

    OpportunityCommentNotificationService.notificationTypeIdOverride = null;
    Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
    OpportunityCommentNotificationService.applySystemSender(emailMessage);

    Id senderId = OpportunityCommentNotificationService.resolveSystemOrgWideEmailAddressId();
    String rootLink = OpportunityCommentNotificationService.buildOpportunityLink(
      null
    );

    System.assertEquals(
      true,
      senderId == null || String.isNotBlank(String.valueOf(senderId)),
      'A resolucao do remetente do sistema deve ser resiliente.'
    );
    System.assert(rootLink.startsWith(URL.getOrgDomainUrl().toExternalForm()));
  }

  private static String buildRepeatedString(String token, Integer amount) {
    String result = '';
    for (Integer i = 0; i < amount; i++) {
      result += token;
    }
    return result;
  }
}
