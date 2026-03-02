@IsTest
private class ClickSignRESTTest {
  @IsTest
  static void shouldUpdateSignerOnSignEvent() {
    ContentVersion cv = new ContentVersion(
      Title = 'Doc',
      PathOnClient = 'doc.pdf',
      VersionData = Blob.valueOf('conteudo'),
      ExternalId__c = 'doc-key'
    );
    insert cv;

    ClickSignSigner__c signer = new ClickSignSigner__c(
      Name = 'Signer',
      ExternalId__c = 'signer-key',
      Status__c = 'Criado'
    );
    insert signer;

    String body = '{"event":{"name":"sign","data":{"signer":{"key":"signer-key"}}},"document":{"key":"doc-key"}}';
    String signature = EncodingUtil.base64Encode(
      Crypto.generateMac(
        'HMACSHA256',
        Blob.valueOf(body),
        Blob.valueOf('58a75003d36ccb8acfb9482436084784')
      )
    );

    RestRequest req = new RestRequest();
    req.requestBody = Blob.valueOf(body);
    req.httpMethod = 'POST';
    req.addHeader('Content-Hmac', signature);
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;

    String result = ClickSignREST.updateRecords();
    System.assert(result.contains('sucesso'));

    ClickSignSigner__c updated = [
      SELECT Status__c
      FROM ClickSignSigner__c
      WHERE Id = :signer.Id
    ];
    System.assertEquals('Assinado', updated.Status__c);
  }
}
