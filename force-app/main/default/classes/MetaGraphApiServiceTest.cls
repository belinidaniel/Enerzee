/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MetaGraphApiServiceTest {
  private static void stubMetaConfig() {
    MetaGraphApiService.testConfig = new Integrador__mdt(
      URL__c = 'https://graph.facebook.com/v25.0',
      LastToken__c = 'TEST_TOKEN',
      TokenLong__c = null
    );
  }

  private class MetaMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');

      if (request.getEndpoint().contains('/insights')) {
        response.setStatusCode(200);
        response.setBody(
          '{"data":[{"spend":"127.45","impressions":"1000","reach":"800","clicks":"25","ctr":"2.5","cpc":"5.10","cpm":"127.45","frequency":"1.25","actions":[{"action_type":"onsite_conversion.messaging_first_reply","value":"8"}],"cost_per_action_type":[{"action_type":"onsite_conversion.messaging_first_reply","value":"15.93"}]}]}'
        );
        return response;
      }

      response.setStatusCode(200);
      response.setBody(
        '{"id":"120247934274870536","name":"Enerzee CTWA Ad","effective_status":"ACTIVE","created_time":"2026-04-01T10:00:00+0000","updated_time":"2026-04-02T10:00:00+0000","campaign":{"id":"238000111222","name":"Campanha Meta Energia Solar","objective":"OUTCOME_ENGAGEMENT","status":"ACTIVE","effective_status":"ACTIVE","buying_type":"AUCTION","bid_strategy":"LOWEST_COST_WITHOUT_CAP","daily_budget":"5000","lifetime_budget":"100000","spend_cap":"150000","start_time":"2026-04-01T00:00:00+0000","stop_time":"2026-04-30T23:59:59+0000","created_time":"2026-03-30T10:00:00+0000","updated_time":"2026-04-01T10:00:00+0000","account_id":"act_123","special_ad_categories":"[]"},"adset":{"id":"238000333444","name":"AdSet WhatsApp Cuiaba","effective_status":"ACTIVE","daily_budget":"5000","lifetime_budget":"100000","billing_event":"IMPRESSIONS","optimization_goal":"CONVERSATIONS"},"creative":{"id":"999888777","body":"Economize com energia solar","title":"Enerzee Solar","image_url":"https://example.com/image.jpg","thumbnail_url":"https://example.com/thumb.jpg","video_id":"vid123"}}'
      );
      return response;
    }
  }

  @IsTest
  static void parsesAdAndInsightsResponses() {
    stubMetaConfig();
    Test.setMock(HttpCalloutMock.class, new MetaMock());

    Test.startTest();
    MetaGraphApiService.AdEnvelope ad = MetaGraphApiService.getAd(
      '120247934274870536'
    );
    MetaGraphApiService.InsightsEnvelope insights = MetaGraphApiService.getInsights(
      '120247934274870536',
      'lifetime'
    );
    Test.stopTest();

    Assert.areEqual('120247934274870536', ad.id);
    Assert.areEqual('238000111222', ad.campaign.id);
    Assert.areEqual(50, ad.campaign.dailyBudget);
    Assert.areEqual('238000333444', ad.adSet.id);
    Assert.areEqual('999888777', ad.creative.id);
    Assert.areEqual(127.45, insights.spend);
    Assert.areEqual(8, insights.leads);
    Assert.areEqual(15.93, insights.costPerLead);
  }

  @IsTest
  static void enrichmentQueueableCreatesHierarchyAndMember() {
    stubMetaConfig();
    Test.setMock(HttpCalloutMock.class, new MetaMock());

    Lead leadRecord = new Lead(
      LastName = 'Cliente Meta',
      Company = 'N/A',
      MobilePhone = '5511999990000',
      LeadSource = 'Anúncio'
    );
    insert leadRecord;

    Meta_Ad__c adRecord = new Meta_Ad__c(
      Name = 'Placeholder',
      Meta_Ad_ID__c = '120247934274870536',
      Enrichment_Status__c = 'Pending'
    );
    insert adRecord;

    Test.startTest();
    System.enqueueJob(
      new MetaAdEnrichmentQueueable(
        '120247934274870536',
        leadRecord.Id,
        'CTWA_TEST'
      )
    );
    Test.stopTest();

    Meta_Ad__c enriched = [
      SELECT
        Campaign__c,
        Meta_AdSet__c,
        Creative_Headline__c,
        Enrichment_Status__c
      FROM Meta_Ad__c
      WHERE Id = :adRecord.Id
    ];
    Assert.areEqual(
      'Enriched',
      enriched.Enrichment_Status__c,
      'Erro no Queueable: ' + MetaAdEnrichmentQueueable.lastErrorMessage
    );
    Assert.isNotNull(enriched.Campaign__c);
    Assert.isNotNull(enriched.Meta_AdSet__c);
    Assert.areEqual('Enerzee Solar', enriched.Creative_Headline__c);

    List<CampaignMember> members = [
      SELECT Id, Meta_Ad__c, First_Referral_CTWA_CLID__c
      FROM CampaignMember
      WHERE LeadId = :leadRecord.Id
    ];
    Assert.areEqual(1, members.size());
    Assert.areEqual(adRecord.Id, members[0].Meta_Ad__c);
    Assert.areEqual('CTWA_TEST', members[0].First_Referral_CTWA_CLID__c);

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Log__c WHERE RelatedId__c = :leadRecord.Id]
    );
  }

  @IsTest
  static void enrichmentPlatformEventRunsQueueableOutsidePublisherContext() {
    stubMetaConfig();
    Test.setMock(HttpCalloutMock.class, new MetaMock());

    Lead leadRecord = new Lead(
      LastName = 'Cliente Evento',
      Company = 'N/A',
      MobilePhone = '5511999993333',
      LeadSource = 'Anúncio'
    );
    insert leadRecord;

    Meta_Ad__c adRecord = new Meta_Ad__c(
      Name = 'Placeholder Evento',
      Meta_Ad_ID__c = '120247934274870536',
      Enrichment_Status__c = 'Pending'
    );
    insert adRecord;

    Test.startTest();
    EventBus.publish(
      new Meta_Ad_Enrichment_Request__e(
        Meta_Ad_ID__c = '120247934274870536',
        Lead_ID__c = String.valueOf(leadRecord.Id),
        CTWA_CLID__c = 'CTWA_EVENT'
      )
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Meta_Ad__c enriched = [
      SELECT Campaign__c, Meta_AdSet__c, Enrichment_Status__c
      FROM Meta_Ad__c
      WHERE Id = :adRecord.Id
    ];
    Assert.areEqual(
      'Enriched',
      enriched.Enrichment_Status__c,
      'Erro no Queueable via Platform Event: ' +
      MetaAdEnrichmentQueueable.lastErrorMessage
    );
    Assert.isNotNull(enriched.Campaign__c);
    Assert.isNotNull(enriched.Meta_AdSet__c);

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM CampaignMember
        WHERE LeadId = :leadRecord.Id AND Meta_Ad__c = :adRecord.Id
      ]
    );
  }

  @IsTest
  static void insightsBatchUpdatesAdAndCampaignTotals() {
    stubMetaConfig();
    Test.setMock(HttpCalloutMock.class, new MetaMock());

    Campaign campaign = new Campaign(Name = 'Campanha Batch Test');
    insert campaign;

    Meta_Ad__c adRecord = new Meta_Ad__c(
      Name = 'Ad com Métricas',
      Meta_Ad_ID__c = '120247934274870536',
      Campaign__c = campaign.Id,
      Enrichment_Status__c = 'Enriched'
    );
    insert adRecord;

    Test.startTest();
    Database.executeBatch(new MetaInsightsRefreshBatch('lifetime'), 1);
    Test.stopTest();

    Meta_Ad__c updatedAd = [
      SELECT
        Spend__c,
        Impressions__c,
        Reach__c,
        Clicks__c,
        Leads_Generated__c,
        Cost_Per_Lead__c
      FROM Meta_Ad__c
      WHERE Id = :adRecord.Id
    ];
    Assert.areEqual(127.45, updatedAd.Spend__c);
    Assert.areEqual(1000, updatedAd.Impressions__c);
    Assert.areEqual(800, updatedAd.Reach__c);
    Assert.areEqual(25, updatedAd.Clicks__c);
    Assert.areEqual(8, updatedAd.Leads_Generated__c);
    Assert.areEqual(15.93, updatedAd.Cost_Per_Lead__c);

    Campaign updatedCampaign = [
      SELECT
        Total_Spend__c,
        Total_Impressions__c,
        Total_Reach__c,
        Total_Clicks__c,
        Total_Leads__c,
        Cost_Per_Lead__c
      FROM Campaign
      WHERE Id = :campaign.Id
    ];
    Assert.areEqual(
      127.45,
      updatedCampaign.Total_Spend__c,
      'Campaign Total_Spend__c deve ser 127.45'
    );
    Assert.areEqual(
      1000,
      updatedCampaign.Total_Impressions__c,
      'Campaign Total_Impressions__c deve ser 1000'
    );
    Assert.areEqual(
      8,
      updatedCampaign.Total_Leads__c,
      'Campaign Total_Leads__c deve ser 8'
    );
    Assert.isNotNull(
      updatedCampaign.Cost_Per_Lead__c,
      'Campaign Cost_Per_Lead__c deve ser calculado'
    );
  }

  @IsTest
  static void schedulableStartsBatch() {
    stubMetaConfig();
    Test.setMock(HttpCalloutMock.class, new MetaMock());
    insert new Meta_Ad__c(
      Name = 'Ad agendado',
      Meta_Ad_ID__c = '120247934274870536',
      Enrichment_Status__c = 'Enriched'
    );

    Test.startTest();
    new MetaInsightsRefreshSchedulable().execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Meta_Ad__c WHERE Spend__c = 127.45]
    );
  }
}
