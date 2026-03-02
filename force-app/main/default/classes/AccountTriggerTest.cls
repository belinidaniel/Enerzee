@isTest
public class AccountTriggerTest {
  @TestSetup
  static void makeData() {
    Consultor__c seller = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(),
      true
    );
  }

  @isTest
  static void assignSellerToIntegratedClientTest() {
    Consultor__c seller = [
      SELECT Id, IdVirtualOffice__c
      FROM Consultor__c
      WHERE
        RecordTypeID = :Schema.SObjectType.Consultor__c.getRecordTypeInfosByDeveloperName()
          .get('Consultor')
          .getRecordTypeId()
      LIMIT 1
    ];

    Account client = (Account) TestFactory.createSObject(
      new Account(IdExternoConsultor__c = seller.IdVirtualOffice__c),
      true
    );

    client = [
      SELECT Consultor__c
      FROM Account
      LIMIT 1
    ];
    System.assertEquals(seller.Id, client.Consultor__c);
  }

  @isTest
  static void assignCPFCNPJToIdentificationNumberTest() {
    Account account = (Account) TestFactory.createSObject(
      new Account(NumeroIdentificacao__c = null),
      true
    );

    account = [
      SELECT SeCPFouCNPJ__c, NumeroIdentificacao__c
      FROM Account
      WHERE Id = :account.Id
    ];

    System.assertEquals(account.SeCPFouCNPJ__c, account.NumeroIdentificacao__c);
  }

  @isTest
  static void coverageOtherTriggerMethods() {
    Account account = (Account) TestFactory.createSObject(new Account(), true);

    account.Name = 'Teste 2';
    update account;

    delete account;

    AccountTriggerHandler.disableTrigger();
    System.assert(!AccountTriggerHandler.isTriggerEnabled());

    AccountTriggerHandler.enableTrigger();
    System.assert(AccountTriggerHandler.isTriggerEnabled());
  }
}
