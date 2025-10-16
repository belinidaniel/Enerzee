public class TokenAPIVOWs {
    public String erro{get; set;}
    public VOTokenResponse tokenResponse {get; set;}
    public HttpResponse finalResponse {get; set;}
    public static String access_token {get; set;}
        
    public boolean callService()
    {
        Integrador__mdt token = [
            SELECT  Id, URL__c, login__c, senha__c, validade_token__c 
            FROM    Integrador__mdt 
            WHERE   DeveloperName = 'Login_VO'
        ];
            
        if(access_token != null && access_token != ''){
            tokenResponse = new VOTokenResponse();
            tokenResponse.access_token = access_token;
            return true;
        }

        String body = 'grant_type=password' +
                      '&UserName=' + EncodingUtil.urlEncode(token.login__c, 'UTF-8') +
                      '&Password=' + EncodingUtil.urlEncode(token.senha__c, 'UTF-8');
            
        if(token != null){
            Http h = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(token.URL__c);
            request.setTimeout(120000);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setBody(body);
        
            HttpResponse response = h.send(request);
            finalResponse = response;

            if (response.getStatusCode() == 200) {
                tokenResponse = VOTokenResponse.parse(response.getBody());
                access_token = tokenResponse.access_token;
            } else {
                erro = EncodingUtil.urlDecode(response.getBody(), 'UTF-8');
                return false;
            }
        }     

        return true;
    }        
}