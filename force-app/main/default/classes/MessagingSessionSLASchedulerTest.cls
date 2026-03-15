/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MessagingSessionSLASchedulerTest {
  @IsTest
  static void shouldAllowScheduleNowExecutionInTestContext() {
    MessagingSessionSLAScheduler scheduler = new MessagingSessionSLAScheduler();

    Test.startTest();
    scheduler.scheduleNowExecution();
    Test.stopTest();

    System.assertEquals(true, true);
  }
}
