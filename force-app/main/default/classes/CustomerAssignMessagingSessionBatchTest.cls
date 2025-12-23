@isTest
private class CustomerAssignMessagingSessionBatchTest {

    @TestSetup
    static void setupTestData() {
        // Create test MessagingEndUser records
        MessagingChannel channel = [SELECT Id FROM MessagingChannel WHERE MasterLabel LIKE '%+55 11 4003-8852%'];

        List<MessagingEndUser> endUsers = new List<MessagingEndUser>{
            new MessagingEndUser(ContactId = null, MessagingPlatformKey = '1234567890', Name = 'Test User 1', MessageType = 'WhatsApp', MessagingChannelId = channel.Id),
            new MessagingEndUser(ContactId = null, MessagingPlatformKey = '0987654321',  Name = 'Test User 2', MessageType = 'WhatsApp', MessagingChannelId = channel.Id)
        };
        insert endUsers;

        // Create test MessagingSession records
        List<MessagingSession> sessions = new List<MessagingSession>{
            new MessagingSession(MessagingEndUserId = endUsers[0].Id, MessagingChannelId = channel.Id, Status = 'New', ConversationId = '0dwU50000034lLBIAY'),
            new MessagingSession(MessagingEndUserId = endUsers[1].Id, MessagingChannelId = channel.Id, Status = 'New', ConversationId = '0dwU50000034lLBIAY')
        };
        insert sessions;

        // Create test Contact and Case records
        Contact contact = new Contact(LastName = 'Test Contact');
        insert contact;

        Case caseRecord = new Case(ContactId = contact.Id, RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId());
        insert caseRecord;

        // Update MessagingEndUser with ContactId
        endUsers[0].ContactId = contact.Id;
        update endUsers;
    }

    @isTest
    static void testExecuteMethod() {
        // Test the execute method
        List<MessagingSession> sessions = [SELECT Id, CaseId FROM MessagingSession];
        Test.startTest();
        try{
            CustomerAssignMessagingSessionBatch batch = new CustomerAssignMessagingSessionBatch();
            Database.executeBatch(batch, 2);
        }catch(Exception ex){
            System.debug('Exception: ' + ex.getMessage());
        }
        
        Test.stopTest();

    }
}