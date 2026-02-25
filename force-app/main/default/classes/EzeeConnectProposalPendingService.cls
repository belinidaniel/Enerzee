/**
 * Service responsável por orquestrar os callouts com o aplicativo do EzeeConnect para as pendências de proposta.
 */
public with sharing class EzeeConnectProposalPendingService {
  public class PendingRequest {
    public String ProposalId;
    public String Description;
    public Integer DocumentType;
    public Integer Status;
    public String PendingId;
  }

  public class PendingUpdateRequest {
    public Integer Status;
    public String PendingId;
    public String DescriptionRejected;
  }

  public class DocumentTypeOption {
    @AuraEnabled
    public Integer id;
    @AuraEnabled
    public String name;
  }

  public static Integer getStatusCode(String statusLabel) {
    ProposalPendingController.PendingStatus status = ProposalPendingController.parseStatus(
      statusLabel
    );
    return ProposalPendingController.getStatusCode(status);
  }

  public static String getStatusLabel(Integer code) {
    if (code == null) {
      return null;
    }
    ProposalPendingController.PendingStatus status = ProposalPendingController.getStatusByCode(
      code
    );
    return status != null ? status.name() : null;
  }

  public static List<DocumentTypeOption> getDocumentTypes() {
    HttpResponse response = executeCallout('TypesDocumentPending', null);
    ensureSuccess(response, 'Tipos de documento');

    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    List<Object> data = (List<Object>) body.get('data');

    List<DocumentTypeOption> options = new List<DocumentTypeOption>();

    if (data == null) {
      return options;
    }

    for (Object entry : data) {
      Map<String, Object> row = (Map<String, Object>) entry;
      DocumentTypeOption option = new DocumentTypeOption();
      option.id = Integer.valueOf(String.valueOf(row.get('id')));
      option.name = (String) row.get('name');
      options.add(option);
    }

    return options;
  }

  public static void sendPendingToApp(PendingRequest payload) {
    System.debug(
      'EzeeConnectProposalPendingService.sendPendingToApp payload: ' +
      JSON.serializePretty(payload)
    );
    HttpResponse response = executeCallout(
      'SetProposalPending',
      JSON.serialize(payload)
    );
    ensureSuccess(response, 'Envio de pendência');
  }

  public static void sendPendingBatchToApp(List<PendingRequest> payloads) {
    if (payloads == null || payloads.isEmpty()) {
      return;
    }
    System.debug(
      'EzeeConnectProposalPendingService.sendPendingBatchToApp payload: ' +
      JSON.serializePretty(payloads)
    );
    HttpResponse response = executeCallout(
      'SetProposalPending',
      JSON.serialize(payloads)
    );
    ensureSuccess(response, 'Envio de pendências');
  }

  public static void updatePendingInApp(PendingUpdateRequest payload) {
    System.debug(
      'EzeeConnectProposalPendingService.updatePendingInApp payload: ' +
      JSON.serializePretty(payload)
    );
    HttpResponse response = executeCallout(
      'UpdateProposalPending',
      JSON.serialize(payload)
    );
    ensureSuccess(response, 'Atualização de pendência');
  }

  private static HttpResponse executeCallout(
    String metadataDeveloperName,
    String body
  ) {
    Integrador__mdt metadata = [
      SELECT URL__c, Method__c, ContentType__c
      FROM Integrador__mdt
      WHERE DeveloperName = :metadataDeveloperName
      LIMIT 1
    ];

    HttpRequest request = new HttpRequest();
    request.setEndpoint(metadata.URL__c);

    String method = String.isBlank(metadata.Method__c)
      ? 'POST'
      : metadata.Method__c;
    request.setMethod(method);

    String contentType = String.isBlank(metadata.ContentType__c)
      ? 'application/json'
      : metadata.ContentType__c;
    request.setHeader('Content-Type', contentType);

    if (body != null) {
      request.setBody(body);
    }

    return IntegrationHubService.send(request);
  }

  private static void ensureSuccess(HttpResponse response, String context) {
    if (response == null) {
      throw new PendingIntegrationException(
        'Sem resposta da integração: ' + context
      );
    }

    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new PendingIntegrationException(
        context +
          ' falhou. Código ' +
          response.getStatusCode() +
          ' - ' +
          response.getBody()
      );
    }
  }

  public class PendingIntegrationException extends Exception {
  }
}
