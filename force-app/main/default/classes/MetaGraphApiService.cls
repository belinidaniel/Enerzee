/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaGraphApiServiceTest
 **/
/**
 * @description Cliente HTTP centralizado para Meta Graph API.
 */
public with sharing class MetaGraphApiService {
  private static final String INTEGRATION_DEV_NAME = 'WhatsApp_Cloud_API';
  private static final String DEFAULT_GRAPH_URL = 'https://graph.facebook.com/v25.0';
  private static final Integer TIMEOUT_MS = 120000;

  public class MetaGraphException extends Exception {
  }

  public class AdEnvelope {
    public String id;
    public String name;
    public String effectiveStatus;
    public Datetime createdTime;
    public Datetime updatedTime;
    public CampaignEnvelope campaign;
    public AdSetEnvelope adSet;
    public CreativeEnvelope creative;
  }

  public class CampaignEnvelope {
    public String id;
    public String name;
    public String objective;
    public String status;
    public String effectiveStatus;
    public String buyingType;
    public String bidStrategy;
    public Decimal dailyBudget;
    public Decimal lifetimeBudget;
    public Decimal spendCap;
    public Date startDate;
    public Date endDate;
    public Datetime createdTime;
    public Datetime updatedTime;
    public String accountId;
    public String specialAdCategories;
  }

  public class AdSetEnvelope {
    public String id;
    public String name;
    public String effectiveStatus;
    public Decimal dailyBudget;
    public Decimal lifetimeBudget;
    public String billingEvent;
    public String optimizationGoal;
  }

  public class CreativeEnvelope {
    public String id;
    public String body;
    public String title;
    public String imageUrl;
    public String thumbnailUrl;
    public String videoId;
  }

  public class InsightsEnvelope {
    public Decimal spend;
    public Decimal ctr;
    public Decimal cpc;
    public Decimal cpm;
    public Decimal frequency;
    public Integer impressions;
    public Integer reach;
    public Integer clicks;
    public Integer leads;
    public Decimal costPerLead;
  }

  public static AdEnvelope getAd(String adId) {
    String fields =
      'id,name,effective_status,created_time,updated_time,' +
      'adset{id,name,effective_status,daily_budget,lifetime_budget,billing_event,optimization_goal},' +
      'campaign{id,name,objective,status,effective_status,buying_type,bid_strategy,daily_budget,lifetime_budget,spend_cap,start_time,stop_time,created_time,updated_time,account_id,special_ad_categories},' +
      'creative{id,body,title,image_url,thumbnail_url,video_id}';
    HttpResponse response = send(
      'GET',
      '/' +
        EncodingUtil.urlEncode(adId, 'UTF-8') +
        '?fields=' +
        EncodingUtil.urlEncode(fields, 'UTF-8')
    );
    if (response.getStatusCode() == 404) {
      return null;
    }
    ensureSuccess(response);
    return parseAd(
      (Map<String, Object>) JSON.deserializeUntyped(response.getBody())
    );
  }

  public static InsightsEnvelope getInsights(String metaId, String datePreset) {
    String fields = 'spend,impressions,reach,clicks,ctr,cpc,cpm,frequency,actions,cost_per_action_type';
    String path =
      '/' +
      EncodingUtil.urlEncode(metaId, 'UTF-8') +
      '/insights?fields=' +
      EncodingUtil.urlEncode(fields, 'UTF-8') +
      '&date_preset=' +
      EncodingUtil.urlEncode(
        String.isBlank(datePreset) ? 'lifetime' : datePreset,
        'UTF-8'
      );
    HttpResponse response = send('GET', path);
    ensureSuccess(response);
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    List<Object> data = (List<Object>) payload.get('data');
    return data == null || data.isEmpty()
      ? new InsightsEnvelope()
      : parseInsights((Map<String, Object>) data[0]);
  }

  @TestVisible
  static HttpResponse send(String method, String path) {
    Integrador__mdt config = [
      SELECT URL__c, LastToken__c, TokenLong__c
      FROM Integrador__mdt
      WHERE DeveloperName = :INTEGRATION_DEV_NAME
      LIMIT 1
    ];

    String baseUrl = String.isBlank(config.URL__c)
      ? DEFAULT_GRAPH_URL
      : config.URL__c;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
    }
    HttpRequest request = new HttpRequest();
    request.setMethod(method);
    request.setEndpoint(baseUrl + path);
    request.setTimeout(TIMEOUT_MS);
    request.setHeader('Content-Type', 'application/json');
    String token = String.isNotBlank(config.TokenLong__c)
      ? config.TokenLong__c
      : config.LastToken__c;
    if (String.isNotBlank(token)) {
      request.setHeader('Authorization', 'Bearer ' + token);
    }
    return new Http().send(request);
  }

  private static void ensureSuccess(HttpResponse response) {
    Integer statusCode = response.getStatusCode();
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    throw new MetaGraphException(
      'Meta Graph API returned ' + statusCode + ': ' + response.getBody()
    );
  }

  private static AdEnvelope parseAd(Map<String, Object> payload) {
    AdEnvelope ad = new AdEnvelope();
    ad.id = stringValue(payload.get('id'));
    ad.name = stringValue(payload.get('name'));
    ad.effectiveStatus = stringValue(payload.get('effective_status'));
    ad.createdTime = parseDatetime(stringValue(payload.get('created_time')));
    ad.updatedTime = parseDatetime(stringValue(payload.get('updated_time')));

    Map<String, Object> campaign = asMap(payload.get('campaign'));
    if (campaign != null) {
      ad.campaign = new CampaignEnvelope();
      ad.campaign.id = stringValue(campaign.get('id'));
      ad.campaign.name = stringValue(campaign.get('name'));
      ad.campaign.objective = stringValue(campaign.get('objective'));
      ad.campaign.status = stringValue(campaign.get('status'));
      ad.campaign.effectiveStatus = stringValue(
        campaign.get('effective_status')
      );
      ad.campaign.buyingType = stringValue(campaign.get('buying_type'));
      ad.campaign.bidStrategy = stringValue(campaign.get('bid_strategy'));
      ad.campaign.dailyBudget = centsToCurrency(campaign.get('daily_budget'));
      ad.campaign.lifetimeBudget = centsToCurrency(
        campaign.get('lifetime_budget')
      );
      ad.campaign.spendCap = centsToCurrency(campaign.get('spend_cap'));
      ad.campaign.startDate = parseDate(
        stringValue(campaign.get('start_time'))
      );
      ad.campaign.endDate = parseDate(stringValue(campaign.get('stop_time')));
      ad.campaign.createdTime = parseDatetime(
        stringValue(campaign.get('created_time'))
      );
      ad.campaign.updatedTime = parseDatetime(
        stringValue(campaign.get('updated_time'))
      );
      ad.campaign.accountId = stringValue(campaign.get('account_id'));
      ad.campaign.specialAdCategories = stringValue(
        campaign.get('special_ad_categories')
      );
    }

    Map<String, Object> adSet = asMap(payload.get('adset'));
    if (adSet != null) {
      ad.adSet = new AdSetEnvelope();
      ad.adSet.id = stringValue(adSet.get('id'));
      ad.adSet.name = stringValue(adSet.get('name'));
      ad.adSet.effectiveStatus = stringValue(adSet.get('effective_status'));
      ad.adSet.dailyBudget = centsToCurrency(adSet.get('daily_budget'));
      ad.adSet.lifetimeBudget = centsToCurrency(adSet.get('lifetime_budget'));
      ad.adSet.billingEvent = stringValue(adSet.get('billing_event'));
      ad.adSet.optimizationGoal = stringValue(adSet.get('optimization_goal'));
    }

    Map<String, Object> creative = asMap(payload.get('creative'));
    if (creative != null) {
      ad.creative = new CreativeEnvelope();
      ad.creative.id = stringValue(creative.get('id'));
      ad.creative.body = stringValue(creative.get('body'));
      ad.creative.title = stringValue(creative.get('title'));
      ad.creative.imageUrl = stringValue(creative.get('image_url'));
      ad.creative.thumbnailUrl = stringValue(creative.get('thumbnail_url'));
      ad.creative.videoId = stringValue(creative.get('video_id'));
    }
    return ad;
  }

  private static InsightsEnvelope parseInsights(Map<String, Object> payload) {
    InsightsEnvelope insights = new InsightsEnvelope();
    insights.spend = decimalValue(payload.get('spend'));
    insights.impressions = integerValue(payload.get('impressions'));
    insights.reach = integerValue(payload.get('reach'));
    insights.clicks = integerValue(payload.get('clicks'));
    insights.ctr = decimalValue(payload.get('ctr'));
    insights.cpc = decimalValue(payload.get('cpc'));
    insights.cpm = decimalValue(payload.get('cpm'));
    insights.frequency = decimalValue(payload.get('frequency'));
    insights.leads = integerValue(
      findActionValue((List<Object>) payload.get('actions'))
    );
    insights.costPerLead = decimalValue(
      findActionValue((List<Object>) payload.get('cost_per_action_type'))
    );
    return insights;
  }

  private static Object findActionValue(List<Object> actions) {
    if (actions == null) {
      return null;
    }
    Object fallback;
    for (Object actionObj : actions) {
      Map<String, Object> action = asMap(actionObj);
      if (action == null) {
        continue;
      }
      String actionType = stringValue(action.get('action_type'));
      if (actionType == 'onsite_conversion.messaging_first_reply') {
        return action.get('value');
      }
      if (actionType == 'lead') {
        fallback = action.get('value');
      }
    }
    return fallback;
  }

  private static Decimal centsToCurrency(Object value) {
    Decimal cents = decimalValue(value);
    return cents == null ? null : cents / 100;
  }

  private static Date parseDate(String value) {
    Datetime parsed = parseDatetime(value);
    return parsed == null ? null : parsed.date();
  }

  private static Datetime parseDatetime(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
    } catch (Exception ignored) {
      return null;
    }
  }

  private static Map<String, Object> asMap(Object value) {
    return value instanceof Map<String, Object>
      ? (Map<String, Object>) value
      : null;
  }

  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Decimal decimalValue(Object value) {
    return value == null || String.isBlank(String.valueOf(value))
      ? null
      : Decimal.valueOf(String.valueOf(value));
  }

  private static Integer integerValue(Object value) {
    return value == null || String.isBlank(String.valueOf(value))
      ? null
      : Integer.valueOf(String.valueOf(value));
  }
}
