/**
 * @description       : REST endpoint para receber eventos do webhook da WhatsApp Cloud API. GET  → verificação do webhook (hub.challenge handshake com o Meta). POST → recebimento de eventos (mensagens,
 *                       status etc.). Credenciais lidas de Integrador__mdt (DeveloperName = 'WhatsApp_Cloud_API').
 * @author            : Daniel Belini
 * @group             : Integration
 * @last modified on  : 03-30-2026
 * @last modified by  : Daniel Belini
 * @test              : WhatsAppWebhookHandlerTest
 **/
@RestResource(urlMapping='/api/whatsapp/*')
global without sharing class WhatsAppWebhookHandler {
  private static final String CMT_DEVELOPER_NAME = 'WhatsApp_Cloud_API';
  private static final String HUB_MODE_SUBSCRIBE = 'subscribe';

  // ─── GET — verificação do webhook pelo Meta ─────────────────────────────────
  @HttpGet
  global static void doGet() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String mode = req.params.get('hub.mode');
    String token = req.params.get('hub.verify_token');
    String challenge = req.params.get('hub.challenge');

    System.debug(
      LoggingLevel.INFO,
      'WhatsAppWebhookHandler.doGet - mode: ' +
        mode +
        ', token: ' +
        token +
        ', challenge: ' +
        challenge
    );

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
      res.statusCode = 200;
      res.responseBody = Blob.valueOf(challenge);
    }
  }

  // ─── POST — eventos enviados pelo Meta ──────────────────────────────────────
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

      logIncomingRequest(req);

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        body
      );

      // WhatsAppWebhookHandler.processAsync(body);

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

  // ─── Queueable — processamento assíncrono do payload ────────────────────────
  @TestVisible
  static void processAsync(String rawPayload) {
    System.enqueueJob(new WhatsAppEventProcessor(rawPayload));
  }

  // ─── Helper — leitura do CMT ─────────────────────────────────────────────────
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

  // ─── Inner Queueable ─────────────────────────────────────────────────────────
  public class WhatsAppEventProcessor implements Queueable {
    private final String rawPayload;

    public WhatsAppEventProcessor(String rawPayload) {
      this.rawPayload = rawPayload;
    }

    public void execute(QueueableContext ctx) {
      try {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          rawPayload
        );

        List<Object> entryList = (List<Object>) payload.get('entry');
        if (entryList == null || entryList.isEmpty()) {
          return;
        }

        List<Lead> leadsToInsert = new List<Lead>();

        for (Object entryObj : entryList) {
          Map<String, Object> entry = (Map<String, Object>) entryObj;
          List<Object> changes = (List<Object>) entry.get('changes');
          if (changes == null)
            continue;

          for (Object changeObj : changes) {
            Map<String, Object> change = (Map<String, Object>) changeObj;
            Map<String, Object> value = (Map<String, Object>) change.get(
              'value'
            );
            if (value == null)
              continue;

            List<Object> messages = (List<Object>) value.get('messages');
            if (messages == null)
              continue;

            for (Object msgObj : messages) {
              Map<String, Object> msg = (Map<String, Object>) msgObj;

              String senderPhone = (String) msg.get('from');
              String ctwaClid = extractCtwaClid(msg);
              String sourceUrl = extractSourceUrl(msg);

              if (!String.isBlank(senderPhone) && !String.isBlank(ctwaClid)) {
                Lead l = new Lead(
                  LastName = 'WhatsApp ' + senderPhone,
                  MobilePhone = senderPhone,
                  LeadSource = 'Anúncio',
                  Company = 'N/A',
                  CtwaClid__c = ctwaClid,
                  AdSourceUrl__c = sourceUrl
                );
                leadsToInsert.add(l);
              }
            }
          }
        }

        if (!leadsToInsert.isEmpty()) {
          insert leadsToInsert;
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'WhatsAppEventProcessor.execute error: ' + e.getMessage()
        );
      }
    }

    private String extractCtwaClid(Map<String, Object> msg) {
      Map<String, Object> referral = (Map<String, Object>) msg.get('referral');
      if (referral == null)
        return null;
      return (String) referral.get('ctwa_clid');
    }

    private String extractSourceUrl(Map<String, Object> msg) {
      Map<String, Object> referral = (Map<String, Object>) msg.get('referral');
      if (referral == null)
        return null;
      return (String) referral.get('source_url');
    }
  }
}
