/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
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
    System.debug('Enviando kit para Nivello: ' + JSON.serialize(requestBody));

    try {
      HttpResponse response = chamadaIntegracao(
        JSON.serialize(requestBody),
        'updateInfosKit'
      );
      Utils.createLog(
        'IntegracaoNivelloContrato',
        'enviarKit ' + requestBody.Id,
        response
      );

      System.debug(
        '[enviarKit] status=' +
          response.getStatusCode() +
          ' | body=' +
          response.getBody()
      );

      //Sucesso
      if (response.getStatusCode() == 200) {
        KitResponseWrapper responseWrapper = (KitResponseWrapper) JSON.deserialize(
          response.getBody(),
          KitResponseWrapper.class
        );
        System.debug(
          '[enviarKit] parsed response=' + JSON.serialize(responseWrapper.data)
        );
        return responseWrapper.data;
      }
      //Erro
      else {
        return null;
      }
    } catch (Exception e) {
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

    System.debug('Chamada de integração Nivello: ' + endpointName);
    System.debug('Chamada de integração Nivello: ' + parametrosIntegracao);
    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c);
    System.debug('Endpoint: ' + request.getEndpoint());
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);
    System.debug('body: ' + request.getBody());

    return Utils.callIntegrationNivello(request);
  }

  public class EnviarKitRequest {
    public String Id;
    public Decimal PotenciaPicoSistema;
    public Decimal ConsumoDesejado;
    public Integer QtdModulos;
    public Integer StructureType;
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
