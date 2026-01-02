@IsTest
private class AttachmentFeedServiceTest {

    @IsTest
    static void shouldPublishFeed() {
        Account acc = new Account(Name = 'Feed Acc');
        insert acc;

        Test.startTest();
        AttachmentFeedService.publishAttachmentNote(acc.Id, new List<String>{'file1.pdf', null, ''}, 'atividade de teste');
        Test.stopTest();

        Integer feedCount = [SELECT count() FROM FeedItem WHERE ParentId = :acc.Id];
        System.assertEquals(1, feedCount);
    }

    @IsTest
    static void shouldRequireParentId() {
        try {
            AttachmentFeedService.publishAttachmentNote(null, new List<String>(), null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Record Id is required.'));
        }
    }
}
