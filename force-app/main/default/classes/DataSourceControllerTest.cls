@IsTest
private class DataSourceControllerTest {
  @IsTest
  static void shouldListObjects() {
    List<Map<String, String>> objs = DataSourceController.getObjectList();
    System.assert(!objs.isEmpty());
  }

  @IsTest
  static void shouldQueryRecords() {
    Account acc = new Account(Name = 'DSC');
    insert acc;

    List<SObject> recs = DataSourceController.getRecords('Account', 'DSC');
    System.assert(!recs.isEmpty());
  }

  @IsTest
  static void shouldDescribeFields() {
    List<Map<String, String>> fields = DataSourceController.getObjectFields(
      'Account'
    );
    System.assert(!fields.isEmpty());

    Map<String, List<Map<String, String>>> categorized = DataSourceController.getObjectFieldsPage(
      'Account'
    );
    System.assert(categorized.containsKey('objectFields'));

    List<Map<String, String>> related = DataSourceController.getRelatedFields(
      'Account'
    );
    System.assert(!related.isEmpty());
  }

  @IsTest
  static void shouldReturnRelationshipFields() {
    List<Map<String, String>> rel = DataSourceController.getRelationshipFields(
      'Case',
      'AccountId'
    );
    System.assert(!rel.isEmpty());
  }
}
