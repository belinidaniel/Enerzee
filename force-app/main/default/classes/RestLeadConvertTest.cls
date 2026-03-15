@isTest
private class RestLeadConvertTest {
  @isTest
  static void testPostWithBadJson() {
    RestContext.request = new RestRequest();
    RestContext.request.requestURI = '/leadconvert/00Q4K000001iiKjUAI';
    RestContext.request.httpMethod = 'POST';
    RestContext.request.requestBody = Blob.valueOf(
      '{"accountId":,"convertedStatus":"Opportunity"}'
    );

    RestContext.response = new RestResponse();

    Test.startTest();
    RestLeadConvert.doPost();
    Test.stopTest();

    System.assertEquals(
      RestLeadConvert.StatusCodeBadRequest,
      RestContext.response.statusCode
    );
  }

  @isTest
  static void testGetTrailingLeadId() {
    Id leadId = '00Q4K000001iiKjUAI';
    String uri = '/' + leadId;
    Id parsed = RestLeadConvert.getTrailingLeadId(uri);
    System.assertEquals(leadId, parsed);

    System.assertEquals(
      null,
      RestLeadConvert.getTrailingLeadId('/0014K000001iiKjUAI')
    );
  }

  @isTest
  static void testParseTrailingLeadIdThrows() {
    Test.startTest();
    try {
      RestLeadConvert.parseTrailingLeadId('/invalid');
      System.assert(false, 'Should have thrown BadRequestException');
    } catch (RestLeadConvert.BadRequestException e) {
      System.assert(
        e.getMessage()
          .contains('requestURI does not have a valid trailing Lead Id')
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testCreateDefaultLeadConvert() {
    Test.startTest();
    Database.LeadConvert lc = RestLeadConvert.createDefaultLeadConvert();
    Test.stopTest();

    // Como os getters não são visíveis, só podemos verificar que o objeto foi criado
    System.assertNotEquals(null, lc);
  }

  @isTest
  static void testExceptionTypeNameToCode() {
    Exception e = new RestLeadConvert.BadRequestException('test');
    String code = RestLeadConvert.exceptionTypeNameToCode(e);
    System.assertEquals('BadRequestException', code);
  }
}
