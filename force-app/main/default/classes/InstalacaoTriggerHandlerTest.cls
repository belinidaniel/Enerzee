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
