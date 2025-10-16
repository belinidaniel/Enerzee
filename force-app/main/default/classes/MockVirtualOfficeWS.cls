@isTest
global class MockVirtualOfficeWS implements HttpCalloutMock {
    // Implement this interface method
    global HTTPResponse respond(HTTPRequest req) {
        // Optionally, only send a mock response for a specific endpoint
        // and method.
        // System.assert(req.getEndpoint().contains('https://geradorpropostaenerzeehomolog.azurewebsites.net/api/'));
        // System.assertEquals('POST', req.getMethod());

        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"erro": false, "idusuario": "98765"}');
        res.setStatusCode(200);
        return res;
    }
}