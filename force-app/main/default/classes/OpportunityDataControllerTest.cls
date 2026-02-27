@IsTest
public class OpportunityDataControllerTest {
  @IsTest
  static void testGenerateOpportunityChartImage() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    opportunity testOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.id,
        MunicipioInstalacao__c = 'São Paulo'
      ),
      true
    );

    ApexPages.StandardController sc = new ApexPages.StandardController(
      testOpportunity
    );
    OpportunityDataController controller = new OpportunityDataController(sc);

    String chartImageUrl = controller.getOpportunityChartImage();

    System.assertNotEquals(null, chartImageUrl);
    System.assertNotEquals('', chartImageUrl);
    System.assert(
      chartImageUrl.startsWith(
        '<img src="https://quickchart.io/chart?width=350&height=200&c='
      )
    );
  }

  @IsTest
  static void testGenerateQuickChartImageUrl() {
    List<String> years = new List<String>{ '2024', '2025', '2026' };
    List<Decimal> saldoData = new List<Decimal>{ 5000, -10000, 15000 };
    List<String> colors = new List<String>{
      'rgb(0, 119, 229)',
      'rgb(255, 0, 0)',
      'rgb(0, 119, 229)'
    };

    String chartUrl = OpportunityDataController.generateQuickChartImageUrl(
      years,
      saldoData,
      colors
    );

    System.assertNotEquals(null, chartUrl);
    System.assertNotEquals('', chartUrl);
    System.assert(
      chartUrl.startsWith(
        '<img src="https://quickchart.io/chart?width=350&height=200&c='
      )
    );
  }

  @IsTest
  static void testGenerateOpportunityChartImageNoData() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);
    opportunity testOpportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.id,
        MunicipioInstalacao__c = 'São Paulo'
      ),
      true
    );

    ApexPages.StandardController sc = new ApexPages.StandardController(
      testOpportunity
    );
    OpportunityDataController controller = new OpportunityDataController(sc);

    String chartImageUrl = controller.getOpportunityChartImage();

    System.assertNotEquals(null, chartImageUrl);
    System.assertNotEquals('', chartImageUrl);
    System.assert(
      chartImageUrl.startsWith(
        '<img src="https://quickchart.io/chart?width=350&height=200&c='
      )
    );
  }

  @IsTest
  static void shouldResolveInvestmentUsingPaybackWhenAvailable() {
    Opportunity opp = new Opportunity(PaybackAnos__c = 2.3);

    Decimal investment = OpportunityDataController.resolveInvestment(
      opp,
      10000
    );
    System.assertEquals(23000, investment);
  }
}
