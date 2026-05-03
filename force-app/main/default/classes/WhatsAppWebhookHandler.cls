/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : WhatsAppWebhookHandlerTest
 **/
/**
 * @description REST endpoint para receber eventos do webhook da WhatsApp Cloud API.
 *              GET  → verificação do webhook (hub.challenge handshake com o Meta).
 *              POST → recebimento de eventos (mensagens, status etc.).
 *              Log__c só é criado quando há pelo menos uma mensagem no payload (ignora status updates).
 * @test : WhatsAppWebhookHandlerTest
 */
@RestResource(urlMapping='/api/whatsapp/*')
global without sharing class WhatsAppWebhookHandler {
  private static final String CMT_DEVELOPER_NAME = 'WhatsApp_Cloud_API';
  private static final String HUB_MODE_SUBSCRIBE = 'subscribe';

  @HttpGet
  global static void doGet() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String mode = req.params.get('hub.mode');
    String token = req.params.get('hub.verify_token');
    String challenge = req.params.get('hub.challenge');

    Integrador__mdt config = getConfig();

    if (
      mode == HUB_MODE_SUBSCRIBE &&
      token != null &&
      config != null &&
      token == config.Verify_Token__c
    ) {
      res.statusCode = 200;
      res.responseBody = Blob.valueOf(challenge);
    } else {
      res.statusCode = 403;
      res.responseBody = Blob.valueOf('Forbidden');
    }
  }

  @HttpPost
  global static void doPost() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    try {
      String body = req.requestBody != null ? req.requestBody.toString() : '';

      if (String.isBlank(body)) {
        res.statusCode = 400;
        return;
      }

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        body
      );

      // só loga e processa se o payload contém mensagens (ignora status read/sent/delivered)
      if (hasMessages(payload)) {
        logIncomingRequest(req);
        WhatsAppWebhookHandler.processAsync(body);
      }

      res.statusCode = 200;
      res.responseBody = Blob.valueOf('EVENT_RECEIVED');
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'WhatsAppWebhookHandler.doPost error: ' + e.getMessage()
      );
      res.statusCode = 500;
    }
  }

  // retorna true se o payload tem pelo menos uma entrada com messages[]
  @TestVisible
  static Boolean hasMessages(Map<String, Object> payload) {
    List<Object> entries = asList(payload.get('entry'));
    for (Object entryObj : entries) {
      Map<String, Object> entry = asMap(entryObj);
      if (entry == null) {
        continue;
      }
      for (Object changeObj : asList(entry.get('changes'))) {
        Map<String, Object> changeRecord = asMap(changeObj);
        if (changeRecord == null) {
          continue;
        }
        Map<String, Object> value = asMap(changeRecord.get('value'));
        if (value == null) {
          continue;
        }
        List<Object> messages = asList(value.get('messages'));
        if (!messages.isEmpty()) {
          return true;
        }
      }
    }
    return false;
  }

  @TestVisible
  static void logIncomingRequest(RestRequest req) {
    try {
      insert Utils.createLogNoInsert('WhatsAppWebhookHandler', 'doPost', req);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'WhatsAppWebhookHandler.doPost log error: ' + e.getMessage()
      );
    }
  }

  @TestVisible
  static void processAsync(String rawPayload) {
    System.enqueueJob(new WhatsAppEventProcessor(rawPayload));
  }

  @TestVisible
  static Integrador__mdt getConfig() {
    List<Integrador__mdt> records = [
      SELECT
        URL__c,
        Client_Id__c,
        Client_Secret__c,
        LastToken__c,
        Verify_Token__c
      FROM Integrador__mdt
      WHERE DeveloperName = :CMT_DEVELOPER_NAME
      LIMIT 1
    ];
    return records.isEmpty() ? null : records[0];
  }

  public class WhatsAppEventProcessor implements Queueable {
    private final String rawPayload;

    public WhatsAppEventProcessor(String rawPayload) {
      this.rawPayload = rawPayload;
    }

    public void execute(QueueableContext ctx) {
      try {
        MetaLeadAttributionService.processRawPayload(rawPayload);
      } catch (Exception e) {
        Utils.createLog('WhatsAppEventProcessor', 'execute', e.getMessage());
      }
    }
  }

  private static Map<String, Object> asMap(Object value) {
    return value instanceof Map<String, Object>
      ? (Map<String, Object>) value
      : null;
  }

  private static List<Object> asList(Object value) {
    return value instanceof List<Object>
      ? (List<Object>) value
      : new List<Object>();
  }
}
