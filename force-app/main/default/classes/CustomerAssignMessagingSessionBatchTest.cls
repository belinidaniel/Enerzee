/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
private class CustomerAssignMessagingSessionBatchTest {

    @IsTest
    static void shouldLinkCaseOnBatch() {
        // Cria Contact/Case com RecordType Jornada_do_Cliente
        Contact c = new Contact(LastName = 'Test');
        insert c;
        Id rtId = [SELECT Id FROM RecordType WHERE SObjectType='Case' AND DeveloperName='Jornada_do_Cliente' LIMIT 1].Id;
        Case cs = new Case(Status='New', Origin='Web', RecordTypeId=rtId, ContactId=c.Id, Subject='Teste');
        insert cs;

        // EndUser com telefone e contact
        MessagingEndUser endUser = new MessagingEndUser(ContactId=c.Id);
        insert endUser;

        MessagingSession session = new MessagingSession(MessagingEndUserId=endUser.Id);
        insert session;

        Test.startTest();
        Database.executeBatch(new CustomerAssignMessagingSessionBatch(), 1);
        Test.stopTest();

        MessagingSession updated = [SELECT CaseId FROM MessagingSession WHERE Id = :session.Id];
        System.assertEquals(cs.Id, updated.CaseId);
    }
}
