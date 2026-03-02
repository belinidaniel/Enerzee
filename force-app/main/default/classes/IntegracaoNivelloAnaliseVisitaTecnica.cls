public class IntegracaoNivelloAnaliseVisitaTecnica {
  @future(callout=true)
  public static void sendTechnicalVisitAnalysis(Set<Id> triggerIds) {
    List<Opportunity> oppList = [
      SELECT
        Id,
        IdVirtualOffice__c,
        StatusViabilidade__c,
        TextoEstudo__c,
        TextoMotivo__c
      FROM Opportunity
      WHERE Id IN :triggerIds
    ];

    for (Opportunity opp : oppList) {
      TechnicalVisitAnalysisRequest corpoRequisicao = new TechnicalVisitAnalysisRequest();
      corpoRequisicao.id = opp.IdVirtualOffice__c;
      corpoRequisicao.status = opp.StatusViabilidade__c.equalsIgnoreCase(
          'Viável'
        )
        ? 'Viavel'
        : opp.StatusViabilidade__c.equalsIgnoreCase('Inviável')
            ? 'Inviavel'
            : opp.StatusViabilidade__c.equalsIgnoreCase('Parcialmente Viável')
                ? 'ParcialmenteInviavel'
                : '';

      corpoRequisicao.study = corpoRequisicao.status.equalsIgnoreCase(
          'ParcialmenteInviavel'
        )
        ? opp.TextoEstudo__c
        : null;
      corpoRequisicao.reason = corpoRequisicao.status.equalsIgnoreCase(
          'Inviavel'
        )
        ? opp.TextoMotivo__c
        : null;

      try {
        HttpResponse response = chamadaIntegracao(
          JSON.serialize(corpoRequisicao),
          'AnaliseVisitaTecnica',
          opp.Id,
          'sendTechnicalVisitAnalysis'
        );

        //Sucesso
        if (response.getStatusCode() == 200) {
          System.debug('SUCCESS');
          opp.SucessoIntegracaoNivello__c = true;
        }
        //Erro
        else {
          System.debug('ERROR');
          opp.SucessoIntegracaoNivello__c = false;
        }
        opp.StatusBodyIntegracaoNivello__c =
          response.getStatusCode() +
          ' ' +
          response.getBody();
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoNivelloAnaliseVisitaTecnica',
          'sendTechnicalVisitAnalysis',
          e,
          opp.Id
        );

        opp.SucessoIntegracaoNivello__c = false;
        opp.StatusBodyIntegracaoNivello__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }
    OpportunityTriggerHandler.disableTrigger();
    update oppList;
    OpportunityTriggerHandler.enableTrigger();
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String metadataDeveloperName,
    Id relatedId,
    String logMethodName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :metadataDeveloperName
    ];

    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c);
    request.setMethod('PUT');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);

    HttpResponse response = Utils.callIntegrationNivello(request);

    Utils.LogDTO logDTO = new Utils.LogDTO();
    logDTO.className = 'IntegracaoNivelloAnaliseVisitaTecnica';
    logDTO.methodName = logMethodName;
    logDTO.relatedId = relatedId;
    logDTO.httpMethod = request.getMethod();
    logDTO.requestBody = body;
    logDTO.requestURI = parametrosIntegracao.URL__c;
    if (response != null) {
      logDTO.statusCode = response.getStatusCode();
      logDTO.status = response.getStatus();
      logDTO.responseBody = response.getBody();
    }
    Utils.createLog(logDTO);

    return response;
  }

  public class TechnicalVisitAnalysisRequest {
    public String id;
    public String status;
    public String study;
    public String reason;
  }
}
