/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class StringListDelimiterHelperTest {
  @IsTest
  static void invocableReturnsSupportedTypes() {
    List<StringListDelimiterHelper.Request> requests = new List<StringListDelimiterHelper.Request>{
      new StringListDelimiterHelper.Request()
    };

    List<StringListDelimiterHelper.Response> responses = StringListDelimiterHelper.getSupportedDelimiters(
      requests
    );

    System.assertEquals(
      1,
      responses.size(),
      'Helper should return a single response payload'
    );
    List<String> types = responses[0].delimiterTypes;

    System.assert(
      types.contains('COMMA'),
      'Expected COMMA in the supported types'
    );
    System.assert(types.contains(';'), 'Expected ; in the supported types');
  }
}
