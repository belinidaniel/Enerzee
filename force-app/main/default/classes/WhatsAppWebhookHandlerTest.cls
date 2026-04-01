/**
 * @description       : Testes unitários para WhatsAppWebhookHandler.
 * @author            : Daniel Belini
 * @group             : Integration
 * @last modified on  : 03-30-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class WhatsAppWebhookHandlerTest {
  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private static RestRequest buildGetRequest(
    String mode,
    String token,
    String challenge
  ) {
    RestRequest req = new RestRequest();
    req.httpMethod = 'GET';
    req.requestURI = '/services/apexrest/whatsapp/webhook/';
    if (mode != null)
      req.addParameter('hub.mode', mode);
    if (token != null)
      req.addParameter('hub.verify_token', token);
    if (challenge != null)
      req.addParameter('hub.challenge', challenge);
    return req;
  }

  private static RestRequest buildPostRequest(String bodyJson) {
    RestRequest req = new RestRequest();
    req.httpMethod = 'POST';
    req.requestURI = '/services/apexrest/whatsapp/webhook/';
    req.requestBody = Blob.valueOf(bodyJson);
    return req;
  }

  private static String buildMessagePayload(
    String senderPhone,
    String ctwaClid,
    String sourceUrl
  ) {
    return JSON.serialize(
      new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
          new Map<String, Object>{
            'id' => 'WABA_ID',
            'changes' => new List<Object>{
              new Map<String, Object>{
                'value' => new Map<String, Object>{
                  'messaging_product' => 'whatsapp',
                  'messages' => new List<Object>{
                    new Map<String, Object>{
                      'from' => senderPhone,
                      'id' => 'wamid.test',
                      'type' => 'text',
                      'referral' => new Map<String, Object>{
                        'ctwa_clid' => ctwaClid,
                        'source_url' => sourceUrl
                      }
                    }
                  }
                },
                'field' => 'messages'
              }
            }
          }
        }
      }
    );
  }

  // ─── GET — verificação válida ────────────────────────────────────────────────
  @isTest
  static void testGetVerificationSuccess() {
    RestContext.request = buildGetRequest(
      'subscribe',
      'MY_VERIFY_TOKEN',
      'CHALLENGE_123'
    );
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doGet();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode);
    Assert.areEqual(
      'CHALLENGE_123',
      RestContext.response.responseBody.toString()
    );
  }

  // ─── GET — token incorreto → 403 ─────────────────────────────────────────────
  @isTest
  static void testGetVerificationWrongToken() {
    RestContext.request = buildGetRequest(
      'subscribe',
      'WRONG_TOKEN',
      'CHALLENGE_XYZ'
    );
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doGet();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode);
  }

  // ─── GET — mode incorreto → 403 ──────────────────────────────────────────────
  @isTest
  static void testGetVerificationWrongMode() {
    RestContext.request = buildGetRequest(
      'unsubscribe',
      'MY_VERIFY_TOKEN',
      'CHALLENGE_XYZ'
    );
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doGet();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode);
  }

  // ─── POST — body vazio → 400 ──────────────────────────────────────────────────
  @isTest
  static void testPostEmptyBody() {
    RestRequest req = new RestRequest();
    req.httpMethod = 'POST';
    req.requestURI = '/services/apexrest/whatsapp/webhook/';
    req.requestBody = Blob.valueOf('');
    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doPost();
    Test.stopTest();

    Assert.areEqual(400, RestContext.response.statusCode);
  }

  // ─── POST — payload com mensagem + ctwa_clid → cria Lead ─────────────────────
  @isTest
  static void testPostMessageWithCtwaClid() {
    String payload = buildMessagePayload(
      '5511999990000',
      'CTWA_CLID_ABC123',
      'https://fb.com/ad/123'
    );

    RestContext.request = buildPostRequest(payload);
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doPost();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode);
    Assert.areEqual(
      'EVENT_RECEIVED',
      RestContext.response.responseBody.toString()
    );

    // O Lead é criado dentro do Queueable — verificamos após o enqueueJob ter rodado no contexto de teste
    List<Lead> leads = [
      SELECT Id, MobilePhone, CtwaClid__c
      FROM Lead
      WHERE CtwaClid__c = 'CTWA_CLID_ABC123'
    ];
    Assert.areEqual(1, leads.size());
    Assert.areEqual('5511999990000', leads[0].MobilePhone);
  }

  // ─── POST — payload sem ctwa_clid → não cria Lead ────────────────────────────
  @isTest
  static void testPostMessageWithoutCtwaClid() {
    String payload = JSON.serialize(
      new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
          new Map<String, Object>{
            'id' => 'WABA_ID',
            'changes' => new List<Object>{
              new Map<String, Object>{
                'value' => new Map<String, Object>{
                  'messages' => new List<Object>{
                    new Map<String, Object>{
                      'from' => '5511888880000',
                      'type' => 'text'
                    }
                  }
                },
                'field' => 'messages'
              }
            }
          }
        }
      }
    );

    RestContext.request = buildPostRequest(payload);
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doPost();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode);

    List<Lead> leads = [
      SELECT Id
      FROM Lead
      WHERE MobilePhone = '5511888880000'
    ];
    Assert.areEqual(0, leads.size());
  }

  // ─── POST — entry list vazia → 200 sem criar Lead ────────────────────────────
  @isTest
  static void testPostEmptyEntryList() {
    String payload = JSON.serialize(
      new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>()
      }
    );

    RestContext.request = buildPostRequest(payload);
    RestContext.response = new RestResponse();

    Test.startTest();
    WhatsAppWebhookHandler.doPost();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode);
  }

  // ─── Helper — persiste Log__c com body e origem ───────────────────────────────
  @isTest
  static void testLogIncomingRequestCreatesLogRecord() {
    String payload = buildMessagePayload(
      '5511999991111',
      'CTWA_CLID_LOG',
      'https://fb.com/ad/log'
    );
    RestRequest req = buildPostRequest(payload);

    Test.startTest();
    WhatsAppWebhookHandler.logIncomingRequest(req);
    Test.stopTest();

    Log__c logRecord = [
      SELECT Class__c, Method__c, HTTPMethod__c, RequestURI__c, RequestBody__c
      FROM Log__c
      WHERE Class__c = 'WhatsAppWebhookHandler' AND Method__c = 'doPost'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    Assert.areEqual('WhatsAppWebhookHandler', logRecord.Class__c);
    Assert.areEqual('doPost', logRecord.Method__c);
    Assert.areEqual('POST', logRecord.HTTPMethod__c);
    Assert.areEqual(
      '/services/apexrest/whatsapp/webhook/',
      logRecord.RequestURI__c
    );
    Assert.isTrue(
      logRecord.RequestBody__c.contains('CTWA_CLID_LOG'),
      'O body bruto deve ser salvo no Log__c.'
    );
  }
}
