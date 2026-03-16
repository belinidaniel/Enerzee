/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class LeadIntegrationSchedulerTest {
  @isTest
  static void testSchedulerExecution() {
    Test.startTest();
    LeadIntegrationScheduler scheduler = new LeadIntegrationScheduler();
    String cronExp = '0 0 0 1 1 ?'; // Run once
    System.schedule('Test LeadIntegrationScheduler', cronExp, scheduler);
    Test.stopTest();
    // No assert needed, just verify no exceptions
  }

  @isTest
  static void testScheduleNowExecution() {
    Test.startTest();
    LeadIntegrationScheduler scheduler = new LeadIntegrationScheduler();
    scheduler.scheduleNowExecution();
    Test.stopTest();
    // No assert needed, just verify no exceptions
  }

  @isTest
  static void testRunMethod() {
    Test.startTest();
    LeadIntegrationScheduler scheduler = new LeadIntegrationScheduler();
    scheduler.execute(null);
    Test.stopTest();
    // No assert needed, just verify no exceptions
  }
}
