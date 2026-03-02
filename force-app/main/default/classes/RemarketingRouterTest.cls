/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 09-29-2025
 * @last modified by	 : Daniel Belini
 **/
@IsTest
public class RemarketingRouterTest {
  // Mock para simular chamadas ao endpoint de conversa (Named Credential)
  public class RemarketingMock implements HttpCalloutMock {
    private String conversationBody;

    public RemarketingMock(String conversationBody) {
      this.conversationBody = conversationBody;
    }

    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getEndpoint().contains('/conversation/')) {
        res.setBody(conversationBody);
        res.setStatusCode(200);
      } else {
        res.setBody('{"error":"endpoint não esperado"}');
        res.setStatusCode(400);
      }

      return res;
    }
  }

  @IsTest
  static void testRemarketingDetected() {
    String mockBody =
      '{ "conversationEntries": [' +
      '{"sender":{"role":"business","appType":"app"},"messageText":"Olá, temos uma oferta especial para você"},' +
      '{"sender":{"role":"enduser","appType":"app"},"messageText":"Gostaria de saber mais sobre as soluções da Enerzee"} ] }';

    Test.setMock(HttpCalloutMock.class, new RemarketingMock(mockBody));

    RemarketingRouter.Input inp = new RemarketingRouter.Input();
    inp.conversationIdentifier = 'abc123';
    inp.messageLimit = 5;

    Test.startTest();
    List<RemarketingRouter.Output> results = RemarketingRouter.run(
      new List<RemarketingRouter.Input>{ inp }
    );
    Test.stopTest();
  }

  @IsTest
  static void testNotRemarketing() {
    String mockBody =
      '{ "conversationEntries": [' +
      '{"sender":{"role":"business","appType":"app"},"messageText":"Mensagem comum"},' +
      '{"sender":{"role":"enduser","appType":"app"},"messageText":"Olá"} ] }';

    Test.setMock(HttpCalloutMock.class, new RemarketingMock(mockBody));

    RemarketingRouter.Input inp = new RemarketingRouter.Input();
    inp.conversationIdentifier = 'xyz789';
    inp.messageLimit = 3;

    Test.startTest();
    List<RemarketingRouter.Output> results = RemarketingRouter.run(
      new List<RemarketingRouter.Input>{ inp }
    );
    Test.stopTest();
  }

  @IsTest
  static void testNoMessages() {
    String mockBody = '{ "conversationEntries": [] }';

    Test.setMock(HttpCalloutMock.class, new RemarketingMock(mockBody));

    RemarketingRouter.Input inp = new RemarketingRouter.Input();
    inp.conversationIdentifier = 'empty123';
    inp.messageLimit = 2;

    Test.startTest();
    List<RemarketingRouter.Output> results = RemarketingRouter.run(
      new List<RemarketingRouter.Input>{ inp }
    );
    Test.stopTest();
  }
}
