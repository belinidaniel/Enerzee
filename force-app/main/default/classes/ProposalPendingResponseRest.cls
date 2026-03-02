@RestResource(urlMapping='/ProposalPendingResponse/*')
global with sharing class ProposalPendingResponseRest {
  @HttpPost
  global static ResponseWrapper handleResponse() {
    RestRequest request = RestContext.request;
    ResponseWrapper responseWrapper = new ResponseWrapper();

    try {
      if (request == null || request.requestBody == null) {
        throw new PendingApiException('Corpo da requisição não encontrado.');
      }

      ResponsePayload payload = (ResponsePayload) JSON.deserialize(
        request.requestBody.toString(),
        ResponsePayload.class
      );
      validatePayload(payload);

      ProposalPending__c pending = [
        SELECT
          Id,
          Name,
          Status__c,
          Description__c,
          Opportunity__c,
          Opportunity__r.OwnerId,
          Opportunity__r.IdVirtualOffice__c
        FROM ProposalPending__c
        WHERE
          Id = :payload.PendingId
          AND Opportunity__r.IdVirtualOffice__c = :payload.ProposalId
        LIMIT 1
      ];

      pending.Response__c = payload.Response;
      pending.FileUrl__c = payload.UrlArquivo;
      pending.RespondedDate__c = System.now();
      if (payload.Status != null) {
        ProposalPendingController.PendingStatus statusEnum = ProposalPendingController.getStatusByCode(
          payload.Status
        );
        pending.Status__c = ProposalPendingController.getStatusValue(
          statusEnum
        );
      } else {
        pending.Status__c = ProposalPendingController.getStatusValue(
          ProposalPendingController.PendingStatus.Respondido
        );
      }

      update pending;

      linkAttachmentToOpportunity(pending, payload);
      notifyOwner(pending);

      responseWrapper.success = true;
      responseWrapper.message = 'Pendência atualizada com sucesso.';
      RestContext.response.statusCode = 200;
    } catch (QueryException qe) {
      RestContext.response.statusCode = 404;
      responseWrapper.success = false;
      responseWrapper.message = 'Pendência não encontrada para a proposta informada.';
      Utils.createLog(
        'ProposalPendingResponseRest',
        'handleResponse - not found',
        qe.getMessage()
      );
    } catch (PendingApiException pae) {
      RestContext.response.statusCode = 400;
      responseWrapper.success = false;
      responseWrapper.message = pae.getMessage();
      Utils.createLog(
        'ProposalPendingResponseRest',
        'handleResponse - validation',
        pae.getMessage()
      );
    } catch (AuraHandledException ahe) {
      RestContext.response.statusCode = 400;
      responseWrapper.success = false;
      responseWrapper.message = ahe.getMessage();
      Utils.createLog(
        'ProposalPendingResponseRest',
        'handleResponse - business',
        ahe.getMessage()
      );
    } catch (Exception e) {
      RestContext.response.statusCode = 500;
      responseWrapper.success = false;
      responseWrapper.message = 'Erro interno ao atualizar a pendência.';
      Utils.createLog(
        'ProposalPendingResponseRest',
        'handleResponse - exception',
        e
      );
    }

    return responseWrapper;
  }

  private static void validatePayload(ResponsePayload payload) {
    if (payload == null) {
      throw new PendingApiException('JSON inválido.');
    }

    if (String.isBlank(payload.ProposalId)) {
      throw new PendingApiException('O campo proposalId é obrigatório.');
    }

    if (String.isBlank(payload.PendingId)) {
      throw new PendingApiException('O campo pendingId é obrigatório.');
    }
  }

  private static void linkAttachmentToOpportunity(
    ProposalPending__c pending,
    ResponsePayload payload
  ) {
    if (
      pending == null ||
      pending.Opportunity__c == null ||
      String.isBlank(payload.UrlArquivo)
    ) {
      return;
    }

    try {
      OpportunityAttachmentLinkService.AttachmentInput input = new OpportunityAttachmentLinkService.AttachmentInput();
      input.opportunityId = pending.Opportunity__c;
      input.attachmentUrl = payload.UrlArquivo;
      input.externalId = pending.Id;
      input.type = 'Other';
      if (String.isNotBlank(pending.Description__c)) {
        input.description = pending.Description__c;
      } else if (String.isNotBlank(payload.Description)) {
        input.description = payload.Description;
      } else {
        input.description = pending.Name;
      }
      OpportunityAttachmentLinkService.upsertAttachment(input);
    } catch (Exception e) {
      Utils.createLog(
        'ProposalPendingResponseRest',
        'linkAttachmentToOpportunity ' + pending.Id,
        e
      );
    }
  }

  private static void notifyOwner(ProposalPending__c pending) {
    if (
      pending.Opportunity__r == null ||
      String.isBlank(String.valueOf(pending.Opportunity__r.OwnerId))
    ) {
      return;
    }

    try {
      String message =
        'A pendência ' +
        pending.Name +
        ' foi respondida pelo aplicativo.';
      Utils.notificacaoPersonalizada(
        message,
        'Pendência respondida',
        pending.Opportunity__r.OwnerId,
        pending.Opportunity__c
      );
    } catch (Exception e) {
      Utils.createLog('ProposalPendingResponseRest', 'notifyOwner', e);
    }
  }

  global class ResponsePayload {
    public String ProposalId { get; set; }
    public String Description { get; set; }
    public Integer DocumentType { get; set; }
    public Integer Status { get; set; }
    public String PendingId { get; set; }
    public String Response { get; set; }
    public String UrlArquivo { get; set; }
  }

  global class ResponseWrapper {
    public Boolean success { get; set; }
    public String message { get; set; }
  }

  public class PendingApiException extends Exception {
  }
}
