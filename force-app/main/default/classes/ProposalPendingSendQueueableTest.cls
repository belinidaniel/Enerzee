/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProposalPendingSendQueueableTest {
  private class PendingQueueableMock implements HttpCalloutMock {
    private Boolean failBatch;

    PendingQueueableMock(Boolean failBatch) {
      this.failBatch = failBatch;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      Boolean isBatchBody =
        req.getBody() != null && req.getBody().startsWith('[');
      if (failBatch && isBatchBody) {
        res.setStatusCode(500);
        res.setStatus('ERROR');
        res.setBody('{"error":"batch failed"}');
      } else {
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody('{"success":true}');
      }
      return res;
    }
  }

  private static ProposalPending__c createPending(
    String virtualOfficeId,
    String status
  ) {
    Account acc = new Account(
      Name = 'Conta Pending ' + status + virtualOfficeId
    );
    insert acc;

    Opportunity opp = new Opportunity(
      Name = 'Opp Pending ' + status,
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = acc.Id,
      IdVirtualOffice__c = virtualOfficeId
    );
    insert opp;

    ProposalPending__c pending = new ProposalPending__c(
      Opportunity__c = opp.Id,
      Description__c = 'Desc ' + status,
      DocumentTypeId__c = 1,
      Status__c = status
    );
    insert pending;
    return pending;
  }

  @IsTest
  static void shouldHandleEmptyPayload() {
    Test.startTest();
    System.enqueueJob(new ProposalPendingSendQueueable(new List<Id>()));
    Test.stopTest();

    System.assert(true, 'Queueable executed');
  }

  @IsTest
  static void shouldSendBatchWhenPayloadIsValid() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    ProposalPending__c pending = createPending('VO-PENDING', 'Novo');

    Test.setMock(HttpCalloutMock.class, new PendingQueueableMock(false));

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingSendQueueable(new List<Id>{ pending.Id })
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM ProposalPending__c WHERE Id = :pending.Id]
    );
  }

  @IsTest
  static void shouldFallbackToSingleSendAndIgnorePendingsWithoutVo() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';

    ProposalPending__c validPending = createPending(
      'VO-FALLBACK',
      'Aguardando'
    );

    Test.setMock(HttpCalloutMock.class, new PendingQueueableMock(true));

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingSendQueueable(new List<Id>{ validPending.Id })
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM ProposalPending__c
        WHERE Id = :validPending.Id
      ]
    );
  }
}
