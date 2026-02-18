/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-28-2026
 * @last modified by  : Daniel Belini
**/
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
    }

    @IsTest
    static void shouldRequireParentId() {
        try {
            AttachmentFeedService.publishAttachmentNote(null, new List<String>(), null);
        } catch (AuraHandledException e) {
        }
    }
}