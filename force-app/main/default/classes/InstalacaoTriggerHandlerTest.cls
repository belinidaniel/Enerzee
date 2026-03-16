/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class InstalacaoTriggerHandlerTest {
  @IsTest
  static void shouldToggleTrigger() {
    InstalacaoTriggerHandler.disableTrigger();
    System.assertEquals(false, InstalacaoTriggerHandler.isTriggerEnabled());
    InstalacaoTriggerHandler.enableTrigger();
    System.assertEquals(true, InstalacaoTriggerHandler.isTriggerEnabled());
  }
}
