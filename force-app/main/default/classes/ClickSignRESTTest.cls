/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignRESTTest {
  private class SignedFileMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/pdf');
      response.setBody('signed file body');
      return response;
    }
  }

  @testSetup
  static void setup() {
    Account acc = new Account(Name = 'Conta ClickSign REST');
    insert acc;

    ClickSignEnvelope__c envelope = new ClickSignEnvelope__c(
      Name = 'Envelope REST',
      Status__c = 'Draft',
      ExternalId__c = 'env-rest'
    );
    insert envelope;

    insert new ClickSign__c(
      CurrentStep__c = 'Documents',
      Status__c = 'Draft',
      ClickSignEnvelope__c = envelope.Id,
      RecordId__c = acc.Id
    );

    insert new ContentVersion(
      Title = 'Doc',
      PathOnClient = 'doc.pdf',
      VersionData = Blob.valueOf('conteudo'),
      ExternalId__c = 'doc-key',
      ClickSignEnvelope__c = envelope.Id
    );

    insert new ClickSignSigner__c(
      Name = 'Signer',
      ExternalId__c = 'signer-key',
      Status__c = 'Criado'
    );
  }

  private static String generateSignature(String body) {
    return EncodingUtil.base64Encode(
      Crypto.generateMac(
        'HMACSHA256',
        Blob.valueOf(body),
        Blob.valueOf('58a75003d36ccb8acfb9482436084784')
      )
    );
  }

  private static void prepareRestContext(String body) {
    RestRequest req = new RestRequest();
    req.requestBody = Blob.valueOf(body);
    req.httpMethod = 'POST';
    req.addHeader('Content-Hmac', generateSignature(body));
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void shouldUpdateSignerOnSignEvent() {
    String body = '{"event":{"name":"sign","data":{"signer":{"key":"signer-key"}}},"document":{"key":"doc-key"}}';
    ClickSignSigner__c signer = [
      SELECT Id
      FROM ClickSignSigner__c
      WHERE ExternalId__c = 'signer-key'
      LIMIT 1
    ];

    prepareRestContext(body);

    String result = ClickSignREST.updateRecords();
    System.assert(result.contains('sucesso'));

    ClickSignSigner__c updated = [
      SELECT Status__c
      FROM ClickSignSigner__c
      WHERE Id = :signer.Id
    ];
    System.assertEquals('Assinado', updated.Status__c);
  }

  @IsTest
  static void shouldUpdateEnvelopeOnAutoCloseEvent() {
    String body = '{"event":{"name":"auto_close","data":{"signer":{"key":"signer-key"}}},"document":{"key":"doc-key"}}';
    prepareRestContext(body);

    String result = ClickSignREST.updateRecords();
    System.assert(result.contains('sucesso'));

    ClickSign__c clickSign = [
      SELECT Status__c, ClickSignEnvelope__c
      FROM ClickSign__c
      LIMIT 1
    ];
    ClickSignEnvelope__c envelope = [
      SELECT Status__c
      FROM ClickSignEnvelope__c
      WHERE Id = :clickSign.ClickSignEnvelope__c
      LIMIT 1
    ];

    System.assertEquals(
      'Document Assign',
      clickSign.Status__c,
      'Auto close deve avançar o status do ClickSign.'
    );
    System.assertEquals(
      'Concluído',
      envelope.Status__c,
      'Envelope deve ser marcado como concluído.'
    );
  }

  @IsTest
  static void shouldCreateSignedVersionOnDocumentClosedEvent() {
    ContentVersion originalVersion = [
      SELECT Id, ContentDocumentId, ExternalId__c
      FROM ContentVersion
      WHERE ExternalId__c = 'doc-key'
      LIMIT 1
    ];
    ClickSign__c clickSign = [
      SELECT RecordId__c
      FROM ClickSign__c
      LIMIT 1
    ];

    String body =
      '{"event":{"name":"document_closed","data":{"signer":{"key":"signer-key"}}},' +
      '"document":{"key":"doc-key","downloads":{"signed_file_url":"https://example.com/signed.pdf"}}}';
    prepareRestContext(body);
    Test.setMock(HttpCalloutMock.class, new SignedFileMock());

    Test.startTest();
    String result = ClickSignREST.updateRecords();
    Test.stopTest();

    System.assert(result.contains('sucesso'));

    ContentVersion refreshedOriginal = [
      SELECT ExternalId__c
      FROM ContentVersion
      WHERE Id = :originalVersion.Id
      LIMIT 1
    ];
    Integer versionCount = [
      SELECT COUNT()
      FROM ContentVersion
      WHERE ContentDocumentId = :originalVersion.ContentDocumentId
    ];
    Integer documentLinks = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :clickSign.RecordId__c
    ];

    System.assertEquals(
      'doc-key_original',
      refreshedOriginal.ExternalId__c,
      'Versão original deve ser renomeada após assinatura.'
    );
    System.assert(
      versionCount >= 2,
      'Fechamento do documento deve criar uma nova versão assinada.'
    );
    System.assert(
      documentLinks > 0,
      'Documento assinado deve ser vinculado ao registro de destino.'
    );
  }

  @IsTest
  static void shouldReturnHandledMessageWhenDocumentIsMissing() {
    String body = '{"event":{"name":"sign","data":{"signer":{"key":"signer-key"}}},"document":{"key":"doc-missing"}}';
    prepareRestContext(body);

    String result = ClickSignREST.updateRecords();

    System.assert(
      result.contains('List index out of bounds'),
      'Fluxo de erro deve retornar a mensagem tratada.'
    );
  }
}
