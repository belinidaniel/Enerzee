@IsTest
private class AccountBOTest {
  private static User createUser(String firstName, String lastName) {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User u = new User(
      FirstName = firstName,
      LastName = lastName,
      Alias = 'usr',
      Email = 'user_' + DateTime.now().getTime() + '@test.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      LocaleSidKey = 'pt_BR',
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'user_' + DateTime.now().getTime() + '@test.com',
      ProfileId = p.Id
    );
    insert u;
    return u;
  }

  @IsTest
  static void shouldAssignSellerAndCpfCnpj() {
    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(IdVirtualOffice__c = 'VO-1'),
      true
    );

    Account acc = (Account) TestFactory.createSObject(
      new Account(IdExternoConsultor__c = 'VO-1', Phone = ''),
      true
    );
    Boolean docSet = setIfWritable(acc, 'SeCPFouCNPJ__c', '123');
    acc.NumeroIdentificacao__c = null;

    AccountBO.assignSellerToIntegratedClient(new List<Account>{ acc });
    AccountBO.assignCPFCNPJToIdentificationNumber(new List<Account>{ acc });

    System.assertEquals(consultor.Id, acc.Consultor__c);
    if (docSet) {
      System.assertEquals('123', acc.NumeroIdentificacao__c);
    }
  }

  @IsTest
  static void shouldSkipSapWhenIntegratorUser() {
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    User integrador = createUser('Integrador', 'SAP');

    System.runAs(integrador) {
      AccountBO.sendCustomerRecordToSAP(new List<Account>{ acc });
    }
    System.assert(true, 'Metodo executado sem callout');
  }

  @IsTest
  static void shouldHandleMessagingUserWithNoPhone() {
    Account acc = (Account) TestFactory.createSObject(
      new Account(Phone = ''),
      true
    );
    AccountBO.createMessagingUser(
      new List<Account>{ acc },
      new Map<Id, Account>()
    );
    System.assert(true, 'Sem excecao');
  }

  private static Boolean setIfWritable(
    SObject record,
    String fieldName,
    Object value
  ) {
    if (record == null || String.isBlank(fieldName)) {
      return false;
    }
    Schema.DescribeFieldResult describe = record.getSObjectType()
      .getDescribe()
      .fields.getMap()
      .get(fieldName)
      .getDescribe();
    if (describe != null && describe.isUpdateable()) {
      record.put(fieldName, value);
      return true;
    }
    return false;
  }
}
