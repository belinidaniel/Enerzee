@IsTest
public class TaskWhatNameTest {
	
    @TestSetup
    private static void testSetup(){
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Contact contact = (Contact) TestFactory.createSObject(new Contact(AccountId = account.Id, LastName = 'Data Test'), true);
        
        Task task = (Task) TestFactory.createSObject(new Task(
            WhatId = account.Id,
            WhoId = contact.Id
        ), true);
        
        
    }

	@IsTest
    private static void shouldGetWhoName(){
        
        List<Task> tasks = [SELECT id, WhatId, Whoid, Subject, Status FROM Task];
        
        Test.startTest();
        TaskWhatName.getWhatName(tasks);
        Test.stopTest();
        
    }    
    
}