@IsTest
private class StringListParserTest {

    @IsTest
    static void splitValuesComma() {
        List<String> values = StringListParser.splitValues('comma', ' A , B ,C ');
        System.assertEquals(3, values.size(), 'Should parse three comma-separated values');
        System.assertEquals(new List<String>{'A', 'B', 'C'}, values);
    }

    @IsTest
    static void splitValuesSemicolon() {
        List<String> values = StringListParser.splitValues(';', 'X; Y;Z');
        System.assertEquals(new List<String>{'X', 'Y', 'Z'}, values);
    }

    @IsTest
    static void splitValuesDefault() {
        List<String> values = StringListParser.splitValues(null, 'one,two');
        System.assertEquals(new List<String>{'one', 'two'}, values, 'Null delimiter falls back to comma');
    }

    @IsTest
    static void splitValuesEmptySegmentsIgnored() {
        List<String> values = StringListParser.splitValues('virgula', 'A,, ,B');
        System.assertEquals(new List<String>{'A', 'B'}, values, 'Empty segments must be ignored');
    }

    @IsTest
    static void splitValuesBlankInput() {
        List<String> values = StringListParser.splitValues('comma', '   ');
        System.assertEquals(0, values.size(), 'Blank input returns an empty list');
    }

    @IsTest
    static void invokeMethodReturnsValues() {
        StringListParser.Request req = new StringListParser.Request();
        req.delimiterType = 'ponto_virgula';
        req.rawValue = 'A;B;C';

        List<StringListParser.Request> input = new List<StringListParser.Request>{req};
        List<StringListParser.Response> responses = StringListParser.invoke(input);

        System.assertEquals(1, responses.size(), 'Should return a single response for each request');
        System.assertEquals(new List<String>{'A', 'B', 'C'}, responses[0].values, 'Flow-facing method must delegate to parser');
    }

    @IsTest
    static void getSupportedDelimiterTypesReturnsKnown() {
        List<String> types = StringListParser.getSupportedDelimiterTypes();
        System.assert(types.contains('COMMA'), 'Expected COMMA in the supported types');
        System.assert(types.contains(';'), 'Expected ; in the supported types');
        System.assert(types.contains('PONTO_VIRGULA'), 'Expected PONTO_VIRGULA in the supported types');
    }
}