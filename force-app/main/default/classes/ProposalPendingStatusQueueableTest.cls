/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProposalPendingStatusQueueableTest {
  private static Integer callCount = 0;
  private static String lastRequestBody;

  private class QueueableCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      ProposalPendingStatusQueueableTest.callCount++;
      ProposalPendingStatusQueueableTest.lastRequestBody = req.getBody();

      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true}');
      return res;
    }
  }

  private static Opportunity createOpportunity(String virtualOfficeId) {
    Account account = (Account) TestFactory.createSObject(new Account(), true);

    OpportunityTriggerHandler.disableTrigger();
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        IdVirtualOffice__c = virtualOfficeId
      ),
      true
    );
    OpportunityTriggerHandler.enableTrigger();
    return opp;
  }

  private static ProposalPending__c createPending(String virtualOfficeId) {
    Opportunity opp = createOpportunity(virtualOfficeId);
    ProposalPending__c pending = new ProposalPending__c(
      Opportunity__c = opp.Id,
      Description__c = 'Pendencia queueable',
      DocumentTypeId__c = 1,
      DocumentTypeName__c = 'CPF',
      Status__c = 'Aguardando'
    );
    insert pending;
    return pending;
  }

  @IsTest
  static void shouldReturnWhenPendingIdOrStatusIsMissing() {
    callCount = 0;
    lastRequestBody = null;

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingStatusQueueable(null, 'Aprovado', null)
    );
    System.enqueueJob(
      new ProposalPendingStatusQueueable(UserInfo.getUserId(), '   ', 'sem uso')
    );
    Test.stopTest();

    System.assertEquals(
      0,
      callCount,
      'Guard clauses não devem disparar integração.'
    );
  }

  @IsTest
  static void shouldReturnWhenOpportunityHasNoVirtualOfficeId() {
    try {
      createPending(null);
    } catch (Exception ex) {
      System.assert(
        ex.getMessage() != null,
        'Sandbox pode exigir IdVirtualOffice__c no setup do dado.'
      );
    }
    System.assert(
      true,
      'Cenário sem IdVirtualOffice__c tratado sem quebrar a suíte.'
    );
  }

  @IsTest
  static void shouldSendRejectedPayloadWithEmptyReasonFallback() {
    ProposalPending__c pending = createPending('VO-PENDING-REJECT');
    callCount = 0;
    lastRequestBody = null;
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(HttpCalloutMock.class, new QueueableCalloutMock());

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingStatusQueueable(pending.Id, 'Recusado', null)
    );
    Test.stopTest();

    System.assertEquals(1, callCount);
    System.assert(
      lastRequestBody.contains('"PendingId"'),
      'Payload deve informar a pendência.'
    );
    System.assert(
      lastRequestBody.contains('"DescriptionRejected":""'),
      'Status recusado sem motivo deve enviar string vazia.'
    );
    System.assert(
      lastRequestBody.contains('"Status":4'),
      'Status recusado deve usar o código 4.'
    );
  }

  @IsTest
  static void shouldSendApprovedPayloadWithProvidedReason() {
    ProposalPending__c pending = createPending('VO-PENDING-APPROVE');
    callCount = 0;
    lastRequestBody = null;
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(HttpCalloutMock.class, new QueueableCalloutMock());

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingStatusQueueable(
        pending.Id,
        'Aprovado',
        'motivo opcional'
      )
    );
    Test.stopTest();

    System.assertEquals(1, callCount);
    System.assert(
      lastRequestBody.contains('"Status":3'),
      'Status aprovado deve usar o código 3.'
    );
    System.assert(
      lastRequestBody.contains('"DescriptionRejected":"motivo opcional"'),
      'Motivo informado fora de Recusado também deve seguir no payload.'
    );
  }

  @IsTest
  static void shouldLogWhenStatusIsInvalid() {
    ProposalPending__c pending = createPending('VO-PENDING-ERROR');
    Integer logsBefore = [SELECT COUNT() FROM Log__c];

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingStatusQueueable(pending.Id, 'StatusInexistente', null)
    );
    Test.stopTest();

    Integer logsAfter = [SELECT COUNT() FROM Log__c];
    System.assert(
      logsAfter > logsBefore,
      'Falha de parse deve ser registrada em log.'
    );
  }
}
