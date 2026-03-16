/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProposalCoverTriggerHandlerTest {
  @IsTest
  static void shouldToggleTrigger() {
    ProposalCoverTriggerHandler.disableTrigger();
    System.assertEquals(false, ProposalCoverTriggerHandler.isTriggerEnabled());
    ProposalCoverTriggerHandler.enableTrigger();
    System.assertEquals(true, ProposalCoverTriggerHandler.isTriggerEnabled());
  }
}
