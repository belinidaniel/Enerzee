/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaGraphApiServiceTest
 **/
/**
 * @description Atualiza insights agregados de Meta_Ad__c e rollup Campaign (Total_*).
 * @test : MetaGraphApiServiceTest
 */
public with sharing class MetaInsightsRefreshBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
  private final String datePreset;

  public MetaInsightsRefreshBatch(String datePreset) {
    this.datePreset = String.isBlank(datePreset) ? 'lifetime' : datePreset;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id, Meta_Ad_ID__c, Campaign__c
        FROM Meta_Ad__c
        WHERE Meta_Ad_ID__c != NULL
      ]
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Meta_Ad__c> scope
  ) {
    List<Meta_Ad__c> adsToUpdate = new List<Meta_Ad__c>();
    Map<Id, Campaign> campaignTotalsMap = new Map<Id, Campaign>();

    for (Meta_Ad__c adRecord : scope) {
      try {
        MetaGraphApiService.InsightsEnvelope insights = MetaGraphApiService.getInsights(
          adRecord.Meta_Ad_ID__c,
          datePreset
        );

        adRecord.Spend__c = insights.spend;
        adRecord.Impressions__c = insights.impressions;
        adRecord.Reach__c = insights.reach;
        adRecord.Clicks__c = insights.clicks;
        adRecord.CTR__c = insights.ctr;
        adRecord.CPC__c = insights.cpc;
        adRecord.CPM__c = insights.cpm;
        adRecord.Frequency__c = insights.frequency;
        adRecord.Leads_Generated__c = insights.leads;
        adRecord.Cost_Per_Lead__c = insights.costPerLead;
        adRecord.Insights_Last_Refreshed__c = System.now();
        adsToUpdate.add(adRecord);

        if (adRecord.Campaign__c != null) {
          accumulateCampaignTotals(
            campaignTotalsMap,
            adRecord.Campaign__c,
            insights
          );
        }
      } catch (Exception e) {
        Utils.createLog(
          'MetaInsightsRefreshBatch',
          'execute',
          e.getMessage(),
          adRecord.Id
        );
      }
    }

    if (!adsToUpdate.isEmpty()) {
      update adsToUpdate;
    }

    if (!campaignTotalsMap.isEmpty()) {
      updateCampaignTotals(campaignTotalsMap);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  private static void accumulateCampaignTotals(
    Map<Id, Campaign> totalsMap,
    Id campaignId,
    MetaGraphApiService.InsightsEnvelope insights
  ) {
    if (!totalsMap.containsKey(campaignId)) {
      Campaign c = new Campaign(Id = campaignId);
      c.Total_Spend__c = 0;
      c.Total_Impressions__c = 0;
      c.Total_Reach__c = 0;
      c.Total_Clicks__c = 0;
      c.Total_Leads__c = 0;
      totalsMap.put(campaignId, c);
    }
    Campaign c = totalsMap.get(campaignId);
    c.Total_Spend__c += insights.spend != null ? insights.spend : 0;
    c.Total_Impressions__c += insights.impressions != null
      ? insights.impressions
      : 0;
    c.Total_Reach__c += insights.reach != null ? insights.reach : 0;
    c.Total_Clicks__c += insights.clicks != null ? insights.clicks : 0;
    c.Total_Leads__c += insights.leads != null ? insights.leads : 0;
  }

  private static void updateCampaignTotals(Map<Id, Campaign> totalsMap) {
    List<Campaign> campaigns = totalsMap.values();
    for (Campaign c : campaigns) {
      c.Insights_Last_Refreshed__c = System.now();
      if (
        c.Total_Leads__c != null &&
        c.Total_Leads__c > 0 &&
        c.Total_Spend__c != null
      ) {
        c.Cost_Per_Lead__c = c.Total_Spend__c / c.Total_Leads__c;
      }
    }
    update campaigns;
  }
}
