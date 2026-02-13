@IsTest
private class TokenAPIVOWsTest {
    private class TokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"abc","token_type":"bearer","expires_in":3600}');
            return res;
        }
    }

    @IsTest
    static void shouldFetchToken() {
        if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'Login_VO')) {
            return;
        }

        Test.setMock(HttpCalloutMock.class, new TokenMock());
        TokenAPIVOWs token = new TokenAPIVOWs();
        Boolean success = token.callService();
        System.assertEquals(true, success);
        System.assertEquals('abc', TokenAPIVOWs.access_token);
    }
}
