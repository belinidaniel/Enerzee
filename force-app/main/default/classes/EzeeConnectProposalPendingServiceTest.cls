@IsTest
private class EzeeConnectProposalPendingServiceTest {
  private class ServiceMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    ServiceMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setStatus(statusCode >= 200 && statusCode < 300 ? 'OK' : 'ERROR');
      res.setHeader('Content-Type', 'application/json');

      if (
        req.getEndpoint() != null &&
        req.getEndpoint().contains('TypesDocumentPending')
      ) {
        res.setBody(body);
        return res;
      }

      res.setBody(body == null ? '{"success":true}' : body);
      return res;
    }
  }

  @IsTest
  static void shouldHandleStatusHelpersAndEmptyBatch() {
    System.assertEquals(
      null,
      EzeeConnectProposalPendingService.getStatusLabel(null)
    );

    Integer awaitingCode = EzeeConnectProposalPendingService.getStatusCode(
      'Aguardando'
    );
    System.assertNotEquals(null, awaitingCode);
    System.assertNotEquals(
      null,
      EzeeConnectProposalPendingService.getStatusLabel(awaitingCode)
    );

    Test.startTest();
    EzeeConnectProposalPendingService.sendPendingBatchToApp(
      new List<EzeeConnectProposalPendingService.PendingRequest>()
    );
    Test.stopTest();
  }

  @IsTest
  static void shouldReturnEmptyDocumentTypesWhenDataIsNull() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(
      HttpCalloutMock.class,
      new ServiceMock(200, '{"success":true,"data":null}')
    );

    Test.startTest();
    List<EzeeConnectProposalPendingService.DocumentTypeOption> options = EzeeConnectProposalPendingService.getDocumentTypes();
    Test.stopTest();

    System.assertEquals(0, options.size());
  }

  @IsTest
  static void shouldSendAndUpdatePendingSuccessfully() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(
      HttpCalloutMock.class,
      new ServiceMock(200, '{"success":true}')
    );

    EzeeConnectProposalPendingService.PendingRequest createPayload = new EzeeConnectProposalPendingService.PendingRequest();
    createPayload.ProposalId = 'VO-123';
    createPayload.Description = 'Documento pendente';
    createPayload.DocumentType = 1;
    createPayload.Status = 0;

    EzeeConnectProposalPendingService.PendingUpdateRequest updatePayload = new EzeeConnectProposalPendingService.PendingUpdateRequest();
    updatePayload.PendingId = 'PEND-123';
    updatePayload.Status = 1;
    updatePayload.DescriptionRejected = 'OK';

    Test.startTest();
    EzeeConnectProposalPendingService.sendPendingToApp(createPayload);
    EzeeConnectProposalPendingService.sendPendingBatchToApp(
      new List<EzeeConnectProposalPendingService.PendingRequest>{
        createPayload
      }
    );
    EzeeConnectProposalPendingService.updatePendingInApp(updatePayload);
    Test.stopTest();

    System.assert(true, 'Chamadas concluídas sem exceções.');
  }

  @IsTest
  static void shouldThrowWhenIntegrationReturnsErrorStatus() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(
      HttpCalloutMock.class,
      new ServiceMock(500, '{"error":"fail"}')
    );

    EzeeConnectProposalPendingService.PendingRequest payload = new EzeeConnectProposalPendingService.PendingRequest();
    payload.ProposalId = 'VO-500';
    payload.Description = 'Erro esperado';
    payload.DocumentType = 1;
    payload.Status = 0;

    Test.startTest();
    try {
      EzeeConnectProposalPendingService.sendPendingToApp(payload);
      System.assert(false, 'Era esperado erro na integração.');
    } catch (EzeeConnectProposalPendingService.PendingIntegrationException ex) {
      System.assert(ex.getMessage().contains('falhou. Código 500'));
    }
    Test.stopTest();
  }
}
