/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class APIOpcoesCondicaoPagamentoCoverageTest {
  private class MetadataUpdateMock implements WebServiceMock {
    private final Boolean shouldSucceed;

    MetadataUpdateMock(Boolean shouldSucceed) {
      this.shouldSucceed = shouldSucceed;
    }

    public void doInvoke(
      Object stub,
      Object request,
      Map<String, Object> response,
      String endpoint,
      String soapAction,
      String requestName,
      String responseNS,
      String responseName,
      String responseType
    ) {
      if (!(request instanceof MetadataService.updateMetadata_element)) {
        return;
      }

      MetadataService.updateMetadataResponse_element result = new MetadataService.updateMetadataResponse_element();
      MetadataService.SaveResult saveResult = new MetadataService.SaveResult();
      saveResult.fullName = 'Opportunity.CondicaoPagamento2__c';
      saveResult.success = shouldSucceed;

      if (!shouldSucceed) {
        MetadataService.Error errorItem = new MetadataService.Error();
        errorItem.message = 'Falha simulada';
        errorItem.statusCode = 'ERROR';
        saveResult.errors = new List<MetadataService.Error>{ errorItem };
      }

      result.result = new List<MetadataService.SaveResult>{ saveResult };
      response.put('response_x', result);
    }
  }

  private class RecordTypeToolingMock implements HttpCalloutMock {
    private final Integer getStatusCode;
    private final Integer patchStatusCode;

    RecordTypeToolingMock(Integer getStatusCode, Integer patchStatusCode) {
      this.getStatusCode = getStatusCode;
      this.patchStatusCode = patchStatusCode;
    }

    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');

      if (request.getMethod() == 'GET') {
        response.setStatusCode(getStatusCode);
        response.setBody(JSON.serialize(buildRecordTypeMetadataBody()));
        return response;
      }

      response.setStatusCode(patchStatusCode);
      response.setBody('{}');
      return response;
    }
  }

  @IsTest
  static void testValidationAndMergeHelpers() {
    APIOpcoesCondicaoPagamento.RespostaWrapper response = new APIOpcoesCondicaoPagamento.RespostaWrapper();
    response.success = true;

    APIOpcoesCondicaoPagamento.RespostaWrapper overLimit = APIOpcoesCondicaoPagamento.validarRequisicao(
      response,
      1000,
      buildRequestOptions(1)
    );
    System.assertEquals(false, overLimit.success);
    System.assertEquals(
      'LIMITE_OPCOES_ATINGIDO',
      overLimit.errors[0].errorCode
    );

    APIOpcoesCondicaoPagamento.RespostaWrapper invalidOption = APIOpcoesCondicaoPagamento.validarRequisicao(
      response,
      0,
      buildRequestOptionsWithNullValue()
    );
    System.assertEquals(false, invalidOption.success);
    System.assertEquals('OPCAO_INVALIDA', invalidOption.errors[0].errorCode);

    APIOpcoesCondicaoPagamento.RespostaWrapper duplicatedOption = APIOpcoesCondicaoPagamento.validarRequisicao(
      response,
      0,
      buildDuplicatedRequestOptions()
    );
    System.assertEquals(false, duplicatedOption.success);
    System.assertEquals(
      'OPCAO_DUPLICADA',
      duplicatedOption.errors[0].errorCode
    );

    List<APIOpcoesCondicaoPagamento.ValueCustomField> merged = APIOpcoesCondicaoPagamento.montarListaFinalDeValores(
      buildExistingOptions(),
      buildRequestOptions(2)
    );
    System.assertEquals(3, merged.size());
    System.assertEquals('NOVA_OPCAO_1', merged[2].valueName);
  }

  @IsTest
  static void testRecordTypeMetadataHelpers() {
    APIOpcoesCondicaoPagamento.MetadadosReqCustomField customFieldMetadata = buildCustomFieldMetadata();
    HttpResponse readResponse = new HttpResponse();
    readResponse.setStatusCode(200);
    readResponse.setBody(JSON.serialize(buildRecordTypeMetadataBody()));

    Test.setMock(HttpCalloutMock.class, new RecordTypeToolingMock(200, 204));
    Test.startTest();
    HttpResponse patchResponse = APIOpcoesCondicaoPagamento.atualizarMetadadosTipoReg(
      readResponse,
      customFieldMetadata,
      'https://example.com/tooling/sobjects/RecordType/012000000000000AAA'
    );
    APIOpcoesCondicaoPagamento.MetadadosReqRecType merged = APIOpcoesCondicaoPagamento.montarReqTipoReg(
      customFieldMetadata,
      buildRecordTypeMetadataBody()
    );
    Boolean success = APIOpcoesCondicaoPagamento.gerenciarOpcoesTipoRegistro(
      'ContratoMini',
      customFieldMetadata
    );
    Test.stopTest();

    System.assertEquals(204, patchResponse.getStatusCode());
    System.assertEquals(2, merged.Metadata.picklistValues.size());
    System.assertEquals(true, success);

    Test.setMock(HttpCalloutMock.class, new RecordTypeToolingMock(500, 500));
    Boolean failedByRead = APIOpcoesCondicaoPagamento.gerenciarOpcoesTipoRegistro(
      'ContratoMini',
      customFieldMetadata
    );
    System.assertEquals(false, failedByRead);

    Test.setMock(HttpCalloutMock.class, new RecordTypeToolingMock(200, 500));
    Boolean failedByPatch = APIOpcoesCondicaoPagamento.gerenciarOpcoesTipoRegistro(
      'ContratoMini',
      customFieldMetadata
    );
    System.assertEquals(false, failedByPatch);
  }

  @IsTest
  static void testMetadataUpdateHelpersWithSuccessfulMock() {
    List<APIOpcoesCondicaoPagamento.ValueCustomField> values = buildExistingOptions();
    values.add(buildValue('NOVA_OPCAO_1', 'Nova opcao 1'));

    Test.setMock(WebServiceMock.class, new MetadataUpdateMock(true));

    Test.startTest();
    APIOpcoesCondicaoPagamento.atualizarCampoComMetadataAPI(values);
    APIOpcoesCondicaoPagamento.atualizarTiposDeRegistro(
      new List<String>{ 'ContratoMini' },
      values
    );
    Test.stopTest();
  }

  @IsTest
  static void testCriarOpcoesReturnsInternalErrorWhenMetadataFails() {
    Test.setMock(WebServiceMock.class, new MetadataUpdateMock(false));

    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestUri =
      URL.getOrgDomainUrl().toExternalForm() +
      '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf(JSON.serialize(buildRequestOptions(1)));
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    APIOpcoesCondicaoPagamento.RespostaWrapper result = APIOpcoesCondicaoPagamento.criarOpcoes();
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('ERRO_API_INTERNO_SF', result.errors[0].errorCode);
    System.assertEquals(500, RestContext.response.statusCode);
  }

  private static List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> buildRequestOptions(
    Integer quantity
  ) {
    List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> options = new List<APIOpcoesCondicaoPagamento.RequisicaoWrapper>();

    for (Integer indexValue = 0; indexValue < quantity; indexValue++) {
      APIOpcoesCondicaoPagamento.RequisicaoWrapper optionItem = new APIOpcoesCondicaoPagamento.RequisicaoWrapper();
      optionItem.rotulo = 'Nova opcao ' + indexValue;
      optionItem.valor = 'NOVA_OPCAO_' + indexValue;
      options.add(optionItem);
    }

    return options;
  }

  private static List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> buildRequestOptionsWithNullValue() {
    List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> options = buildRequestOptions(
      1
    );
    options[0].valor = null;
    return options;
  }

  private static List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> buildDuplicatedRequestOptions() {
    List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> options = buildRequestOptions(
      2
    );
    options[1].rotulo = options[0].rotulo;
    return options;
  }

  private static List<APIOpcoesCondicaoPagamento.ValueCustomField> buildExistingOptions() {
    return new List<APIOpcoesCondicaoPagamento.ValueCustomField>{
      buildValue('VALOR_EXISTENTE', 'Valor existente')
    };
  }

  private static APIOpcoesCondicaoPagamento.ValueCustomField buildValue(
    String valueName,
    String label
  ) {
    APIOpcoesCondicaoPagamento.ValueCustomField valueItem = new APIOpcoesCondicaoPagamento.ValueCustomField();
    valueItem.default_Z = false;
    valueItem.label = label;
    valueItem.valueName = valueName;
    return valueItem;
  }

  private static APIOpcoesCondicaoPagamento.MetadadosReqCustomField buildCustomFieldMetadata() {
    APIOpcoesCondicaoPagamento.MetadadosReqCustomField requestItem = new APIOpcoesCondicaoPagamento.MetadadosReqCustomField();
    requestItem.FullName = 'Opportunity.CondicaoPagamento2__c';
    requestItem.Metadata = new APIOpcoesCondicaoPagamento.MetadataCustomField();
    requestItem.Metadata.valueSet = new APIOpcoesCondicaoPagamento.ValueSetCustomField();
    requestItem.Metadata.valueSet.valueSetDefinition = new APIOpcoesCondicaoPagamento.ValSetDefCustomField();
    requestItem.Metadata.valueSet.valueSetDefinition.value = new List<APIOpcoesCondicaoPagamento.ValueCustomField>{
      buildValue('VALOR_EXISTENTE', 'Valor existente'),
      buildValue('NOVA_OPCAO_1', 'Nova opcao 1')
    };
    return requestItem;
  }

  private static APIOpcoesCondicaoPagamento.MetadadosReqRecType buildRecordTypeMetadataBody() {
    APIOpcoesCondicaoPagamento.MetadadosReqRecType responseItem = new APIOpcoesCondicaoPagamento.MetadadosReqRecType();
    responseItem.Metadata = new APIOpcoesCondicaoPagamento.MetadataRecordType();
    responseItem.Metadata.picklistValues = new List<APIOpcoesCondicaoPagamento.PicklistValuesRecordType>();

    APIOpcoesCondicaoPagamento.PicklistValuesRecordType existingItem = new APIOpcoesCondicaoPagamento.PicklistValuesRecordType();
    existingItem.picklist = 'StageName';
    existingItem.values = new List<APIOpcoesCondicaoPagamento.ValuesRecordType>();
    responseItem.Metadata.picklistValues.add(existingItem);

    return responseItem;
  }
}
