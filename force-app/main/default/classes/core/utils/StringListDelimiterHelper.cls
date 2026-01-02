/**
 * @description Exposes the supported delimiter list to Flow.
**/
public with sharing class StringListDelimiterHelper {

    public class Request {
        @InvocableVariable(required = false)
        public String context; // Reserved for future use (e.g., locale filtering)
    }

    public class Response {
        @InvocableVariable
        public List<String> delimiterTypes;
    }

    @InvocableMethod(label = 'Get Supported Delimiter Types' description = 'Retorna os tipos aceitos no parâmetro delimiterType.')
    public static List<Response> getSupportedDelimiters(List<Request> requests) {
        Response res = new Response();
        res.delimiterTypes = StringListParser.getSupportedDelimiterTypes();
        return new List<Response>{res};
    }
}