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

  private static String validVerifyToken() {
    return WhatsAppWebhookHandler.getConfig().Verify_Token__c;
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
                      'from_user_id' => 'BR.4417941618490306',
                      'id' => 'wamid.test',
                      'timestamp' => '1777737600',
                      'type' => 'text',
                      'referral' => new Map<String, Object>{
                        'ctwa_clid' => ctwaClid,
                        'source_id' => '120247934274870536',
                        'headline' => 'Enerzee Solar',
                        'body' => 'Economize com energia solar',
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
      validVerifyToken(),
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
      SELECT
        Id,
        MobilePhone,
        CtwaClid__c,
        WhatsApp_User_ID__c,
        WhatsApp_ID__c,
        First_Touch_Ad__c,
        Last_Touch_Ad__c
      FROM Lead
      WHERE CtwaClid__c = 'CTWA_CLID_ABC123'
    ];
    Assert.areEqual(1, leads.size());
    Assert.areEqual('5511999990000', leads[0].MobilePhone);
    Assert.areEqual('BR.4417941618490306', leads[0].WhatsApp_User_ID__c);
    Assert.areEqual('5511999990000', leads[0].WhatsApp_ID__c);
    Assert.isNotNull(leads[0].First_Touch_Ad__c);
    Assert.areEqual(leads[0].First_Touch_Ad__c, leads[0].Last_Touch_Ad__c);

    List<Meta_Ad__c> ads = [
      SELECT Id, Meta_Ad_ID__c, Creative_Headline__c, Enrichment_Status__c
      FROM Meta_Ad__c
      WHERE Meta_Ad_ID__c = '120247934274870536'
    ];
    Assert.areEqual(1, ads.size());
    Assert.areEqual('Enerzee Solar', ads[0].Creative_Headline__c);

    List<Lead_Touch__c> touches = [
      SELECT Id, CTWA_CLID__c, Meta_Ad__c
      FROM Lead_Touch__c
      WHERE Lead__c = :leads[0].Id
    ];
    Assert.areEqual(1, touches.size());
    Assert.areEqual('CTWA_CLID_ABC123', touches[0].CTWA_CLID__c);
  }

  // ─── POST — mensagem orgânica (sem ctwa_clid) → não cria Lead nem Meta_Ad__c ──
  @isTest
  static void testPostOrganicMessageIgnored() {
    String payload = JSON.serialize(
      new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
          new Map<String, Object>{
            'id' => 'WABA_ID',
            'changes' => new List<Object>{
              new Map<String, Object>{
                'value' => new Map<String, Object>{
                  'contacts' => new List<Object>{
                    new Map<String, Object>{
                      'wa_id' => '5511888880000',
                      'profile' => new Map<String, Object>{
                        'name' => 'João Orgânico'
                      }
                    }
                  },
                  'messages' => new List<Object>{
                    new Map<String, Object>{
                      'from' => '5511888880000',
                      'from_user_id' => 'BR.ORGANIC_USER',
                      'timestamp' => '1777737600',
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
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead],
      'Mensagem orgânica sem referral não deve criar Lead'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Meta_Ad__c],
      'Sem referral, Meta_Ad__c não deve ser criado'
    );
  }

  // ─── POST — payload de status (read/sent/delivered) → não loga, não cria Lead ──
  @isTest
  static void testPostStatusUpdateIgnored() {
    String payload = JSON.serialize(
      new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
          new Map<String, Object>{
            'id' => 'WABA_ID',
            'changes' => new List<Object>{
              new Map<String, Object>{
                'value' => new Map<String, Object>{
                  'statuses' => new List<Object>{
                    new Map<String, Object>{
                      'id' => 'wamid.TEST',
                      'status' => 'read',
                      'timestamp' => '1777737600',
                      'recipient_id' => '5511999990000'
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
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead],
      'Status update não deve criar Lead'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Log__c WHERE Class__c = 'WhatsAppWebhookHandler'],
      'Status update não deve gerar Log__c'
    );
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
