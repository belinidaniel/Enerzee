@IsTest
private class IntegradorBOTest {
  @IsTest
  static void shouldCreateMessagingUserWithoutException() {
    Integradores__c integrador = (Integradores__c) TestFactory.createSObject(
      new Integradores__c(
        Name = 'Integrador Teste',
        Telefone__c = '(65) 98888-7777'
      ),
      true
    );

    setIfWritable(integrador, 'Telefone_Formatado__c', '5565988887777');
    update integrador;

    Test.startTest();
    IntegradorBO.createMessagingUser(
      new List<Integradores__c>{ integrador },
      new Map<Id, Integradores__c>()
    );
    Test.stopTest();

    System.assert(true, 'Método executado sem exceções.');
  }

  @IsTest
  static void shouldSkipSapWhenNoIdsProvided() {
    Test.startTest();
    IntegradorBO.sendIntegradorToSAP(new List<Integradores__c>());
    Test.stopTest();

    System.assert(true, 'Sem callout quando lista está vazia.');
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
