/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaGraphApiServiceTest
 **/
/**
 * @description Enriquece o anúncio CTWA com Campaign, AdSet e Creative da Meta Graph API.
 * @test : MetaGraphApiServiceTest
 */
public without sharing class MetaAdEnrichmentQueueable implements Queueable, Database.AllowsCallouts {
  @TestVisible
  static String lastErrorMessage;

  private final String metaAdId;
  private final Id leadId;
  private final String ctwaClid;

  public MetaAdEnrichmentQueueable(
    String metaAdId,
    Id leadId,
    String ctwaClid
  ) {
    this.metaAdId = metaAdId;
    this.leadId = leadId;
    this.ctwaClid = ctwaClid;
  }

  public void execute(QueueableContext context) {
    if (String.isBlank(metaAdId)) {
      return;
    }

    try {
      MetaGraphApiService.AdEnvelope adEnvelope = MetaGraphApiService.getAd(
        metaAdId
      );
      if (adEnvelope == null) {
        markAdAsDeleted();
        return;
      }

      Campaign campaign = upsertCampaign(adEnvelope.campaign);
      Meta_AdSet__c adSet = upsertAdSet(adEnvelope.adSet, campaign);
      Meta_Ad__c adRecord = upsertAd(adEnvelope, campaign, adSet);

      if (leadId != null && campaign != null) {
        MetaLeadAttributionService.upsertCampaignMember(
          leadId,
          campaign.Id,
          adRecord.Id,
          ctwaClid
        );
        updateTouchWithHierarchy(
          adRecord,
          campaign.Id,
          adSet != null ? adSet.Id : null
        );
        updateLeadMetaIds(adEnvelope, campaign, adSet);
      }

      Utils.createLog(
        'MetaAdEnrichmentQueueable',
        'execute',
        'Enriquecimento concluído — Ad: ' +
          metaAdId +
          (campaign != null ? ' | Campaign: ' + campaign.Id : ''),
        leadId
      );
    } catch (Exception e) {
      lastErrorMessage = e.getMessage();
      Utils.createLog('MetaAdEnrichmentQueueable', 'execute', e);
    }
  }

  private Campaign upsertCampaign(
    MetaGraphApiService.CampaignEnvelope envelope
  ) {
    if (envelope == null || String.isBlank(envelope.id)) {
      return null;
    }

    Campaign campaign = MetaAdsRepository.findCampaignByMetaId(envelope.id);
    Boolean isNew = campaign == null;
    if (isNew) {
      campaign = new Campaign();
      campaign.Meta_Campaign_ID__c = envelope.id;
    }

    campaign.Name = truncate(
      firstNonBlank(envelope.name, 'Meta Campaign ' + envelope.id),
      80
    );
    campaign.IsActive = envelope.effectiveStatus == 'ACTIVE';
    campaign.StartDate = envelope.startDate;
    campaign.EndDate = envelope.endDate;
    campaign.Meta_Account_ID__c = envelope.accountId;
    campaign.Meta_Objective__c = envelope.objective;
    campaign.Meta_Buying_Type__c = envelope.buyingType;
    campaign.Meta_Bid_Strategy__c = envelope.bidStrategy;
    campaign.Meta_Daily_Budget__c = envelope.dailyBudget;
    campaign.Meta_Lifetime_Budget__c = envelope.lifetimeBudget;
    campaign.Meta_Spend_Cap__c = envelope.spendCap;
    campaign.Meta_Effective_Status__c = envelope.effectiveStatus;
    campaign.Meta_Special_Ad_Categories__c = truncate(
      envelope.specialAdCategories,
      255
    );
    campaign.Meta_Created_Time__c = envelope.createdTime;
    campaign.Meta_Updated_Time__c = envelope.updatedTime;

    if (isNew) {
      insert campaign;
    } else {
      update campaign;
    }
    return campaign;
  }

  private Meta_AdSet__c upsertAdSet(
    MetaGraphApiService.AdSetEnvelope envelope,
    Campaign campaign
  ) {
    if (envelope == null || String.isBlank(envelope.id)) {
      return null;
    }

    Meta_AdSet__c adSet = MetaAdsRepository.findAdSetByMetaId(envelope.id);
    Boolean isNew = adSet == null;
    if (isNew) {
      adSet = new Meta_AdSet__c();
      adSet.Meta_AdSet_ID__c = envelope.id;
    }

    adSet.Name = truncate(
      firstNonBlank(envelope.name, 'Meta AdSet ' + envelope.id),
      80
    );
    adSet.Campaign__c = campaign != null ? campaign.Id : null;
    adSet.Meta_Effective_Status__c = envelope.effectiveStatus;
    adSet.Meta_Daily_Budget__c = envelope.dailyBudget;
    adSet.Meta_Lifetime_Budget__c = envelope.lifetimeBudget;
    adSet.Meta_Billing_Event__c = envelope.billingEvent;
    adSet.Meta_Optimization_Goal__c = envelope.optimizationGoal;

    if (isNew) {
      insert adSet;
    } else {
      update adSet;
    }
    return adSet;
  }

  private Meta_Ad__c upsertAd(
    MetaGraphApiService.AdEnvelope envelope,
    Campaign campaign,
    Meta_AdSet__c adSet
  ) {
    Meta_Ad__c adRecord = MetaAdsRepository.findAdByMetaId(envelope.id);
    Boolean isNew = adRecord == null;
    if (isNew) {
      adRecord = new Meta_Ad__c();
      adRecord.Meta_Ad_ID__c = envelope.id;
    }

    adRecord.Name = truncate(
      firstNonBlank(envelope.name, 'Meta Ad ' + envelope.id),
      80
    );
    adRecord.Campaign__c = campaign != null ? campaign.Id : null;
    adRecord.Meta_AdSet__c = adSet != null ? adSet.Id : null;
    adRecord.Meta_Effective_Status__c = envelope.effectiveStatus;
    adRecord.Meta_Created_Time__c = envelope.createdTime;
    adRecord.Meta_Updated_Time__c = envelope.updatedTime;
    adRecord.Enrichment_Status__c = 'Enriched';

    if (envelope.creative != null) {
      adRecord.Creative_Body__c = firstNonBlank(
        adRecord.Creative_Body__c,
        envelope.creative.body
      );
      adRecord.Creative_Headline__c = firstNonBlank(
        adRecord.Creative_Headline__c,
        envelope.creative.title
      );
      adRecord.Creative_Image_URL__c = envelope.creative.imageUrl;
      adRecord.Creative_Thumbnail_URL__c = firstNonBlank(
        adRecord.Creative_Thumbnail_URL__c,
        envelope.creative.thumbnailUrl
      );
      adRecord.Meta_Creative_ID__c = envelope.creative.id;
      adRecord.Meta_Video_ID__c = envelope.creative.videoId;
    }

    if (isNew) {
      insert adRecord;
    } else {
      update adRecord;
    }
    return adRecord;
  }

  private void markAdAsDeleted() {
    Meta_Ad__c adRecord = MetaAdsRepository.findAdByMetaId(metaAdId);
    if (adRecord == null) {
      adRecord = new Meta_Ad__c(
        Name = truncate('Meta Ad ' + metaAdId, 80),
        Meta_Ad_ID__c = metaAdId
      );
      insert adRecord;
    }
    adRecord.Meta_Effective_Status__c = 'DELETED';
    adRecord.Enrichment_Status__c = 'Failed_Not_Found';
    update adRecord;
  }

  private void updateTouchWithHierarchy(
    Meta_Ad__c adRecord,
    Id campaignId,
    Id adSetId
  ) {
    List<Lead_Touch__c> touches = [
      SELECT Id, Campaign__c, Meta_AdSet__c
      FROM Lead_Touch__c
      WHERE
        Lead__c = :leadId
        AND Meta_Ad__c = :adRecord.Id
        AND CTWA_CLID__c = :ctwaClid
      LIMIT 1
    ];
    if (touches.isEmpty()) {
      return;
    }
    Lead_Touch__c touch = touches[0];
    touch.Campaign__c = campaignId;
    touch.Meta_AdSet__c = adSetId;
    update touch;
  }

  private void updateLeadMetaIds(
    MetaGraphApiService.AdEnvelope adEnvelope,
    Campaign campaign,
    Meta_AdSet__c adSet
  ) {
    Lead leadRecord = new Lead(Id = leadId);
    leadRecord.Meta_Ad_ID__c = adEnvelope.id;
    leadRecord.Nome_do_An_ncio_Meta__c = truncate(adEnvelope.name, 255);
    if (campaign != null && adEnvelope.campaign != null) {
      leadRecord.Meta_Campaign_ID__c = adEnvelope.campaign.id;
      leadRecord.Nome_da_Campanha_Meta__c = truncate(
        adEnvelope.campaign.name,
        255
      );
    }
    if (adSet != null && adEnvelope.adSet != null) {
      leadRecord.Meta_AdSet_ID__c = adEnvelope.adSet.id;
      leadRecord.Nome_do_Conjunto_de_An_ncios_Meta__c = truncate(
        adEnvelope.adSet.name,
        255
      );
    }
    update leadRecord;
  }

  private static String firstNonBlank(String preferred, String fallbackValue) {
    return String.isBlank(preferred) ? fallbackValue : preferred;
  }

  private static String truncate(String value, Integer maxLength) {
    if (String.isBlank(value) || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}
