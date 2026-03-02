@IsTest
private class OpportunityRecordsTOTest {
  @IsTest
  static void shouldBuildNestedPayload() {
    OpportunityRecordsTO.SingleOpportunity opp = new OpportunityRecordsTO.SingleOpportunity();
    opp.Id = 'opp-1';
    opp.PartnerName = 'Parceiro';
    opp.StageName = 'Prospecting';
    opp.Products = new List<OpportunityRecordsTO.Product>{};
    opp.Client = new OpportunityRecordsTO.Client();
    opp.Client.Email = 'cliente@teste.com';

    OpportunityRecordsTO.Opportunities wrapper = new OpportunityRecordsTO.Opportunities();
    wrapper.SingleOpportunity = new List<OpportunityRecordsTO.SingleOpportunity>{
      opp
    };

    String jsonBody = JSON.serialize(wrapper);
    System.assert(jsonBody.contains('PartnerName'));
    System.assert(jsonBody.contains('cliente@teste.com'));
  }
}
