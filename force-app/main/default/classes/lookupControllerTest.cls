@isTest
private class lookupControllerTest {
  @testSetup
  static void setupData() {
    // Creating test data
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'TestAccount' + i, Phone = '1234567890'));
    }
    insert accounts;
  }

  @isTest
  static void testSearchLookupRecords() {
    // Get some inserted account records
    List<Account> accs = [SELECT Id, Name, Phone FROM Account];

    // Prepare inputs
    String searchTerm = 'TestAccount';
    List<String> selectedIds = new List<String>{ accs[0].Id }; // Exclude one record
    String sObjectName = 'Account';
    String field = 'Name';
    String subField = 'Phone';
    Integer maxResults = 10;

    // Call method
    Test.startTest();
    List<lookupController.LookupSearchResult> results = lookupController.searchLookupRecords(
      searchTerm,
      selectedIds,
      sObjectName,
      field,
      subField,
      maxResults
    );
    Test.stopTest();

    // Assertions
    System.assertNotEquals(0, results.size(), 'Expected some search results');
    for (lookupController.LookupSearchResult res : results) {
      System.assertNotEquals(null, res.Id);
      System.assert(res.title.startsWith('TestAccount'));
    }
  }

  @isTest
  static void testGetRecentlyCreatedRecord() {
    // Create and insert a new Account
    Account acc = new Account(Name = 'LatestAccount', Phone = '9876543210');
    insert acc;

    // Prepare inputs
    String sObjectName = 'Account';
    String recordId = acc.Id;
    String field = 'Name';
    String subField = 'Phone';

    // Call method
    Test.startTest();
    lookupController.LookupSearchResult result = lookupController.getRecentlyCreatedRecord(
      sObjectName,
      recordId,
      field,
      subField
    );
    Test.stopTest();

    // Assertions
    System.assertEquals(acc.Id, result.Id);
    System.assertEquals('LatestAccount', result.title);
    System.assertEquals('9876543210', result.subtitle);
  }
}
