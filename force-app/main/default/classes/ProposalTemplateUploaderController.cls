/**
 * @description       : Controller do LWC proposalTemplateUploader. Recebe o arquivo PPTX em base64 do client,
 *                       faz o upload para a API de templates e salva a URL retornada no campo TemplateUrl__c do ProposalCover__c.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : NO_TESTS_MAPPED
 **/
public with sharing class ProposalTemplateUploaderController {
  private static final String INTEGRADOR_DEV_NAME = 'EnerzeeProposalApi';
  private static final String BOUNDARY = '----EnerzeeTemplateBoundary3xG7mN9kQp';
  private static final Integer TIMEOUT_MS = 120000;

  @AuraEnabled
  public static String uploadTemplate(
    Id recordId,
    String fileName,
    String base64Content,
    String env
  ) {
    if (
      recordId == null ||
      String.isBlank(fileName) ||
      String.isBlank(base64Content)
    ) {
      throw new AuraHandledException(
        'Parametros invalidos para upload do template.'
      );
    }

    String safeEnv = String.isBlank(env) ? 'uat' : env.toLowerCase();
    Blob fileBlob = EncodingUtil.base64Decode(base64Content);
    String baseUrl = loadBaseUrl();

    String templateUrl = doUpload(baseUrl, fileName, fileBlob, safeEnv);

    // Salva a URL retornada no ProposalCover__c
    update new ProposalCover__c(Id = recordId, TemplateUrl__c = templateUrl);

    return templateUrl;
  }

  private static String doUpload(
    String baseUrl,
    String fileName,
    Blob fileBlob,
    String env
  ) {
    String crlf = '\r\n';

    // Campo env (texto)
    String envField =
      '--' +
      BOUNDARY +
      crlf +
      'Content-Disposition: form-data; name="env"' +
      crlf +
      crlf +
      env +
      crlf;

    // Header do campo file
    String fileHeader =
      '--' +
      BOUNDARY +
      crlf +
      'Content-Disposition: form-data; name="file"; filename="' +
      fileName +
      '"' +
      crlf +
      'Content-Type: application/vnd.openxmlformats-officedocument.presentationml.presentation' +
      crlf +
      crlf;

    String footer = crlf + '--' + BOUNDARY + '--';

    // Concatena em base64 e decodifica para blob binário contíguo
    String prefixBase64 = EncodingUtil.base64Encode(
      Blob.valueOf(envField + fileHeader)
    );
    String fileBase64 = EncodingUtil.base64Encode(fileBlob);
    String footerBase64 = EncodingUtil.base64Encode(Blob.valueOf(footer));

    Blob requestBody = EncodingUtil.base64Decode(
      joinBase64(prefixBase64, fileBase64, footerBase64)
    );

    HttpRequest req = new HttpRequest();
    req.setEndpoint(baseUrl + '/templates');
    req.setMethod('POST');
    req.setTimeout(TIMEOUT_MS);
    req.setHeader('Content-Type', 'multipart/form-data; boundary=' + BOUNDARY);
    req.setBodyAsBlob(requestBody);

    HttpResponse res = new Http().send(req);

    System.debug(
      '[ProposalTemplateUploaderController] statusCode=' + res.getStatusCode()
    );
    System.debug('[ProposalTemplateUploaderController] body=' + res.getBody());

    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
      throw new AuraHandledException(
        'Falha ao enviar template. Status ' +
          res.getStatusCode() +
          ': ' +
          res.getBody()
      );
    }

    // Resposta esperada: { "url": "https://..." } ou { "filename": "...", "url": "..." }
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    String url = extractUrl(body, fileName, env, baseUrl);

    if (String.isBlank(url)) {
      throw new AuraHandledException(
        'API nao retornou URL do template. Resposta: ' + res.getBody()
      );
    }

    return url;
  }

  /**
   * Tenta extrair a URL do template da resposta da API.
   * Suporta: { "url": "..." }, { "templateUrl": "..." }, { "file": { "url": "..." } }
   * Se nao encontrar, monta a URL consultando GET /templates.
   */
  private static String extractUrl(
    Map<String, Object> body,
    String fileName,
    String env,
    String baseUrl
  ) {
    for (String key : new List<String>{ 'url', 'templateUrl', 'fileUrl' }) {
      if (body.containsKey(key) && body.get(key) != null) {
        return String.valueOf(body.get(key));
      }
    }
    // Tenta no nível aninhado
    for (String parentKey : new List<String>{ 'file', 'data', 'template' }) {
      if (
        body.containsKey(parentKey) &&
        body.get(parentKey) instanceof Map<String, Object>
      ) {
        Map<String, Object> nested = (Map<String, Object>) body.get(parentKey);
        for (String key : new List<String>{ 'url', 'templateUrl' }) {
          if (nested.containsKey(key) && nested.get(key) != null) {
            return String.valueOf(nested.get(key));
          }
        }
      }
    }
    // Fallback: busca na listagem GET /templates
    return fetchTemplateUrl(baseUrl, fileName, env);
  }

  private static String fetchTemplateUrl(
    String baseUrl,
    String fileName,
    String env
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(baseUrl + '/templates?env=' + env);
    req.setMethod('GET');
    req.setTimeout(30000);

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() != 200) {
      return null;
    }

    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    Object templatesObj = body.get('templates');
    if (!(templatesObj instanceof List<Object>)) {
      return null;
    }

    for (Object t : (List<Object>) templatesObj) {
      Map<String, Object> tMap = (Map<String, Object>) t;
      String name = tMap.containsKey('name')
        ? String.valueOf(tMap.get('name'))
        : '';
      if (name == fileName || name.endsWith(fileName)) {
        return tMap.containsKey('url') ? String.valueOf(tMap.get('url')) : null;
      }
    }
    return null;
  }

  /**
   * Concatena 3 segmentos base64 removendo padding intermediario e repadding no final.
   */
  private static String joinBase64(String a, String b, String c) {
    String combined =
      a.replace('=', '') +
      b.replace('=', '') +
      c.replace('=', '');
    Integer rem = Math.mod(combined.length(), 4);
    if (rem != 0) {
      combined = combined + (rem == 1 ? '===' : rem == 2 ? '==' : '=');
    }
    return combined;
  }

  private static String loadBaseUrl() {
    Integrador__mdt integrador = [
      SELECT URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :INTEGRADOR_DEV_NAME
      LIMIT 1
    ];
    // Remove o path /convertProposal se presente — usa apenas a base URL
    return integrador.URL__c.removeEnd('/convertProposal');
  }
}
