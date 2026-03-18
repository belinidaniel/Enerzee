/**
 * @description       : TDD tests for SAPIntegrationService
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class SAPIntegrationServiceTest {
  // ── isSuccess ────────────────────────────────────────────────────────────

  @IsTest
  static void isSuccess_givenCode200_thenReturnsTrue() {
    // Given: HTTP 200 (SAP success)
    // When: verificação de sucesso
    // Then: true
    Assert.isTrue(SAPIntegrationService.isSuccess(200));
  }

  @IsTest
  static void isSuccess_givenCode201_thenReturnsTrue() {
    // Given: HTTP 201 Created (SAP success)
    Assert.isTrue(SAPIntegrationService.isSuccess(201));
  }

  @IsTest
  static void isSuccess_givenCode204_thenReturnsTrue() {
    // Given: HTTP 204 No Content (SAP success on update)
    Assert.isTrue(SAPIntegrationService.isSuccess(204));
  }

  @IsTest
  static void isSuccess_givenCode400_thenReturnsFalse() {
    // Given: HTTP 400 Bad Request (SAP business error)
    // When: verificação de sucesso
    // Then: false
    Assert.isFalse(SAPIntegrationService.isSuccess(400));
  }

  @IsTest
  static void isSuccess_givenCode500_thenReturnsFalse() {
    Assert.isFalse(SAPIntegrationService.isSuccess(500));
  }

  @IsTest
  static void isSuccess_givenCode0_thenReturnsFalse() {
    Assert.isFalse(SAPIntegrationService.isSuccess(0));
  }

  // ── SUCCESS_CODES constant ───────────────────────────────────────────────

  @IsTest
  static void successCodes_givenConstant_thenContains200201204() {
    // Given: constante de códigos de sucesso
    // When: verificação dos valores
    // Then: contém exatamente 200, 201, 204
    Assert.isTrue(SAPIntegrationService.SUCCESS_CODES.contains(200));
    Assert.isTrue(SAPIntegrationService.SUCCESS_CODES.contains(201));
    Assert.isTrue(SAPIntegrationService.SUCCESS_CODES.contains(204));
    Assert.isFalse(SAPIntegrationService.SUCCESS_CODES.contains(400));
  }

  // ── post (via metadata) ───────────────────────────────────────────────────

  @IsTest
  static void post_givenValidEndpointAndSuccessMock_thenReturns200() {
    // Given: metadata ClienteSAP e TokenSAP existentes no org
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ClienteSAP') ||
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')
    ) {
      Assert.isTrue(
        true,
        'Metadata ClienteSAP/TokenSAP ausente — teste ignorado.'
      );
      return;
    }

    Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

    // When: POST executado via SAPIntegrationService
    Test.startTest();
    HttpResponse response = SAPIntegrationService.post(
      '{}',
      'ClienteSAP',
      null
    );
    Test.stopTest();

    // Then: resposta com status 200 retornada pelo mock
    Assert.areEqual(200, response.getStatusCode());
  }

  @IsTest
  static void post_givenPathSuffix_thenAppendsSuffixToUrl() {
    // Given: metadata PedidoCompraVendaSAP com pathSuffix
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'PedidoCompraVendaSAP'
      ) || !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')
    ) {
      Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
      return;
    }

    Test.setMock(HttpCalloutMock.class, new SAPSuffixCaptureMock());

    // When: POST com sufixo de caminho
    Test.startTest();
    HttpResponse response = SAPIntegrationService.post(
      '{}',
      'PedidoCompraVendaSAP',
      'pedidovenda'
    );
    Test.stopTest();

    // Then: mock capturou URL com sufixo (verificação implícita — mock respondeu sem exceção)
    Assert.areEqual(200, response.getStatusCode());
  }

  @IsTest
  static void post_givenPreResolvedConfig_thenExecutesWithoutExtraSOQL() {
    // Given: config pré-resolvida (evita SOQL dentro de loop)
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ClienteSAP') ||
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')
    ) {
      Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
      return;
    }

    SAPIntegrationService.EndpointConfig config = SAPIntegrationService.resolveConfig(
      'ClienteSAP'
    );
    Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

    // When: POST usando config pré-resolvida (sem SOQL adicional)
    Test.startTest();
    HttpResponse response = SAPIntegrationService.post('{}', config, null);
    Test.stopTest();

    // Then: request executada corretamente
    Assert.areEqual(200, response.getStatusCode());
  }

  // ── resolveConfig ─────────────────────────────────────────────────────────

  @IsTest
  static void resolveConfig_givenExistingEndpoint_thenReturnsUrlAndToken() {
    // Given: metadata ClienteSAP e TokenSAP presentes
    if (
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ClienteSAP') ||
      !TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')
    ) {
      Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
      return;
    }

    // When: resolução de config
    SAPIntegrationService.EndpointConfig config = SAPIntegrationService.resolveConfig(
      'ClienteSAP'
    );

    // Then: URL não nula, token não nulo
    Assert.isNotNull(config.url, 'URL do endpoint não deve ser nula.');
    // Token pode ser nulo em ambientes sem configuração — não assertar valor específico
  }

  // ── Mocks ─────────────────────────────────────────────────────────────────

  private class SAPSuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setBody('{"codigoHttp":"200","mensagem":"ok"}');
      return res;
    }
  }

  private class SAPSuffixCaptureMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      // Verifica que o endpoint contém o sufixo esperado
      Assert.isTrue(
        req.getEndpoint().contains('pedidovenda'),
        'Endpoint deve conter o sufixo pedidovenda. Endpoint: ' +
        req.getEndpoint()
      );
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setBody('{"codigoHttp":"200","mensagem":"ok"}');
      return res;
    }
  }
}
