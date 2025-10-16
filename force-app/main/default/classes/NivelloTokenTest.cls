@isTest
public class NivelloTokenTest {
    public static Integer STATUS_CODE = 200;

    @isTest
    static void getNivelloTokenPositiveTest(){
        Test.setMock(HttpCalloutMock.class, new NivelloTokenMock());

        Test.startTest();

        NivelloTokenRequest.parse(
            '{' +
            '    "login": "login",' +
            '    "password": "password"' +
            '}'
        );
        
        TokenAPINivelloWs instance = new TokenAPINivelloWs();
        instance.callService();

        TokenAPINivelloWs.access_token = 'token';
        instance.callService();

        Test.stopTest();
    }

    @isTest
    static void getNivelloTokenNegativeTest(){
        STATUS_CODE = 201;

        Test.setMock(HttpCalloutMock.class, new NivelloTokenMock());

        Test.startTest();

        TokenAPINivelloWs instance = new TokenAPINivelloWs();
        instance.callService();

        Test.stopTest();
    }

    @isTest
    static void urlEncodeTest(){
        TokenAPINivelloWs.urlEncode(new Map<String, String>{'teste' => 'teste'});
    }

    public class NivelloTokenMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(STATUS_CODE);
            res.setStatus('OK');
            res.setBody(
                '    {' +
                '        "success": true,' +
                '        "data": {' +
                '            "token": "token",' +
                '            "refreshToken": "refresh_token"' +
                '        }' +
                '    }'
            );

            return res;
        }
    }
}