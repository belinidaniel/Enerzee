@IsTest
private class ClickSignQueueableTest {
    @IsTest
    static void shouldInsertLogs() {
        ClickSignLog__c log = new ClickSignLog__c(Name = 'Queue Test');

        Test.startTest();
        System.enqueueJob(new ClickSignQueueable(log));
        Test.stopTest();

        System.assertEquals(1, [SELECT count() FROM ClickSignLog__c WHERE Name = 'Queue Test']);
    }
}