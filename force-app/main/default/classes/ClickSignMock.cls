/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de apoio a testes
 **/
@IsTest
global class ClickSignMock implements HttpCalloutMock {
  private String body;

  global ClickSignMock() {
  }

  global ClickSignMock(String body) {
    this.body = body;
  }

  global HTTPResponse respond(HTTPRequest req) {
    String requestBody = req.getBody();

    // Cria uma resposta HTTP simulada
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setStatusCode(200);

    if (String.isNotBlank(this.body)) {
      res.setBody(this.body);
    } else {
      res.setBody('{"status":"success", "message":"Body válido"}');
    }

    return res;
  }
}
