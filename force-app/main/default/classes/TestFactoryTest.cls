@IsTest
private class TestFactoryTest{

    @IsTest
    static void when_objectIsCreated_expect_defaultFieldsArePopulated(){
        //when
        Account a = (Account)TestFactory.createSObject(new Account());
        //then
        System.assertEquals('Test Account - Default', a.Name, 'Expecting Default field value is set to specific value');
    }

    @IsTest
    static void when_objectIsInserted_expect_defaultFieldsArePopulated(){
        //when
        Account a = (Account)TestFactory.createSObject(new Account(),true);
        //then
        a = [SELECT Name FROM Account WHERE Id = :a.Id];
        System.assertEquals('Test Account - Default', a.Name, 'Expecting Default field value is set to specific value');
    }

    @IsTest
    static void when_objectIsCreatedWithSpecificDefaultsSet_expect_defaultFieldsArePopulated(){
        //when
        Account a = (Account)TestFactory.createSObject(new Account(), 'TestFactoryDefaults.PhysicalPersonAccount');
        //then
        System.assertEquals('Test Account - Physical Person', a.Name, 'Expecting Default field value is set to specific value');
    }

    @IsTest
    static void when_objectIsInsertedWithSpecificDefaultsSet_expect_defaultFieldsArePopulated(){
        //when
        Account a = (Account)TestFactory.createSObject(new Account(), 'TestFactoryDefaults.PhysicalPersonAccount', true);
        //then
        System.assertEquals('Test Account - Physical Person', a.Name, 'Expecting Default field value is set to specific value');
    }

    @IsTest
    static void when_ListOfObjectsIsCreated_expect_defaultFieldsArePopulated(){
        //when
        Account[] aList = (Account[])TestFactory.createSObjectList(new Account(), 200);
        //then
        for(Account a : aList){
            System.assert(a.Name.startsWith('Test Account - Default'), 'Expecting Default field value is set to specific value');
        }
    }

    @IsTest
    static void when_ListOfObjectIsInserted_expect_defaultFieldsArePopulated(){
        //when
        Account[] aList = (Account[])TestFactory.createSObjectList(new Account(), 1, true);
        //then
        aList = [SELECT Name FROM Account WHERE Id IN :aList ORDER BY Name];
        for(Account a : aList){
            System.assert(a.Name.startsWith('Test Account - Default'), 'Expecting Default field value is set to specific value');
        }
    }

    @IsTest
    static void when_ListOfObjectsIsCreatedWithSpecificDefaultsSet_expect_defaultFieldsArePopulated(){
        //when
        Account[] aList = (Account[])TestFactory.createSObjectList(new Account(), 200, 'TestFactoryDefaults.PhysicalPersonAccount');
        //then
        for(Account a : aList){
            System.assert(a.Name.startsWith('Test Account - Physical Person'), 'Expecting Default field value is set to specific value');
        }
    }

    @IsTest
    static void when_ListOfObjectsIsInsertedWithSpecificDefaultsSet_expect_defaultFieldsArePopulated(){
        //when
        Account[] aList = (Account[])TestFactory.createSObjectList(new Account(), 1, 'TestFactoryDefaults.PhysicalPersonAccount', true);
        //then
        aList = [SELECT Name FROM Account WHERE Id IN :aList ORDER BY Name];
        for(Account a : aList){
            System.assert(a.Name.startsWith('Test Account - Physical Person'), 'Expecting Default field value is set to specific value');
        }
    }

}