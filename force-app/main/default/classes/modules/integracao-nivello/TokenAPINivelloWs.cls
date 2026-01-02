public class TokenAPINivelloWs {
    public String erro{get; set;}
    public NivelloTokenResponse tokenResponse {get; set;}
    public NivelloTokenRequest tokenRequest {get; set;}
    public HttpResponse finalResponse {get; set;}
    public static String access_token {get; set;}
	
    public boolean callService()
    {
        Integrador__mdt token = [
            SELECT  Id, URL__c, login__c, senha__c, validade_token__c 
            FROM    Integrador__mdt 
            WHERE   DeveloperName = 'Login_Nivello'
        ];
        
        //se já temos o access_token setado, usamos ele mesmo
        if(access_token != null && access_token != ''){
            tokenResponse = new NivelloTokenResponse();
            tokenResponse.data = new NivelloTokenResponse.ResponseData();

            tokenResponse.data.token = access_token;
            
            return true;
        }

        tokenRequest = new NivelloTokenRequest();
        tokenRequest.login = token.login__c;
        tokenRequest.password = token.senha__c;
        String body = JSON.serialize(tokenRequest);
        
        if(token != null){
            Http h = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(token.URL__c);
            request.setTimeout(120000);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(body);
        
            HttpResponse response;
            response = h.send(request);
            finalResponse = response;
            
            //Utils.createLog('TokenAPINivelloWs', 'callService', response);

            if(response.getStatusCode() == 200){
                tokenResponse = NivelloTokenResponse.parse(response.getBody());

                String tokenAux = tokenResponse.data.token;
                access_token = tokenResponse.data.token;
            } else {
                erro = response.getBody() ;
                erro = EncodingUtil.urlDecode(erro, 'UTF-8');
                return false;
            }
        }
        
        return true;
    }
    
    public static String urlEncode(Map<String, String> vals)
    {
        String result = '';
        
        for(String thisKey : vals.keySet()){
            result += EncodingUtil.urlEncode(thisKey, 'UTF-8') + '=' + EncodingUtil.urlEncode(vals.get(thisKey), 'UTF-8') + '&';
        }
        
        return result.removeEnd('&');    
    }
}