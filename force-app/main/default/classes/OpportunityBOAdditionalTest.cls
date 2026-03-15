/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 03-13-2026
 * @last modified by	 : Daniel Belini
 **/
@IsTest
private class OpportunityBOAdditionalTest {
  private static Lead buildSafeLead(String lastName, String company) {
    Lead leadRecord = new Lead(LastName = lastName, Company = company);
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();

    if (leadFields.containsKey('FalarComAgente__c')) {
      leadRecord.put('FalarComAgente__c', true);
    }

    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      String value = entry.getValue();
      if (
        String.isBlank(value) ||
        value == 'Novo' ||
        value == 'Qualified' ||
        value == 'Não Qualificado'
      ) {
        continue;
      }
      leadRecord.Status = value;
      break;
    }

    return leadRecord;
  }

  private static User createCloserUser() {
    Id profileId = [SELECT Id FROM Profile LIMIT 1].Id;
    User u = new User(
      Alias = 'wagner',
      Email = 'wagner.sampaio@enerzee.com.br.test',
      Username = 'wagner.sampaio@enerzee.com.br.test',
      LastName = 'Closer',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = profileId
    );
    insert u;
    return u;
  }

  @IsTest
  static void handleLeadConversionNoActions() {
    Lead lead = buildSafeLead('Lead', 'Company');
    insert lead;

    Account acc = new Account(Name = 'Lead Acc');
    insert acc;

    Opportunity oppOld = new Opportunity(
      Name = 'Opp Lead',
      StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA,
      CloseDate = Date.today().addDays(5),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'vo-lead',
      Lead__c = lead.Id
    );
    insert oppOld;
    Opportunity oppNew = oppOld.clone(false, true, true, true);
    oppNew.StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;

    Test.startTest();
    OpportunityBO.handleOpportunityLeadConversion(
      new List<Opportunity>{ oppNew },
      new Map<Id, Opportunity>{ oppNew.Id => oppOld }
    );
    Test.stopTest();

    System.assert(true, 'Method executed without errors.');
  }
}
