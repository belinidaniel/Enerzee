@IsTest
public class CollectionTest {

    @isTest
    static void test1(){
        List<Account> accounts = new List<Account>{
            (Account) TestFactory.createSObject(new Account(
                Name = 'Foo'
            ), true),
            (Account) TestFactory.createSObject(new Account(
                Name                   = 'Bar',
                CPF__c                 = '234.567.897-56',
                CNPJ__c                = '12.345.678/9012-35',
                IdVirtualOffice__c     = 'klskdjf9-dmz-nf-r93u4-edjl-kdna7',
                NumeroIdentificacao__c = '234.567.897-56'
            ), true)
        };

        List<String> names = Collection.of(accounts).pluckNotNullStrings(Account.Name);
		System.assertEquals(2, names.size());
		System.assertEquals('Foo', names[0]);
		System.assertEquals('Bar', names[1]);

		List<Id> ownerIds = Collection.of(accounts).pluckIds();
		Set<Id> idSet = new Set<Id>(ownerIds);
		System.assertEquals(2, idSet.size());
    }
}