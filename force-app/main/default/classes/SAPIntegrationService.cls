/**
 * @description       : Camada centralizada de execução HTTP para integrações SAP. Elimina a duplicação do método chamadaIntegracao() que existia nas 9 classes de integração. Resolve endpoint URL e token em uma única query SOQL (evitando o anti-padrão SOQL-in-loop quando chamado antes de loops).
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPCoverageTest, SAPIntegrationServiceTest
 **/
public with sharing class SAPIntegrationService {
  public static final List<Integer> SUCCESS_CODES = new List<Integer>{
    200,
    201,
    204
  };

  private static final String AUTH_PREFIX = 'Bearer ';
  private static final String CONTENT_TYPE_JSON = 'application/json';
  private static final String HTTP_POST = 'POST';

  /**
   * @description Executa POST para um endpoint SAP resolvendo endpoint e token
   *              em uma única query (fix SOQL-in-loop).
   *              Use esta assinatura para chamadas FORA de loops.
   * @param body      JSON body serializado
   * @param endpointName  DeveloperName do Integrador__mdt (sem sufixo _QA — resolvido automaticamente)
   * @param pathSuffix    Caminho adicional após a URL base (ex: 'pedidocompra'). Null = sem sufixo.
   */
  public static HttpResponse post(
    String body,
    String endpointName,
    String pathSuffix
  ) {
    return post(body, resolveConfig(endpointName), pathSuffix);
  }

  /**
   * @description Overload sem pathSuffix para endpoints que usam apenas a URL base.
   */
  public static HttpResponse post(String body, String endpointName) {
    return post(body, endpointName, null);
  }

  /**
   * @description Executa POST usando uma EndpointConfig pré-resolvida.
   *              Use esta assinatura DENTRO de loops para evitar SOQL repetido:
   *
   *              EndpointConfig config = SAPIntegrationService.resolveConfig('EndpointName');
   *              for (SObject record : records) {
   *                  SAPIntegrationService.post(JSON.serialize(req), config, 'path');
   *              }
   *
   * @param body      JSON body serializado
   * @param config    Config pré-resolvida via resolveConfig()
   * @param pathSuffix Caminho adicional após a URL base. Null = sem sufixo.
   */
  public static HttpResponse post(
    String body,
    EndpointConfig config,
    String pathSuffix
  ) {
    String fullUrl =
      config.url + (String.isBlank(pathSuffix) ? '' : pathSuffix);
    System.debug('### SAP Integration - Endpoint: ' + fullUrl);
    System.debug('### SAP Integration - Token: ' + config.token);
    System.debug('### SAP Integration - Payload: ' + body);
    HttpRequest request = new HttpRequest();
    request.setEndpoint(fullUrl);
    request.setMethod(HTTP_POST);
    request.setHeader('Content-Type', CONTENT_TYPE_JSON);
    request.setHeader('Authorization', AUTH_PREFIX + config.token);
    request.setBody(body);
    return Utils.callIntegrationSAP(request);
  }

  /**
   * @description Verifica se um código HTTP é considerado sucesso pelo SAP.
   */
  public static Boolean isSuccess(Integer statusCode) {
    return SUCCESS_CODES.contains(statusCode);
  }

  /**
   * @description Resolve URL do endpoint e token em uma ÚNICA query SOQL.
   *              Chame este método UMA VEZ antes de loops que fazem múltiplos POSTs.
   * @param endpointName  DeveloperName do Integrador__mdt (sem sufixo _QA)
   */
  public static EndpointConfig resolveConfig(String endpointName) {
    String resolvedEndpoint = Utils.getSAPMetadataName(endpointName);
    String resolvedToken = Utils.getSAPMetadataName('TokenSAP');

    List<Integrador__mdt> records = [
      SELECT DeveloperName, URL__c, LastToken__c
      FROM Integrador__mdt
      WHERE DeveloperName IN (:resolvedEndpoint, :resolvedToken)
    ];

    EndpointConfig config = new EndpointConfig();
    for (Integrador__mdt mdt : records) {
      if (mdt.DeveloperName == resolvedEndpoint) {
        config.url = mdt.URL__c;
      } else if (mdt.DeveloperName == resolvedToken) {
        config.token = mdt.LastToken__c;
      }
    }
    System.debug(
      '### SAP resolveConfig - Endpoint MDT: ' +
        resolvedEndpoint +
        ' → ' +
        config.url
    );
    System.debug(
      '### SAP resolveConfig - Token MDT: ' +
        resolvedToken +
        ' → ' +
        config.token
    );
    return config;
  }

  /**
   * @description DTO com URL e token do endpoint SAP resolvidos.
   *              Pode ser reutilizado em múltiplas chamadas dentro de um @future.
   */
  public class EndpointConfig {
    public String url;
    public String token;
  }
}
