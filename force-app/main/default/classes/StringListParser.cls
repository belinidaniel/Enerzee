/**
 * @description  Utility to split a text payload into a list of strings based on a configurable delimiter.
**/
public with sharing class StringListParser {

    private static final Map<String, String> SUPPORTED_DELIMITERS = new Map<String, String>{
        'COMMA' => ',',
        'VIRGULA' => ',',
        'SEMICOLON' => ';',
        'PONTO_VIRGULA' => ';',
        ',' => ',',
        ';' => ';'
    };

    public class Request {
        @InvocableVariable(required = true)
        public String delimiterType;

        @InvocableVariable(required = true)
        public String rawValue;
    }

    public class Response {
        @InvocableVariable
        public List<String> values;
    }

    @InvocableMethod(label = 'Split String Into List' description = 'Recebe uma string e retorna uma lista conforme o separador informado.')
    public static List<Response> invoke(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            res.values = splitValues(req != null ? req.delimiterType : null, req != null ? req.rawValue : null);
            results.add(res);
        }
        return results;
    }

    /**
     * Splits a string using the informed delimiter type and returns the cleaned values.
     *
     * @param delimiterType Text describing the delimiter (e.g. 'comma', 'virgula', ';').
     * @param rawValue      The string to split.
     * @return List<String> Values split using the chosen delimiter with blanks removed.
     */
    public static List<String> splitValues(String delimiterType, String rawValue) {
        List<String> result = new List<String>();
        if (String.isBlank(rawValue)) {
            return result;
        }

        String delimiter = resolveDelimiter(delimiterType);
        for (String chunk : rawValue.split(delimiter)) {
            String cleaned = chunk != null ? chunk.trim() : null;
            if (!String.isBlank(cleaned)) {
                result.add(cleaned);
            }
        }
        return result;
    }

    private static String resolveDelimiter(String delimiterType) {
        if (String.isBlank(delimiterType)) {
            return ',';
        }

        String key = delimiterType.trim().toUpperCase();
        if (SUPPORTED_DELIMITERS.containsKey(key)) {
            return SUPPORTED_DELIMITERS.get(key);
        }
        return ',';
    }

    public static List<String> getSupportedDelimiterTypes() {
        List<String> types = new List<String>(SUPPORTED_DELIMITERS.keySet());
        types.sort();
        return types;
    }
}