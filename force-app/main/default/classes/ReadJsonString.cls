/**
 * @description       : Parseia um JSON de string e retorna até 5 campos fixos conforme as chaves recebidas.
 * @author            : Daniel Belini
 * @last modified on  : 11-16-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class ReadJsonString {
    
    public class InputWrapper {
        @InvocableVariable(required = true)
        public String json; // JSON puro vindo do Prompt Builder
        
        @InvocableVariable(required = true)
        public List<String> keys; // lista de chaves (até 5)
    }
    
    public class OutputWrapper {
        @InvocableVariable public String field1;
        @InvocableVariable public String field2;
        @InvocableVariable public String field3;
        @InvocableVariable public String field4;
        
        @InvocableVariable public String field5;
    }
    
    @InvocableMethod(label = 'Parse JSON Fixed Fields')
    public static List<OutputWrapper> parse(List<InputWrapper> requests) {
        List<OutputWrapper> results = new List<OutputWrapper>();
        
        for (InputWrapper req : requests) {
            OutputWrapper out = new OutputWrapper();
            
            if (String.isNotBlank(req.json)) {
                try {
                    System.debug('🔹 Raw JSON recebido: ' + req.json);
                    
                    // Garante que o JSON esteja limpo (caso tenha espaços ou \n)
                    String cleanJson = req.json.trim();
                    
                    // Faz o parse para um Map
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
                    System.debug('✅ Parsed Map: ' + parsed);
                    
                    // Atribui dinamicamente conforme as chaves
                    if (req.keys.size() > 0) out.field1 = getValue(parsed, req.keys, 0);
                    if (req.keys.size() > 1) out.field2 = getValue(parsed, req.keys, 1);
                    if (req.keys.size() > 2) out.field3 = getValue(parsed, req.keys, 2);
                    if (req.keys.size() > 3) out.field4 = getValue(parsed, req.keys, 3);
                    if (req.keys.size() > 4) out.field5 = getValue(parsed, req.keys, 4);
                    
                } catch (Exception e) {
                    System.debug('⚠️ Erro ao processar JSON: ' + e.getMessage());
                }
            }
            
            results.add(out);
        }
        
        return results;
    }

    private static String getValue(Map<String, Object> parsed, List<String> keys, Integer index) {
        String key = keys[index];
        if (parsed.containsKey(key)) {
            Object value = parsed.get(key);
            return value != null ? String.valueOf(value) : null;
        }
        return null;
    }
}