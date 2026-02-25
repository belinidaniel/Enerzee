@IsTest
private class ContactBOTest {
  @IsTest
  static void shouldCreateMessagingUserWithoutException() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);

    Contact contact = (Contact) TestFactory.createSObject(
      new Contact(
        AccountId = account.Id,
        LastName = 'Contato Teste',
        Phone = '(11) 99999-9999'
      ),
      true
    );

    setIfWritable(contact, 'Telefone_Formatado__c', '5511999999999');
    update contact;

    Test.startTest();
    ContactBO.createMessagingUser(
      new List<Contact>{ contact },
      new Map<Id, Contact>()
    );
    Test.stopTest();

    System.assert(true, 'Método executado sem exceções.');
  }

  @IsTest
  static void shouldSkipWhenPhoneHasNotChanged() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);

    Contact contact = (Contact) TestFactory.createSObject(
      new Contact(
        AccountId = account.Id,
        LastName = 'Contato Sem Mudança',
        Phone = '(11) 98888-7777'
      ),
      true
    );

    setIfWritable(contact, 'Telefone_Formatado__c', '5511988887777');
    update contact;

    Map<Id, Contact> oldMap = new Map<Id, Contact>{
      contact.Id => contact.clone(true, true, true, true)
    };

    Test.startTest();
    ContactBO.createMessagingUser(new List<Contact>{ contact }, oldMap);
    Test.stopTest();

    System.assert(
      true,
      'Método executado sem exceções para telefone inalterado.'
    );
  }

  private static Boolean setIfWritable(
    SObject record,
    String fieldName,
    Object value
  ) {
    if (record == null || String.isBlank(fieldName)) {
      return false;
    }
    Schema.DescribeFieldResult describe = record
      .getSObjectType()
      .getDescribe()
      .fields
      .getMap()
      .get(fieldName)
      .getDescribe();
    if (describe != null && describe.isUpdateable()) {
      record.put(fieldName, value);
      return true;
    }
    return false;
  }
}
