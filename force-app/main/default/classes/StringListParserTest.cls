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
}