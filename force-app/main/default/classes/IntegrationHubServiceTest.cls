@IsTest
private class IntegrationHubServiceTest {
  private class SuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setStatus('OK');
      response.setBody('{"success":true}');
      return response;
    }
  }

  @IsTest
  static void shouldResolveProviderByEndpoint() {
    System.assertEquals(
      IntegrationHubService.PROVIDER_NIVELLO,
      IntegrationHubService.resolveProvider(
        'https://api.enerzee.com/geradorproposta/v1'
      )
    );
    System.assertEquals(
      IntegrationHubService.PROVIDER_VO,
      IntegrationHubService.resolveProvider('https://api.enerzee.com/vo/v1')
    );
    System.assertEquals(
      IntegrationHubService.PROVIDER_VO,
      IntegrationHubService.resolveProvider(null)
    );
  }

  @IsTest
  static void shouldRouteToNivello() {
    TokenAPINivelloWs.access_token = 'token-nivello';
    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://api.enerzee.com/geradorproposta/discount');
    request.setMethod('POST');
    request.setBody('{"id":"123"}');

    Test.startTest();
    HttpResponse response = IntegrationHubService.send(request);
    Test.stopTest();

    System.assertEquals(200, response.getStatusCode());
  }

  @IsTest
  static void shouldRouteToVO() {
    TokenAPIVOWs.access_token = 'token-vo';
    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://api.enerzee.com/vo/discount');
    request.setMethod('POST');
    request.setBody('{"id":"123"}');

    Test.startTest();
    HttpResponse response = IntegrationHubService.send(request);
    Test.stopTest();

    System.assertEquals(200, response.getStatusCode());
  }

  @IsTest
  static void shouldThrowWhenRequestIsNull() {
    try {
      IntegrationHubService.send((HttpRequest) null);
      System.assert(false, 'Era esperado erro quando request é nulo.');
    } catch (IntegrationHubService.IntegrationHubException ex) {
      System.assert(ex.getMessage().contains('HttpRequest não informado.'));
    }
  }
}
