/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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

  @IsTest
  static void shouldCoverCaseQueriesAndFieldFilters() {
    Account acc = new Account(Name = 'Conta DSC');
    insert acc;

    Contact contact = new Contact(
      LastName = 'Contato DSC',
      AccountId = acc.Id,
      Email = 'contato.dsc@example.com'
    );
    insert contact;

    Case caseRecord = new Case(
      Subject = 'Caso DSC',
      Status = 'New',
      Origin = 'Phone',
      AccountId = acc.Id,
      ContactId = contact.Id
    );
    insert caseRecord;

    List<SObject> cases = DataSourceController.getRecords(
      'Case',
      caseRecord.CaseNumber
    );
    System.assert(!cases.isEmpty(), 'Deve localizar cases por CaseNumber.');

    List<Map<String, String>> invalidRelationship = DataSourceController.getRelationshipFields(
      'Case',
      'CampoInexistente__c'
    );
    System.assertEquals(
      0,
      invalidRelationship.size(),
      'Campo inválido deve retornar lista vazia.'
    );

    List<Map<String, String>> relatedFields = DataSourceController.getContactAndAccountFields(
      'Case'
    );
    System.assert(
      !relatedFields.isEmpty(),
      'Case deve expor referências para Contact/Account/User.'
    );

    List<Map<String, String>> emailFields = DataSourceController.getEmailField(
      'Contact'
    );
    System.assert(
      !emailFields.isEmpty(),
      'Contact deve retornar ao menos o campo Email.'
    );
  }
}
