/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-18-2025
 * @last modified by	 : Daniel Belini
 **/
@IsTest
public class ProposalPendingResponseRestTest {
  private static Opportunity createOpportunity() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    OpportunityTriggerHandler.disableTrigger();
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = account.Id),
      true
    );
    OpportunityTriggerHandler.enableTrigger();
    return opp;
  }

  @IsTest
  static void shouldHandleCallback() {
    Opportunity opp = createOpportunity();
    ProposalPending__c pending = new ProposalPending__c();
    pending.Opportunity__c = opp.Id;
    pending.Description__c = 'Documento ilegível';
    pending.DocumentTypeId__c = 1;
    pending.DocumentTypeName__c = 'CPF';
    pending.Status__c = 'Aguardando';
    insert pending;

    RestRequest request = new RestRequest();
    request.httpMethod = 'POST';
    request.requestUri = '/services/apexrest/ProposalPendingResponse';
    request.requestBody = Blob.valueOf(
      '{"proposalId":"' +
        opp.IdVirtualOffice__c +
        '","pendingId":"' +
        pending.Id +
        '","response":"Nova foto enviada","urlArquivo":"https://teste.com/rg.pdf","status":2}'
    );

    RestContext.request = request;
    RestContext.response = new RestResponse();

    ProposalPendingResponseRest.ResponseWrapper response = ProposalPendingResponseRest.handleResponse();

    ProposalPending__c refreshed = [
      SELECT Status__c, Response__c, FileUrl__c, RespondedDate__c
      FROM ProposalPending__c
      WHERE Id = :pending.Id
    ];
  }

  @IsTest
  static void shouldReturnNotFound() {
    RestRequest request = new RestRequest();
    request.httpMethod = 'POST';
    request.requestUri = '/services/apexrest/ProposalPendingResponse';
    request.requestBody = Blob.valueOf(
      '{"proposalId":"fake","pendingId":"a000000000000000000","response":"Teste"}'
    );

    RestContext.request = request;
    RestContext.response = new RestResponse();

    ProposalPendingResponseRest.ResponseWrapper response = ProposalPendingResponseRest.handleResponse();
  }
}
