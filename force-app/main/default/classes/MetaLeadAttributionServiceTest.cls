/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MetaLeadAttributionServiceTest {
  @IsTest
  static void processesReferralWithoutAdIdAsLeadOnly() {
    MetaWebhookPayloadParser.MessageContext context = new MetaWebhookPayloadParser.MessageContext();
    context.senderPhone = '551188887777';
    context.waId = '551188887777';
    context.fromUserId = 'BR.TEST.USER';
    context.profileName = 'Maria Energia Solar';
    context.ctwaClid = 'CTWA_ONLY_LEAD';
    context.sourceUrl = 'https://example.com/source';
    context.messageDatetime = System.now();

    Test.startTest();
    MetaLeadAttributionService.processContext(context);
    Test.stopTest();

    Lead leadRecord = [
      SELECT
        FirstName,
        LastName,
        WhatsApp_User_ID__c,
        WhatsApp_ID__c,
        Meta_CTWA_CLID__c
      FROM Lead
      WHERE WhatsApp_User_ID__c = 'BR.TEST.USER'
      LIMIT 1
    ];
    Assert.areEqual('Maria', leadRecord.FirstName);
    Assert.areEqual('Energia Solar', leadRecord.LastName);
    Assert.areEqual('551188887777', leadRecord.WhatsApp_ID__c);
    Assert.areEqual('CTWA_ONLY_LEAD', leadRecord.Meta_CTWA_CLID__c);
    Assert.areEqual(0, [SELECT COUNT() FROM Meta_Ad__c]);
  }

  @IsTest
  static void campaignMemberUpsertIsIdempotent() {
    Lead leadRecord = new Lead(
      LastName = 'Cliente',
      Company = 'N/A',
      MobilePhone = '551177776666',
      LeadSource = 'Anúncio'
    );
    insert leadRecord;

    Campaign campaign = new Campaign(Name = 'Campanha Teste');
    insert campaign;

    Meta_Ad__c adRecord = new Meta_Ad__c(
      Name = 'Anúncio Teste',
      Meta_Ad_ID__c = 'AD_IDEMPOTENT',
      Campaign__c = campaign.Id,
      Enrichment_Status__c = 'Enriched'
    );
    insert adRecord;

    Test.startTest();
    MetaLeadAttributionService.upsertCampaignMember(
      leadRecord.Id,
      campaign.Id,
      adRecord.Id,
      'CTWA_ONE'
    );
    MetaLeadAttributionService.upsertCampaignMember(
      leadRecord.Id,
      campaign.Id,
      adRecord.Id,
      'CTWA_TWO'
    );
    Test.stopTest();

    List<CampaignMember> members = [
      SELECT Id, Meta_Ad__c, First_Referral_CTWA_CLID__c
      FROM CampaignMember
      WHERE LeadId = :leadRecord.Id AND CampaignId = :campaign.Id
    ];
    Assert.areEqual(1, members.size());
    Assert.areEqual(adRecord.Id, members[0].Meta_Ad__c);
    Assert.areEqual('CTWA_ONE', members[0].First_Referral_CTWA_CLID__c);
  }
}
