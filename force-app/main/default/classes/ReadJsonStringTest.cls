/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-02-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
public class ReadJsonStringTest {
    
    @IsTest
    static void testValidJsonWithMultipleKeys() {
        // JSON de exemplo
        String json = '{"status":"Qualified","score":85,"reason":"Complete profile","lead":{"owner":{"name":"Maria"}},"contacts":[{"email":"john@test.com"},{"email":"paul@test.com"}]}';
        
        // Monta a entrada
        ReadJsonString.InputWrapper input = new ReadJsonString.InputWrapper();
        input.json = json;
        input.keys = New String[]{'status', 'score', 'reason', 'lead.owner.name', 'contacts.0.email'};
        
        List<ReadJsonString.OutputWrapper> results = ReadJsonString.parse(new List<ReadJsonString.InputWrapper>{input});
        ReadJsonString.OutputWrapper out = results[0];
        
    }
    
    @IsTest
    static void testJsonWithMissingKeys() {
        String json = '{"status":"Rejected"}';
        
        ReadJsonString.InputWrapper input = new ReadJsonString.InputWrapper();
        input.json = json;
        input.keys = New String[]{'status', 'score', 'reason', 'lead.owner.name', 'contacts.0.email'};
        
        List<ReadJsonString.OutputWrapper> results = ReadJsonString.parse(new List<ReadJsonString.InputWrapper>{input});
        ReadJsonString.OutputWrapper out = results[0];
        
    }
    
    @IsTest
    static void testEmptyJson() {
        ReadJsonString.InputWrapper input = new ReadJsonString.InputWrapper();
        input.json = '';
        input.keys = New String[]{'status', 'score', 'reason', 'lead.owner.name', 'contacts.0.email'};
        
        List<ReadJsonString.OutputWrapper> results = ReadJsonString.parse(new List<ReadJsonString.InputWrapper>{input});
        ReadJsonString.OutputWrapper out = results[0];
        
    }
}