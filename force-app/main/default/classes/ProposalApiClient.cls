/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalApiClient {
  private static final String INTEGRADOR_DEV_NAME = 'EnerzeeProposalApi';
  private static final Integer TIMEOUT_MS = 120000;
  private static final String BOUNDARY = '----EnerzeeFormBoundary7MA4YWxkTrZu0gW';

  // URL publica do template no Azure Blob.
  // Temporaria: quando ProposalCover__c.Template__c estiver populado, usar esse campo.
  @TestVisible
  private static final String TEMPLATE_URL_OVERRIDE = 'https://gerenciadorblobhomolog.blob.core.windows.net/publicresources/proposal/proposal/Proposta_valores.pptx';

  @TestVisible
  private static String testIntegrationUrl;

  public class ApiResponse {
    public Blob fileBlob;
    public String fileName;
    public String mimeType;
  }

  /**
   * Envia templateUrl + tags + sections_to_show como multipart/form-data.
   * A API busca o .pptx pelo templateUrl internamente — o Apex nao transmite o arquivo,
   * eliminando o problema de heap com arquivos grandes.
   */
  public static ApiResponse convertProposal(
    ContentVersion templateVersion,
    String tagsJson,
    String sectionsJson
  ) {
    return convertProposal(templateVersion, tagsJson, sectionsJson, null);
  }

  public static ApiResponse convertProposal(
    ContentVersion templateVersion,
    String tagsJson,
    String sectionsJson,
    ProposalCover__c cover
  ) {
    return convertProposal(
      templateVersion,
      tagsJson,
      sectionsJson,
      cover,
      null
    );
  }

  public static ApiResponse convertProposal(
    ContentVersion templateVersion,
    String tagsJson,
    String sectionsJson,
    ProposalCover__c cover,
    String layoutBase64
  ) {
    String tagsResolved = (String.isBlank(tagsJson) || tagsJson == 'null')
      ? '{}'
      : tagsJson;
    String sectionsResolved = (String.isBlank(sectionsJson) ||
      sectionsJson == 'null')
      ? '[]'
      : sectionsJson;
    String title = templateVersion != null ? templateVersion.Title : 'Proposta';
    String integrationUrl = loadIntegrationUrl();

    String templateUrl = (cover != null &&
      String.isNotBlank(cover.TemplateUrl__c))
      ? cover.TemplateUrl__c
      : TEMPLATE_URL_OVERRIDE;

    // Monta multipart/form-data com campos de texto apenas (sem arquivo)
    String crlf = '\r\n';
    String body =
      '--' +
      BOUNDARY +
      crlf +
      'Content-Disposition: form-data; name="templateUrl"' +
      crlf +
      crlf +
      templateUrl +
      crlf +
      '--' +
      BOUNDARY +
      crlf +
      'Content-Disposition: form-data; name="tags"' +
      crlf +
      crlf +
      tagsResolved +
      crlf +
      '--' +
      BOUNDARY +
      crlf +
      'Content-Disposition: form-data; name="sections_to_show"' +
      crlf +
      crlf +
      sectionsResolved +
      crlf;

    if (String.isNotBlank(layoutBase64)) {
      body +=
        '--' +
        BOUNDARY +
        crlf +
        'Content-Disposition: form-data; name="layout"' +
        crlf +
        crlf +
        layoutBase64 +
        crlf;
    }

    body += '--' + BOUNDARY + '--';

    System.debug('[ProposalApiClient] endpoint=' + integrationUrl);
    System.debug('[ProposalApiClient] templateUrl=' + templateUrl);
    System.debug(
      '[ProposalApiClient] tags (primeiros 500)=' + tagsResolved.left(500)
    );
    System.debug('[ProposalApiClient] sections_to_show=' + sectionsResolved);

    HttpRequest request = new HttpRequest();
    request.setEndpoint(integrationUrl);
    request.setMethod('POST');
    request.setTimeout(TIMEOUT_MS);
    request.setHeader(
      'Content-Type',
      'multipart/form-data; boundary=' + BOUNDARY
    );
    request.setBodyAsBlob(Blob.valueOf(body));

    HttpResponse response = new Http().send(request);

    System.debug('[ProposalApiClient] statusCode=' + response.getStatusCode());

    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      String errorBody = response.getBody();
      System.debug('[ProposalApiClient] ERROR body=' + errorBody);
      throw new ProposalGenerationService.ProposalGenerationException(
        'Falha ao gerar proposta na API. Status ' +
          response.getStatusCode() +
          ': ' +
          errorBody
      );
    }

    return parseResponse(response, title);
  }

  private static ApiResponse parseResponse(
    HttpResponse response,
    String fallbackTitle
  ) {
    ApiResponse apiResponse = new ApiResponse();
    String contentType = response.getHeader('Content-Type');

    System.debug(
      '[ProposalApiClient.parseResponse] Content-Type=' + contentType
    );

    if (
      String.isNotBlank(contentType) &&
      contentType.toLowerCase().contains('application/json')
    ) {
      Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );

      // Resposta com fileBase64 inline
      String fileBase64 = (String) json.get('fileBase64');
      if (String.isNotBlank(fileBase64)) {
        apiResponse.fileBlob = EncodingUtil.base64Decode(fileBase64);
        apiResponse.fileName = json.containsKey('fileName') &&
          json.get('fileName') != null
          ? (String) json.get('fileName')
          : fallbackTitle + '.pdf';
        apiResponse.mimeType = json.containsKey('mimeType') &&
          json.get('mimeType') != null
          ? (String) json.get('mimeType')
          : 'application/pdf';
        return apiResponse;
      }

      // Resposta com urlFile para download
      String urlFile = (String) json.get('urlFile');
      if (String.isBlank(urlFile) && json.containsKey('data')) {
        Map<String, Object> dataObj = (Map<String, Object>) json.get('data');
        if (dataObj != null) {
          urlFile = (String) dataObj.get('urlFile');
        }
      }
      if (String.isNotBlank(urlFile)) {
        HttpRequest downloadReq = new HttpRequest();
        downloadReq.setEndpoint(urlFile);
        downloadReq.setMethod('GET');
        downloadReq.setTimeout(TIMEOUT_MS);
        HttpResponse downloadRes = new Http().send(downloadReq);
        apiResponse.fileBlob = downloadRes.getBodyAsBlob();
        apiResponse.fileName = fallbackTitle + '.pdf';
        apiResponse.mimeType = 'application/pdf';
        return apiResponse;
      }
    }

    // Fallback: resposta binária direta (PDF cru)
    apiResponse.fileBlob = response.getBodyAsBlob();
    apiResponse.fileName = fallbackTitle + '.pdf';
    apiResponse.mimeType = 'application/pdf';
    System.debug(
      '[ProposalApiClient.parseResponse] bodySize=' +
      apiResponse.fileBlob.size()
    );
    return apiResponse;
  }

  private static String loadIntegrationUrl() {
    if (testIntegrationUrl != null) {
      return testIntegrationUrl;
    }
    Integrador__mdt integrador = [
      SELECT URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :INTEGRADOR_DEV_NAME
      LIMIT 1
    ];
    return integrador.URL__c;
  }
}
