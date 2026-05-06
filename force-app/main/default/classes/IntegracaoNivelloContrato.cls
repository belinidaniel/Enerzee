/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoNivelloContratoCoverageTest, IntegracaoNivelloContratoTest
 **/
public without sharing class IntegracaoNivelloContrato {
  @future(callout=true)
  public static void enviarContrato(Set<Id> triggerIds) {
    List<Opportunity> opplist = [
      SELECT
        Id,
        IdVirtualOffice__c,
        LinkContrato__c,
        recordType.Name,
        Status__c,
        StageName,
        ValorTotalProposta__c
      FROM Opportunity
      WHERE Id IN :triggerIds
    ];

    Integer statusEnum;
    Integer substatusId;

    for (Opportunity opp : oppList) {
      statusEnum = StatusEnumMap.getStatusEnum(
        opp.recordType.Name,
        opp.StageName
      );
      substatusId = StatusEnumMap.getSubstatusEnum(statusEnum, opp.Status__c);

      GORecordsTO request = new GORecordsTO();
      request.IdSalesForce = opp.Id;
      request.Status = statusEnum;
      request.SubStatus = substatusId;
      request.ProposalType = StatusEnumMap.getProposalTypeEnum(
        opp.recordType.Name
      );
      request.url = opp.LinkContrato__c;
      request.Value = opp.ValorTotalProposta__c;

      System.debug(
        'Enviando contrato para Nivello: ' + JSON.serialize(request)
      );

      try {
        HttpResponse response = chamadaIntegracao(
          JSON.serialize(request),
          'ProposalStatus'
        );
        Utils.createLog(
          'IntegracaoNivelloContrato',
          'enviarContrato ' + opp.Id,
          response,
          opp.Id
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
          'IntegracaoNivelloContrato',
          'enviarContrato ' + opp.Id,
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

  public static EnviarKitResponse enviarKit(EnviarKitRequest requestBody) {
    System.debug(
      '[enviarKit] requestId=' +
        requestBody.Id +
        ' | request=' +
        JSON.serialize(requestBody)
    );

    try {
      HttpResponse response = chamadaIntegracao(
        JSON.serialize(requestBody),
        'updateInfosKit'
      );

      if (response == null) {
        System.debug(
          '[enviarKit] requestId=' +
            requestBody.Id +
            ' | response is null after chamadaIntegracao.'
        );
        return null;
      }

      Utils.createLog(
        'IntegracaoNivelloContrato',
        'enviarKit ' + requestBody.Id,
        response
      );

      Integer statusCode = response.getStatusCode();
      String status = response.getStatus();
      String responseBody = response.getBody();
      System.debug(
        '[enviarKit] requestId=' +
          requestBody.Id +
          ' | statusCode=' +
          statusCode +
          ' | status=' +
          status +
          ' | body=' +
          responseBody
      );

      if (statusCode != 200) {
        System.debug(
          '[enviarKit] requestId=' +
            requestBody.Id +
            ' | returning null because statusCode != 200.'
        );
        return null;
      }

      if (String.isBlank(responseBody)) {
        System.debug(
          '[enviarKit] requestId=' +
            requestBody.Id +
            ' | returning null because response body is blank.'
        );
        return null;
      }

      KitResponseWrapper responseWrapper = (KitResponseWrapper) JSON.deserialize(
        responseBody,
        KitResponseWrapper.class
      );

      if (responseWrapper == null) {
        System.debug(
          '[enviarKit] requestId=' +
            requestBody.Id +
            ' | returning null because responseWrapper is null.'
        );
        return null;
      }

      System.debug(
        '[enviarKit] requestId=' +
          requestBody.Id +
          ' | wrapperSuccess=' +
          responseWrapper.success +
          ' | wrapperData=' +
          JSON.serialize(responseWrapper.data)
      );

      if (responseWrapper.data == null) {
        System.debug(
          '[enviarKit] requestId=' +
            requestBody.Id +
            ' | returning null because wrapper.data is null.'
        );
        return null;
      }

      return responseWrapper.data;
    } catch (Exception e) {
      System.debug(
        '[enviarKit] requestId=' +
          requestBody.Id +
          ' | exceptionType=' +
          e.getTypeName() +
          ' | line=' +
          e.getLineNumber() +
          ' | message=' +
          e.getMessage() +
          ' | stack=' +
          e.getStackTraceString()
      );
      Utils.createLog(
        'IntegracaoNivelloContrato',
        'enviarKit ' + requestBody.Id,
        e
      );
      // You might want to handle the exception differently.
      return null;
    }
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String endpointName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :endpointName
    ];

    System.debug(
      '[chamadaIntegracao] endpointName=' +
        endpointName +
        ' | metadata=' +
        JSON.serialize(parametrosIntegracao)
    );
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);

    System.debug(
      '[chamadaIntegracao] endpointName=' +
        endpointName +
        ' | endpoint=' +
        request.getEndpoint() +
        ' | method=' +
        request.getMethod() +
        ' | body=' +
        request.getBody()
    );

    HttpResponse response = Utils.callIntegrationNivello(request);
    if (response == null) {
      System.debug(
        '[chamadaIntegracao] endpointName=' +
          endpointName +
          ' | response is null.'
      );
      return null;
    }

    System.debug(
      '[chamadaIntegracao] endpointName=' +
        endpointName +
        ' | responseStatusCode=' +
        response.getStatusCode() +
        ' | responseStatus=' +
        response.getStatus() +
        ' | responseBody=' +
        response.getBody()
    );

    return response;
  }

  public class EnviarKitRequest {
    public String Id;
    public Decimal PotenciaPicoSistema;
    public Decimal ConsumoDesejado;
    public Integer QtdModulos;
    public Integer StructureType;
    public Boolean IsRSD;
    public List<Product> listProducts;
  }

  public class Product {
    public String name;
    public Integer Qtd;
    public Decimal valueUnity;
    public String productFamily;
    public String externalId;
  }

  public class EnviarKitResponse {
    public Decimal Direct;
    public Decimal Pontos;
    public Decimal Rede;
    public Decimal Bdi;
    public Decimal AdditionalFixedCost;
    public Decimal Installation;
    public Decimal FinancialCostWeg;
  }

  public class KitResponseWrapper {
    public boolean success;
    public EnviarKitResponse data;
  }
}
