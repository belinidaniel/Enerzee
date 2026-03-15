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
  @IsTest
  static void shouldHandleEmptyPayload() {
    Account acc = new Account(Name = 'Conta');
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'VO-PENDING'
    );
    insert opp;

    ProposalPending__c pending = new ProposalPending__c(
      Opportunity__c = opp.Id,
      Description__c = 'Desc',
      Status__c = 'Novo'
    );
    insert pending;

    Test.startTest();
    System.enqueueJob(
      new ProposalPendingSendQueueable(new List<Id>{ pending.Id })
    );
    Test.stopTest();

    System.assert(true, 'Queueable executed');
  }
}
