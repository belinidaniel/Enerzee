/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalApiClient {
  private static final String NAMED_CREDENTIAL = 'callout:Enerzee_Proposal_Api';
  private static final Integer TIMEOUT_MS = 120000;

  public class ApiResponse {
    public Blob fileBlob;
    public String fileName;
    public String mimeType;
    public String rawResponseBody;
  }

  public static ApiResponse convertProposal(
    ContentVersion templateVersion,
    String tagsJson,
    String sectionsJson
  ) {
    if (templateVersion == null || templateVersion.VersionData == null) {
      throw new AuraHandledException(
        'Template PPTX invalido para geracao da proposta.'
      );
    }

    Map<String, String> formFields = new Map<String, String>{
      'tags' => String.isBlank(tagsJson) ? '{}' : tagsJson,
      'sections_to_show' => String.isBlank(sectionsJson) ? '[]' : sectionsJson
    };
    Blob requestBody = ProposalMultipartFormBuilder.compose(
      formFields,
      'file',
      getFileName(templateVersion),
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      templateVersion.VersionData
    );

    HttpRequest request = new HttpRequest();
    request.setEndpoint(NAMED_CREDENTIAL + '/convertProposal');
    request.setMethod('POST');
    request.setTimeout(TIMEOUT_MS);
    request.setHeader(
      'Content-Type',
      ProposalMultipartFormBuilder.getContentType()
    );
    request.setHeader('Accept', 'application/json');
    request.setBodyAsBlob(requestBody);

    HttpResponse response = new Http().send(request);
    if (response == null) {
      throw new AuraHandledException(
        'A API de proposta nao retornou resposta.'
      );
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new AuraHandledException(
        'Falha ao gerar proposta na API. Status ' +
          response.getStatusCode() +
          ': ' +
          response.getBody()
      );
    }

    return parseResponse(response, templateVersion.Title);
  }

  private static ApiResponse parseResponse(
    HttpResponse response,
    String fallbackTitle
  ) {
    ApiResponse apiResponse = new ApiResponse();
    String contentType = response.getHeader('Content-Type');

    if (
      String.isNotBlank(contentType) &&
      contentType.toLowerCase().contains('application/pdf')
    ) {
      apiResponse.fileBlob = response.getBodyAsBlob();
      apiResponse.fileName = fallbackTitle + '.pdf';
      apiResponse.mimeType = 'application/pdf';
      return apiResponse;
    }

    apiResponse.rawResponseBody = response.getBody();
    if (String.isBlank(apiResponse.rawResponseBody)) {
      throw new AuraHandledException(
        'A API retornou sucesso, mas o corpo da resposta veio vazio.'
      );
    }

    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      apiResponse.rawResponseBody
    );
    String fileBase64 = getStringValue(body, 'fileBase64');
    if (String.isBlank(fileBase64)) {
      fileBase64 = getNestedStringValue(body, 'data', 'fileBase64');
    }

    if (String.isNotBlank(fileBase64)) {
      apiResponse.fileBlob = EncodingUtil.base64Decode(fileBase64);
      apiResponse.fileName = coalesce(
        getStringValue(body, 'fileName'),
        getNestedStringValue(body, 'data', 'fileName'),
        fallbackTitle + '.pdf'
      );
      apiResponse.mimeType = coalesce(
        getStringValue(body, 'mimeType'),
        getNestedStringValue(body, 'data', 'mimeType'),
        'application/pdf'
      );
      return apiResponse;
    }

    String urlFile = coalesce(
      getStringValue(body, 'urlFile'),
      getStringValue(body, 'fileUrl'),
      getNestedStringValue(body, 'data', 'urlFile'),
      getNestedStringValue(body, 'data', 'fileUrl')
    );
    if (String.isBlank(urlFile)) {
      throw new AuraHandledException(
        'A API nao retornou fileBase64 nem urlFile para a proposta.'
      );
    }

    HttpRequest downloadRequest = new HttpRequest();
    downloadRequest.setEndpoint(urlFile);
    downloadRequest.setMethod('GET');
    downloadRequest.setTimeout(TIMEOUT_MS);
    HttpResponse downloadResponse = new Http().send(downloadRequest);
    if (
      downloadResponse == null ||
      downloadResponse.getStatusCode() < 200 ||
      downloadResponse.getStatusCode() >= 300
    ) {
      throw new AuraHandledException(
        'Falha ao baixar o arquivo final da proposta.'
      );
    }

    apiResponse.fileBlob = downloadResponse.getBodyAsBlob();
    apiResponse.fileName = coalesce(
      getStringValue(body, 'fileName'),
      getNestedStringValue(body, 'data', 'fileName'),
      fallbackTitle + '.pdf'
    );
    apiResponse.mimeType = coalesce(
      downloadResponse.getHeader('Content-Type'),
      'application/pdf'
    );
    return apiResponse;
  }

  private static String getFileName(ContentVersion templateVersion) {
    if (String.isNotBlank(templateVersion.PathOnClient)) {
      return templateVersion.PathOnClient;
    }
    String extension = String.isNotBlank(templateVersion.FileExtension)
      ? '.' + templateVersion.FileExtension
      : '.pptx';
    return templateVersion.Title + extension;
  }

  private static String getStringValue(Map<String, Object> source, String key) {
    if (source == null || !source.containsKey(key) || source.get(key) == null) {
      return null;
    }
    return String.valueOf(source.get(key));
  }

  private static String getNestedStringValue(
    Map<String, Object> source,
    String parentKey,
    String childKey
  ) {
    if (source == null || !source.containsKey(parentKey)) {
      return null;
    }
    try {
      return getStringValue(
        (Map<String, Object>) source.get(parentKey),
        childKey
      );
    } catch (Exception e) {
      return null;
    }
  }

  private static String coalesce(String firstValue, String secondValue) {
    return String.isNotBlank(firstValue) ? firstValue : secondValue;
  }

  private static String coalesce(
    String firstValue,
    String secondValue,
    String thirdValue,
    String fourthValue
  ) {
    return String.isNotBlank(firstValue)
      ? firstValue
      : String.isNotBlank(secondValue)
          ? secondValue
          : String.isNotBlank(thirdValue) ? thirdValue : fourthValue;
  }

  private static String coalesce(
    String firstValue,
    String secondValue,
    String thirdValue
  ) {
    return String.isNotBlank(firstValue)
      ? firstValue
      : String.isNotBlank(secondValue) ? secondValue : thirdValue;
  }
}
