@IsTest
public class TestMetadataUtils {
  public static Boolean hasMetadata(String apiName) {
    return Schema.getGlobalDescribe().containsKey(apiName);
  }

  public static Boolean hasMetadataRecord(
    String apiName,
    String developerName
  ) {
    if (String.isBlank(apiName) || String.isBlank(developerName)) {
      return false;
    }
    if (!hasMetadata(apiName)) {
      return false;
    }
    String soql =
      'SELECT Id FROM ' +
      apiName +
      ' WHERE DeveloperName = :developerName LIMIT 1';
    List<SObject> records = Database.query(soql);
    return !records.isEmpty();
  }

  public static void setIfFieldExists(
    SObject record,
    String fieldName,
    Object value
  ) {
    if (record == null || String.isBlank(fieldName)) {
      return;
    }
    Map<String, Schema.SObjectField> fields = record.getSObjectType()
      .getDescribe()
      .fields.getMap();
    if (!fields.containsKey(fieldName)) {
      return;
    }
    Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
    if (
      describe != null && (describe.isCreateable() || describe.isUpdateable())
    ) {
      record.put(fieldName, value);
    }
  }

  public static String base64(String input) {
    return EncodingUtil.base64Encode(Blob.valueOf(input));
  }

  public class MockHttpSuccess implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"data":{}}');
      return res;
    }
  }

  public class MockHttpSuccessWithData implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"data":"https://example.com/file"}');
      return res;
    }
  }
}
