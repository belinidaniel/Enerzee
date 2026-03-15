/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
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

  private static void prepareRequest(String body) {
    RestRequest request = new RestRequest();
    request.httpMethod = 'POST';
    request.requestUri = '/services/apexrest/ProposalPendingResponse';
    if (body != null) {
      request.requestBody = Blob.valueOf(body);
    }
    RestContext.request = request;
    RestContext.response = new RestResponse();
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

    prepareRequest(
      '{"proposalId":"' +
        opp.IdVirtualOffice__c +
        '","pendingId":"' +
        pending.Id +
        '","response":"Nova foto enviada","urlArquivo":"https://teste.com/rg.pdf","status":2}'
    );

    ProposalPendingResponseRest.ResponseWrapper response = ProposalPendingResponseRest.handleResponse();

    ProposalPending__c refreshed = [
      SELECT Status__c, Response__c, FileUrl__c, RespondedDate__c
      FROM ProposalPending__c
      WHERE Id = :pending.Id
    ];

    System.assertEquals(true, response.success);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals('Nova foto enviada', refreshed.Response__c);
    System.assertEquals('https://teste.com/rg.pdf', refreshed.FileUrl__c);
    System.assertNotEquals(null, refreshed.RespondedDate__c);
  }

  @IsTest
  static void shouldReturnNotFound() {
    prepareRequest(
      '{"proposalId":"fake","pendingId":"a000000000000000000","response":"Teste"}'
    );

    ProposalPendingResponseRest.ResponseWrapper response = ProposalPendingResponseRest.handleResponse();

    System.assertEquals(false, response.success);
    System.assertEquals(404, RestContext.response.statusCode);
    System.assert(
      response.message.contains('Pendência não encontrada'),
      'Deve retornar mensagem amigável quando a pendência não existir.'
    );
  }

  @IsTest
  static void shouldValidateMissingBodyAndRequiredFields() {
    prepareRequest(null);
    ProposalPendingResponseRest.ResponseWrapper missingBodyResponse = ProposalPendingResponseRest.handleResponse();
    System.assertEquals(false, missingBodyResponse.success);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(
      missingBodyResponse.message.contains('Corpo da requisição'),
      'Corpo vazio deve ser rejeitado.'
    );

    prepareRequest('{"proposalId":"","pendingId":""}');
    ProposalPendingResponseRest.ResponseWrapper invalidPayloadResponse = ProposalPendingResponseRest.handleResponse();
    System.assertEquals(false, invalidPayloadResponse.success);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(
      invalidPayloadResponse.message.contains('proposalId'),
      'Campo obrigatório ausente deve retornar mensagem clara.'
    );
  }

  @IsTest
  static void shouldApplyDefaultStatusAndRejectUnsupportedCode() {
    Opportunity opp = createOpportunity();
    ProposalPending__c pending = new ProposalPending__c(
      Opportunity__c = opp.Id,
      Description__c = 'Documento complementar',
      DocumentTypeId__c = 1,
      DocumentTypeName__c = 'Comprovante',
      Status__c = 'Aguardando'
    );
    insert pending;

    prepareRequest(
      '{"proposalId":"' +
        opp.IdVirtualOffice__c +
        '","pendingId":"' +
        pending.Id +
        '","response":"Respondido sem status"}'
    );
    ProposalPendingResponseRest.ResponseWrapper defaultStatusResponse = ProposalPendingResponseRest.handleResponse();
    pending = [
      SELECT Status__c, Response__c
      FROM ProposalPending__c
      WHERE Id = :pending.Id
    ];
    System.assertEquals(true, defaultStatusResponse.success);
    System.assertEquals(
      ProposalPendingController.getStatusValue(
        ProposalPendingController.PendingStatus.Respondido
      ),
      pending.Status__c
    );

    prepareRequest(
      '{"proposalId":"' +
        opp.IdVirtualOffice__c +
        '","pendingId":"' +
        pending.Id +
        '","response":"Status inválido","status":999}'
    );
    ProposalPendingResponseRest.ResponseWrapper invalidStatusResponse = ProposalPendingResponseRest.handleResponse();
    System.assertEquals(false, invalidStatusResponse.success);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(
      true,
      String.isNotBlank(invalidStatusResponse.message),
      'Código inválido deve retornar uma mensagem de erro.'
    );
  }
}
