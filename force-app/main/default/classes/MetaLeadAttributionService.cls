/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaLeadAttributionServiceTest
 **/
/**
 * @description Orquestra a criação normalizada de Lead, Anúncio, CampaignMember e histórico de touch.
 */
public without sharing class MetaLeadAttributionService {
  private static final String LEAD_SOURCE_AD = 'Anúncio';
  private static final String META_LEAD_YES = 'Sim';
  private static final String PLACEHOLDER_COMPANY = 'N/A';
  private static final String RECORD_TYPE_DEV_NAME = 'QualificacaodeClientes';

  private static Id leadRecordTypeId {
    get {
      if (leadRecordTypeId == null) {
        List<RecordType> rts = [
          SELECT Id
          FROM RecordType
          WHERE SObjectType = 'Lead' AND DeveloperName = :RECORD_TYPE_DEV_NAME
          LIMIT 1
        ];
        leadRecordTypeId = rts.isEmpty() ? null : rts[0].Id;
      }
      return leadRecordTypeId;
    }
    set;
  }

  public static void processRawPayload(String rawPayload) {
    List<MetaWebhookPayloadParser.MessageContext> contexts = MetaWebhookPayloadParser.parse(
      rawPayload
    );
    for (MetaWebhookPayloadParser.MessageContext context : contexts) {
      if (context == null) {
        continue;
      }
      processContext(context);
    }
  }

  @TestVisible
  static void processContext(MetaWebhookPayloadParser.MessageContext context) {
    if (!context.hasReferral()) {
      return;
    }

    Lead leadRecord = upsertLead(context);

    Meta_Ad__c adRecord = upsertAdPlaceholder(context);

    if (adRecord != null) {
      updateLeadTouches(leadRecord, adRecord, context);
      insertTouchIfMissing(leadRecord.Id, adRecord, context);

      if (adRecord.Campaign__c != null) {
        upsertCampaignMember(
          leadRecord.Id,
          adRecord.Campaign__c,
          adRecord.Id,
          context.ctwaClid
        );
      } else {
        publishEnrichmentRequest(
          adRecord.Meta_Ad_ID__c,
          leadRecord.Id,
          context.ctwaClid
        );
      }
    }
  }

  private static void publishEnrichmentRequest(
    String metaAdId,
    Id leadId,
    String ctwaClid
  ) {
    if (String.isBlank(metaAdId)) {
      return;
    }

    Database.SaveResult result = EventBus.publish(
      new Meta_Ad_Enrichment_Request__e(
        Meta_Ad_ID__c = metaAdId,
        Lead_ID__c = leadId != null ? String.valueOf(leadId) : null,
        CTWA_CLID__c = ctwaClid
      )
    );

    if (!result.isSuccess()) {
      Database.Error error = result.getErrors()[0];
      Utils.createLog(
        'MetaLeadAttributionService',
        'publishEnrichmentRequest',
        'Falha ao publicar evento de enriquecimento Meta Ads: ' +
        error.getMessage(),
        leadId != null ? String.valueOf(leadId) : null
      );
    }
  }

  private static Lead upsertLead(
    MetaWebhookPayloadParser.MessageContext context
  ) {
    Lead leadRecord = MetaAdsRepository.findLead(
      context.fromUserId,
      context.waId
    );
    Boolean isNew = leadRecord == null;
    if (isNew) {
      leadRecord = new Lead();
      leadRecord.Company = PLACEHOLDER_COMPANY;
      if (leadRecordTypeId != null) {
        leadRecord.RecordTypeId = leadRecordTypeId;
      }
    }

    applyName(leadRecord, context.profileName, context.senderPhone);
    leadRecord.MobilePhone = firstNonBlank(
      context.senderPhone,
      leadRecord.MobilePhone
    );
    leadRecord.Phone = firstNonBlank(context.senderPhone, leadRecord.Phone);
    leadRecord.LeadSource = LEAD_SOURCE_AD;
    leadRecord.MetaLead__c = META_LEAD_YES;
    leadRecord.WhatsApp_User_ID__c = firstNonBlank(
      context.fromUserId,
      leadRecord.WhatsApp_User_ID__c
    );
    leadRecord.WhatsApp_ID__c = firstNonBlank(
      context.waId,
      leadRecord.WhatsApp_ID__c
    );
    leadRecord.Meta_CTWA_CLID__c = firstNonBlank(
      context.ctwaClid,
      leadRecord.Meta_CTWA_CLID__c
    );
    leadRecord.AdSourceUrl__c = firstNonBlank(
      context.sourceUrl,
      leadRecord.AdSourceUrl__c
    );
    leadRecord.Welcome_Message__c = firstNonBlank(
      context.welcomeMessage,
      leadRecord.Welcome_Message__c
    );
    leadRecord.Meta_Ad_ID__c = firstNonBlank(
      context.sourceId,
      leadRecord.Meta_Ad_ID__c
    );
    leadRecord.Nome_do_An_ncio_Meta__c = firstNonBlank(
      context.headline,
      leadRecord.Nome_do_An_ncio_Meta__c
    );

    if (isNew) {
      insert leadRecord;
    } else {
      update leadRecord;
    }
    return leadRecord;
  }

  private static Meta_Ad__c upsertAdPlaceholder(
    MetaWebhookPayloadParser.MessageContext context
  ) {
    if (String.isBlank(context.sourceId)) {
      return null;
    }

    Meta_Ad__c adRecord = MetaAdsRepository.findAdByMetaId(context.sourceId);
    Boolean isNew = adRecord == null;
    if (isNew) {
      adRecord = new Meta_Ad__c();
      adRecord.Meta_Ad_ID__c = context.sourceId;
      adRecord.Name = firstNonBlank(
        context.headline,
        'Meta Ad ' + context.sourceId
      );
      adRecord.Enrichment_Status__c = 'Pending';
    }

    adRecord.Creative_Headline__c = firstNonBlank(
      context.headline,
      adRecord.Creative_Headline__c
    );
    adRecord.Creative_Body__c = firstNonBlank(
      context.body,
      adRecord.Creative_Body__c
    );
    adRecord.Creative_Video_URL__c = firstNonBlank(
      context.videoUrl,
      adRecord.Creative_Video_URL__c
    );
    adRecord.Creative_Thumbnail_URL__c = firstNonBlank(
      context.thumbnailUrl,
      adRecord.Creative_Thumbnail_URL__c
    );
    adRecord.Source_URL__c = firstNonBlank(
      context.sourceUrl,
      adRecord.Source_URL__c
    );
    adRecord.Media_Type__c = firstNonBlank(
      context.mediaType,
      adRecord.Media_Type__c
    );
    adRecord.Source_Type__c = firstNonBlank(
      context.sourceType,
      adRecord.Source_Type__c
    );

    if (isNew) {
      insert adRecord;
    } else {
      update adRecord;
    }
    return adRecord;
  }

  private static void updateLeadTouches(
    Lead leadRecord,
    Meta_Ad__c adRecord,
    MetaWebhookPayloadParser.MessageContext context
  ) {
    Boolean shouldUpdate = false;
    if (leadRecord.First_Touch_Ad__c == null) {
      leadRecord.First_Touch_Ad__c = adRecord.Id;
      leadRecord.First_Touch_Date__c = context.messageDatetime;
      shouldUpdate = true;
    }
    leadRecord.Last_Touch_Ad__c = adRecord.Id;
    leadRecord.Last_Touch_Date__c = context.messageDatetime;
    shouldUpdate = true;

    if (shouldUpdate) {
      update leadRecord;
    }
  }

  private static void insertTouchIfMissing(
    Id leadId,
    Meta_Ad__c adRecord,
    MetaWebhookPayloadParser.MessageContext context
  ) {
    List<Lead_Touch__c> existing = [
      SELECT Id
      FROM Lead_Touch__c
      WHERE
        Lead__c = :leadId
        AND Meta_Ad__c = :adRecord.Id
        AND CTWA_CLID__c = :context.ctwaClid
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return;
    }

    insert new Lead_Touch__c(
      Lead__c = leadId,
      Campaign__c = adRecord.Campaign__c,
      Meta_AdSet__c = adRecord.Meta_AdSet__c,
      Meta_Ad__c = adRecord.Id,
      CTWA_CLID__c = context.ctwaClid,
      Touch_Date__c = context.messageDatetime,
      Source__c = 'WhatsApp CTWA'
    );
  }

  public static void upsertCampaignMember(
    Id leadId,
    Id campaignId,
    Id adId,
    String ctwaClid
  ) {
    if (leadId == null || campaignId == null) {
      return;
    }

    List<CampaignMember> members = [
      SELECT Id, Meta_Ad__c, First_Referral_CTWA_CLID__c
      FROM CampaignMember
      WHERE LeadId = :leadId AND CampaignId = :campaignId
      LIMIT 1
    ];

    if (members.isEmpty()) {
      insert new CampaignMember(
        LeadId = leadId,
        CampaignId = campaignId,
        Meta_Ad__c = adId,
        First_Referral_CTWA_CLID__c = ctwaClid
      );
      return;
    }

    CampaignMember member = members[0];
    if (member.Meta_Ad__c == null) {
      member.Meta_Ad__c = adId;
    }
    if (String.isBlank(member.First_Referral_CTWA_CLID__c)) {
      member.First_Referral_CTWA_CLID__c = ctwaClid;
    }
    update member;
  }

  private static void applyName(
    Lead leadRecord,
    String fullName,
    String fallbackPhone
  ) {
    if (String.isBlank(fullName)) {
      if (String.isBlank(leadRecord.LastName)) {
        leadRecord.LastName = 'WhatsApp ' + fallbackPhone;
      }
      return;
    }

    List<String> tokens = fullName.trim().split('\\s+');
    if (tokens.size() == 1) {
      leadRecord.FirstName = null;
      leadRecord.LastName = tokens[0];
    } else {
      leadRecord.FirstName = tokens[0];
      List<String> lastNameTokens = new List<String>();
      for (Integer i = 1; i < tokens.size(); i++) {
        lastNameTokens.add(tokens[i]);
      }
      leadRecord.LastName = String.join(lastNameTokens, ' ');
    }
  }

  private static String firstNonBlank(String preferred, String fallbackValue) {
    return String.isBlank(preferred) ? fallbackValue : preferred;
  }
}
