@IsTest
private class OpportunityLogViewerControllerTest {
  private static User createAdminUser() {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User u = new User(
      Alias = 'adm2',
      Email = 'admin2_' + DateTime.now().getTime() + '@test.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Admin',
      LanguageLocaleKey = 'pt_BR',
      LocaleSidKey = 'pt_BR',
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'admin2_' + DateTime.now().getTime() + '@test.com',
      ProfileId = p.Id
    );
    insert u;
    return u;
  }

  @IsTest
  static void shouldReturnLogsAndDetails() {
    Account acc = new Account(Name = 'Conta');
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'VO-LOG'
    );
    insert opp;

    Log__c log = new Log__c(
      Name = 'Log',
      RelatedId__c = opp.Id,
      Status__c = '200'
    );
    insert log;

    User admin = createAdminUser();
    System.runAs(admin) {
      System.assertEquals(
        true,
        OpportunityLogViewerController.isCurrentUserAdmin()
      );
      List<Log__c> logs = OpportunityLogViewerController.getLogsByOpportunity(
        opp.Id,
        10
      );
      System.assertEquals(1, logs.size());
      Log__c detail = OpportunityLogViewerController.getLogDetail(log.Id);
      System.assertEquals(log.Id, detail.Id);
    }
  }
}
