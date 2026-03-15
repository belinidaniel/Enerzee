/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignQueueableTest {
  @IsTest
  static void shouldInsertLogs() {
    ClickSignLog__c log = new ClickSignLog__c(Name = 'Queue Test');

    Test.startTest();
    System.enqueueJob(new ClickSignQueueable(log));
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM ClickSignLog__c WHERE Name = 'Queue Test']
    );
  }
}
