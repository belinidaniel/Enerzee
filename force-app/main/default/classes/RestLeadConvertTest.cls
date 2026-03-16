/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class RestLeadConvertTest {
  private static void setIfExists(
    SObject record,
    String fieldName,
    Object value
  ) {
    Map<String, Schema.SObjectField> fields = record.getSObjectType()
      .getDescribe()
      .fields.getMap();
    if (
      fields.containsKey(fieldName) &&
      fields.get(fieldName).getDescribe().isCreateable()
    ) {
      record.put(fieldName, value);
    }
  }

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

  @isTest
  static void testPostWithEmptyBodyConvertsLeadSuccessfully() {
    String document = '12345678901';

    Account existingAccount = new Account(Name = 'Existing Conversion Account');
    setIfExists(existingAccount, 'Formata_CPF__c', document);
    setIfExists(existingAccount, 'Formata_CNPJ__c', document);
    insert existingAccount;

    Lead leadRecord = new Lead(
      LastName = 'Lead Convert Success',
      Company = 'Enerzee',
      CPFCNPJ__c = document
    );
    Test.disableProcessesAndFlows();
    insert leadRecord;

    RestContext.request = new RestRequest();
    RestContext.request.requestURI =
      '/services/apexrest/leadconvert/' + leadRecord.Id;
    RestContext.request.httpMethod = 'POST';
    RestContext.request.requestBody = Blob.valueOf('');
    RestContext.response = new RestResponse();

    Test.startTest();
    RestLeadConvert.doPost();
    Test.stopTest();

    Lead convertedLead = [
      SELECT IsConverted, ConvertedAccountId
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    System.assertEquals(
      RestLeadConvert.StatusCodeOK,
      RestContext.response.statusCode
    );
    System.assertEquals(true, convertedLead.IsConverted);
    System.assert(
      RestContext.response.responseBody.toString().contains('Success'),
      'Successful conversions must return a success payload.'
    );
  }

  @isTest
  static void testPostWithInvalidTrailingLeadIdReturnsBadRequest() {
    RestContext.request = new RestRequest();
    RestContext.request.requestURI = '/services/apexrest/leadconvert/not-a-lead';
    RestContext.request.httpMethod = 'POST';
    RestContext.request.requestBody = Blob.valueOf('');
    RestContext.response = new RestResponse();

    Test.startTest();
    RestLeadConvert.doPost();
    Test.stopTest();

    System.assertEquals(
      RestLeadConvert.StatusCodeBadRequest,
      RestContext.response.statusCode
    );
    System.assert(
      RestContext.response.responseBody.toString()
        .contains('BadRequestException'),
      'Invalid URIs must surface the bad request code in the response body.'
    );
  }
}
