/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaLeadAttributionServiceTest
 **/
/**
 * @description Parser tipado para eventos WhatsApp Cloud API com referral CTWA.
 */
public with sharing class MetaWebhookPayloadParser {
  public class MessageContext {
    public String senderPhone;
    public String fromUserId;
    public String waId;
    public String profileName;
    public Datetime messageDatetime;
    public String ctwaClid;
    public String sourceId;
    public String sourceUrl;
    public String sourceType;
    public String mediaType;
    public String headline;
    public String body;
    public String thumbnailUrl;
    public String videoUrl;
    public String welcomeMessage;

    public Boolean hasReferral() {
      return !String.isBlank(ctwaClid) || !String.isBlank(sourceId);
    }
  }

  public static List<MessageContext> parse(String rawPayload) {
    List<MessageContext> contexts = new List<MessageContext>();
    if (String.isBlank(rawPayload)) {
      return contexts;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      rawPayload
    );
    List<Object> entries = asList(payload.get('entry'));
    for (Object entryObj : entries) {
      Map<String, Object> entry = asMap(entryObj);
      for (Object changeObj : asList(entry.get('changes'))) {
        Map<String, Object> changeRecord = asMap(changeObj);
        Map<String, Object> value = asMap(changeRecord.get('value'));
        if (value == null) {
          continue;
        }

        Map<String, MessageContext> contextsByWaId = buildContactContexts(
          value
        );
        for (Object messageObj : asList(value.get('messages'))) {
          MessageContext context = parseMessage(
            asMap(messageObj),
            contextsByWaId
          );
          if (context != null) {
            contexts.add(context);
          }
        }
      }
    }
    return contexts;
  }

  private static Map<String, MessageContext> buildContactContexts(
    Map<String, Object> value
  ) {
    Map<String, MessageContext> contextsByWaId = new Map<String, MessageContext>();
    for (Object contactObj : asList(value.get('contacts'))) {
      Map<String, Object> contact = asMap(contactObj);
      if (contact == null) {
        continue;
      }

      MessageContext context = new MessageContext();
      context.waId = stringValue(contact.get('wa_id'));
      Map<String, Object> profile = asMap(contact.get('profile'));
      if (profile != null) {
        context.profileName = stringValue(profile.get('name'));
      }
      if (!String.isBlank(context.waId)) {
        contextsByWaId.put(context.waId, context);
      }
    }
    return contextsByWaId;
  }

  private static MessageContext parseMessage(
    Map<String, Object> message,
    Map<String, MessageContext> contextsByWaId
  ) {
    if (message == null) {
      return null;
    }

    String senderPhone = stringValue(message.get('from'));
    MessageContext baseContext = !String.isBlank(senderPhone) &&
      contextsByWaId.containsKey(senderPhone)
      ? contextsByWaId.get(senderPhone)
      : new MessageContext();

    MessageContext context = cloneContext(baseContext);
    context.senderPhone = senderPhone;
    if (String.isBlank(context.waId)) {
      context.waId = senderPhone;
    }
    context.fromUserId = stringValue(message.get('from_user_id'));
    context.messageDatetime = parseTimestamp(
      stringValue(message.get('timestamp'))
    );

    Map<String, Object> referral = asMap(message.get('referral'));
    if (referral != null) {
      context.ctwaClid = stringValue(referral.get('ctwa_clid'));
      context.sourceId = stringValue(referral.get('source_id'));
      context.sourceUrl = stringValue(referral.get('source_url'));
      context.sourceType = stringValue(referral.get('source_type'));
      context.mediaType = stringValue(referral.get('media_type'));
      context.headline = stringValue(referral.get('headline'));
      context.body = stringValue(referral.get('body'));
      context.thumbnailUrl = stringValue(referral.get('thumbnail_url'));
      context.videoUrl = stringValue(referral.get('video_url'));

      Map<String, Object> welcome = asMap(referral.get('welcome_message'));
      if (welcome != null) {
        context.welcomeMessage = stringValue(welcome.get('text'));
      }
    }
    return context;
  }

  private static MessageContext cloneContext(MessageContext source) {
    MessageContext target = new MessageContext();
    if (source == null) {
      return target;
    }
    target.waId = source.waId;
    target.profileName = source.profileName;
    return target;
  }

  private static Datetime parseTimestamp(String value) {
    if (String.isBlank(value)) {
      return System.now();
    }
    try {
      Long seconds = Long.valueOf(value);
      return Datetime.newInstance(1970, 1, 1, 0, 0, 0)
        .addSeconds(Integer.valueOf(seconds));
    } catch (Exception ignored) {
      return System.now();
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

  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
