/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaGraphApiServiceTest, MetaLeadAttributionServiceTest
 **/
/**
 * @description Repositório para persistência normalizada de Meta Ads.
 */
public without sharing class MetaAdsRepository {
  public static Lead findLead(String fromUserId, String waId) {
    if (!String.isBlank(fromUserId)) {
      List<Lead> leads = [
        SELECT
          Id,
          FirstName,
          LastName,
          Company,
          Phone,
          MobilePhone,
          LeadSource,
          WhatsApp_User_ID__c,
          WhatsApp_ID__c,
          CtwaClid__c,
          Meta_CTWA_CLID__c,
          First_Touch_Ad__c,
          First_Touch_Date__c,
          Last_Touch_Ad__c,
          Last_Touch_Date__c,
          Welcome_Message__c,
          MetaLead__c,
          AdSourceUrl__c,
          Meta_Ad_ID__c,
          Nome_do_An_ncio_Meta__c,
          Nome_da_Campanha_Meta__c,
          Nome_do_Conjunto_de_An_ncios_Meta__c,
          Meta_Campaign_ID__c,
          Meta_AdSet_ID__c
        FROM Lead
        WHERE WhatsApp_User_ID__c = :fromUserId
        LIMIT 1
      ];
      if (!leads.isEmpty()) {
        return leads[0];
      }
    }

    if (!String.isBlank(waId)) {
      List<Lead> leads = [
        SELECT
          Id,
          FirstName,
          LastName,
          Company,
          Phone,
          MobilePhone,
          LeadSource,
          WhatsApp_User_ID__c,
          WhatsApp_ID__c,
          CtwaClid__c,
          Meta_CTWA_CLID__c,
          First_Touch_Ad__c,
          First_Touch_Date__c,
          Last_Touch_Ad__c,
          Last_Touch_Date__c,
          Welcome_Message__c,
          MetaLead__c,
          AdSourceUrl__c,
          Meta_Ad_ID__c,
          Nome_do_An_ncio_Meta__c,
          Nome_da_Campanha_Meta__c,
          Nome_do_Conjunto_de_An_ncios_Meta__c,
          Meta_Campaign_ID__c,
          Meta_AdSet_ID__c
        FROM Lead
        WHERE WhatsApp_ID__c = :waId
        LIMIT 1
      ];
      if (!leads.isEmpty()) {
        return leads[0];
      }
    }

    // fallback: busca por MobilePhone para evitar duplicatas quando os campos
    // WhatsApp_*_ID__c ainda não foram preenchidos no registro existente
    String phone = !String.isBlank(waId) ? waId : fromUserId;
    if (!String.isBlank(phone)) {
      List<Lead> leads = [
        SELECT
          Id,
          FirstName,
          LastName,
          Company,
          Phone,
          MobilePhone,
          LeadSource,
          WhatsApp_User_ID__c,
          WhatsApp_ID__c,
          CtwaClid__c,
          Meta_CTWA_CLID__c,
          First_Touch_Ad__c,
          First_Touch_Date__c,
          Last_Touch_Ad__c,
          Last_Touch_Date__c,
          Welcome_Message__c,
          MetaLead__c,
          AdSourceUrl__c,
          Meta_Ad_ID__c,
          Nome_do_An_ncio_Meta__c,
          Nome_da_Campanha_Meta__c,
          Nome_do_Conjunto_de_An_ncios_Meta__c,
          Meta_Campaign_ID__c,
          Meta_AdSet_ID__c
        FROM Lead
        WHERE MobilePhone = :phone
        LIMIT 1
      ];
      if (!leads.isEmpty()) {
        return leads[0];
      }
    }

    return null;
  }

  public static Meta_Ad__c findAdByMetaId(String metaAdId) {
    if (String.isBlank(metaAdId)) {
      return null;
    }
    List<Meta_Ad__c> ads = [
      SELECT
        Id,
        Campaign__c,
        Meta_AdSet__c,
        Meta_Ad_ID__c,
        Enrichment_Status__c,
        Creative_Body__c,
        Creative_Headline__c,
        Creative_Video_URL__c,
        Creative_Thumbnail_URL__c,
        Source_URL__c,
        Media_Type__c,
        Source_Type__c
      FROM Meta_Ad__c
      WHERE Meta_Ad_ID__c = :metaAdId
      LIMIT 1
    ];
    return ads.isEmpty() ? null : ads[0];
  }

  public static Campaign findCampaignByMetaId(String metaCampaignId) {
    if (String.isBlank(metaCampaignId)) {
      return null;
    }
    List<Campaign> campaigns = [
      SELECT Id, Meta_Campaign_ID__c
      FROM Campaign
      WHERE Meta_Campaign_ID__c = :metaCampaignId
      LIMIT 1
    ];
    return campaigns.isEmpty() ? null : campaigns[0];
  }

  public static Meta_AdSet__c findAdSetByMetaId(String metaAdSetId) {
    if (String.isBlank(metaAdSetId)) {
      return null;
    }
    List<Meta_AdSet__c> adSets = [
      SELECT Id, Meta_AdSet_ID__c
      FROM Meta_AdSet__c
      WHERE Meta_AdSet_ID__c = :metaAdSetId
      LIMIT 1
    ];
    return adSets.isEmpty() ? null : adSets[0];
  }
}
