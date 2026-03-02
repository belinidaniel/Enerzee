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
}
